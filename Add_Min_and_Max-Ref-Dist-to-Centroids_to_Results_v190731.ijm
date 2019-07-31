/*	This macro determines the minimum and maximum distances for all objects compared to a reference file of XY coordinates.
	It adds 20 new columns to the results table - which is perhaps a little excessive!
		Conversions to pixel data based on scale factor: X\(px\), Y\(px\), XM\(px\), YM\(px\), BX\(px\), BY\(px\), Width\(px\), Height\(px\).
		New minimum distance measurements: MinDist\(px\), MinLocX, MinLocY, MinDistAngle, Feret_MinDAngle_Offset.
		New minimum distance to average \(~center\) location of reference set: DistToRefCtr\(px\).
		New maximum distance measurements: MaxDist\(px\), MaxLocX, MaxLocY.
		Scaled distances: MinRefDist \("+unit+"\), CtrRefDist\("+unit+"\), MaxRefDist\("+unit+"\).
	Text file import is based on an imageJWiki Example "Last modified: 2013/11/28 13:47 by borovec"
	http://imagejdocu.tudor.lu/doku.php?id=macro:multiple_points
	Array sorting based on macro example: http://rsb.info.nih.gov/ij/macros/examples/ArraySortingDemo.txt
	Mod Peter J. Lee (NHMFL) to calculate minimum and maximum distances from reference file of xy coordinates 5/5/2016,
	mod 6/10/2016 to be universal regardless of scale and method (I hope). Added angular offsets 7/20/2016.
	v170503 adds a message box with a some description of the required reference file
	v170504 garbage collection
	v180323 Cleanup up some redundant code and tried to make macro smarter about removing header (and NaN) rows.
	v180604 Add option to convert coordinate reference values to "Analyze" pixel centroids by adding 0.5 pixels to X and Y.
	v190706 Removed unnecessary ROI requirement, fixed unclosed comment area, introduced Table functions, added delimiter test for coordinate file.
	v190722 Added additional output options, including reverting to imported coordinates. Preferences are saved.
	v190723 New table columns can be relabeled using a global prefix and/or suffix. v190723b Min and Lax lines can be drawn as overlays. v190725 LUTs can be used to color code lines according to table values.
	v190731 Calibrated imported XY values can be used if they are to the same scale as the active image.
*/

macro "Add Min and Max Reference Distances Analyze Results Table" {
	requires("1.52a"); /* For table functions */
	getPixelSize(unit, pixelWidth, pixelHeight);
	imageTitle = getTitle();
	userPath = getInfo("user.dir");
	prefsNameKey = "ascMinMaxRefDistPrefs.";
	delimiter = "|";
	prefsAddedColsString = call("ij.Prefs.get", prefsNameKey+"AdedCols", "None");
	prefsAddedColsString = replace(prefsAddedColsString, "_unit_", unit);
	prefsCentroids = call("ij.Prefs.get", prefsNameKey+"Centroids", "None");
	prefsAddedCols = split(prefsAddedColsString,delimiter);
	nRes = nResults;
	if (nRes==0) exit("This macro requires that you have already run Analyze or Particles to obtain object coordinates.");
	saveSettings(); /* To restore settings at the end */
	/* Set options for black objects on white background as this works better for publications */
	run("Options...", "iterations=1 white count=1"); /* Set the background to white */
	run("Colors...", "foreground=black background=white selection=yellow"); /* Set the preferred colors for these macros */
	setOption("BlackBackground", false);
	run("Appearance...", " "); if(is("Inverting LUT")) run("Invert LUT"); /* do not use Inverting LUT */
	/* The above should be the defaults but this makes sure (black particles on a white background) http://imagejdocu.tudor.lu/doku.php?id=faq:technical:how_do_i_set_up_imagej_to_deal_with_white_particles_on_a_black_background_by_default
	*/
	print("");
	print("Macro: " + getInfo("macro.filepath"));
	print("Image analyzed: " + getTitle());
	setBatchMode(true);
	tableHeadings = split(String.getResultsHeadings);
	if (indexOfArray(tableHeadings,"X",-1)<0 && indexOfArray(tableHeadings,"XM",-1)<0 && indexOfArray(tableHeadings,"BX",-1)<0 && indexOfArray(tableHeadings,"X\(px\)",-1)<0 && indexOfArray(tableHeadings,"XM\(px\)",-1)<0 && indexOfArray(tableHeadings,"ROI_BX\(px\)",-1)<0 && indexOfArray(tableHeadings,"mc_X\(px\)",-1)<0)
		restoreExit("This macro requires that you have already run Analyze or Particles to obtain object coordinates.");
	lcf=(pixelWidth+pixelHeight)/2; /*---> add here the side size of 1 pixel in the new calibrated units (e.g. lcf=5, if 1 pixel is 5 mm) <---
	*/
	description1 = "Results Table coordinates assumed to be in " + unit + ".\n     A reference location file with X in column 1 and Y in column 2 is now required\n     \(either a tab separated txt file exported by ImageJ or a csv file\).\n     ";
	importXY = "To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates.\n";
	zeroAtTop = "ZERO Y AT TOP: Zero Y should be at the top of the image.\n     This is OPPOSITE to the current ImageJ default XY export setting.";
	if (lcf!=1) {
		print("Current image pixel width = " + pixelWidth + " " + unit +".");
		/* ask for a file to be imported */
		message1 = description1 + "      The macro will generate both pixel and scaled information.\n \n" + zeroAtTop + " \n \n" + importXY + "\nThe macro adds the following conversions to pixel data based on 1 pixel = " + lcf + " " + unit + ":\n     X\(px\), Y\(px\), XM\(px\), YM\(px\), BX\(px\), BY\(px\), Width\(px\), Height\(px\)\n";
		impCals = newArray("pixels","same as image","exit");
	}
	else {
		print("No scale is set; all data is assumed to be in pixels.");
		/* ask for a file to be imported */
		message1 = description1 + "Because the image scale is pixels the macro will generate only pixel distances.\n \n" + zeroAtTop + "\n \n" + importXY;
		impCals = newArray("pixels","exit");
	}
	Dialog.create("Calibration for Imported Coordinates");
		Dialog.addMessage(message1);
		Dialog.addRadioButtonGroup("Calibration of imported coordinates: ", impCals,1,3,"pixels");
	Dialog.show;
		impCal = Dialog.getRadioButton;
	if (impCal == "exit") restoreExit("Sorry, I am not sophisticated enough to handle mixed calibrations.");
	else if (impCal == "pixels") unitP = "pixels";
	else unitP = unit;
	if (indexOfArray(tableHeadings,"X",-1)<0 && lcf!=1)
		print("As coordinates from Particles4-8 are never scaled three scaled \(" + unit + "\) columns will be added at the end.");
	fileName = File.openDialog("Select the file to import with X and Y " + unitP + " coordinates.");
	allText = File.openAsString(fileName);
	if (impCal == "pixels"){
		Dialog.create("Pixel center correction");	
			Dialog.addMessage("Exported pixel coordinates use the top left the pixel but analyzed object coordinates\nare based on the center of the pixel.\n \nTo correct for this you can add 0.5 pixels to the imported X and Y coordinates.")
			Dialog.addCheckbox("Convert pixel coordinates to Analyze pixel centers? \(Add 0.5 pixels to X and Y\)", true);
			Dialog.addMessage("Subsequently revert the discovered MinLoc/MaxLoc coordinates to match imported values\nwhen saving to the Results table \(MinLoc X&Y and MaxLoc X&Y only\).")
			Dialog.addCheckbox("Revert new MinLoc/MaxLoc coordinates to match imported values? \(Subtract 0.5 pixels from X and Y\)", true);
			Dialog.show;
			coordToCtr = Dialog.getCheckbox();
			revertToImportedXY = Dialog.getCheckbox();
		if (!coordToCtr && revertToImportedXY) {
			areUShure = getBoolean("Are you sure you want to revert the unconverted coordinates?");
			if (!areUShure) revertToImportedXY = false;
		}
	}
	else { 
		coordToCtr = false;
		revertToImportedXY = false;
	}
	fileFormat = substring(fileName, indexOf(fileName,".",lengthOf(fileName)-5));
	// if (endsWith(fileName, ".txt")) fileFormat = "txt"; /* for input is in TXT format with tab */
	// else if (endsWith(fileName, ".csv")) fileFormat = "csv"; /* for input is in CSV format */
	// else restoreExit("Selected file is not in a supported format \(.txt or .csv\)");	 /* in case of any other format */
	text = split(allText, "\n"); /* parse text by lines */
	hdrCount = 0;
	iX = 0; iY = 1;
	coOrds = lengthOf(text);
	xpoints = newArray(coOrds);
	ypoints = newArray(coOrds);
	for (i = 0; i < (coOrds); i++){ /* loading and parsing each line */
		if (indexOf(text[i],",")>=0) line = split(text[i],",");
		else if (indexOf(text[i],"\t")>=0) line = split(text[i],"\t");
		else if (indexOf(text[i],"|")>=0) line = split(text[i],"|");
		else if (indexOf(text[i],"0")>=0) line = split(text[i]," ");
		else restoreExit("No common delimiters found in coordinate file, goodbye.");
		if (isNaN(parseInt(line[iX]))){ /* Do not test line[iY] is it might not exist */
			hdrCount += 1;
		}
		else {
			xpoints[i-hdrCount] = parseInt(line[iX]);
			ypoints[i-hdrCount] = parseInt(line[iY]);
			if (unitP!="pixels"){
				xpoints[i-hdrCount] /= lcf;
				ypoints[i-hdrCount] /= lcf;
			}
			else if (coordToCtr) { /* assumes that calibrated coordinates will not have 0.5 pixels offset issue */
				xpoints[i-hdrCount] += 0.5;
				ypoints[i-hdrCount] += 0.5;
			}
		}
	}
	if (hdrCount > 0){
		coOrds = coOrds-hdrCount;
		xpoints = Array.trim(xpoints, coOrds);
		ypoints = Array.trim(ypoints, coOrds);
	}
	importReport1 = "Imported " + coOrds + " points from " + fileName + " " +  fileFormat + " point set";
	if (hdrCount==0) print(importReport1);	
	else print(importReport1 + ", ignoring " + hdrCount + " lines of header.");
	/* loading and parsing each line */
	Array.getStatistics(xpoints, minx, maxx, meanx, stdx);
	Array.getStatistics(ypoints, miny, maxy, meany, stdy);
	importReport2 = "Center of Reference Point Set is at x = " + meanx + ", y= " + meany + " \(" + unitP + "\).\n";
	importReport3 = "Reference Point Set Range x: " + minx + " - " + maxx + ", y: " + miny + " - " + maxy + " \(" + unitP + "\).";
	print(importReport2,importReport3);
	/* Imported pixel coordinates are more typically used for this macro so for consistency the pixel values will be created for the results table as well as calibrated final results */
	lcfs = newArray(nRes);
	Array.fill(lcfs, lcf);
	Table.setColumn("lcfc", lcfs); /* just a trick to use a variable in a table macro in anticipation of using variables in future imageJ versions */
	pxXCoords = newArray("");
	pxColumns = newArray("");
	/* generate new pixel columns if not in Results table */
	if (indexOfArray(tableHeadings,"Pixels",-1)<0 && lcf!=1) {
		if (indexOfArray(tableHeadings,"X\(px\)",-1)<0 && indexOfArray(tableHeadings,"X",-1)>=0) {
			Table.applyMacro("Xpx = X/lcfc");
			Table.applyMacro("Ypx = Y/lcfc");
			Table.renameColumn("Xpx", "X\(px\)");
			Table.renameColumn("Ypx", "Y\(px\)");
		}
		if (indexOfArray(tableHeadings,"XM\(px\)",-1)<0 && indexOfArray(tableHeadings,"XM",-1)>=0)  {
			Table.applyMacro("XMpx=XM/lcfc");
			Table.applyMacro("YMpx=YM/lcfc");
			Table.renameColumn("XMpx", "XM\(px\)");
			Table.renameColumn("YMpx","YM\(px\)");
		}
		if (indexOfArray(tableHeadings,"BX\(px\)",-1)<0 && indexOfArray(tableHeadings,"BX",-1)>=0)  {
			Table.applyMacro("BXpx=d2s(BX/lcfc,0)");
			Table.applyMacro("BYpx=d2s(BY/lcfc,0)");
			Table.renameColumn("BXpx","BX\(px\)");
			Table.renameColumn("BYpx","BY\(px\)");
		}
		if (indexOfArray(tableHeadings,"Width\(px\)",-1)<0 && indexOfArray(tableHeadings,"Width",-1)>=0)  {
			Table.applyMacro("Widthpx=Width/lcfc");
			Table.applyMacro("Heightpx=Height/lcfc");
			Table.renameColumn("Widthpx","Width\(px\)");
			Table.renameColumn("Heightpx","Height\(px\)");
		}
		Table.deleteColumn("lcfc");
		updateResults();
	}
	if(!isNaN(getResult("X\(px\)",0))) pxXCoords = Array.concat(pxXCoords,"X\(px\)");
	if(!isNaN(getResult("XM\(px\)",0))) pxXCoords = Array.concat(pxXCoords,"XM\(px\)");
	if(!isNaN(getResult("BX\(px\)",0))) pxXCoords = Array.concat(pxXCoords,"BX\(px\)");
	if(!isNaN(getResult("X",0))) pxXCoords = Array.concat(pxXCoords,"X");
	if(!isNaN(getResult("XM",0))) pxXCoords = Array.concat(pxXCoords,"XM");
	if(!isNaN(getResult("BX",0))) pxXCoords = Array.concat(pxXCoords,"BX");
	/* Also add coordinates based on other ASC macros */
	if(!isNaN(getResult("ROI_BX\(px\)",0))) pxXCoords = Array.concat(pxXCoords,"ROI_BX\(px\)");
	if(!isNaN(getResult("ROI_MX\(px\)",0))) pxXCoords = Array.concat(pxXCoords,"ROI_MX\(px\)");
	if(!isNaN(getResult("mc_X\(px\)",0))) pxXCoords = Array.concat(pxXCoords,"mc_X\(px\)");
	if (pxXCoords[0] == "") pxXCoords = Array.slice(pxXCoords,1,pxXCoords.length);
	newDistCols = newArray("MinDist\(px\)","MinLocX","MinLocY","MinDistAngle","Feret_MinDAngle_Offset","DistToRefCtr\(px\)","MaxDist\(px\)","MaxLocX","MaxLocY");
	newDistColsUnit = newArray("MinRefDist" + "\(" + unit + "\)","CtrRefDist" + "\(" + unit + "\)","MaxRefDist" + "\(" + unit + "\)");
	if (lcf!=1) newDistCols = Array.concat(newDistCols,newDistColsUnit);
	addedColsCheck = newArray(newDistCols.length);
	if (prefsAddedColsString=="None") Array.fill(addedColsCheck,true);
	else {
		Array.fill(addedColsCheck,false);
		for (i=0 ; i<prefsAddedCols.length; i++){
			newColRank = indexOfArray(newDistCols,prefsAddedCols[i],-1);
			if (newColRank>=0) addedColsCheck[newColRank] = true;
		}
	}
	/* Choose centroids for analysis */
	iPxC = indexOfArray(pxXCoords,prefsCentroids,0);
	luts=getLutsList();
	Dialog.create("Choose object coordinates");
		optionalMeasurements = "Choose new measurements to add to " + Table.title + ":\n   Minimum distance measurement: MinDist\(px\)\n   Coordinates of nearest reference points MinLocX, MinLocY\n   Directions: MinDistAngle, Feret_MinDAngle_Offset\n   Minimum distance to average \(~center\) location of reference set: DistToRefCtr\(px\)\n   Maximum distance measurements: MaxDist\(px\), MaxLocX, MaxLocY.";
		optionalScaled = "\n   Calibrated distances: MinRefDist \("+unit+"\), CtrRefDist \("+unit+"\), MaxRefDist \("+unit+"\).";
		if (lcf!=1) optionalMeasurements += optionalScaled;
		Dialog.addMessage("Reference source: " + coOrds + " imported coordinates");
		Dialog.addRadioButtonGroup("Select object coordinate set in Results Table \(Y will match\):",pxXCoords,round(pxXCoords.length/4),4,pxXCoords[iPxC]);
		Dialog.addMessage(optionalMeasurements);
		Dialog.addCheckboxGroup(4, round(newDistCols.length/4)+1, newDistCols, addedColsCheck);
		Dialog.addCheckbox("Select all measurements \(override above\)", false);
		Dialog.addString("Optional prefix to add to new measurement column labels","");
		Dialog.addString("Optional suffix to append to new measurement column labels","");
		colorChoice = newArray("LUT", "red", "green", "white", "black", "off-white", "off-black", "light_gray", "gray", "dark_gray", "pink",  "blue", "yellow", "orange", "garnet", "gold", "aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "gray_modern", "green_dark_modern", "green_modern", "orange_modern", "pink_modern", "purple_modern", "jazzberry_jam", "red_N_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern", "Radical Red", "Wild Watermelon", "Outrageous Orange", "Supernova Orange","Atomic Tangerine", "Neon Carrot", "Sunglow", "Laser Lemon", "Electric Lime", "Screamin' Green", "Magic Mint", "Blizzard Blue", "Dodger Blue", "Shocking Pink", "Razzle Dazzle Rose", "Hot Magenta");
		grayChoice = newArray("white", "black", "light_gray", "gray", "dark_gray");
		Dialog.addCheckbox("Draw overlay lines from centroid to nearest reference point?", false);
		Dialog.addChoice("Line color to minimum \(choose LUT for indexed color\):", colorChoice, colorChoice[2]);
		Dialog.addChoice("Choose LUT for Min line:", luts, luts[0]);
		iCol = indexOfArray(newDistCols,"MinDist\(px\)",0);
		oldAndNewCols = Array.concat(newDistCols, tableHeadings);
		Dialog.addChoice("If LUT choose a parameter to code min line by:", oldAndNewCols, oldAndNewCols[iCol]);
		Dialog.addNumber("Line width to minimum",1);
		Dialog.addCheckbox("Draw overlay lines from centroid to furthest reference point?", false);
		Dialog.addChoice("Line color to maximum \(choose LUT for indexed color\):", colorChoice, colorChoice[1]);
		Dialog.addChoice("Choose LUT for Max line:", luts, luts[1]);
		iCol = indexOfArray(newDistCols,"MaxDist\(px\)",0);
		Dialog.addChoice("If LUT choose a parameter to code max line by:", oldAndNewCols, oldAndNewCols[iCol]);
		Dialog.addNumber("Line width to maximum",1);
	Dialog.show();
		coordChoice = Dialog.getRadioButton();
		addedCols = newArray("");
		for (i=0; i<newDistCols.length; i++)
			if (Dialog.getCheckbox()) addedCols = Array.concat(addedCols,newDistCols[i]);
		if (addedCols[0]=="") addedCols = Array.slice(addedCols,1,addedCols.length);
		if (Dialog.getCheckbox()) addedCols = newDistCols;
		labelPrefix = Dialog.getString;
		labelSuffix = Dialog.getString;
		drawMinLine = Dialog.getCheckbox;
		minLineColor = Dialog.getChoice;
		minLineLUT = Dialog.getChoice;
		minLineParameter = Dialog.getChoice;
		minLineWidth = Dialog.getNumber;
		drawMaxLine = Dialog.getCheckbox;
		maxLineColor = Dialog.getChoice;
		maxLineLUT = Dialog.getChoice;
		maxLineParameter = Dialog.getChoice;
		maxLineWidth = Dialog.getNumber;
	// start = getTime(); /* Start after last dialog: used for debugging macro to optimize speed */
	if (coordChoice == "X") {
		x1 = Table.getColumn("X");
		y1 = Table.getColumn("Y");
	}
	else if (coordChoice == "XM") {
		x1 = Table.getColumn("XM");
		y1 = Table.getColumn("YM");
	}
	else if (coordChoice == "BX") {
		x1 = Table.getColumn("BX");
		y1 = Table.getColumn("BY");
	}
	else if (coordChoice == "X\(px\)") {
		x1 = Table.getColumn("X\(px\)");
		y1 = Table.getColumn("Y\(px\)");
	}
	else if (coordChoice == "XM\(px\)") {
		x1 = Table.getColumn("XM\(px\)");
		y1 = Table.getColumn("YM\(px\)");
	}
	else if (coordChoice == "BX\(px\)") {
		x1 = Table.getColumn("BX\(px\)");
		y1 = Table.getColumn("BY\(px\)");
	}
	else if (coordChoice == "ROI_BX\(px\)") {
		x1 = Table.getColumn("ROI_BX\(px\)");
		y1 = Table.getColumn("ROI_BY\(px\)");
	}
	else if (coordChoice == "ROI_MX\(px\)") {
		x1 = Table.getColumn("ROI_MX\(px\)");
		y1 = Table.getColumn("ROI_MY\(px\)");
	}
	else if (coordChoice == "mc_X\(px\)") {
		x1 = Table.getColumn("mc_X\(px\)");
		y1 = Table.getColumn("mc_Y\(px\)");
	}
	else restoreExit("No centroids selected, goodbye.");
	addedColsString = arrayToString(addedCols,delimiter);
	/* Remove units */
	addedColsString = replace(addedColsString, unit, "_unit_");
	call("ij.Prefs.set", prefsNameKey+"AdedCols", addedColsString);
	call("ij.Prefs.set", prefsNameKey+"Centroids", coordChoice);
	distances = newArray(coOrds);
	fAngles = Table.getColumn("FeretAngle");
	/* Choose new column output before loop */
	if (indexOfArray(addedCols,"MinDist\(px\)",-1)>=0) minDistC = true;
	else minDistC = false;
	if (indexOfArray(addedCols,"MinLocX",-1)>=0) minLocC = true;
	else minLocC = false;
	if (indexOfArray(addedCols,"MinDistAngle",-1)>=0) minDistAngleC = true;
	else minDistAngleC = false;
	if (indexOfArray(addedCols,"Feret_MinDAngle_Offset",-1)>=0) feret_MinDAngle_OffsetC = true;
	else feret_MinDAngle_OffsetC = false;
	if (indexOfArray(addedCols,"DistToRefCtr\(px\)",-1)>=0) distToRefCtrC = true;
	else distToRefCtrC = false;
	if (indexOfArray(addedCols,"MaxDist\(px\)",-1)>=0) maxDistC = true;
	else maxDistC = false;
	if (indexOfArray(addedCols,"MaxLocX",-1)>=0) maxLocC = true;
	else maxLocC = true;
	if (indexOfArray(addedCols,"MinRefDist" + "\(" + unit + "\)",-1)>=0) minRefDistC = true;
	else minRefDistC = false;
	if (indexOfArray(addedCols,"CtrRefDist" + "\(" + unit + "\)",-1)>=0) ctrRefDistC = true;
	else ctrRefDistC = false;
	if (indexOfArray(addedCols,"MaxRefDist" + "\(" + unit + "\)",-1)>=0) maxRefDistC = true;
	else maxRefDistC = false;
	/* End of new column selection */
	minDs = newArray(nRes);
	maxDs = newArray(nRes);
	minLocXs = newArray(nRes);
	minLocYs = newArray(nRes);
	maxLocXs = newArray(nRes);
	maxLocYs = newArray(nRes);
	minDistAngles = newArray(nRes);
	fMinDAngleOs = newArray(nRes);
	dRefs = newArray(nRes);
	minRefDists = newArray(nRes);
	ctrRefDists = newArray(nRes);
	maxRefDists = newArray(nRes);
	if (revertToImportedXY) modP = 0.5;
	else modP = 0;
	for (i=0 ; i<nRes; i++) {
		showProgress(i, nRes);
		for (j=0 ; j<(lengthOf(xpoints)); j++) distances[j] = sqrt((x1[i]-xpoints[j])*(x1[i]-xpoints[j])+(y1[i]-ypoints[j])*(y1[i]-ypoints[j]));
		sortedDistances = Array.copy(distances);
		Array.sort(sortedDistances);
		rankPosDist = Array.rankPositions(distances);
		minDs[i] = sortedDistances[0];
		maxDs[i] = sortedDistances[lengthOf(distances)-1];
		/* nearest neighbor alternative */
		if (minDs[i]==0) {
			minDs[i] = sortedDistances[1];
			k = rankPosDist[1];
		}
		else {
			k = rankPosDist[0];
		}
		if (minLocC) {
			minLocXs[i] = d2s(xpoints[k]- modP,0);
			minLocYs[i] = d2s(ypoints[k]- modP,0);
		}
		iEnd = rankPosDist[lengthOf(distances)-1];
		if (maxLocC) {
			maxLocXs[i] = d2s(xpoints[iEnd]- modP,0);
			maxLocYs[i] = d2s(ypoints[iEnd]- modP,0);
		}
		mda = (180/PI)*atan((y1[i]-ypoints[k])/((xpoints[k]-x1[i])));
		if (mda<0) mda = 180 + mda; /* modify angle to match 0-180 FeretAngle */
		if (minDistAngleC) minDistAngles[i] = mda;
		dRefs[i] = sqrt(pow((x1[i]-meanx),2)+pow((y1[i]-meany),2));
		fMinDAngleOs[i] = abs(fAngles[i]-mda);
		if (fMinDAngleOs[i]>90) fMinDAngleOs[i] = 180 - fMinDAngleOs[i]; 
		if (lcf!=1) {
			if (minRefDistC) minRefDists[i] = minDs[i]*lcf;
			if (ctrRefDistC) ctrRefDists[i] = dRefs[i]*lcf;
			if (maxRefDistC) maxRefDists[i] = maxDs[i]*lcf;
		}
	}
	if (minDistC) Table.setColumn("MinDist\(px\)", minDs);
	if (maxDistC) Table.setColumn("MaxDist\(px\)", maxDs);
	if (minLocC) {
		Table.setColumn("MinLocX",minLocXs);
		Table.setColumn("MinLocY",minLocYs);
	}
	if (maxLocC) {
		Table.setColumn("MaxLocX",maxLocXs);
		Table.setColumn("MaxLocY",maxLocYs);
	}
	if (minDistAngleC) Table.setColumn("MinDistAngle", minDistAngles);
	if (feret_MinDAngle_OffsetC) Table.setColumn("Feret_MinDAngle_Offset",fMinDAngleOs);
	if (distToRefCtrC) Table.setColumn("DistToRefCtr\(px\)", dRefs);
	if (lcf!=1) {
		if (minRefDistC) Table.setColumn("MinRefDist" + "\(" + unit + "\)", minRefDists);
		if (ctrRefDistC) Table.setColumn("CtrRefDist" + "\(" + unit + "\)", ctrRefDists);
		if (maxRefDistC) Table.setColumn("MaxRefDist" + "\(" + unit + "\)", maxRefDists);
	}
	updateResults();
	// selectWindow(imageTitle);
	// run("Select None");
	if (drawMaxLine) {
		setLineWidth(maxLineWidth);
		if (maxLineColor!="LUT"){
			setColorFromColorName(maxLineColor);
			for (i=0; i<nRes; i++) Overlay.drawLine(x1[i],y1[i],getResult("MaxLocX", i),getResult("MaxLocY",i));
			setColorFromColorName(maxLineColor);
		}
		else {
			maxValues = Table.getColumn(maxLineParameter);
			Array.getStatistics(maxValues, min, max, null, null);
			lutF = 255/(max-min);
			print("LUT for maxDist lines: " + maxLineLUT + " range " + min + " to " + max + ", coded by: " + maxLineParameter);
			maxLineColors = loadLutColorsFromTemp(maxLineLUT); /* load the LUT as a hexColor array: requires function */
			for (i=0; i<nRes; i++) {
				maxLineColorIndex = round(lutF*(maxValues[i]-min));
				Overlay.drawLine(x1[i],y1[i],maxLocXs[i],maxLocYs[i]);
				setColor("#" + maxLineColors[maxLineColorIndex]); /* set color after line drawn */
			}
		}
	}
	Overlay.show;
	if (drawMinLine) {
		setLineWidth(minLineWidth);
		if (minLineColor!="LUT"){
			setColorFromColorName(minLineColor);
			for (i=0; i<nRes; i++) Overlay.drawLine(round(x1[i]),round(y1[i]),getResult("MinLocX", i),getResult("MinLocY",i));
			setColorFromColorName(minLineColor);
		}
		else {
			minValues = Table.getColumn(minLineParameter);
			Array.getStatistics(minValues, min, max, null, null);
			lutF = 255/(max-min);
			print("LUT for minDist lines: " + minLineLUT + " range " + min + " to " + max + ", coded by: " + minLineParameter);
			minLineColors = loadLutColorsFromTemp(minLineLUT); /* load the LUT as a hexColor array: requires function */
			for (i=0; i<nRes; i++) {
				minLineColorIndex = round(lutF*(minValues[i]-min));
				Overlay.drawLine(x1[i],y1[i],minLocXs[i],minLocYs[i]);
				setColor("#" + minLineColors[minLineColorIndex]); /* set color after line drawn */
			}
		}
	}
	Overlay.show;
	if (labelPrefix!="" || labelSuffix!=""){
		allFinalTableHeadings = split(String.getResultsHeadings);
		for (i=0; i<newDistCols.length; i++) {
			newLabel = labelPrefix+newDistCols[i]+labelSuffix;
			if (indexOfArray(allFinalTableHeadings,newLabel,-1)>=0) {Table.deleteColumn(newLabel);}
			Table.renameColumn(newDistCols[i], newLabel);
			print ("relabeled column: " + newLabel);
		}
	}
	run("Select None");
	setBatchMode("exit & display"); /* exit batch mode */
	// print(nRes + " objects analyzed in " + (getTime()-start)/1000 + "s.");
	print("-----");
	restoreSettings();
	showStatus(nRes + " min & max distances from reference coords to centroids added to results");
	beep(); wait(300); beep(); wait(300); beep();
	run("Collect Garbage"); 
}
	/*  ( 8(|)	( 8(|)	All ASC Functions	@@@@@:-)	@@@@@:-)   */
	
	function arrayToString(array,delimiters){
		/* 1st version April 2019 PJL
			v190722 Modified to handle zero length array */
		string = "";
		for (i=0; i<array.length; i++){
			if (i==0) string += array[0];
			else  string = string + delimiters + array[i];
		}
		return string;
	}
	function indexOfArray(array, value, default) {
		/* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first found value */
		index = default;
		for (i=0; i<lengthOf(array); i++){
			if (array[i]==value) {
				index = i;
				i = lengthOf(array);
			}
		}
	  return index;
	}
	function restoreExit(message){ /* Make a clean exit from a macro, restoring previous settings */
		/* 9/9/2017 added Garbage clean up suggested by Luc LaLonde - LBNL */
		restoreSettings(); /* Restore previous settings before exiting */
		setBatchMode("exit & display"); /* Probably not necessary if exiting gracefully but otherwise harmless */
		run("Collect Garbage");
		exit(message);
	}
	function getColorArrayFromColorName(colorName) {
		/* v180828 added Fluorescent Colors
		   v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
		*/
		if (colorName == "white") cA = newArray(255,255,255);
		else if (colorName == "black") cA = newArray(0,0,0);
		else if (colorName == "off-white") cA = newArray(245,245,245);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "red") cA = newArray(255,0,0);
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "green") cA = newArray(0,255,0); /* #00FF00 AKA Lime green */
		else if (colorName == "blue") cA = newArray(0,0,255);
		else if (colorName == "yellow") cA = newArray(255,255,0);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
		else if (colorName == "garnet") cA = newArray(120,47,64);
		else if (colorName == "gold") cA = newArray(206,184,136);
		else if (colorName == "aqua_modern") cA = newArray(75,172,198); /* #4bacc6 AKA "Viking" aqua */
		else if (colorName == "blue_accent_modern") cA = newArray(79,129,189); /* #4f81bd */
		else if (colorName == "blue_dark_modern") cA = newArray(31,73,125);
		else if (colorName == "blue_modern") cA = newArray(58,93,174); /* #3a5dae */
		else if (colorName == "gray_modern") cA = newArray(83,86,90);
		else if (colorName == "green_dark_modern") cA = newArray(121,133,65);
		else if (colorName == "green_modern") cA = newArray(155,187,89); /* #9bbb59 AKA "Chelsea Cucumber" */
		else if (colorName == "green_modern_accent") cA = newArray(214,228,187); /* #D6E4BB AKA "Gin" */
		else if (colorName == "green_spring_accent") cA = newArray(0,255,102); /* #00FF66 AKA "Spring Green" */
		else if (colorName == "orange_modern") cA = newArray(247,150,70);
		else if (colorName == "pink_modern") cA = newArray(255,105,180);
		else if (colorName == "purple_modern") cA = newArray(128,100,162);
		else if (colorName == "jazzberry_jam") cA = newArray(165,11,94);
		else if (colorName == "red_N_modern") cA = newArray(227,24,55);
		else if (colorName == "red_modern") cA = newArray(192,80,77);
		else if (colorName == "tan_modern") cA = newArray(238,236,225);
		else if (colorName == "violet_modern") cA = newArray(76,65,132);
		else if (colorName == "yellow_modern") cA = newArray(247,238,69);
		/* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp */
		else if (colorName == "Radical Red") cA = newArray(255,53,94);			/* #FF355E */
		else if (colorName == "Wild Watermelon") cA = newArray(253,91,120);		/* #FD5B78 */
		else if (colorName == "Outrageous Orange") cA = newArray(255,96,55);	/* #FF6037 */
		else if (colorName == "Supernova Orange") cA = newArray(255,191,63);	/* FFBF3F Supernova Neon Orange*/
		else if (colorName == "Atomic Tangerine") cA = newArray(255,153,102);	/* #FF9966 */
		else if (colorName == "Neon Carrot") cA = newArray(255,153,51);			/* #FF9933 */
		else if (colorName == "Sunglow") cA = newArray(255,204,51); 			/* #FFCC33 */
		else if (colorName == "Laser Lemon") cA = newArray(255,255,102); 		/* #FFFF66 "Unmellow Yellow" */
		else if (colorName == "Electric Lime") cA = newArray(204,255,0); 		/* #CCFF00 */
		else if (colorName == "Screamin' Green") cA = newArray(102,255,102); 	/* #66FF66 */
		else if (colorName == "Magic Mint") cA = newArray(170,240,209); 		/* #AAF0D1 */
		else if (colorName == "Blizzard Blue") cA = newArray(80,191,230); 		/* #50BFE6 Malibu */
		else if (colorName == "Dodger Blue") cA = newArray(9,159,255);			/* #099FFF Dodger Neon Blue */
		else if (colorName == "Shocking Pink") cA = newArray(255,110,255);		/* #FF6EFF Ultra Pink */
		else if (colorName == "Razzle Dazzle Rose") cA = newArray(238,52,210); 	/* #EE34D2 */
		else if (colorName == "Hot Magenta") cA = newArray(255,0,204);			/* #FF00CC AKA Purple Pizzazz */
		else restoreExit("No color match to " + colorName);
		return cA;
	}
	function setColorFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function getLutsList() {
		/* v180723 added check for preferred LUTs */
		lutsCheck = 0;
		defaultLuts= getList("LUTs");
		Array.sort(defaultLuts);
		lutsDir = getDirectory("LUTs");
		/* A list of frequently used LUTs for the top of the menu list . . . */
		preferredLutsList = newArray("Your favorite LUTS here", "silver-asc", "viridis-linearlumin", "mpl-viridis", "mpl-plasma", "Glasbey", "Grays");
		preferredLuts = newArray(preferredLutsList.length);
		counter = 0;
		for (i=0; i<preferredLutsList.length; i++) {
			for (j=0; j<defaultLuts.length; j++) {
				if (preferredLutsList[i] == defaultLuts[j]) {
					preferredLuts[counter] = preferredLutsList[i];
					counter +=1;
					j = defaultLuts.length;
				}
			}
		}
		preferredLuts = Array.trim(preferredLuts, counter);
		lutsList=Array.concat(preferredLuts, defaultLuts);
		return lutsList; /* Required to return new array */
	}
	function pad(n) {
		n = toString(n);
		if(lengthOf(n)==1) n = "0"+n;
		return n;
	}
	function loadLutColorsFromTemp(lut) {
		/* v190724 creates temp image for lut color acquisition */
		if (is("Batch Mode")==false){
			batchWasOff = true;
			setBatchMode(true);	/* toggle batch mode back on */
		}
		else batchWasOff = false;
		newImage("temp-lut","8-bit",1,1,1);
  		run(lut);
		getLut(reds, greens, blues);
		hexColors = newArray(256);
		for (i=0; i<256; i++) {
			r = toHex(reds[i]);  g = toHex(greens[i]); b = toHex(blues[i]);
			hexColors[i]= ""+ pad(r) +""+ pad(g) +""+ pad(b);
		}
		close();
		if (batchWasOff) setBatchMode("exit & display");	/* toggle batch mode back off */
		return hexColors;
	}