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
*/

macro "Add Min and Max Reference Distances Analyze Results Table" {
	requires("1.52a"); /* For table functions */
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
	if (isNaN(getResult('Pixels',0)) && isNaN(getResult('X',0))&& isNaN(getResult('XM',0))) {
		restoreExit("This macro requires that you have already run Analyze or Particles to obtain object coordinates.");
	}	
	getPixelSize(unit, pixelWidth, pixelHeight);
	lcf=(pixelWidth+pixelHeight)/2; /*---> add here the side size of 1 pixel in the new calibrated units (e.g. lcf=5, if 1 pixel is 5 mm) <---
	*/
	if (lcf!=1) {
		print("Current image pixel width = " + pixelWidth + " " + unit +".");
		/* ask for a file to be imported */
		showMessageWithCancel("XY coordinates in pixels", "A reference location file with X in column 1 and Y in column 2 is now required\n\(either a tab separated txt file exported by ImageJ or a csv file\).\nPIXELS: The macro assumes that the imported XY values are in pixels.\n - - the macro will generate both pixel and scaled information.\nZERO Y AT TOP: Zero Y should be at the top of the image\n - - this is OPPOSITE to the current ImageJ default XY export setting.\n - - To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates\n \nThe macro adds the following 20\(!\) columns:\n   Conversions to pixel data based on scale factor: X\(px\), Y\(px\), XM\(px\), YM\(px\), BX\(px\), BY\(px\), Width\(px\), Height\(px\)\n   New minimum distance measurements: MinDist\(px\), MinLocX, MinLocY, MinDistAngle, Feret_MinDAngle_Offset\n   New minimum distance to average \(~center\) location of reference set: DistToRefCtr\(px\)\n   New maximum distance measurements: MaxDist\(px\), MaxLocX, MaxLocY\n   Scaled distances: MinRefDist \("+unit+"\), CtrRefDist\("+unit+"\), MaxRefDist\("+unit+"\)");
	}
	else {
		print("No scale is set; all data is assumed to be in pixels.");
		/* ask for a file to be imported */
		showMessageWithCancel("XY coordinates in pixels", "A reference location file with X in column 1 and Y in column 2 is now required.\n - - either a tab separated txt file exported by ImageJ or a csv file.\nPIXELS: The macro assumes that the imported XY values are in pixels.\n - - Because the image scale is pixels the macro will generate only pixel distances.\nZERO Y AT TOP: Zero Y should be at the top of the image\n - - this is OPPOSITE to the current ImageJ default XY export setting.\n - - To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates\n \nThe macro adds the following 9 columns:\n   New minimum distance measurements: MinDist\(px\), MinLocX, MinLocY, MinDistAngle, Feret_MinDAngle_Offset\n   New minimum distance to average \(~center\) location of reference set: DistToRefCtr\(px\)\n   New maximum distance measurements: MaxDist\(px\), MaxLocX, MaxLocY\n");
	}
	if (isNaN(getResult('X',0)) && lcf!=1) {
		print("As coordinates from Particles4-8 are never scaled three scaled \(" + unit + "\) columns will be added at the end.");
	}
	fileName = File.openDialog("Select the file to import with X and Y pixel coordinates.");
	allText = File.openAsString(fileName);
	coordToCtr = getBoolean("Convert pixel coordinates to Analyze pixel centers? \(Add 0.5 to X and Y\)", "Convert", "No");
	start = getTime(); /* used for debugging macro to optimize speed */
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
			Array.print(xpoints);
			Array.print(ypoints);
		}
	}
	if (hdrCount > 0){
		coOrds = coOrds-hdrCount;
		xpoints = Array.trim(xpoints, coOrds);
		ypoints = Array.trim(ypoints, coOrds);
	}
	// print("length of xpoints = ", lengthOf(xpoints));
	if (hdrCount==0) print("Imported " + coOrds + " points from " + fileName + " " +  fileFormat + " point set...");	
	else print("Imported " + coOrds + " points from " + fileName + " " +  fileFormat + " point set, ignoring " + hdrCount + " lines of header.");
	/* loading and parsing each line */
	Array.getStatistics(xpoints, minx, maxx, meanx, stdx);
	Array.getStatistics(ypoints, miny, maxy, meany, stdy);
	print("Center of Reference Point Set is at x = " + meanx + ", y= " + meany + " \(pixels\).");
	print("Reference Point Set Range x: " + minx + " - " + maxx + ", y: " + miny + " - " + maxy + " \(pixels\).");
	/* Pixel coordinates are used, take the opportunity to add them to the results table if they are missing */
	lcfs = newArray(nRes);
	Array.fill(lcfs, lcf);
	Table.setColumn("lcfc", lcfs);
	if (isNaN(getResult('Pixels',0)) && lcf!=1) {
		if (isNaN(getResult('X\(px\)',0)) && !isNaN(getResult('X',0))) {
			Table.applyMacro("Xpx = X/lcfc");
			Table.applyMacro("Ypx = Y/lcfc");
			Table.renameColumn("Xpx", "X\(px\)");
			Table.renameColumn("Ypx", "Y\(px\)");
		}
		if (isNaN(getResult('XM\(px\)',0)) && !isNaN(getResult('XM',0))) {
			Table.applyMacro("XMpx=XM/lcfc");
			Table.applyMacro("YMpx=YM/lcfc");
			Table.renameColumn("XMpx", "XM\(px\)");
			Table.renameColumn("YMpx","YM\(px\)");
		}
		if (isNaN(getResult('BX\(px\)',0)) && !isNaN(getResult('BX',0))) {
			Table.applyMacro("BXpx=d2s(BX/lcfc,0)");
			Table.applyMacro("BYpx=d2s(BY/lcfc,0)");
			Table.renameColumn("BXpx","BX\(px\)");
			Table.renameColumn("BYpx","BY\(px\)");
		}
		if (isNaN(getResult('Width\(px\)',0)) && !isNaN(getResult('Width',0))) {
			Table.applyMacro("Widthpx=Width/lcfc");
			Table.applyMacro("Heightpx=Height/lcfc");
			Table.renameColumn("Widthpx","Width\(px\)");
			Table.renameColumn("Heightpx","Height\(px\)");
		}
		Table.deleteColumn("lcfc");
		updateResults();
	}	
	if (isNaN(getResult('Pixels',0)) && lcf!=1) {
		x1 = Table.getColumn('X\(px\)');
		y1 = Table.getColumn('Y\(px\)');
	}
	else if (isNaN(getResult('Pixels',0)) && lcf==1) {
		x1 = Table.getColumn('X');  /* for ImageJ Analyze Particles */
		y1 = Table.getColumn('Y');  /* for ImageJ Analyze Particles */
	}
	else {
		x1 = Table.getColumn('XM',i);  /* for Landini Particles */
		y1 = Table.getColumn('YM',i);  /* for Landini Particles */
	}
	distances = newArray(coOrds);
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
			setResult("MinDist\(px\)", i, minD);
			k = rankPosDist[1];
		}
		else {
			setResult("MinDist\(px\)", i, minD);
			k = rankPosDist[0];
		}
		setResult("MinLocX", i, xpoints[k]);
		setResult("MinLocY", i, ypoints[k]);
		mda = (180/PI)*atan((y1[i]-ypoints[k])/((xpoints[k]-x1[i])));
		if (mda<0) mda = 180 + mda; /* modify angle to match 0-180 FeretAngle */
		setResult("MinDistAngle", i, mda);
		dRef = sqrt((x1[i]-meanx)*(x1[i]-meanx)+(y1[i]-meany)*(y1[i]-meany));
		FAngle = getResult("FeretAngle",i);
		FMinDAngleO = abs(FAngle-mda);
		if (FMinDAngleO>90) FMinDAngleO = 180 - FMinDAngleO; 
		setResult("Feret_MinDAngle_Offset", i, FMinDAngleO);
		setResult("DistToRefCtr\(px\)", i, dRef);
		setResult("MaxDist\(px\)", i, maxD);
		l = rankPosDist[lengthOf(distances)-1];
		setResult("MaxLocX", i, xpoints[l]);
		setResult("MaxLocY", i, ypoints[l]);
		if (lcf!=1) {
			setResult('MinRefDist' + "\(" + unit + "\)", i, minD*lcf);
			setResult('CtrRefDist' + "\(" + unit + "\)", i, dRef*lcf);
			setResult('MaxRefDist' + "\(" + unit + "\)", i, maxD*lcf);
		}
	}
	updateResults();
	run("Select None");
	setBatchMode("exit & display"); /* exit batch mode */
	print(nRes + " objects analyzed in " + (getTime()-start)/1000 + "s.");
	print("-----");
	restoreSettings();
	showStatus("Minimum and Maximum Reference Distances to Centroids Added to Results");
	beep(); wait(300); beep(); wait(300); beep();
	run("Collect Garbage"); 
}
	/*  ( 8(|)	( 8(|)	All ASC Functions	@@@@@:-)	@@@@@:-)   */

	function restoreExit(message){ /* Make a clean exit from a macro, restoring previous settings */
		/* 9/9/2017 added Garbage clean up suggested by Luc LaLonde - LBNL */
		restoreSettings(); /* Restore previous settings before exiting */
		setBatchMode("exit & display"); /* Probably not necessary if exiting gracefully but otherwise harmless */
		run("Collect Garbage");
		exit(message);
	}