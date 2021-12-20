
requires("1.53f");	// for Array.filter()


// input/output settings
input_filetype = "tif";
IJmem = parseInt(IJ.maxMemory())/1073741824;	// RAM available to IJ according to settings (GB)
chunkSizeLimit = IJmem/4;	// chunks of 1/4 of available memory ensure that 16bit images will be processed without exceeding memory
//chunkSizeLimit = 0.2; // max filesize (in GB) --> make this a ratio of the max allocated memory to IJ
outdirname = "_OrgaMovies";
Z_step = 2.5;		// microns (can this be read from metadata?)
T_step = 3;			// min (can this be read from metadata?)
framerate = 18;		//fps

// visual settings
minBrightnessFactor	= 1;
min_thresh_meth		= "Percentile";
overexp_percile = 0.1;	// unused
saturate = 0.01;	// saturation value used for contrasting
crop_threshold = "MinError";
crop_boundary = 24;	// pixels

// header settings
header_height = 48; // pixel height of header
fontsize = round(header_height/3);
header_pixoffset = 4;
depth_LUT = "Depth Organoid";
prj_LUT = "The Real Glow";
setFont("SansSerif", fontsize, "antialiased");

// scalebar settings
scalebar_size = 25;	// microns (unused)
scalebarOptions = newArray(1, 2, 5, 7.5, 10, 15, 20, 25, 40, 50, 60, 75, 100, 125, 150, 200, 250, 500, 750, 1000, 1500, 2000); /// in microns
scalebarProportion = 0.2; // proportion of image width best matching scale bar width

// progress display settings
intermediate_times = true;
run_in_background = false;	//apparently buggy; don't understand why. see github issues for info on bug


////////////////////////////////////////////// START MACRO //////////////////////////////

// preliminaries
print("\\Clear");
run("Close All");
roiManager("reset");
setBatchMode(run_in_background);	// bug, see above
dumpMemory(3);

// find all images in base directory
dir = getDirectory("Choose directory with images to process");
list = getFileList(dir);
im_list = Array.filter(list,"."+input_filetype);
printDateTime("running OrgaMovie macro on: "+ dir);
print("size limit for 16-bit images is", round(chunkSizeLimit*10)/10, "GB");
print("");

// prep output folders
outdir = dir + outdirname + File.separator;
if (im_list.length > 0) File.makeDirectory(outdir);
else	{
	printDateTime("");
	print("***MACRO ABORTED***");
	print("no files containing:",input_filetype);
	print("were found in: "+dir);
	exit(getInfo("log"));
}



// start running on all images
for (im = 0; im < im_list.length; im++) {

	// image preliminaries
	dumpMemory(3);
	start = getTime();
	if (intermediate_times)	before = start;
	
	im_name = im_list[im];
	impath = dir + im_name;
	outname_base = File.getNameWithoutExtension(im_name);
	
	// read how many parts image needs to be opened in based on chunkSizeLimit
	chunksArray = fileChunks(impath); // returns: newArray(nImageParts,sizeT,chunkSize);
	nImageParts = chunksArray[0];
	sizeT		= chunksArray[1];
	chunkSize	= chunksArray[2];
	
	if (nImageParts > 1)	print("image is too large to process at once and will be processed in", nImageParts, "parts instead");

	// open chunks one by one
	for (ch = 0; ch < nImageParts; ch++) {
		if (nImageParts > 1)	print("____ now processing part",ch+1,"of",nImageParts,"____");
		run("Close All");	//backup in case something remained open by accident; avoids bugs
		
		// open chunk
		t_begin = (chunkSize * ch) + 1;
		t_end   = chunkSize * (ch + 1);
		run("Bio-Formats Importer", "open=["+impath+"] t_begin="+t_begin+" t_end="+t_end+" t_step=1" +
					" autoscale color_mode=Grayscale specify_range view=Hyperstack stack_order=XYCZT");
		// if (!checkHyperstack())	close();		// decide whether/where/how to use this...

		if (nImageParts > 1)	rename(outname_base + "_" + IJ.pad(t_begin,4) + "-" + IJ.pad(t_end,4));
		ori = getTitle();
		getPixelSize(pix_unit, pixelWidth, pixelHeight);
		Stack.getDimensions(width, height, channels, slices, frames);

		// make projection
		print("making projection");
		run("Z Project...", "projection=[Max Intensity] all");
		rename("PRJ"+getTitle());
		prj = getTitle();
		if (intermediate_times)	before = printTime(before);

		// find B&C (on first chunk, then maintain)
		if (ch == 0){
			print("find brightness & contrast settings");
			setBC();
			getMinAndMax(minBrightness, maxBrightness);
			if (intermediate_times)	before = printTime(before);
		}
		
		// create depth coded image
		print("create depth-coded movie");
		if (nImageParts == 1){
			// ######## add crop function here to speed up depth coding
			_ = 1;	// placeholder
		}
		selectImage(ori);
		depthCoding();
		dep_im = getTitle();
		if (intermediate_times)	before = printTime(before);

		// save intermediates
		outputArray = newArray(prj,dep_im);
		for (i = 0; i < outputArray.length; i++) {
			selectImage(outputArray[i]);
			saveAs("Tiff", outdir + getTitle());
			close();
		}
		close(ori);
	}
	
	// Now assemble separate parts, register and make OrgaMovie
	print("____ opening max projection of all parts ____");
	run("Image Sequence...", "select="+outdir+" dir="+outdir+" type=16-bit filter=PRJMAX_ sort");
	rename("PRJ");
	prj_concat = getTitle();
	deleteIntermediates("PRJMAX", outdir);
	if (intermediate_times)	before = printTime(before);

	// crop around signal and save projection
	print("first crop and registration");
	findSignalSpace(crop_boundary);
	roiManager("select", roiManager("count")-1);
	run("Crop");
	
	// create registration file for drift correction
	print("create registration file");
	selectImage(prj_concat);
	setSlice(nSlices/2);
	TransMatrix_File = outdir + outname_base + "_TrMatrix.txt";
	run("MultiStackReg", "stack_1="+prj_concat+" action_1=Align file_1=["+TransMatrix_File+"] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body] save");
	run(prj_LUT);
	if (intermediate_times)	before = printTime(before);


	// open MAX and COLOR- projections
	print("opening color projection of all parts");
	run("Image Sequence...", "select="+outdir+" type=RGB dir="+outdir+" filter=PRJCOL_ sort");
	rename("PRJCOL_" + outname_base);
	rgb_concat = getTitle();
	deleteIntermediates("PRJCOL", outdir);
	if (intermediate_times)	before = printTime(before);

	// correct drift on depth coded image
	print("correct drift on depth code");
	roiManager("select", roiManager("count")-1);
	run("Crop");
	
	correctDriftRGB(rgb_concat);
	dep_reg = getTitle();
	if (intermediate_times)	before = printTime(before);

	// find final crop
	print("output intermediates");
	selectImage(prj_concat);
	findSignalSpace(crop_boundary);


	// prep and save separate projections
	outputArray = newArray(prj_concat, dep_reg);
	for (x = 0; x < outputArray.length; x++) {
		selectImage(outputArray[x]);
		// crop image
		roiManager("select", roiManager("count")-1);
		run("Crop");
		run("Remove Overlay");	// fix for overlay box in RGB (obsolete?)
		run("Select None");

		saveAs("Tiff", outdir + outname_base + "_" + getTitle());
		rename(outputArray[x]);	// fixes renaming after saving

		// create scale bar and time stamp
		scalebarsize = findScalebarSize();
		run("Scale Bar...", "width="+scalebarsize+" height=2 font="+fontsize+" color=White background=None location=[Lower Right] label");
		timeStamper();
	}
	if (intermediate_times)	before = printTime(before);

	// create and save final movie
	print("assemble into OrgaMovie");
	fuseImages();
	savename = outdir + outname_base + "_OrgaMovie";
	saveAs("Tiff", savename);
	run("AVI... ", "compression=JPEG frame="+framerate+" save=[" + savename + ".avi]");
	roiManager("reset");
	if (intermediate_times)	before = printTime(before);

	printDateTime("Finished processing "+im_name);
	time = round((getTime() - start)/1000);
	timeformat = d2s(floor(time/60),0) + ":" + IJ.pad(time%60,2);
	if (intermediate_times)		print("    image took",timeformat,"min to process");
	run("Close All");

	File.delete(TransMatrix_File);
	print("\\Update:____________________________");
	selectWindow("Log");
	saveAs("Text", outdir + "Log.txt");
}
//run("Tile");
for (q = 0; q < 3; q++) 	run("Collect Garbage"); // clear memory
print("----");
print("----");
printDateTime("run finished");






//% STEPS TO TAKE IN MACRO
// check filesizes; if too large allow for splitting?
	// do this via python os if IJ does not have good tools to measure filesize
	// or do via metadata (open crop) SizeC*SizeT*SizeX*SizeY*SizeZ*2^BitsPerPixel/(Bits/GB)
	// or: open virtual stack, metadata has filesize (key: Size)
// open file
	// check for hyperstack
	// if not, retry once?
// generate Z-project
	// apply LUT
	// store for later (for right hand side of movie)
// generate drift correction matrix
	// Z-project
	// multistackreg
		// could this be done on final product instead? 
			// NO, doesn not appear to work on RGBs
// find ideal B&C
	// what is substrate for this? maybe the Z-projection or potentially a Z/T-projection?
// make color-projection for each frame
	// remove single frame (Z-stack)
		// alternatively, open single frame
	// temporal color code
// apply drift correction on final product
// add time-stamp & depth-legend
// save final
	// export options
		// AVI
		// TIFF compiled (large file)
		// TIFF split (separate smaller files, can be stored in 8bit grayscale to save MBs, then can add separate package to compile each part in LUT of choice)


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
	nImageParts_max = Math.ceil(filesize/true_chunkSizeLimit);	// nImageparts based on size limit
	line9 = split(MD_lines[9],"\t"); // metadata line 9 contains contains info on number of time steps
	sizeT = parseInt(line9[1]);		 // index 0 is key, index 1 is value
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
	minT = minT * minBrightnessFactor;
	
	// get max brightness setting based on percentile of overexposed pixels
	//maxT = getPercentile(overexp_percile);
	run("Enhance Contrast", "saturated="+saturate);
	getMinAndMax(_, maxT);

	// set min and max according to rules above
	if (minT < maxT)	setMinAndMax(minT,maxT);
	else				resetMinAndMax();
}



function correctDriftRGB(im){
	// %% use transformatin matrix to correct drift
	
	// split channels
	selectImage(im);
	run("Duplicate...", "duplicate");
	run("Split Channels");
	
	// do registration on each channel
	names = newArray("RED","GREEN","BLUE");
	for (c = 0; c < 3; c++) {
		selectImage(nImages-2+c);
		rename(names[c]);
		run("MultiStackReg", "stack_1=["+names[c]+"] action_1=[Load Transformation File] file_1=["+TransMatrix_File+"] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body]");
	}
	run("Merge Channels...", "c1=[RED] c2=[GREEN] c3=[BLUE]");
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
	if (run_in_background)	run("Temporal-Color Code", "lut=["+depth_LUT+"] start=1 end="+slices+" batch");
	else					run("Temporal-Color Code", "lut=["+depth_LUT+"] start=1 end="+slices);
	rename("PRJCOL_" + precolorname);
	dumpMemory(3);

	// reset dimensions
	Stack.setXUnit(pix_unit);
	run("Properties...", "channels=1 slices=1 frames="+frames+ " pixel_width="+pixelWidth+" pixel_height="+pixelHeight);
}


function findScalebarSize(){
	// get ideal width for scale bar
	fullW = getWidth() * pixelWidth;
	idealW = fullW * scalebarProportion;

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
		maxD = Z_step * (slices-1);	// max depth of organoid
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
	run("Combine...", "stack1=" + dep_reg + " stack2=" + prj_concat);	// main movies
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
			Log = getInfo("log");
			Log = substring(Log, 0, lengthOf(Log)-3);
			print("\\Clear");
			print(Log);
		}
	}
}


function timeStamper(){
	// fix offsetting bug of time stamper in 00:00 format
	w_dec_form = getStringWidth("00:00");
	w_num_form = getStringWidth(toString(frames*T_step)+"_");
	x_corr = w_dec_form - w_num_form;
	x_pos = 2 + x_corr;

	// stamp time
	run("Colors...", "foreground=white");
	run("Time Stamper", "starting=0 interval="+T_step+" x="+x_pos+" y="+getHeight-2+" font="+fontsize+" '00 decimal=0 anti-aliased or=_");
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
