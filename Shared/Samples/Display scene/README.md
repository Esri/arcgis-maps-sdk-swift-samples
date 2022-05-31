# Display scene

Display a scene with a terrain surface and some imagery.

![Image of display scene](display-scene.png)

## Use case

Scene views are 3D representations of real-world areas and objects. Scene views are helpful for visualizing complex datasets where 3D relationships, topography, and elevation of elements are important factors.

## How to use the sample

When loaded, the sample will display a scene. Pan and zoom to explore the scene.

## How it works

1. Create a `Scene` object with `arcGISImagery` basemap style.
2. Create an `ArcGISTiledElevationSource` object and add it to a `Surface` object.
3. Set the `Surface` object to the scene's basemap surface.
4. Create a `SceneView` view with the scene.

## Relevant API

* ArcGISTiledElevationSource
* Scene
* SceneView
* Surface

## Tags

3D, basemap, elevation, scene, surface