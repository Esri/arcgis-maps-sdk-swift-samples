# Select features in scene layer

Select features in scene layer.

![Screenshot of Select features in scene layer sample](select-features-in-scene-layer.png)

## Use case

Select a features in a scene layer using the tap gesture.

## How to use the sample

Tap on a feature in the scene.

## How it works

1. Create a `Scene` instance.
2. Create instances of `SceneViewReader` and `SceneView`.
3. Asynchronously identify nearby features at the tapped location from the map view using the `SceneViewProxy.identify(layer:screenPoint:tolerance:maximumResults:)` method.
4. Select all identified features in the feature layer with `ArcGISSceneLayer.select(features:)`.

## Relevant API

* ArcGISSceneLayer
* Scene
* SceneView

## About the data

This sample uses the [Brest France Buildings Scene](https://www.arcgis.com/home/item.html?id=1c00d02465394b6ebaeffe8eb9739cd1) scene viewer.

## Tags

3D, buildings, identify, model, query, search, select
