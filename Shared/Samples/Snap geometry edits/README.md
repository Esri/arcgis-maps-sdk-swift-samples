# Snap geometry edits

Use the Geometry Editor to edit a geometry and align it to existing geometries on a map.

![Image of Snap geometry edits sample](snap-geometry-edits.png)

## Use case

A field worker can create new features by editing and snapping the vertices of a geometry to existing features on a map. In a water distribution network, service line features can be represented with the polyline geometry type. By snapping the vertices of a proposed service line to existing features in the network, an exact footprint can be identified to show the path of the service line and what features in the network it connects to. The feature layer containing the service lines can then be accurately modified to include the proposed line.

## How to use the sample

To create a geometry, press the create button to choose the geometry type you want to create (i.e. points, multipoints, polyline, or polygon) and interactively tap and drag on the map view to create the geometry.

Snap settings can be configured by enabling or disabling snapping, feature snapping, geometry guides, and snap sources.

To interactively snap a vertex to a feature or graphic, ensure that snapping is enabled for the relevant snap source and move the mouse pointer or drag a vertex close to an existing feature or graphic. When the pointer is close to that existing geoelement, the edit position will be adjusted to coincide with (or snap to), edges and vertices of its geometry. Release the touch pointer to place the vertex at the snapped location.

To more clearly see how the vertex is snapped, long press to invoke the magnifier before starting to move the pointer.

## How it works

1. Create a `Map` from the portal item and add it to the `MapView`.
2. Set the map's `loadSettings.featureTilingMode` to `enabledWithFullResolutionWhenSupported`.
3. Create a `GeometryEditor` and connect it to the map view.
4. Call `syncSourceSettings()` after the map's operational layers are loaded and the geometry editor is connected to the map view.
5. Set `SnapSettings.isEnabled` and each `SnapSourceSettings.isEnabled` to `true` for the `SnapSource` of interest.
6. Toggle geometry guides using `SnapSettings.snapsToGeometryGuides` and feature snapping using `SnapSettings.snapsToFeatures`.
7. Start the geometry editor with a `GeometryType`.

## Relevant API

* FeatureLayer
* Geometry
* GeometryEditor
* GeometryEditorStyle
* GraphicsOverlay
* MapView
* ReticleVertexTool
* SnapSettings
* SnapSource
* SnapSourceSettings

## About the data

The [Naperville water distribution network](https://www.arcgis.com/home/item.html?id=b95fe18073bc4f7788f0375af2bb445e) is based on ArcGIS Solutions for Water Utilities and provides a realistic depiction of a theoretical stormwater network.

## Additional information

Snapping is used to maintain data integrity between different sources of data when editing, so it is important that each `SnapSource` provides full resolution geometries to be valid for snapping. This means that some of the default optimizations used to improve the efficiency of data transfer and display of polygon and polyline layers based on feature services are not appropriate for use with snapping.

To snap to polygon and polyline layers, the recommended approach is to set the `FeatureLayer`'s feature tiling mode to `FeatureTilingMode.enabledWithFullResolutionWhenSupported` and use the default `ServiceFeatureTable` feature request mode `FeatureRequestMode.onInteractionCache`. Local data sources, such as geodatabases, always provide full resolution geometries. Point and multipoint feature layers are also always full resolution.

Snapping can be used during interactive edits that move existing vertices using the `VertexTool` or `ReticleVertexTool`. When adding new vertices, snapping also works with a hover event (such as a mouse move without a mouse button press). Using the `ReticleVertexTool` to add and move vertices allows users of touch screen devices to clearly see the visual cues for snapping.

Geometry guides are enabled by default when snapping is enabled. These allow for snapping to a point coinciding with, parallel to, perpendicular to, or extending an existing geometry.

On supported platforms, haptic feedback on `SnapState.snappedToFeature` and `SnapState.snappedToGeometryGuide` is enabled by default when snapping is enabled. Custom haptic feedback can be configured by setting `SnapSettings.hapticFeedbackIsEnabled` to false and listening to the `GeometryEditor.snapChanges` stream to provide specific feedback depending on the `SnapState`.

When using `SubtypeFeatureLayer` objects as snap sources instead of `FeatureLayer`, child `SubtypeSublayer` objects are included as snap sources in the parent `SnapSourceSettings.childSourceSettings` collection in the same order as the `SubtypeFeatureLayer.subtypeSublayers` collection.

## Tags

edit, feature, geometry editor, graphics, layers, map, snapping
