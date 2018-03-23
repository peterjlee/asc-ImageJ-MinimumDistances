/*	This macro determines the minimum and maximum distances for all objects compared to a reference file of XY coordinates.
	It adds 20 new columns to the results table - which is perhaps a little excessive!
	Text file import is based on an imageJWiki Example "Last modified: 2013/11/28 13:47 by borovec"
	http://imagejdocu.tudor.lu/doku.php?id=macro:multiple_points
	Array sorting based on macro example: http://rsb.info.nih.gov/ij/macros/examples/ArraySortingDemo.txt
	Mod Peter J. Lee (NHMFL) to calculate minimum and maximum distances from reference file of xy coordinates 5/5/2016,
	mod 6/10/2016 to be universal regardless of scale and method (I hope). Added angular offsets 7/20/2016.
	v170503 adds a message box with a some description of the required reference file
	v170504 garbage collection
	v180323 Cleanup up some redundant code and tried to make macro smarter about removing header (and NaN) rows.
*/

macro "Add Min and Max Reference Distances Analyze Results Table" {

	saveSettings(); /* To restore settings at the end */
	
	/* Set options for black objects on white background as this works better for publications */
	run("Options...", "iterations=1 white count=1"); /* set white background */
	run("Colors...", "foreground=black background=white selection=yellow"); /* set colors */
	setOption("BlackBackground", false);
	run("Appearance...", " "); /* do not use Inverting LUT */
	/* The above should be the defaults but this makes sure (black particles on a white background) http://imagejdocu.tudor.lu/doku.php?id=faq:technical:how_do_i_set_up_imagej_to_deal_with_white_particles_on_a_black_background_by_default
	*/
	print("");
	print("Macro: " + getInfo("macro.filepath"));
	print("Image analyzed: " + getTitle());	 
	checkForRoiManager(); /* see functions - if there is no ROI manager it will ask to run Analyze Particles */
	objects = roiManager("count");
	run("Select None");
	if (isNaN(getResult('Pixels',0)) && isNaN(getResult('X',0))) {
		restoreExit("This macro requires that you have already run Analyze or Particles.");
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
	if (isNaN(getResult('Pixels',0)) && lcf!=1) {
		for (i=0 ; i<objects; i++) {
			setResult("X\(px\)", i, (getResult("X", i))/lcf);
			setResult("Y\(px\)", i, (getResult("Y", i))/lcf);
			setResult("XM\(px\)", i, (getResult("XM", i))/lcf);
			setResult("YM\(px\)", i, (getResult("YM", i))/lcf);
			setResult("BX\(px\)", i, round((getResult("BX", i))/lcf));
			setResult("BY\(px\)", i, round((getResult("BY", i))/lcf));
			setResult("Width\(px\)", i, round((getResult("Width", i))/lcf));
			setResult("Height\(px\)", i, round((getResult("Height", i))/lcf));
		}
		updateResults();
	}
	setBatchMode(true);
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
		if (fileFormat=="csv") line = split(text[i],",");
		if (fileFormat=="txt") line = split(text[i],"	");
		if (isNaN(parseInt(line[iX]))){ /* Do not test line[iY] is it might not exist */
			hdrCount += 1;
		}
		else {
			xpoints[i-hdrCount] = parseInt(line[iX]);
			ypoints[i-hdrCount] = parseInt(line[iY]);
		}
	}
	if (hdrCount > 0){
		coOrds = coOrds-hdrCount;
		xpoints = Array.trim(xpoints, coOrds);
		ypoints = Array.trim(ypoints, coOrds);
	}
	print(xpoints[coOrds-1], ypoints[coOrds-1]);
	print(xpoints[coOrds-1], ypoints[coOrds-2]);
	print(xpoints[coOrds-1], ypoints[coOrds-3]);
	print(xpoints[coOrds-1], ypoints[coOrds-4]);
	print(xpoints[coOrds-1], ypoints[coOrds-5]);
	
	if (hdrCount==0) print("Imported " + coOrds + " points from " + fileName + " " +  fileFormat + " point set...");	
	else print("Imported " + coOrds + " points from " + fileName + " " +  fileFormat + " point set, ignoring " + hdrCount + " lines of header.");
	/* loading and parsing each line */
	Array.getStatistics(xpoints, minx, maxx, meanx, stdx);
	Array.getStatistics(ypoints, miny, maxy, meany, stdy);
	print("Center of Reference Point Set is at x = " + meanx + ", y= " + meany + " \(pixels\).");
	print("Reference Point Set Range x: " + minx + " - " + maxx + ", y: " + miny + " - " + maxy + " \(pixels\).");
	
	distances = newArray(coOrds);
	for (i=0 ; i<objects; i++) {
		showProgress(i, objects);
		roiManager("select", i);
		if (isNaN(getResult('Pixels',0)) && lcf!=1) {
			X1 = getResult("X\(px\)", i);
			Y1 = getResult("Y\(px\)", i); 
		}
		else if (isNaN(getResult('Pixels',0)) && lcf==1) {
			X1 = getResult('X',i);  /* for ImageJ Analyze Particles */
			Y1 = getResult('Y',i);  /* for ImageJ Analyze Particles */
		}
		else {
			X1 = getResult('XM',i);  /* for Landini Particles */
			Y1 = getResult('YM',i);  /* for Landini Particles */
		}
		for (j=0 ; j<(lengthOf(xpoints)); j++) distances[j] = sqrt((X1-xpoints[j])*(X1-xpoints[j])+(Y1-ypoints[j])*(Y1-ypoints[j]));
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
		mda = (180/PI)*atan((Y1-ypoints[k])/((xpoints[k]-X1)));
		if (mda<0) mda = 180 + mda; /* modify angle to match 0-180 FeretAngle */
		setResult("MinDistAngle", i, mda);
		dRef = sqrt((X1-meanx)*(X1-meanx)+(Y1-meany)*(Y1-meany));
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
	print(roiManager("count") + " objects analyzed in " + (getTime()-start)/1000 + "s.");
	print("-----");
	restoreSettings();
	showStatus("Minimum and Maximum Reference Distances to Centroids Added to Results");
	beep(); wait(300); beep(); wait(300); beep();
	run("Collect Garbage"); 
}
	/*  ( 8(|)	( 8(|)	All ASC Functions	@@@@@:-)	@@@@@:-)   */
	
	function checkForRoiManager() {
		/* v161109 adds the return of the updated ROI count and also adds dialog if there are already entries just in case . .
			v180104 only asks about ROIs if there is a mismatch with the results */
		nROIs = roiManager("count");
		nRES = nResults; /* Used to check for ROIs:Results mismatch */
		if(nROIs==0) runAnalyze = true; /* Assumes that ROIs are required and that is why this function is being called */
		else if(nROIs!=nRES) runAnalyze = getBoolean("There are " + nRES + " results and " + nROIs + " ROIs; do you want to clear the ROI manager and reanalyze?");
		else runAnalyze = false;
		if (runAnalyze) {
			roiManager("reset");
			Dialog.create("Analysis check");
			Dialog.addCheckbox("Run Analyze-particles to generate new roiManager values?", true);
			Dialog.addMessage("This macro requires that all objects have been loaded into the roi manager.\n \nThere are   " + nRES +"   results.\nThere are   " + nROIs +"   ROIs.");
			Dialog.show();
			analyzeNow = Dialog.getCheckbox();
			if (analyzeNow) {
				setOption("BlackBackground", false);
				if (nResults==0)
					run("Analyze Particles...", "display add");
				else run("Analyze Particles..."); /* let user select settings */
				if (nResults!=roiManager("count"))
					restoreExit("Results and ROI Manager counts do not match!");
			}
			else restoreExit("Goodbye, your previous setting will be restored.");
		}
		return roiManager("count"); /* returns the new count of entries */
	}
	function restoreExit(message){ /* clean up before aborting macro then exit */
		/* 9/9/2017 added Garbage clean up suggested by Luc LaLonde - LBNL */
		restoreSettings(); /* clean up before exiting */
		setBatchMode("exit & display"); /* not sure if this does anything useful if exiting gracefully but otherwise harmless */
		run("Collect Garbage");
		exit(message);
	}