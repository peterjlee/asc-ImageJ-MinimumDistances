# asc-ImageJ-MinimumDistance Macros for ImageJ/Fiji

The Add_Min_and_Max-Ref-Dist-to-Centroids_to_Results.ijm ImageJ macro adds the minimum distance between the centroid of a set of analyzed objects and a reference set of points to the ImageJ results table. This could be done with just a few lines of ImageJ/Fiji macro code but here we try to extract a few more distance derived details. This data can then used to provide position normalized quantification of microstructures, microchemistry and even images as in this publication: <a href="https://fs.magnet.fsu.edu/~lee/asc/pdf_papers/SMRG_pub643.html">PDF</a></p>

A reference location file with X coordinates in column 1 and Y coordinates in column 2 is required (using standard mageJ delimeters - e.g. a tab separated txt file exported by ImageJ or a csv file).<br />
The macro can use imported XY values that are in pixels or to the same scale as the active image<br />
&nbsp;&nbsp;&nbsp;but if the active image is calibrated the macro will generate both pixel and scaled information.<br />
ZERO Y AT TOP: Zero Y should be at the top of the image<br />
&nbsp;&nbsp;&nbsp;this is OPPOSITE to the current ImageJ default XY export setting.<br />
&nbsp;&nbsp;&nbsp;To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates<br />
 <p>Up to 20 additional columns (12 optional) are added to the Results table in the current version:</p>
 <p>
&nbsp;&nbsp;&nbsp;Minimum distances to the reference set (and the coordinates of the minimum location).<br />
&nbsp;&nbsp;&nbsp;Maximum distances to the reference set (and the coordinates of the maximum location).<br />
&nbsp;&nbsp;&nbsp;Minimum distances to the center (based on mean of coordinates) of the reference set.<br />
&nbsp;&nbsp;&nbsp;Angle of minimum distance direction (degrees).<br />
&nbsp;&nbsp;&nbsp;Angular offset of minimum distance angle from Feret angle.</p>
&nbsp;&nbsp;&nbsp;The added columns can be relabeled with a global prefix and/or suffix.<br />
  <p>If the image is scaled, additional columns of &quot;unscaled&quot; pixel values will be added.</p>
  <p>The minimum and maximum distance lines can be drawn as overlays. LUTs can be used to color code the lines according to any parameters in the Results table.</p>
<p><img src="https://fs.magnet.fsu.edu/~lee/asc/ImageJUtilities/IA_Images/Centroid-Intfc_Dist_Menu3_LCF_v190725_Lines_723x512_PAL.png" alt="Min and Max distance to reference coordinates example. This example uses a LUT to color code the minimum distances." height="512" /> </p>
<p> The Calculate_Min-Dist_Using_2_Text_Coord_Files.ijm macro simply calculates the minimum distances between two sets of coordinates imported from text files. If an image is option there is the option to use the scale and units from the active image.
<p><sub><sup>
 <strong>Legal Notice:</strong> <br />
These macros have been developed to demonstrate the power of the ImageJ macro language and we assume no responsibility whatsoever for its use by other parties, and make no guarantees, expressed or implied, about its quality, reliability, or any other characteristic. On the other hand we hope you do have fun with them without causing harm.
<br />
The macros are continually being tweaked and new features and options are frequently added, meaning that not all of these are fully tested. Please contact me if you have any problems, questions or requests for new modifications.
 </sup></sub>
</p>
