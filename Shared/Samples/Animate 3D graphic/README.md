# Animate 3D graphic

An `OrbitGeoElementCameraController` follows a graphic while the graphic's position and rotation are animated.

![Image of animate 3D graphic](animate-3d-graphic.png)

## Use case

Visualize movement through a 3D landscape.

## How to use the sample

Tap the buttons on the bottom toolbar to adjust the settings for the animation:

* Mission: change the flight path, speed, and view progress
* Play/Pause: toggle the animation
* Camera: change the camera distance, heading, pitch, and other camera properties.

## How it works

1. Create a `GraphicsOverlay` and add it to the `SceneView`.
2. Create a `ModelSceneSymbol` object.
3. Create a `Graphic` object with the model scene symbol.
4. Add heading, pitch, and roll attributes to the graphic.
5. Create a `SimpleRenderer` object and set its expression properties.
6. Add the graphic and the renderer to the graphics overlay.
7. Create a `OrbitGeoElementCameraController` which is set to target the graphic.
8. Assign the camera controller to the `SceneView`.
9. Update the graphic's location, heading, pitch, and roll.

## Relevant API

* Camera
* GlobeCameraController
* Graphic
* GraphicsOverlay
* LayerSceneProperties
* ModelSceneSymbol
* OrbitGeoElementCameraController
* Renderer
* RendererSceneProperties
* Scene
* SceneView
* SurfacePlacement

## Offline data

This sample uses the following data which are all included and downloaded on-demand:

* [Model Marker Symbol Data](https://www.arcgis.com/home/item.html?id=681d6f7694644709a7c830ec57a2d72b)
* [GrandCanyon.csv mission data](https://www.arcgis.com/home/item.html?id=290f0c571c394461a8b58b6775d0bd63)
* [Hawaii.csv mission data](https://www.arcgis.com/home/item.html?id=e87c154fb9c2487f999143df5b08e9b1)
* [Pyrenees.csv mission data](https://www.arcgis.com/home/item.html?id=5a9b60cee9ba41e79640a06bcdf8084d)
* [Snowdon.csv mission data](https://www.arcgis.com/home/item.html?id=12509ffdc684437f8f2656b0129d2c13)

## Tags

animation, camera, heading, pitch, roll, rotation, visualize
