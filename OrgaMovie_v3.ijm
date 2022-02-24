//requirements
requires("1.53f");	// for Array.filter()
requireLUTs();	// checks if relevant LUTs are available

// preliminaries
closeWindows();
fixTemporalColorCode();		// fixes a bug in the Temporal Color Code plugin (might be obsolete after FiJi update, but has no negative effect)


//// SELECT SETTINGS
//get settings from dialog
output_options = newArray("avi & tif", "avi only", "tif only");
fetchSettings();
InputSettings = List.getList;

// move recurring setttings into variables
do_registration = List.get("driftcorrect");
depth_LUT = List.get("depth_LUT");
prj_LUT = List.get("prj_LUT");
intermed_times = List.get("intermed_times");
setBatchMode(List.get("run_in_bg"));	// buggy, always off

// memory allocation & BatchMode
IJmem = parseInt(IJ.maxMemory())/1073741824;	// RAM available to IJ according to settings (GB)
chunkSizeLimit = IJmem/4;						// chunks of 1/4 of available memory ensure that 16bit images will be processed without exceeding memory
if (List.get("reduceRAM")) chunkSizeLimit = chunkSizeLimit / 2;	// in case someone runs into RAM problems, this should be sufficient
print("\\Update:size limit for 16-bit chunks is", round(chunkSizeLimit*10)/10, "GB");


//// SETTINGS NOT IN DIALOG
// visual settings
min_thresh_meth = "Percentile";
crop_threshold = "MinError";
// filename settings
outdirname = "_OrgaMovies";
tempname_col = "_TEMP_PRJCOL_";
tempname_max = "_TEMP_PRJMAX_";
// header & scalebar settings
header_height = 48; // pixel height of header
fontsize = round(header_height/3);
header_pixoffset = 4;
setFont("SansSerif", fontsize, "antialiased");
scalebarOptions = newArray(1, 2, 5, 7.5, 10, 15, 20, 25, 40, 50, 60, 75, 100, 125, 150, 200, 250, 500, 750, 1000, 1500, 2000); /// in microns


///	INPUT/OUTPUT
// select input
dir = getDirectory("Choose directory with images to process");
list = getFileList(dir);
im_list = Array.filter(list,"." + List.get("extension"));

// prep output folder
outdir = dir + outdirname + File.separator;
if (im_list.length > 0) File.makeDirectory(outdir);
else	{
	printDateTime("");
	print("***MACRO ABORTED***");
	print("no files with extension:",List.get("extension"));
	print("were found in: "+dir);
	exit(getInfo("log"));
}


////////////////////////////////////////////// START MACRO //////////////////////////////

print("____________________________\n");
printDateTime("running OrgaMovie macro on: "+ dir);
print("____________________________\n");

for (im = 0; im < im_list.length; im++) {
	// image preliminaries
	dumpMemory(3);
	start = getTime();
	if (intermed_times)	before = start;
	
	im_name = im_list[im];
	impath = dir + im_name;
	outname_base = File.getNameWithoutExtension(im_name);
	
	// read how many parts image needs to be opened in based on chunkSizeLimit
	chunksArray = fileChunks(impath); // returns: newArray(nImageParts,sizeT,chunkSize);
	nImageParts = chunksArray[0];
	sizeT		= chunksArray[1];
	chunkSize	= chunksArray[2];
	
	if (nImageParts > 1)	print("image is too large to process at once and will be processed in", nImageParts, "parts instead");

	// PROCESS IMAGE CHUNKS
	for (ch = 0; ch < nImageParts; ch++) {
		if (nImageParts > 1)	print("____ now processing part",ch+1,"of",nImageParts,"____");
		run("Close All");	//backup in case something remained open by accident; avoids bugs
		
		// open chunk
		t_begin = (chunkSize * ch) + 1;
		t_end   = chunkSize * (ch + 1);
		print("opening file");
		run("Bio-Formats Importer", "open=["+impath+"] t_begin="+t_begin+" t_end="+t_end+" t_step=1" +
					" c_begin="+List.get("input_channel")+" c_end="+List.get("input_channel")+" c_step=1"+
					" autoscale color_mode=Grayscale specify_range view=Hyperstack stack_order=XYCZT");

		// get chunk info
		if (nImageParts > 1)	rename(outname_base + "_" + IJ.pad(t_begin,4) + "-" + IJ.pad(t_end,4));
		ori = getTitle();
		getPixelSize(pix_unit, pixelWidth, pixelHeight);
		Stack.getDimensions(width, height, channels, slices, frames);
		if (intermed_times)	before = printTime(before);

		// make projection
		print("making projection");
		run("Z Project...", "projection=[Max Intensity] all");
		rename(tempname_max+ori);
		prj = getTitle();

		// find B&C (on first chunk, then maintain throughout)
		if (ch == 0){
			print("\\Update:making projection + finding brightness & contrast settings");
			setBC();
			getMinAndMax(minBrightness, maxBrightness);
		}
		if (intermed_times)	before = printTime(before);
		
		// create depth coded image
		print("create depth-coded movie");
		selectImage(ori);
		depthCoding();
		dep_im = getTitle();
		if (intermed_times)	before = printTime(before);

		// save intermediates
		print("saving chunk");
		outputArray = newArray(prj,dep_im);
		for (i = 0; i < outputArray.length; i++) {
			selectImage(outputArray[i]);
			saveAs("Tiff", outdir + getTitle());
			close();
		}
		close(ori);
		if (intermed_times)	before = printTime(before);
	}


	// ASSEMBLE ALL CHUNKS INTO FINAL OUTPUT
	
	// open MAX projections
	print("re-opening all max projections");
	run("Image Sequence...", "select=["+outdir+"] dir=["+outdir+"] type=16-bit filter="+tempname_max+" sort");
	rename("PRJMAX");
	prj_concat = getTitle();
	deleteIntermediates(tempname_max, outdir);

	// crop around signal and save projection
	print("  first crop and registration");
	findSignalSpace(List.get("crop_boundary"));
	roiManager("select", roiManager("count")-1);
	run("Crop");
	if (intermed_times)	before = printTime(before);
	
	// create registration file for drift correction
	if (do_registration){
		print("create registration file");
		selectImage(prj_concat);
		setSlice(nSlices/2);
		TransMatrix_File = outdir + outname_base + "_TrMatrix.txt";
		run("MultiStackReg", "stack_1="+prj_concat+" action_1=Align file_1=["+TransMatrix_File+"] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body] save");
		run(prj_LUT);
		if (intermed_times)	before = printTime(before);
	}

	// open and crop COLOR projections
	print("re-opening all color projections");
	run("Image Sequence...", "select=["+outdir+"] type=RGB dir=["+outdir+"] filter="+tempname_col+" sort");
	rename("PRJCOL");
	rgb_concat = getTitle();
	roiManager("select", roiManager("count")-1);
	run("Crop");
	deleteIntermediates(tempname_col, outdir);
	if (intermed_times)	before = printTime(before);

	// correct drift on depth coded image
	if (do_registration){
		print("  correct drift on depth code");		
		correctDriftRGB(rgb_concat);
		if (intermed_times)	before = printTime(before);
	}

	// find final crop region
	print("process separate images");
	selectImage(prj_concat);
	if (do_registration)	findSignalSpace(List.get("crop_boundary"));
	else {
		run("Select All");
		roiManager("add");
	}

	// prep and save separate projections
	outputArray = newArray(prj_concat, rgb_concat);
	for (x = 0; x < outputArray.length; x++) {
		selectImage(outputArray[x]);
		
		// crop image
		roiManager("select", roiManager("count")-1);
		run("Crop");
		run("Remove Overlay");	// fix for overlay box in RGB (obsolete?)
		run("Select None");
		
		// save image
		if (List.get("saveSinglePRJs")){
			saveAs("Tiff", outdir + outname_base + "_" + getTitle());
			rename(outputArray[x]);	// fixes renaming after saving
		}

		// create scale bar and time stamp
		timeStamper();
		scalebarsize = findScalebarSize();
		run("Scale Bar...", "width="+scalebarsize+" height=2 font="+fontsize+" color=White background=None location=[Lower Right] label");
	}
	if (intermed_times)	before = printTime(before);

	// create and save final movie
	print("assemble into OrgaMovie");
	fuseImages();
	savename = outdir + outname_base + "_OrgaMovie";
		//output_options = newArray("*.avi AND *.tif", "*.avi only", "*.tif only");	// TO SEE FORMAT OF OUTPUT OPTIONS ARRAY
	if (List.get("out_format") != output_options[1])
		saveAs("Tiff", savename);
	if (List.get("out_format") != output_options[2])
		run("AVI... ", "compression=JPEG frame="+List.get("framerate")+" save=[" + savename + ".avi]");
	if (intermed_times)	before = printTime(before);

	// close stuff
	//run("Tile");
	run("Close All");
	roiManager("reset");
	if (do_registration){
		File.delete(TransMatrix_File);
		print("\\Update:");
	}

	// final print & logsave
	printDateTime("Finished processing "+im_name);
	time = round((getTime() - start)/1000);
	timeformat = d2s(floor(time/60),0) + ":" + IJ.pad(time%60,2);
	
	if (intermed_times)		print("    image took",timeformat,"(min:sec) to process");
	print("____________________________");
	selectWindow("Log");
	saveAs("Text", outdir + "Log_InProgress.txt");
}



// FINISHING TOUCHES
dumpMemory(3); // clear memory
print("----");
print("----");
printDateTime("All done; " + im +" movies processed");
LogString = getInfo("log");
LogArray = split(LogString, "\n");
datetime = substring(LogArray[LogArray.length-1],0,15);
datetime = datetime.replace(" ","_");
datetime = datetime.replace(":","");

print("Run finished");
selectWindow("Log");
saveAs("Text", outdir + "Log_"+datetime+".txt");
File.delete(outdir + "Log_InProgress.txt");
print("\\Update:");

////////////////////////////////////// FUNCTIONS //////////////////////////////////////
////////////////////////////////////// FUNCTIONS //////////////////////////////////////
////////////////////////////////////// FUNCTIONS //////////////////////////////////////

function fileChunks(path){
	print_statement = "check and open file: " + path;
	printDateTime(print_statement);

	// get file size
	filesize = getFileSize(path);

	// read metadata
	run("Bio-Formats Importer", "open=["+path+"] display_metadata view=[Metadata only]");
	MD_window = getInfo("window.title");
	MD = getInfo("window.contents");
	MD_lines = split(MD,"\n");	// metadata as array of separate lines (index 0 is header)
	close(MD_window);

	// find image bitdepth
	bitsPerPix = split(MD_lines[1],"\t");	// metadata line 1 contains bitdepth
	bitsPerPix = bitsPerPix[1];			// index 0 is key, index 1 is value
	if (bitsPerPix == 8){
		true_chunkSizeLimit = chunkSizeLimit/1.5;	// 8-bit images do not get compressed before opening
		print("image is 8-bit; size limit adjusted to", round(true_chunkSizeLimit*10)/10, "GB");
	}
	else true_chunkSizeLimit = chunkSizeLimit;

	// calculate how many chunks it needs to be opened in
	line8 = split(MD_lines[8],"\t"); // metadata line 8 contains contains info on number of channels
	sizeC = parseInt(line8[1]);		 // index 0 is key, index 1 is value
	
	line9 = split(MD_lines[9],"\t"); // metadata line 9 contains contains info on number of time steps
	sizeT = parseInt(line9[1]);		 // index 0 is key, index 1 is value

	nImageParts_max = Math.ceil(filesize/true_chunkSizeLimit/sizeC);	// nImageparts based on size limit
	chunkSize = Math.ceil(sizeT/nImageParts_max); // calculate number of time steps per chunk
	nImageParts_true = Math.ceil(sizeT/chunkSize); // corrects nImageParts because some chunks could contain 0 frames

	// return file chunk parameters
	return newArray(nImageParts_true,sizeT,chunkSize);
}

function getFileSize(path){

	// python code to print filesize to log (can't find how to do this from IJ)
	endex = "||";
	py= "path = r'" + path + "'\n" +
		"import os" + "\n" + 
		"size = os.path.getsize(path)" + "\n" +
		"from ij.IJ import log" + "\n" +
		"log(str(size) + '"+endex+"')";
	eval ("python",py);

	// read filesize from logwindow
	L = getInfo("log");
	index1 = indexOf(L, print_statement) + lengthOf(print_statement);
	index2 = indexOf(L, endex);
	size = substring(L,index1,index2);

	// convert to GB
	G = 1073741824;	// bytes in GB
	size = parseInt(size)/G;
	print("\\Update:  "+round(size*100)/100 + " GB");

	return size;
}

function checkHyperstack(){
	
	// check if hyperstack
	hstack_check =  Stack.isHyperstack;
	
	if (!hstack_check){
		//%% if not hstack: check if error would occur upon conversion
		frames = Property.getNumber("SizeT"); // reads number of frames (T-dimension) from metadata
		z_slices = nSlices/frames;			  // calculates number of Z-slices from total slices in stack and number of frames
		if (isNaN(frames) || round(z_slices) != z_slices) {	// checks if frames can be read from metadata and if all slices and frames are present
			print("file not (opened as) a hyperstack:", filename);
			print("--total number of slices in file:", nSlices);
			print("--number of frames found (from metadata):", frames);
			print("--number of z-slices found (calculated from above):", z_slices);
			print("SKIPPING THIS IMAGE DURING ANALYSIS");
			print("");
		}
		// if no error: convert to hyperstack and proceed with analysis
		else {
			run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+z_slices+" frames="+frames+" display=Grayscale");
			hstack_check = true;
		}
	}
	return hstack_check;
}


function setBC(){
	//%% select center frame for determining B&C
	selectImage(prj);
	setSlice(nSlices/2);

	// get min brightness setting of threshold method
	setAutoThreshold(min_thresh_meth);
	getThreshold(_,minT);
	minT = minT * List.get("minBrightFactor");
	
	// get max brightness setting based on percentile of overexposed pixels
	//maxT = getPercentile(overexp_percile);
	run("Enhance Contrast", "saturated="+List.get("satpix"));
	getMinAndMax(_, maxT);

	// set min and max according to rules above
	if (minT < maxT)	setMinAndMax(minT,maxT);
	else				resetMinAndMax();
}



function correctDriftRGB(im){
	// %% use transformatin matrix to correct drift
	
	// split channels
	selectImage(im);
	pre = getTitle();
	run("Split Channels");
	
	// do registration on each channel
	names = newArray("RED","GREEN","BLUE");
	for (c = 0; c < 3; c++) {
		selectImage(nImages-2+c);
		rename(names[c]);
		run("MultiStackReg", "stack_1=["+names[c]+"] action_1=[Load Transformation File] file_1=["+TransMatrix_File+"] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body]");
	}
	run("Merge Channels...", "c1=[RED] c2=[GREEN] c3=[BLUE]");
	rename(pre);
}



function getPercentile(percile){
	getSelectionBounds(x0, y0, w, h);
	run("Select None");
	
	a = newArray(w*h);
	i = 0;
	
	for (y=y0; y<getHeight; y++)
		for (x=x0; x<getWidth; x++)
			a[i++] = getPixel(x,y);
	Array.sort(a);
	
	perc_pos = a.length * (1 - percile/100);
	perc_value = a[perc_pos];
	
	return perc_value;
}



function createDepthLegend(nBands, W, H){
	newImage("" + nBands + "_bands_header", "8-bit black", W, H, 1);
	
	for (i = 0; i < nBands; i++) {
		BW = getWidth()/nBands;
		CW = 256/nBands;
		
		makeRectangle(0+BW*i, 0, W, getHeight);
		setColor(CW*(i+0.5));
		fill();

		run("Select None");
	}
	run(depth_LUT);
	
}


function findSignalSpace(boundary){
	im = getTitle();
	
	// project
	run("Z Project...", "projection=[Max Intensity]");
	if (bitDepth() == 24)	run("8-bit");
	
	// find crop outline
	setAutoThreshold(crop_threshold + " dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Erode");
	setThreshold(255, 255);

	roiManager("reset");
	minSize = 10000;
	while (roiManager("count") == 0){
		run("Analyze Particles...", "size="+minSize+"-Infinity clear add");
		minSize = minSize/2;
	}
	
	if (roiManager("count") > 1){
		roiManager("deselect");
		roiManager("Combine");
	}
	else roiManager("select", 0);
	getSelectionBounds(x, y, width, height);
	close();
	roiManager("reset");
	
	// crop before registration
	selectImage(im);
	makeRectangle(x-boundary, y-boundary, width+2*boundary, height+2*boundary);
	roiManager("add");
	roiManager("Show None");
	run("Select None");
}

function depthCoding(){

	// prep image (swap frames/slices -> 8-bit -> set B&C
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	setMinAndMax(minBrightness, maxBrightness);
	wait(500);	// avoids a crash
	run("8-bit");
	run("Grays");
	dumpMemory(1);
	

	// run color coding
	precolorname = getTitle();
	if (List.get("run_in_bg"))	run("Temporal-Color Code", "lut=["+depth_LUT+"] start=1 end="+slices+" batch");
	else						run("Temporal-Color Code", "lut=["+depth_LUT+"] start=1 end="+slices);
	rename(tempname_col + precolorname);
	dumpMemory(3);

	// reset dimensions
	Stack.setXUnit(pix_unit);
	run("Properties...", "channels=1 slices=1 frames="+frames+ " pixel_width="+pixelWidth+" pixel_height="+pixelHeight);
}


function findScalebarSize(){
	// get ideal width for scale bar
	fullW = getWidth() * pixelWidth;
	idealW = fullW * List.get("scalebartarget") / 100;

	// initialize in case full width is smaller than all options 
		// (unlikely, but don't want any chance of a crash)
	returnValue = fullW;
	minDiff = fullW;
	
	// find scale that closest matches ideal
	for (i = 0; i < scalebarOptions.length; i++) {
		diff = abs(scalebarOptions[i] - idealW);
		if (diff < minDiff) {
			returnValue = scalebarOptions[i];
			minDiff = diff;
		}
	}

	// return best match scalebar size
	return returnValue;
}

function makeHeaderImage(title, type){
	im_width = getWidth();
	
	// type has to be "D" for depth or "P" for projection
	type = type.toUpperCase;

	// specify LUT min/max labels depending on type
	if (type == "D"){
		scalemin = "0";
		maxD = parseFloat(List.get("Z_step")) * (slices-1);	// max depth of organoid
		maxD = round(maxD*10)/10;	// make max 1 decimal long
		scalemax = toString(maxD);	// convert to string
	}
	else if (type == "P"){
		scalemin = "min";
		scalemax = "max";
	}


	// sizes (move some of these to input parameters?)
	wleft = getStringWidth(scalemin)+4;
	wright = getStringWidth(scalemax)+4;
	wmax = maxOf(wleft,wright);
	lut_x = 2*header_pixoffset + wmax;
	lut_y = header_height-fontsize*1.5-1;
	lut_w = im_width-4*header_pixoffset-2*wmax;
	lut_h = fontsize*1.5;


	// create LUT bar image
	if (type == "D"){
		createDepthLegend(slices, lut_w, lut_h);
	}
	else if (type == "P"){
		newImage(prj_LUT+"_header", "8-bit ramp", lut_w, lut_h, 1);
		run(prj_LUT);
	}
	lut_im = getTitle();
	run("RGB Color");
	Image.copy;
	setColor(255,255,255);

	// create header image
	newImage(title, "RGB black", im_width, header_height, sizeT);
	head = getTitle();
	Stack.setXUnit(pix_unit);
	run("Properties...", "pixel_width="+pixelWidth+" pixel_height="+pixelHeight);

	// create labels on each slice
	for (i = 0; i < nSlices; i++) {
		setSlice(i+1);
		setJustification("center");
		drawString(title, getWidth()/2, fontsize + header_pixoffset);			// image title
		drawString(scalemin, (wmax/2+header_pixoffset), getHeight-header_pixoffset);				// left of LUT bar
		drawString(scalemax, getWidth-(wmax/2+header_pixoffset), getHeight-header_pixoffset);	// right of LUT bar

		// draw LUT bar and outline
		Image.paste(lut_x, lut_y)
		drawRect(lut_x, lut_y, lut_w, lut_h);
	}
	close(lut_im);
}


function fuseImages(){
	// apply LUT to normal projection
	selectImage(prj_concat);
	run(prj_LUT);
	setMinAndMax(minBrightness, maxBrightness);
	run("RGB Color");

	// create 2 header images
	header1 = "DEPTH ("+ getInfo("micrometer.abbreviation") + ")";	// DEPTH (micron)
	makeHeaderImage(header1, "d");
	rename("HEAD1");
	
	header2 = "PROJECTION (AU)";
	makeHeaderImage(header2, "p");
	rename("HEAD2");
	
	// combine images
	run("Combine...", "stack1=" + rgb_concat + " stack2=" + prj_concat);	// main movies
	rename("MAIN");
	run("Combine...", "stack1=HEAD1 stack2=HEAD2"); // headers
	rename("HEADS");
	run("Combine...", "stack1=HEADS stack2=MAIN combine"); // headers above movies

	for (n = 0; n < nSlices; n++) {
		setSlice(n+1);
		setColor(128,128,128);
		drawLine(getWidth()/2, 0, getWidth()/2, getHeight());
	}
}

function deleteIntermediates(filestart, directory){
	L = getFileList(directory);
	for (i = 0; i < L.length; i++) {
		if (startsWith(L[i], filestart)){
			File.delete(directory + L[i]);

			// this prints a 1, which I want to get rid of...
			LogString = getInfo("log");
			LogString = substring(LogString, 0, lengthOf(LogString)-3);
			print("\\Clear");
			print(LogString);
		}
	}
}


function timeStamper(){
	main = getTitle();
	//create new image to place timestamp in
	newImage("TimeStamp", "8-bit black", getWidth, fontsize+5, nSlices);
	run("Colors...", "foreground=white");
	timebar = getTitle();
	
	// initialize
	startframe = 0;
	starttime = 0;
	
	// loop through epochs
	for (i = 0; i < List.get("epochs"); i++) {
		// get stepsize and duration of epoch
		T_step = parseFloat(List.get("Epoch"+i+"_Tstep"));
		duration = parseInt(List.get("Epoch"+i+"_Duration"));
		if (duration == 0){
			endframe = nSlices;	// duration set to 0 means until end of movie
			i += 10000;			// end loop after this
		}
		else endframe = minOf(startframe + duration, nSlices);	// otherwise duration set in number of frames

		// set x position of stamp (required for movies of >100h)
		endtime = (endframe-startframe) * T_step + starttime;
		if (endtime/60 < 100)	label_x = getStringWidth("0");
		else					label_x = 0;

		// stamp time
			// (used 00:00:00-format instead of 00:00-format, because the latter would reset after 60h)
		print(startframe, endframe, starttime, duration);
		run("Label...", "format=00:00:00 starting="+starttime*60+" interval="+T_step*60+" x="+label_x+" y=0 font="+fontsize+" range="+startframe+"-"+endframe);
		
		// now delete the final :00
		makeRectangle(getStringWidth("000:00"), 0, getWidth, getHeight);
		run("Clear", "stack");
		run("Select None");
		
		// set for next loop/end of movie
		startframe = endframe;
		starttime = starttime + T_step*duration;
		if (i == 0)	starttime = starttime - T_step; // fixes t=0 at slice 1 issue
	}
exit;
	// PLACEHOLDER combine with main	
}



function closeWindows(){
	while (isOpen("Exception"))	close("Exception");

	// show warning?
	A = nImages;
	B = roiManager("count");
	C = nResults;
	D = getInfo("log");
	if (A+B+C>0)	waitForUser("Close all without saving?", "All open images, ROI lists, results, log text, etc will be closed without saving.\n\n"+
								"Click OK to continue.");

	// preliminaries
	print("\\Clear");	
	run("Close All");
	roiManager("reset");
	Table.reset();
	dumpMemory(3);
}


function printTime(before){
	after = getTime();
	time = round((after - before)/1000);
	print("    this process took",time,"seconds");
	
	return after;
}



function printDateTime(suffix){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);

	yr = substring (d2s(year,0),2);
	mth = IJ.pad(month+1,2);
	day = IJ.pad(dayOfMonth,2);
	date = yr + mth + day;

	h 	= IJ.pad(hour,2);
	min = IJ.pad(minute,2);
	sec = IJ.pad(second,2);
	time = h + ":" + min + ":" + sec;

	print(date, time, "-", suffix);
}


function dumpMemory(n){
	for (i = 0; i < n; i++) 	run("Collect Garbage");
}


function fixTemporalColorCode(){
	// fixes a bug in the Temporal Color Code plugin
	plugindir = getDirectory("plugins");
	path = plugindir + "Scripts" + File.separator + "Image" + File.separator + "Hyperstacks" + File.separator + "Temporal-Color_Code.ijm";
	TCC_code = File.openAsString(path);
	
	oldline = "lutA = makeLUTsArray";
	newline = "lutA = getList(\"LUTs\"); //makeLUTsArray";
	newTCC = TCC_code.replace(oldline,newline);
	
	File.saveString(newTCC, path);
}


function requireLUTs(){
	LUTlist = getList("LUTs");
	X = Array.filter(LUTlist,"Depth Organoid");
	Y = Array.filter(LUTlist,"The Real Glow");
	
	if(X.length * Y.length == 0){
		run("LUTs");
		waitForUser("Add LUTs to folder","Please copy or move \"Depth Organoid.lut\" and \"The Real Glow.lut\" \n"+
					"from the LUT folder in the location into which you downloaded OrgaMovie\n" +
					"into FiJi's LUT folder, which should have just opened."+
					"\n \nThen restart FiJi.");
		exit("restart FiJi after installing LUTs");
	}
}


function fetchSettings(){
	// load default settings
	default_settings();
	List.toArrays(def_keys, def_values);

	// load previous settings
	settings_dir = getDirectory("macros") + "settings" + File.separator;
	File.makeDirectory(settings_dir);
	settings_file = settings_dir + "OrgaMovie_v3.txt";
	if(File.exists(settings_file)){
		settings_string = File.openAsString(settings_file);
		List.setList(settings_string);
		
		// in case any default settings are missing from saved file, add these back
			// e.g. due to new settings added in updates or due to corruption of the settings file
		List.toArrays(load_keys, load_values);
		for (i = 0; i < def_keys.length; i++) {
			filtered = Array.filter(load_keys,def_keys[i]);	// either empty array or array of length 1
			present = lengthOf(filtered);	// should output 0 or 1 --> can be used as boolean
			if ( !present )		List.set(def_keys[i], def_values[i]);
		}
	}


	
	// dialog settings/layout
	showdialogwindow = 1;
	colw = 8;
	title_fontsize = 15;
	github = "https://github.com/DaniBodor/OrgaMovie_v3#input-settings";
	LUTlist = getList("LUTs");
	print("\\Clear");
	
	// open dialog
	while (showdialogwindow) {
		Dialog.createNonBlocking("OrgaMovie Settings");
			Dialog.addHelp(github);
			
			Dialog.setInsets(10, 0, 0);
			Dialog.addMessage("Input/output settings",title_fontsize);
			Dialog.setInsets(0, 0, -2);
			Dialog.addString("Input filetype", List.get("extension"), colw-2);
			Dialog.addNumber("Input channel", List.get("input_channel"), 0, colw, "");
			Dialog.addNumber("Time interval", List.get("T_step"), 0, colw, "min");
			//Dialog.setInsets(-28, 250, 0);	// might go to shit on Mac
			//Dialog.setInsets(0, 40, 0);
			//Dialog.addToSameRow();
			Dialog.addNumber("Time-lapse epochs", List.get("epochs"));
			Dialog.addNumber("Z-step", List.get("Z_step"), 1, colw, getInfo("micrometer.abbreviation"));
			Dialog.addChoice("Output format", output_options, List.get("out_format"));
			Dialog.setInsets(0, 40, 0);
			Dialog.addCheckbox("Save separate projections", List.get("saveSinglePRJs"));
		
			Dialog.setInsets(20, 0, 0);
			Dialog.addMessage("\nMovie settings",title_fontsize);
			Dialog.setInsets(0, 0, 0);
			Dialog.addNumber("Frame rate", List.get("framerate"), 0, colw, "frames / sec");
			Dialog.setInsets(2, 40, -2);
			Dialog.addCheckbox("Apply drift correction", List.get("driftcorrect"));
			Dialog.addChoice("Depth coding", LUTlist, List.get("depth_LUT"));
			Dialog.addChoice("Projection LUT", LUTlist, List.get("prj_LUT"));
			Dialog.addNumber("Pixel saturation", List.get("satpix"), 2, colw, "%");
			Dialog.addNumber("Min intensity factor", List.get("minBrightFactor"), 1, colw, "");
			Dialog.addNumber("Crop boundary", List.get("crop_boundary"), 0, colw, "pixels");
			Dialog.addNumber("Scalebar target width", List.get("scalebartarget"), 0, colw, "% of total width");
		
			Dialog.setInsets(20, 0, 0);
			Dialog.addMessage("ImageJ settings",title_fontsize);
			Dialog.setInsets(0, 40, 0);
			Dialog.addCheckbox("Reduce RAM usage", List.get("reduceRAM"));
			Dialog.setInsets(0, 40, 0);
			Dialog.addCheckbox("Print progress duration", List.get("intermed_times"));
			//Dialog.setInsets(0, 40, 0);
			//Dialog.addCheckbox("Run in background (doesn't work yet)", List.get("run_in_bg"));
			Dialog.setInsets(0, 40, 0);
			Dialog.addCheckbox("Save these settings for next time", 0);
			Dialog.setInsets(0, 40, 0);
			if (showdialogwindow)	Dialog.addCheckbox("Load defaults (will show this window again)", 0);
		
		Dialog.show();
			// move settings from dialog window into a key/value list
	
			// input/output settings
			List.set("extension", replace(Dialog.getString(),".",""));
			List.set("input_channel", Dialog.getNumber());
			List.set("T_step", Dialog.getNumber());
			List.set("epochs", Dialog.getNumber());
			List.set("Z_step", Dialog.getNumber());
			List.set("out_format", Dialog.getChoice());
			List.set("saveSinglePRJs", Dialog.getCheckbox());
	
			//movie settings
			List.set("framerate", Dialog.getNumber());
			List.set("driftcorrect", Dialog.getCheckbox());
			List.set("depth_LUT", Dialog.getChoice());
			List.set("prj_LUT", Dialog.getChoice());
			List.set("satpix", Dialog.getNumber());
			List.set("minBrightFactor", Dialog.getNumber());
			List.set("crop_boundary", Dialog.getNumber());
			List.set("scalebartarget", Dialog.getNumber());	// proportion of image width best matching scale bar width
	
			//imagej settings
			List.set("reduceRAM", Dialog.getCheckbox());
			List.set("intermed_times", Dialog.getCheckbox());
			List.set("run_in_bg",0);	//buggy; don't understand why. see github issues for info on bug
			//List.set("run_in_bg",Dialog.getCheckbox());
			
			// the following 2 settings are not exported
			export_settings = Dialog.getCheckbox();
			if (Dialog.getCheckbox() )	default_settings();
			else showdialogwindow = 0;
	}

	// dynamic time settings
	nEpochs = parseInt(List.get("epochs"));
	if (nEpochs > 1){
		Dialog.create("Dynamic Time Settings");
		Dialog.addMessage("Set interval and duration (in hours) for each time-lapse sequence.\n"+
							"  You can set duration to 0 for the final epoch (all further epochs will be ignored).");

		// add a step size and duration setting for each epoch
		for (x = 0; x < nEpochs; x++) {
			Tx = "Epoch"+x+"_Tstep";
			Dx = "Epoch"+x+"_Duration";
			
			if (List.get(Tx) == "") List.set(Tx,List.get("T_step"));
			if (List.get(Dx) == "") List.set(Dx,0);

			Dialog.addNumber("Time interval "+x, List.get(Tx), 0, colw, "min");
			Dialog.addNumber("Duration "+x, List.get(Dx), 0, colw, "hours");
			Dialog.setInsets(15, 0, 3);
		}
			Dialog.addCheckbox("Indicate time switch in movie?", List.get("show_switch") );
	
		Dialog.show();
		for (x = 0; x < nEpochs; x++) {
			List.set("Epoch"+x+"_Tstep", Dialog.getNumber());
			List.set("Epoch"+x+"_Duration", Dialog.getNumber());
		}
		List.set("show_switch",	Dialog.getCheckbox());
	}
	else {
		List.set("Epoch0_Tstep",List.get("T_step"));
		List.set("Epoch0_Duration",0);
	}

	
	InputSettings = List.getList;
	if (export_settings)	File.saveString(InputSettings, settings_file);

	//print settings
	print("Input settings from dialog:");
	print(" ",InputSettings.replace("\n","\n  "));	// kinda funky way to make it print all the settings with 2 spacess before
}


function default_settings(){
	List.clear();
	// input/output settings
	List.set("extension", "nd2");
	List.set("input_channel", 1);
	List.set("T_step", 3);
	List.set("epochs", 1);
	List.set("Z_step", 2.5);
	List.set("out_format", "*.avi AND *.tif");
	List.set("saveSinglePRJs", 0);
	//movie settings
	List.set("framerate", 18);
	List.set("driftcorrect", 1);
	List.set("depth_LUT", "Depth Organoid");
	List.set("prj_LUT","The Real Glow");
	List.set("satpix", 0.1);
	List.set("minBrightFactor", 1);
	List.set("crop_boundary", 24);
	List.set("scalebartarget", 20);
	//imagej settings
	List.set("reduceRAM", 0);
	List.set("intermed_times", 0);
	List.set("run_in_bg", false);
	// dynamic time settings
	List.set("Epoch0_Duration",18*20+1);	//first 18 hours
	List.set("Epoch1_Tstep",10);
	List.set("show_switch",0);
}