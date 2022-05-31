# Set viewpoint rotation

Rotate a map.

![Image of set viewpoint rotation](set-viewpoint-rotation.png)

## Use case

A user may wish to view the map in an orientation other than north-facing.

## How to use the sample

Use the slider to rotate the map. If the map is not pointed north, the compass will display the current heading. Click the compass to set the map's heading to north.

## How it works

1. Create a `Map` object with the `arcGISStreets` basemap style.
2. Create an `Optional`-type `Viewpoint` object with a desired starting rotation.
3. Create a `MapView` view with the `Map` and `Viewpoint` objects.
4. Update the viewpoint with a new viewpoint with a different rotation to change the rotation angle.

## Relevant API

* Compass
* MapView

## Tags

rotate, rotation, viewpoint
