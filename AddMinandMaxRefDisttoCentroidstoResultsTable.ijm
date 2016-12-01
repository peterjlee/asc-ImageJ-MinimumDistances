/* Text file import based on an imageJWiki Example "Last modified: 2013/11/28 13:47 by borovec"
  http://imagejdocu.tudor.lu/doku.php?id=macro:multiple_points
  Array sorting based on macro example: http://rsb.info.nih.gov/ij/macros/examples/ArraySortingDemo.txt
  Mod Peter J. Lee (NHMFL) to calculate minimum and maximum distances from reference file of xy coordinates 5/5/2016,
  mod 6/10/2016 to be universal regardless of scale and method (I hope). Added angular offsets 7/20/2016.
  This version v161013
*/

macro "Add Min and Max Reference Distances Analyze Results Table" {

	saveSettings(); /* To restore settings at the end */
	
	/* Set options for black objects on white background as this works better for publications */
	run("Options...", "iterations=1 white count=1"); /* set white background */
	run("Colors...", "foreground=black background=white selection=yellow"); //set colors
	setOption("BlackBackground", false);
	run("Appearance...", " "); /* do not use Inverting LUT */
	// The above should be the defaults but this makes sure (black particles on a white background)
	// http://imagejdocu.tudor.lu/doku.php?id=faq:technical:how_do_i_set_up_imagej_to_deal_with_white_particles_on_a_black_background_by_default
	
	print("");
	print("Macro: " + getInfo("macro.filepath"));
	print("Image analyzed: " + getTitle());	 
	checkForRoiManager(); // see functions - if there is no ROI manager it will ask to run Analyze Particles
	objects = roiManager("count");
	run("Select None");
	if (isNaN(getResult('Pixels',0)) && isNaN(getResult('X',0))) {
		restoreExit("This macro requires that you have already run Analyze or Particles.");
	}	

	getPixelSize(unit, pixelWidth, pixelHeight);
	lcf=(pixelWidth+pixelHeight)/2; //---> add here the side size of 1 pixel in the new calibrated units (e.g. lcf=5, if 1 pixels is 5mm) <---
	
	if (lcf!=1) print("Current image pixel width = " + pixelWidth + " " + unit +".");
	else print("No scale is set; all data is assumed to be in pixels.");
	if (isNaN(getResult('X',0)) && lcf!=1) {
		print("As coordinates from Particles4-8 are never scaled three scaled \(" + unit + "\) columns will be added at the end.");
	}
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

	// ask for a file to be imported
	fileName = File.openDialog("Select the file to import with X and Y the first 2 entries /(either a tab separated txt file exported by ImageJ or a csv file/). Macro assumes that Results table XY values are in PIXELS.");
	allText = File.openAsString(fileName);

	setBatchMode(true); //batch mode on
	start = getTime();

	// in case input is in TXT format with tab
	if (endsWith(fileName, ".txt")) {	
		// parse text by lines
		text = split(allText, "\n");
		//these are the column indexes
		hdr = split(text[0]);
		nbPoints = split(text[1]);
		iX = 0; iY = 1; //iI = 2;
		coOrds = text.length-2;
		xpoints = newArray(coOrds);
		ypoints = newArray(coOrds); 
		print("Imported " + coOrds + " points from " + fileName + " TXT point set...");
		// loading and parsing each line
		for (i = 2; i < (coOrds+2); i++){
			line = split(text[i],"	");
			xpoints[i-2] = parseInt(line[iX]);
			ypoints[i-2] = parseInt(line[iY]); 
		}
	}
	else if (endsWith(fileName, ".csv")) { //in case input is in CSV format
		text = split(allText, "\n"); // parse text by lines
		//these are the column indexes
		hdr = split(text[0]);
		nbPoints = split(text[1]);
		iX = 0; iY = 1; //iI = 2;
		coOrds = text.length-2;
		xpoints = newArray(coOrds);
		ypoints = newArray(coOrds); 
		print("Imported " + coOrds + " points from " + fileName + " CSV point set...");
		// loading and parsing each line
		for (i = 2; i < (coOrds+2); i++){
			line = split(text[i],",");
			xpoints[i-2] = parseInt(line[iX]);
			ypoints[i-2] = parseInt(line[iY]); 
		} 
	}
	else restoreExit("Selected file is not in a supported format...");	 // in case of any other format

	Array.getStatistics(xpoints, minx, maxx, meanx, stdx);
	Array.getStatistics(ypoints, miny, maxy, meany, stdy);
	print("Center of Reference Point Set is at x = " + meanx + ", y= " + meany + " \(pixels\).");
		
	distance = newArray(coOrds);
	for (i=0 ; i<objects; i++) {
		showProgress(i, objects);
		roiManager("select", i);
		if (isNaN(getResult('Pixels',0)) && lcf!=1) {
			X1 = getResult("X\(px\)", i);  // 
			Y1 = getResult("Y\(px\)", i);  // 
		}
		else if (isNaN(getResult('Pixels',0)) && lcf==1) {
			X1 = getResult('X',i);  // for Analyze Particles
			Y1 = getResult('Y',i);  // for Analyze Particles
		}
		else {
			X1 = getResult('XM',i);  // for Landini Particles
			Y1 = getResult('YM',i);  // for Landini Particles
		}
		for (j=0 ; j<(xpoints.length); j++) {
			X2 = xpoints[j];
			Y2 = ypoints[j];
			D = sqrt((X1-X2)*(X1-X2)+(Y1-Y2)*(Y1-Y2));
			distance[j] = D;
		}
		sortedDistances = Array.copy(distance);
		Array.sort(sortedDistances);
		rankPosDist = Array.rankPositions(distance);
		minD = sortedDistances[0];
		maxD = sortedDistances[distance.length-1];
		// nearest neighbor alternative
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
		if (mda<0) mda = 180 + mda; // modify angle to match 0-180 FeretAngle
		setResult("MinDistAngle", i, mda);
		dRef = sqrt((X1-meanx)*(X1-meanx)+(Y1-meany)*(Y1-meany));
		FAngle = getResult("FeretAngle",i);
		FMinDAngleO = abs(FAngle-mda);
		if (FMinDAngleO>90) FMinDAngleO = 180 - FMinDAngleO; 
		setResult("Feret_MinDAngle_Offset", i, FMinDAngleO);
		setResult("DistToRefCtr\(px\)", i, dRef);
		setResult("MaxDist\(px\)", i, maxD);
		l = rankPosDist[distance.length-1];
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
}
	/* ( 8(|)  ( 8(|)  Functions   ( 8(|)  ( 8(|)  */
	
	function checkForRoiManager() {
		if (roiManager("count")==0)  {
			Dialog.create("No ROI");
			Dialog.addCheckbox("Run Analyze-particles to generate roiManager values?", true);
			Dialog.addMessage("This macro requires that all objects have been loaded into the roi manager.");
			Dialog.show();
			analyzeNow = Dialog.getCheckbox(); //if (analyzeNow==true) ImageJ analyze particles will be performed, otherwise exit;
			if (analyzeNow==true) {
				setOption("BlackBackground", false);
				run("Analyze Particles...");
				if (nResults!=roiManager("count")) restoreExit("Results and ROI Manager counts do not match!");
			}
			else restoreExit();
		}
	}
	function restoreExit(message){ // clean up before aborting macro then exit
		restoreSettings(); //clean up before exiting
		setBatchMode("exit & display"); // not sure if this does anything useful if exiting gracefully but otherwise harmless
		exit(message);
	}