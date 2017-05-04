# asc-ImageJ-MinimumDistances
This ImageJ macro adds the minimum distance between the centroid of a set of analyzed objects and a reference set of points to the ImageJ results table. This data can then used to provide position normalized quantification of microstructures and microchemistry.<br />

A reference location file with X in column 1 and Y in column 2 is now required (either a tab separated txt file exported by ImageJ or a csv file).<br />
PIXELS: The macro assumes that the imported XY values are in pixels.<br />
&nbsp;&nbsp;&nbsp;the macro will generate both pixel and scaled information.<br />
ZERO Y AT TOP: Zero Y should be at the top of the image<br />
&nbsp;&nbsp;&nbsp;this is OPPOSITE to the current ImageJ default XY export setting.<br />
&nbsp;&nbsp;&nbsp;To export the XY coordinates of all non-background pixels: Analyze > Tools > Save XY Coordinates<br />
The macro adds the following 20(!) columns:<br />
&nbsp;&nbsp;&nbsp;Conversions to pixel data based on scale factor: X(px), Y(px), XM(px), YM(px), BX(px), BY(px), Width(px), Height(px)<br />
&nbsp;&nbsp;&nbsp;New minimum distance measurements: MinDist(px), MinLocX, MinLocY, MinDistAngle, Feret_MinDAngle_Offset<br />
&nbsp;&nbsp;&nbsp;New minimum distance to average (~center) location of reference set: DistToRefCtr(px)<br />
&nbsp;&nbsp;&nbsp;New maximum distance measurements: MaxDist(px), MaxLocX, MaxLocY<br />
&nbsp;&nbsp;&nbsp;Scaled distances: MinRefDis, CtrRefDist, MaxRefDist<br />
