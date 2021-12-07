
requires("1.53f");	// for Array.filter()

print("\\Clear");
run("Close All");
roiManager("reset");

//%% input parameters

// input settings
input_filetype = "tif";
filesize_limit = 16; // max filesize (in GB)
outdirname = "_Movies";
Z_step = 2.5;		// microns (can this be read from metadata?)
T_step = 3;			// min (can this be read from metadata?)

// layout settings
minBrightnessFactor	= 1;
min_thresh_meth		= "Percentile";
overexp_percile = 0.1;	// unused
saturate = 0.01;	// saturation value used for contrasting
crop_boundary = 24;	// pixels

// header settings
header_height = 48; // pixel height of header
header_fontsize = round(header_height/3);
header_pixoffset = 4;
depth_LUT = "Depth Organoid";
prj_LUT = "The Real Glow";

// scalebar settings
scalebar_size = 25;	// microns (unused)
scalebarOptions = newArray(1, 2, 5, 7.5, 10, 15, 20, 25, 40, 50, 60, 75, 100, 125, 150, 200, 250, 500, 750, 1000, 1500, 2000); /// in microns
scalebarProportion = 0.2; // proportion of image width best matching scale bar width

// progress display settings
intermediate_times = true;
setBatchMode(false);




// find all images in base directory
dir = getDirectory("Choose directory with images to process");
list = getFileList(dir);
im_list = Array.filter(list,"."+input_filetype);

// prep output folders
outdir = dir + outdirname + File.separator;
File.makeDirectory(outdir);
regdir = outdir + "_Registration" + File.separator;
File.makeDirectory(regdir);

// run on all images

for (i = 0; i < im_list.length; i++) {

	// image preliminaries
	
	for (q = 0; q < 3; q++) 	run("Collect Garbage"); // clear memory before opening images
	start = getTime();
	if (intermediate_times)	before = start;
	
	print("__");
	im_name = im_list[i];
	impath = dir + im_name;
	print ("processing:", im_name);
	
	// check filesize and hyperstack-ness
	openFileAndDoChecks(impath);
	
	// if checks not passed, no image will be open at this point
	// and all further steps will be skipped
	if(nImages>0){
		ori = getTitle();
		getPixelSize(pix_unit, pixelWidth, pixelHeight);
		Stack.getDimensions(width, height, channels, slices, frames);

		// make projection & crop
		print("making projection");
		run("Z Project...", "projection=[Max Intensity] all");
		prj = getTitle();
		if (intermediate_times)	before = printTime(before);

		// crop around signal and save projection
		print("first crop around signal");
		findSignalSpace(crop_boundary);
		run("Duplicate...", "duplicate title=PRJ");
		roiManager("select", 0);
		run("Crop");
		crop = getTitle();
		if (intermediate_times)	before = printTime(before);
		
		// find B&C
		print("find brightness & contrast settings");
		setBC();
		getMinAndMax(minBrightness, maxBrightness);
		if (intermediate_times)	before = printTime(before);
		
		// create registration file for drift correction
		print("create registration file");
		run("Tile");
		selectImage(crop);
		setSlice(nSlices/2);
		TransMatrix_File = regdir + im_name + "_TrMatrix.txt";
		run("MultiStackReg", "stack_1="+crop+" action_1=Align file_1="+TransMatrix_File+" stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body] save");
		if (intermediate_times)	before = printTime(before);

		// create depth coded image
		print("create depth-coded movie");
		selectImage(ori);
		depthCoding();
		dep_im = getTitle();
		if (intermediate_times)	before = printTime(before);
		
		// correct drift on depth coded image
		print("correct drift on depth code");
		correctDriftRGB(dep_im);
		dep_reg = getTitle();
		if (intermediate_times)	before = printTime(before);

		// find final crop
		print("output intermediates");
		selectImage(dep_reg);
		findSignalSpace(crop_boundary);

		// crop projections and save
		outputArray = newArray(crop, dep_reg);
		for (x = 0; x < outputArray.length; x++) {
			selectImage(outputArray[x]);	
			roiManager("select", 0);
			run("Crop");
			selectImage(crop);
			saveAs("Tiff", outdir + im_name + "_" + getTitle() + ".tif");
		}
		roiManager("reset");
		if (intermediate_times)	before = printTime(before);

	}
	time = round((getTime() - start)/1000);
	print("image took",time,"seconds to process");

}
run("Tile");
print("----");
print("----");
print("macro end");






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


function openFileAndDoChecks(path){
	filesize = getFileSize(path);
	
	if (filesize > filesize_limit) {
		print("FILE TOO LARGE TO PROCESS");
		print("   file size above size limit");
		print("   consider splitting image or increasing limit");
		print("   this file will be skipped");
	}
	
	else{
		//print("filesize within limit");
		run("Bio-Formats Importer", "open=[&path] use_virtual_stack");
		run("Grays");
		if (!checkHyperstack())	close();
	}
	
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
	run("Enhance Contrast", "saturated=&saturate");
	getMinAndMax(_, maxT);

	// set min and max according to rules above
	if (minT < maxT)	setMinAndMax(minT,maxT);
	else				resetMinAndMax();
}





function getTransformationMatrix(){
	//%% make transformation matrix file
	im = getTitle();
	// register and save matrix
	run("MultiStackReg", "stack_1="+cropped+" action_1=Align file_1="+TransMatrix_File+" stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body] save");
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

function getFileSize(path){
	current = "getFileSize: " + path;
	print(current);
	
	// python code to print filesize to log
	endex = "||";
	py= "path = r'" + path + "'\n" +
		"import os" + "\n" + 
		"size = os.path.getsize(path)" + "\n" +
		"from ij.IJ import log" + "\n" +
		"log(str(size) + '"+endex+"')";
	eval ("python",py);

	// find filesize from logwindow
	L = getInfo("log");
	index1 = indexOf(L, current) + lengthOf(current);
	index2 = indexOf(L, endex);
	size = substring(L,index1,index2);

	// convert to GB
	G = 1073741824;	// bytes in GB
	size = parseInt(size)/G;
	print("\\Update:"+round(size*100)/100 + " GB");

	return size
}


function findSignalSpace(boundary){
	im = getTitle();
	
	// project
	run("Z Project...", "projection=[Max Intensity]");
	if (bitDepth() == 24)	run("8-bit");
	
	// find crop outline
	setAutoThreshold("MinError dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Erode");
	setThreshold(255, 255);
	run("Analyze Particles...", "clear add");
	
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
	run("Select None");
}

function depthCoding(){
	// crop according to previously found size
	roiManager("select", 0);
	run("Duplicate...", "title=hyperstack_region duplicate");
	hstack_crop = getTitle();

	// swap frames and slices 
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	setMinAndMax(minBrightness, maxBrightness);
	run("Temporal-Color Code", "lut=["+depth_LUT+"] start=1 end="+slices);
	depim = getTitle();

	// reset dimensions
	Stack.setXUnit(pix_unit);
	run("Properties...", "channels=1 slices=1 frames="+frames+ " pixel_width="+pixelWidth+" pixel_height="+pixelHeight);
}


function printTime(before){
	after = getTime();
	time = round((after - before)/1000);
	print("    this process took",time,"seconds");
	
	return after;
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
	wleft = getStringWidth(scalemin);
	wright = getStringWidth(scalemax);
	wmax = maxOf(wleft,wright);
	setFont("SansSerif", header_fontsize, "bold antialiased");
	lut_x = 2*header_pixoffset + wmax;
	lut_y = header_height-header_fontsize*1.5-1;
	lut_w = im_width-4*header_pixoffset-2*wmax;
	lut_h = header_fontsize*1.5;


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
	newImage(title, "RGB black", im_width, header_height, frames);
	head = getTitle();
	Stack.setXUnit(pix_unit);
	run("Properties...", "pixel_width="+pixelWidth+" pixel_height="+pixelHeight);

	// create labels on each slice
	for (i = 0; i < nSlices; i++) {
		setSlice(i+1);
		setJustification("center");
		drawString(title, getWidth()/2, header_fontsize + header_pixoffset);			// image title
		drawString(scalemin, (wmax/2+header_pixoffset), getHeight-header_pixoffset);				// left of LUT bar
		drawString(scalemax, getWidth-(wmax/2+header_pixoffset), getHeight-header_pixoffset);	// right of LUT bar

		// draw LUT bar and outline
		Image.paste(lut_x, lut_y)
		drawRect(lut_x, lut_y, lut_w, lut_h);
	}
	close(lut_im);
}


function makeFinalMovie(){
	// apply LUT to normal projection
	selectImage(crop);
	run(prj_LUT);
	setMinAndMax(minBrightness, maxBrightness);
	run("RGB Color");

	// create 2 header images
	header1 = "DEPTH ("+ getInfo("micrometer.abbreviation") + ")";	// DEPTH (micron)
	makeHeaderImage(head1, "d");
	
	header2 = "PROJECTION (AU)";
	makeHeaderImage(head2, "p");

	// run("Scale Bar...", "width=25 height=4 font=14 color=White background=None location=[Lower Left] bold overlay label");
	
	// combine images
	run("Combine...", "stack1=" + dep_reg + " stack2=" + crop);	// main movies
	rename("MAIN");
	run("Combine...", "stack1=" + header1 + " stack2=" + header2); // headers
	rename("HEAD");
	run("Combine...", "stack1=HEAD stack2=MAIN combine"); // headers above movies

	
}
