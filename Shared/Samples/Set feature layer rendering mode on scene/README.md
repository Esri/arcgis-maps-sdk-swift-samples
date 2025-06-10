# Set feature layer rendering mode on scene

Render features in a scene statically or dynamically by setting the feature layer rendering mode.

![Feature layer rendering mode (scene)](feature-layer-renderering-scene.png)

## Use case

In dynamic rendering mode, features and graphics are stored on the GPU. As a result, dynamic rendering mode is good for moving objects and for maintaining graphical fidelity during extent changes, since individual graphic changes can be efficiently applied directly to the GPU state. This gives the map or scene a seamless look and feel when interacting with it. The number of features and graphics has a direct impact on GPU resources, so large numbers of features or graphics can affect the responsiveness of maps or scenes to user interaction. Ultimately, the number and complexity of features and graphics that can be rendered in dynamic rendering mode is dependent on the power and memory of the device's GPU.

In static rendering mode, features and graphics are rendered only when needed (for example, after an extent change) and offloads a significant portion of the graphical processing onto the CPU. As a result, less work is required by the GPU to draw the graphics, and the GPU can spend its resources on keeping the UI interactive. Use this mode for stationary graphics, complex geometries, and very large numbers of features or graphics. The number of features and graphics has little impact on frame render time, meaning it scales well, and pushes a constant GPU payload. However, rendering updates is CPU and system memory intensive, which can have an impact on device battery life.

## How to use the sample

Use the 'Zoom In / Zoom Out' button to trigger the same zoom animation on both static and dynamicly rendered scenes.

## How it works

1. Create two SceneViews and set an inital viewpoint to zoomed out.

2. Setup the FeatureLayers for the scenes using the three service urls: Point, Polyline and Polygon.

3. Set the rendering mode for the SceneViews to dynamic and static.

4. Compare the scenes responsiveness depnding on the rendering mode. Zoom in and out to see the difference.

In Static rendering mode, the number of features and graphics has little impact on frame render time, meaning it scales well, however points don't stay screen-aligned and point/polyline/polygon objects are only redrawn once map view navigation is complete. In Dynamic rendering mode, large numbers of features or graphics can affect the responsiveness of maps or scenes to user interaction, however points remain screen-aligned and point/polyline/polygon objects are continually redrawn while the SceneView view is navigating. When left to automatic rendering, points are drawn dynamically and polylines and polygons statically.

## Relevant API

* ArcGISScene
* FeatureLayer
* FeatureLayer.RenderingMode
* SceneView

## Tags

3D, dynamic, feature layer, features, rendering, static
