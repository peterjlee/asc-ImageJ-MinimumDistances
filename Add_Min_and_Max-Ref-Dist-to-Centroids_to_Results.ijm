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
*/

macro "Add Min and Max Reference Distances Analyze Results Table" {
	requires("1.52a"); /* For table functions */
	getPixelSize(unit, pixelWidth, pixelHeight);
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
	description1 = "Results Table coordinates assumed to be in " + unit + ".\n     A reference location file with X in column 1 and Y in column 2 is now required\n     \(either a tab separated txt file exported by ImageJ or a csv file\).\n \nPIXELS: The macro assumes that the imported XY values are in pixels.\n     ";
	importXY = "To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates\n";
	zeroAtTop = "ZERO Y AT TOP: Zero Y should be at the top of the image.\n     This is OPPOSITE to the current ImageJ default XY export setting.";
	if (lcf!=1) {
		print("Current image pixel width = " + pixelWidth + " " + unit +".");
		/* ask for a file to be imported */
		showMessageWithCancel(description1 + "      The macro will generate both pixel and scaled information.\n \n" + zeroAtTop + "\n \n" + importXY + "\n \nThe macro adds the following conversions to pixel data based on 1 pixel = " + lcf + " " + unit + ":\n     X\(px\), Y\(px\), XM\(px\), YM\(px\), BX\(px\), BY\(px\), Width\(px\), Height\(px\)\n");
	}
	else {
		print("No scale is set; all data is assumed to be in pixels.");
		/* ask for a file to be imported */
		showMessageWithCancel(description1 + "Because the image scale is pixels the macro will generate only pixel distances.\n \n" + zeroAtTop + "\n \n" + importXY);
	}
	if (indexOfArray(tableHeadings,"X",-1)<0 && lcf!=1)
		print("As coordinates from Particles4-8 are never scaled three scaled \(" + unit + "\) columns will be added at the end.");
	fileName = File.openDialog("Select the file to import with X and Y pixel coordinates.");
	allText = File.openAsString(fileName);
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
	if (endsWith(fileName, ".txt")) fileFormat = "txt"; /* for input is in TXT format with tab */
	else if (endsWith(fileName, ".csv")) fileFormat = "csv"; /* for input is in CSV format */
	else restoreExit("Selected file is not in a supported format \(.txt or .csv\)");	 /* in case of any other format */
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
		else restoreExit("No common delimeters found in coordinate file, goodbye.");
		if (isNaN(parseInt(line[iX]))){ /* Do not test line[iY] is it might not exist */
			hdrCount += 1;
		}
		else {
			xpoints[i-hdrCount] = parseInt(line[iX]);
			ypoints[i-hdrCount] = parseInt(line[iY]);
			if (coordToCtr) {
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
	importReport2 = "Center of Reference Point Set is at x = " + meanx + ", y= " + meany + " \(pixels\).\n";
	importReport3 = "Reference Point Set Range x: " + minx + " - " + maxx + ", y: " + miny + " - " + maxy + " \(pixels\).";
	print(importReport2,importReport3);
	/* Pixel coordinates are used, take the opportunity to add them to the results table if they are missing */
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
	Dialog.create("Choose object coordinates");
		optionalMeasurements = "Choose new measurements to add to " + Table.title + ":\n   Minimum distance measurement: MinDist\(px\)\n   Coordinates of nearest reference points MinLocX, MinLocY\n   Directions: MinDistAngle, Feret_MinDAngle_Offset\n   Minimum distance to average \(~center\) location of reference set: DistToRefCtr\(px\)\n   Maximum distance measurements: MaxDist\(px\), MaxLocX, MaxLocY.";
		optionalScaled = "\n   Calibrated distances: MinRefDist \("+unit+"\), CtrRefDist \("+unit+"\), MaxRefDist \("+unit+"\).";
		if (lcf!=1) optionalMeasurements += optionalScaled;
		Dialog.addRadioButtonGroup("Coordinate sets based on X \(Y will match\):",pxXCoords,pxXCoords.length,1,pxXCoords[iPxC]);
		Dialog.addMessage(optionalMeasurements);
		Dialog.addCheckboxGroup(4, round(newDistCols.length/4)+1, newDistCols, addedColsCheck);
		Dialog.addCheckbox("Select all measurements \(override above\)", false);
		Dialog.addString("Optional prefix to add to new measurement column labels","");
		Dialog.addString("Optional suffix to append to new measurement column labels","");
		Dialog.show();
		coordChoice = Dialog.getRadioButton();
		addedCols = newArray("");
		for (i=0; i<newDistCols.length; i++)
			if (Dialog.getCheckbox()) addedCols = Array.concat(addedCols,newDistCols[i]);
		if (addedCols[0]=="") addedCols = Array.slice(addedCols,1,addedCols.length);
		if (Dialog.getCheckbox()) addedCols = newDistCols;
		labelPrefix = Dialog.getString;
		labelSuffix = Dialog.getString;
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
	allTableHeadingsString = Table.headings;
	/* Remove units */
	addedColsString = replace(addedColsString, unit, "_unit_");
	call("ij.Prefs.set", prefsNameKey+"AdedCols", addedColsString);
	call("ij.Prefs.set", prefsNameKey+"Centroids", coordChoice);
	distances = newArray(coOrds);
	FAngles = Table.getColumn("FeretAngle");
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
	if (indexOfArray(addedCols,"MaxDist",-1)>=0) maxDistC = true;
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
	for (i=0 ; i<nRes; i++) {
		showProgress(i, nRes);
		for (j=0 ; j<(lengthOf(xpoints)); j++) distances[j] = sqrt((x1[i]-xpoints[j])*(x1[i]-xpoints[j])+(y1[i]-ypoints[j])*(y1[i]-ypoints[j]));
		sortedDistances = Array.copy(distances);
		Array.sort(sortedDistances);
		rankPosDist = Array.rankPositions(distances);
		minD = sortedDistances[0];
		maxD = sortedDistances[lengthOf(distances)-1];
		/* nearest neighbor alternative */
		if (minD==0) {
			minD = sortedDistances[1];
			k = rankPosDist[1];
		}
		else {
			k = rankPosDist[0];
		}
		if (minDistC) setResult("MinDist\(px\)", i, minD);
		if (minLocC) {
			if (revertToImportedXY) {
				setResult("MinLocX", i, d2s(xpoints[k]-0.5,0));
				setResult("MinLocY", i, d2s(ypoints[k]-0.5,0));
			}
			else {
				setResult("MinLocX", i, d2s(xpoints[k],1));
				setResult("MinLocY", i, d2s(ypoints[k],1));
			}
		}
		mda = (180/PI)*atan((y1[i]-ypoints[k])/((xpoints[k]-x1[i])));
		if (mda<0) mda = 180 + mda; /* modify angle to match 0-180 FeretAngle */
		if (minDistAngleC) setResult("MinDistAngle", i, mda);
		dRef = sqrt((x1[i]-meanx)*(x1[i]-meanx)+(y1[i]-meany)*(y1[i]-meany));
		FMinDAngleO = abs(FAngles[i]-mda);
		if (FMinDAngleO>90) FMinDAngleO = 180 - FMinDAngleO; 
		if (feret_MinDAngle_OffsetC) setResult("Feret_MinDAngle_Offset", i, FMinDAngleO);
		if (distToRefCtrC) setResult("DistToRefCtr\(px\)", i, dRef);
		if (maxDistC) setResult("MaxDist\(px\)", i, maxD);
		iEnd = rankPosDist[lengthOf(distances)-1];
		if (maxLocC) {
			if (revertToImportedXY) {
				setResult("MaxLocX", i, d2s(xpoints[iEnd]-0.5,0));
				setResult("MaxLocY", i, d2s(ypoints[iEnd]-0.5,0));
			}
			else {
				setResult("MaxLocX", i, d2s(xpoints[iEnd],1));
				setResult("MaxLocY", i, d2s(ypoints[iEnd],1));
			}
		}
		if (lcf!=1) {
			if (minRefDistC) setResult('MinRefDist' + "\(" + unit + "\)", i, minD*lcf);
			if (ctrRefDistC) setResult('CtrRefDist' + "\(" + unit + "\)", i, dRef*lcf);
			if (maxRefDistC) setResult('MaxRefDist' + "\(" + unit + "\)", i, maxD*lcf);
		}
	}
	updateResults();
	allNewTableHeadingsString = substring(Table.headings,lengthOf(allTableHeadingsString));
	allNewTableHeadings = split(allNewTableHeadingsString);
	if (labelPrefix!="" || labelSuffix!=""){
		for (i=0; i<allNewTableHeadings.length; i++) {
			Table.renameColumn(allNewTableHeadings[i], labelPrefix+allNewTableHeadings[i]+labelSuffix);
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