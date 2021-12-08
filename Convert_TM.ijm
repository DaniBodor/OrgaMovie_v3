largeW = 720;
largeH = 720;

smallW = 466;
smallH = 456;

print("\\Clear");

path = "C:\\Users\\dani\\Documents\\MyCodes\\OrgaMovie_v3\\test_data\\_Movies\\_RegistrationMatrices\\Point0000_Seq0000.nd2_TrMatrix.txt";
TransfMatrix = File.openAsString(path);

Matrix_split = split(TransfMatrix, "(RIGID_BODY)");

print(Matrix_split[0]);

for (fr = 1; fr < Matrix_split.length; fr++) {
	// read lines and get coordinates
	lines = split(Matrix_split[fr],"\n");
	
	//print(lines[2]);
	new_cen = split(lines[2],"\t");
	new_top = split(lines[3],"\t");
	new_bot = split(lines[4],"\t");
	
	ori_cen = split(lines[6],"\t");
	ori_top = split(lines[7],"\t");
	ori_bot = split(lines[8],"\t");

	xc = parseFloat(new_cen[0]);
	yc = parseFloat(new_cen[1]);
	x1 = parseFloat(new_top[0]);
	y1 = parseFloat(new_top[1]);
	x2 = parseFloat(new_bot[0]);
	y2 = parseFloat(new_bot[1]);

	// calculate other requirements
	x_shift = (largeW/2) - parseFloat(ori_cen[0]);
	y_shift = (largeH/2) - parseFloat(ori_cen[1]);
	y_factor = (largeH/2) / parseFloat(ori_cen[1]);

	// reshape
	angle = findAngle(x1,y1,x2,y2);
	makeLine(x1, y1, x2, y2);
	run("Rotate...", "  angle=" + -angle);
	run("Scale... ", "x=1 y="+y_factor+" centered");
	run("Rotate...", "  angle=" + angle);
	getLine(x1_, y1_, x2_, y2_, lineWidth);
	makeLine(x1_+x_shift, y1_+y_shift, x2_+x_shift, y2_+y_shift);
	
	getLine(x1_, y1_, x2_, y2_, lineWidth);

	// print results
	/*
	print(x1_);
	print(y1_);
	print(x2_);
	print(y2_);
	*/

	// newlines
	new_line2 = toString(xc + largeW/2 - smallW/2) + "\t" + toString(yc + largeH/2 - smallH/2);
	new_line3 = toString(x1_) + "\t" + toString(y1_);
	new_line4 = toString(x2_) + "\t" + toString(y2_);
	
	new_line6 = d2s(floor(largeW/2),1) + "\t" + d2s(floor(largeH/2),1);
	new_line7 = d2s(floor(largeW/2),1) + "\t" + d2s(floor(largeH/4),1);
	new_line8 = d2s(floor(largeW/2),1) + "\t" + d2s(floor(3*largeH/4),1);

	print("\\Update:RIGID_BODY" + lines[0]);
	//print(lines[0]);
	print(lines[1]);
	print(new_line2);
	print(new_line3);
	print(new_line4);
	print("");
	print(new_line6);
	print(new_line7);
	print(new_line8);
	print("");
	print("");
}

function findAngle(x1,y1,x2,y2){
	// test
	dx = x1-x2;
	dy = y1-y2;
	l = sqrt(dx*dx+dy*dy);
	ratio = dx/l;
	rad = asin(ratio);
	angle = Math.toDegrees(rad);

	return angle
}
