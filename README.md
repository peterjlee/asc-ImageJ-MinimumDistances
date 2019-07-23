# asc-ImageJ-MinimumDistances
This ImageJ macro adds the minimum distance between the centroid of a set of analyzed objects and a reference set of points to the ImageJ results table. This data can then used to provide position normalized quantification of microstructures and microchemistry.<br />

A reference location file with X in column 1 and Y in column 2 is now required (either a tab separated txt file exported by ImageJ or a csv file).<br />
PIXELS: The macro assumes that the imported XY values are in pixels.<br />
&nbsp;&nbsp;&nbsp;the macro will generate both pixel and scaled information.<br />
ZERO Y AT TOP: Zero Y should be at the top of the image<br />
&nbsp;&nbsp;&nbsp;this is OPPOSITE to the current ImageJ default XY export setting.<br />
&nbsp;&nbsp;&nbsp;To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates<br />
 <p>Up to 20 additional columns are added to Results table  in the current version:</p>
<blockquote>
  <p>
    Minimum distances to the reference set (and the coordinates of the minimum location).<br />
    Maximum distances to the reference set (and the coordinates of the maximum location).<br />
    Minimum distances to the center (based on mean of coordinates) of the reference set.<br />
    Angle of minimum distance direction (degrees).<br />
    Angular offset of minimum distance angle from Feret angle.</p>
    The added columns can be relabelled with a global prefix and/or suffix.<br />
  <p>If the image is scaled, additional columns of &quot;unscaled&quot; pixel values will be added.</p>
    <p>The minimum and maximum distance lines can be drawn as overlays.</p>
<p><img src="https://fs.magnet.fsu.edu/~lee/asc/ImageJUtilities/IA_Images/Centroid-Intfc_Dist_Menu3_LCF_v190723b_Lines_PAL.png" alt="Color Coder example for autoprefs version using asc-silver LUT" height="326" /> </p>
