# asc-ImageJ-MinimumDistances
This ImageJ macro adds the minimum distance between the centroid of a set of analyzed objects and a reference set of points to the ImageJ results table. This data can then used to provide position normalized quantification of microstructures and microchemistry. This could be done with just a few lines of ImageJ/Fiji macro code but here we try to extract a few more distance derived details.<br />

A reference location file with X in column 1 and Y in column 2 is now required (either a tab separated txt file exported by ImageJ or a csv file).<br />
The macro can use imported XY values that are in pixels of to the same scale as the active image.<br />
&nbsp;&nbsp;&nbsp;the macro will generate both pixel and scaled information.<br />
ZERO Y AT TOP: Zero Y should be at the top of the image<br />
&nbsp;&nbsp;&nbsp;this is OPPOSITE to the current ImageJ default XY export setting.<br />
&nbsp;&nbsp;&nbsp;To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates<br />
 <p>Up to 20 additional columns are added to Results table  in the current version:</p>
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
