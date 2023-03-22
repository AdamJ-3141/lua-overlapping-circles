# luau-overlapping-circles

Luau code that calculates the total area of any number of overlapping (or non-overlapping) circles.  
The table `circles` should contain Vector2D centre coordinates paired with each circle's radius.  

For example, the pre-inputted circles in `OvelappingCircles.lua` generate the following:  
![image](https://user-images.githubusercontent.com/107213996/212503842-14e63d13-1f0b-42e9-b418-abfee27b873d.png)

Behind the scenes, the area above is partitioned into polygons and circle sectors:  
![image](https://user-images.githubusercontent.com/107213996/212503877-bbe41dcc-7c49-43cd-a081-44818c281a78.png)  
So that no area is overlapping.  
  
We then calculate the relevant areas of polygons and circle sectors, and then sum them to calculate the total area of the union.
