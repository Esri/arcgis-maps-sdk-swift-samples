# Style point with scene symbol

Show various kinds of 3D symbols in a scene.

![Image of style point with scene symbol](style-point-with-scene-symbol.png)

## Use case

You can programmatically create different types of 3D symbols and add them to a scene at specified locations. You could do this to call attention to the prominence of a location.

## How to use the sample

When the scene loads, note the different types of 3D symbols that you can create. Pan and zoom to observe the symbols.

## How it works

1. Create a `GraphicsOverlay`.
2. Create various `SimpleMarkerSceneSymbol`s by specifying different styles and colors, and a height, width, depth, and anchor position of each.
3. Create a `Graphic` for each symbol.
4. Add the graphics to the graphics overlay.
5. Add the graphics overlay to a `SceneView`.

## Relevant API

* Graphic
* GraphicsOverlay
* Scene
* SimpleMarkerSceneSymbol

## About the data

This sample shows arbitrary symbols in an empty scene with imagery basemap.

## Tags

3D, cone, cube, cylinder, diamond, geometry, graphic, graphics overlay, pyramid, scene, shape, sphere, symbol, tetrahedron, tube, visualization
