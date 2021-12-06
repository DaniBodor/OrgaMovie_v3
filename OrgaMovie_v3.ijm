requires("1.53f");	// for Array.filter()

print("\\Clear");

//%% input parameters
minBrightnessFactor	= 1;
min_thresh_meth		= "Percentile";
overexp_percile = 0.5;
input_filetype = "nd2";
filesize_limit = 3; // max filesize (in GB)

// find all images in base directory
dir = getDirectory("Choose directory with images to process");
list = getFileList(dir);
im_list = Array.filter(list,"."+input_filetype);

// run on all images
for (i = 0; i < im_list.length; i++) {
	impath = dir + im_list[i];
	
	filesize = getFileSize(impath);
	
	if (filesize > filesize_limit) {
		print("FILE TOO LARGE TO PROCESS");
		print("   file size above size limit");
		print("   consider splitting image or increasing limit");
		print("   this file will be skipped for now");
	}
	else{
		print("filesize within limit");
		//openFile(impath);
	}
	//print(filesize);
	print("__");
}


//setBC(min_thresh_meth, minBrightnessFactor, overexp_percile)







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


function openFile(path){
	skip = false; // in principle, do not skip analysis for this file?
	
	//%% open files
	run("Bio-Formats Importer", "open=[&path] use_virtual_stack");
	getFileSize();
	
	//%% fix file if not opened as Hyperstack
	
	hstack_check = Property.get("hyperstack");
	if (hstack_check != "true"){
		frames = Property.getNumber("SizeT"); // reads number of frames (T-dimension) from metadata
		z_slices = nSlices/frames;			  // calculates number of Z-slices from total slices in stack and number of frames
		if (isNaN(frames) || round(z_slices) != z_slices) {	// checks if frames can be read from metadata and if all slices and frames are present
			print("file not (opened as) a hyperstack:", filename);
			print("--total number of slices in file:", nSlices);
			print("--number of frames found (from metadata):", frames);
			print("--number of z-slices found (calculated from above):", z_slices);
			print("SKIPPING THIS IMAGE DURING ANALYSIS");
			print("");
			skip = true;	// skip analysis for this file
		}
		else {
			run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+z_slices+" frames="+frames+" display=Grayscale");
		}
	}
	return skip;
}


/*
//%% create projections
selectImage(1);
close("\\Others");
ori = getTitle();
run("Z Project...", "projection=[Max Intensity] all");
prj = getTitle();
run("Z Project...", "projection=[Max Intensity]");
t_prj = getTitle();
*/


function setBC(min_thresh_meth, minBrightnessFactor, OE_perc){
	//%% select center frame for determining B&C
	selectImage(prj);
	setSlice(nSlices/2);

	setAutoThreshold(min_thresh_meth);
	getThreshold(no,minT);
	minT = minT * minBrightnessFactor;

	makeRectangle(getWidth/2, 0, getWidth/2, getHeight);
	maxT = getPercentile(OE_perc);
		
	//setAutoThreshold(max_thresh_meth);
	//getThreshold(no,maxT);
	if(maxT <= minT)	resetMinAndMax();
	else				setMinAndMax(minT,maxT);

}





function getTransformationMatrix(base_folder){
	//%% make transformation matrix file
	selectImage(prj);
	run("Duplicate...", "duplicate");
	prj_reg = getTitle();
	TransMatrix_File = base_folder + "TrMatrix.txt";
	
	run("MultiStackReg", "stack_1="+prj_reg+" action_1=Align file_1="+TransMatrix_File+" stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body] save");

	return TransMatrix_File;
}

function correct_drift(im, TransMatrix_File){
	// %% use transformatin matrix to correct drift
	run("MultiStackReg", "stack_1="+im+" action_1=[Load Transformation File] file_1=["+TransMatrix_File+"] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body]");
}



function autoCrop(minSize, extraBoundary) { // DB
	selectImage(t_prj);
	run("Select None");

	//%% find areas with signal
	setAutoThreshold("Percentile dark");
	getThreshold(lower, upper);
	setThreshold(lower*0.95, upper);
	run("Analyze Particles...", "size="+minSize+"-Infinity pixel clear add");

	if (nResults > 0) {
		//%% select largest ROI
		area = -1;
		largest_roi = 0;
		
		for (r = 1; r < nResults; r++) {
			curr_area = getResult("Area", r);
			if (curr_area > area){
				area = curr_area;
				largest_roi = r;
			}
		}

		//%% select largest region
		roiManager("select", largest_roi);
		getBoundingRect(x, y, width, height);
		roiManager("reset");
		makeRectangle(x-extraBoundary, y-extraBoundary, width+2*extraBoundary, height+2*extraBoundary)
		//roiManager("add");
		//roiManager("rename", "Crop1");

		//%% crop images
		for (i = 0; i < nImages; i++) {
			selectImage(i);
			roiManager("select", 0)
			run("Crop");
		}
	}
	
	// in case no region is found use entire image
	/*else {
		run("Select All");
		roiManager("add");
		roiManager("rename", "Crop1");
	}*/
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
	newImage("" + nBands + "_bands", "8-bit black", W, H, 1);
	
	for (i = 0; i < nBands; i++) {
		BW = getWidth()/nBands;
		CW = 256/nBands;
		
		makeRectangle(0+BW*i, 0, W, getHeight);
		setColor(CW*(i+0.5));
		fill();

		run("Select None");
		setColor(1000000000);
	}
	run("Depth Organoid");
	
}

function getFileSize(path){
	current = "getFileSize: " + path;
	print(current);
	
	// python code to print filesize to log
	endex = "||";
	py= "path = '" + path + "'\n" +
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
