# Display scene from mobile scene package

Opens and displays a scene from a Mobile Scene Package (.mspk).

![Image of display scene from mobile scene package](DisplaySceneFromMobileScenePackage.jpg)

## Use case

An .mspk file is an archive containing the data (specifically, basemaps and features), used to display an offline 3D scene.

## How to use the sample

When the sample opens, it will automatically display the Scene in the Mobile Map Package.

Since this sample works with a local .mspk, you may need to download the file to your device.

## How it works

This sample takes a Mobile Scene Package that was created in ArcGIS Pro, and displays a `Scene` from within the package in a `SceneView`.

1. Create a `MobileScenePackage` using the path to the local .mspk file.
2. Call `MobileScenePackage::load` and check for any errors.
3. When the `MobileScenePackage` is loaded, obtain the first `Scene` from the `MobileScenePackage::scenes` property.
4. Create a `SceneView` and call `SceneView::setView` to display the scene from the package.

## Relevant API

* MobileScenePackage
* SceneView

## Offline data

_Put instructions for your SDK's handling of offline data here._

## Tags

offline, scene
