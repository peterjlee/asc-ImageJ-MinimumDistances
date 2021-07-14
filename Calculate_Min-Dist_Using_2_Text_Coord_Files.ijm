/*	ImageJ Macro to calculate minimum distances between two sets of coordinates previously saved as text files. Imports scale from open image if available
	One set contains the origin points.
	8/8/2017 11:39 AM  Peter J. Lee (NHMFL)
	v190802 streamlined code somewhat.
	v191118 Reverted to progress bar and switch "print" to "IJ.log". Uses Table functions introduced in ImageJ 1.52a
	v191119 Added persistent showStatus introduced in ImageJ 1.52s
	v200123 This adds some reassuring information
*/
	macroL = "Calculate_Min-Dist_Using_2_Images_or_Text_Coord_Files_v200123.ijm";
	saveSettings;
	showStatus("!Running Calculate Min-Dist Macro");
	/* Set default pixel size data from active image */
	if (nResults>0) showMessageWithCancel("A results table is already open; do you want to continue?");
	if (nImages>0){
		getPixelSize(unit, pixelWidth, pixelHeight);
		sPs = 5 + lastIndexOf(pixelWidth,0); /* default decimal places */
		imageTitle = getTitle();
	}
	else {
		unit = "pixel";
		pixelWidth = 1;
		pixelHeight = 1;
		sPs = 5; /* default decimal places */
		imageTitle = "none";
	}
	Dialog.create(macroL + ": Options");
	Dialog.addMessage("This macro uses two text files containing sets of coordinates and calculates\nthe minimum distance from each origin point to all destination points");
	Dialog.addMessage("Scale obtained from open image: " + imageTitle);
	Dialog.addNumber("pixelWidth", pixelWidth,sPs,sPs+2,unit);
	Dialog.addNumber("pixelHeight", pixelHeight,sPs,sPs+2,unit);
	Dialog.addMessage("Values in text files will be scaled using the values above");
	Dialog.addString("Override unit with new choice?", unit);
	Dialog.show();
		pixelWidth = Dialog.getNumber();		
		pixelHeight = Dialog.getNumber();
		unit = replace(Dialog.getString(), "(?<![A-Za-z0-9])u(?=m)", fromCharCode(181)); /* convert micrometer units*/;
	lcf=(pixelWidth+pixelHeight)/2; /*---> add here the side size of 1 pixel in the new calibrated units (e.g. lcf=5, if 1 pixels is 5mm) <--- */
	message1 = "XY coordinates in pixels: An origin location file with X in column 1 and Y in column 2 is now required\n\(either a tab separated txt file exported by ImageJ or a csv file\).\nPIXELS: The macro assumes that the imported XY values are in pixels.\nZERO Y AT TOP: Zero Y should be at the top of the image\n - - this is OPPOSITE to the current ImageJ default XY export setting.\n - - To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates\n";
	if (lcf!=1) {
		IJ.log("\nCurrent image pixel width = " + pixelWidth + " " + unit +".\n");
		/* ask for a file to be imported */
		showMessageWithCancel(message1 + "Because of the non-pixel scale scaled distances will also be added: MinRefDist \("+unit+"\), CtrRefDist\("+unit+"\), MaxRefDist\("+unit+"\)");
	}
	else {
		IJ.log("\nNo scale is set; all data is assumed to be in pixels.\n");
		/* ask for a file to be imported */
		showMessageWithCancel(message1 + "Because the image scale is assumed to be in pixels; the macro will generate only pixel distances. New minimum distance measurements will be added to table: MinDist\(px\), NearestDest_X, NearestDest_Y, MinDistAngle");
	}
	fileName = File.openDialog("Select the file to import with X and Y pixel coordinates.");
	showStatus("!Running Calculate Min-Dist Macro with " + fileName);
	allText = File.openAsString(fileName);
	setBatchMode(true);
	fileFormat = substring(fileName, indexOf(fileName,".",lengthOf(fileName)-5));
	if (indexOf(allText,"\n")>=0) text = split(allText, "\n"); /* parse text by newlines */
	else if (indexOf(allText,"\r")>=0) text = split(allText, "\r"); /* parse text by return */
	hdrCount = 0;
	iX = 0; iY = 1;
	coOrds = lengthOf(text);
	xPoints = newArray(coOrds);
	yPoints = newArray(coOrds);
	for (i = 0; i < (coOrds); i++){ /* loading and parsing each line */
		if (indexOf(text[i],",")>=0) line = split(text[i],",");
		else if (indexOf(text[i],"\t")>=0) line = split(text[i],"\t");
		else if (indexOf(text[i],"|")>=0) line = split(text[i],"|");
		else if (indexOf(text[i]," ")>=0) line = split(text[i]," ");
		else restoreExit("No common delimiters found in coordinate file, goodbye.");
		if (isNaN(parseInt(line[iX]))){ /* Do not test line[iY] as it might not exist */
			hdrCount += 1;
		}
		else {
			xPoints[i-hdrCount] = parseInt(line[iX]);
			yPoints[i-hdrCount] = parseInt(line[iY]);
			setResult("X\("+unit+"\)", i-hdrCount, xPoints[i-hdrCount]*lcf);
			setResult("Y\("+unit+"\)", i-hdrCount, yPoints[i-hdrCount]*lcf);
		}
	}
	if (hdrCount > 0){
		coOrds = coOrds-hdrCount;
		xPoints = Array.trim(xPoints, coOrds);
		yPoints = Array.trim(yPoints, coOrds);
	}
	updateResults();
	importReport1 = "Imported " + coOrds + " points from " + fileName + " " +  fileFormat + " point set";
	if (hdrCount!=0) importReport1 += ", ignoring " + hdrCount + " lines of header.";
	IJ.log(importReport1);
	showStatus("!" + importReport1);
	Array.getStatistics(xPoints, minX, maxX, meanX, stdX);
	Array.getStatistics(yPoints, minY, maxY, meanY, stdY);
	IJ.log("Center of Reference Point Set is at x = " + meanX + ", y= " + meanY + " \(px\).");	
	message1 = "A file with destination coordinates X in column 1 and Y in column 2 is now required\n\(either a tab separated txt file exported by ImageJ or a csv file\).";
	if (lcf!=1) {
		/* ask for a destination file to be imported */
		showMessageWithCancel(message1 + "\nThe macro will generate both pixel and scaled information.\n");
		if (isNaN(getResult('X',0)))
			IJ.log("As coordinates from Particles4-8 are never scaled three scaled \(" + unit + "\) columns will be added at the end.");
	}
	else {
		IJ.log("No scale is set; all data is assumed to be in pixels.");
		/* ask for a file to be imported */
		showMessageWithCancel(message1 + "\nBecause the image scale is pixels the macro will generate only pixel distances.");
	}
	fileName = File.openDialog("Select the file to import with X and Y pixel coordinates.");
	allText = File.openAsString(fileName);
	setBatchMode(true);
	startTime = getTime(); /* used for debugging macro to optimize speed */
	
	fileFormat = substring(fileName, indexOf(fileName,".",lengthOf(fileName)-5));
	if (indexOf(allText,"\n")>=0) destText = split(allText, "\n"); /* parse text by newlines */
	else if (indexOf(allText,"\r")>=0) destText = split(allText, "\r"); /* parse text by return */
	destHdrCount = 0;
	iX = 0; iY = 1;
	destCoOrds = lengthOf(destText);
	destXPoints = newArray(destCoOrds);
	destYPoints = newArray(destCoOrds);
	for (i = 0; i < (destCoOrds); i++){ /* loading and parsing each line */
		if (indexOf(destText[i],",")>=0) destLine = split(text[i],",");
		else if (indexOf(destText[i],"\t")>=0) destLine = split(destText[i],"\t");
		else if (indexOf(destText[i],"|")>=0) destLine = split(destText[i],"|");
		else if (indexOf(destText[i]," ")>=0) destLine = split(destText[i]," ");
		else restoreExit("No common delimiters found in coordinate file, goodbye.");
		if (isNaN(parseInt(destLine[iX]))){ /* Do not test destLine[iY] is it might not exist */
			destHdrCount += 1;
		}
		else {
			destXPoints[i-destHdrCount] = parseInt(destLine[iX]);
			destYPoints[i-destHdrCount] = parseInt(destLine[iY]);
		}
	}
	if (destHdrCount > 0){
		destCoOrds = destCoOrds-destHdrCount;
		destXPoints = Array.trim(destXPoints, destCoOrds);
		destYPoints = Array.trim(destYPoints, destCoOrds);
	}
	importReport1 = "Imported " + destCoOrds + " points from " + fileName + " " +  fileFormat + " point set";
	if (destHdrCount!=0) importReport1 += ", ignoring " + destHdrCount + " lines of header.";
	IJ.log(importReport1);	
	// showStatus("!" + importReport1);

	Array.getStatistics(destXPoints, destMinX, destMaxX, destMeanX, destStdX);
	Array.getStatistics(destYPoints, destMinY, destMaxY, destMeanY, destStdY);
	IJ.log("Center of Destination Coordinates Set is at x = " + destMeanX + ", y= " + destMeanY + " \(px\).");
	
/* End of coordinate array filling */
	
	minDists = newArray(coOrds);
	minToX = newArray(coOrds);
	minToY = newArray(coOrds);
	dRef = newArray(coOrds);
	mda =  newArray(coOrds);
	minDistStart = maxX + destMaxX + minY + destMaxY;
	 /* using the minDists[i]>D loop is very slightly faster than using array statistics */
	showStatus("!Looping over " + coOrds + " origination points, testing " + destCoOrds + " destination points");
	for (i=0 ; i<coOrds; i++) {
		showProgress(i, coOrds);
		minDists[i] = minDistStart;
		for (j=0; j<destCoOrds; j++){
			D = sqrt(pow(xPoints[i]-destXPoints[j],2)+pow(yPoints[i]-destYPoints[j],2));
				if (minDists[i]>D) {
					minDists[i] = D; 
					minToX[i] = destXPoints[j];
					minToY[i] = destYPoints[j];
				}
		}
		dRef[i] = sqrt(pow(minToX[i]-meanX,2)+pow(minToY[i]-meanY,2));
		if (lcf!=1 || unit!="pixel"){
			minToX[i] *=lcf;
			minToY[i] *=lcf;
			minDists[i] *=lcf;
			dRef[i] *=lcf;
		}
		mda[i] = (180/PI)*atan((yPoints[i]-minToY[i])/((minToX[i]-xPoints[i])));
		if (mda[i]<0) mda[i] = 180 + mda[i]; 
	}
	/* mda[i]<0 modified angle to match 0-180 FeretAngle */
	if (lcf==1 && unit=="pixel") {
		Table.setColumn("NearestDest_X\(px\)", minToX);
		Table.setColumn("NearestDest_Y(px\)", minToY);
		Table.setColumn("MinDist\(px\)", minDists);
		Table.setColumn("DistToOriginCtr\(px\)", dRef);
	}
	else {
		Table.setColumn("NearestDest_X\("+unit+"\)", minToX);
		Table.setColumn("NearestDest_Y\("+unit+"\)", minToY);
		Table.setColumn("MinDist\(" + unit + "\)", minDists);
		Table.setColumn("DistToOriginCtr\(" + unit + "\)", dRef);
	}	
	Table.setColumn("MinDistAngle\(deg\)", mda);
	updateResults();
		
	Array.getStatistics(minDists, Rmin, Rmax, Rmean, Rstd);
	IJ.log("\nMinimum Distance = " + Rmin + " \(" + unit + "\)\nMaximum Distance = " + Rmax + " \(" + unit + "\)\nMean Distance = " + Rmean + " \(" + unit + "\)\nStd.Dev. = " + Rstd + " \(" + unit + "\)\n");
	elapsed = getTime()- startTime; /* used for debugging macro to optimize speed */
	setBatchMode("exit & display"); /* exit batch mode */
	showStatus("!Min Dist macro completed in " + elapsed/1000 + " seconds");
	beep(); wait(300); beep(); wait(300); beep();
	call("java.lang.System.gc"); 
			
/*-----------functions---------------------*/

	function restoreExit(message){ /* Make a clean exit from a macro, restoring previous settings */
		/* 9/9/2017 added Garbage clean up suggested by Luc LaLonde - LBNL */
		restoreSettings(); /* Restore previous settings before exiting */
		setBatchMode("exit & display"); /* Probably not necessary if exiting gracefully but otherwise harmless */
		call("java.lang.System.gc");
		exit(message);
	}