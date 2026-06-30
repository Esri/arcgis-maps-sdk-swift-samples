# Navigate map view and identify features with keyboard

Perform map navigation and identify nearby features using only the keyboard.

![Screenshot of navigate map view and identify features with keyboard sample](navigate-map-view-and-identify-features-with-keyboard.png)

## Use case

Keyboard access is an important part of building inclusive GIS applications. Users who cannot or prefer not to use touch or pointer input need a way to move around the map, discover features, and read feature details from the keyboard.

## How to use the sample

Use keyboard navigation to pan, zoom, rotate, and reset north until restaurants appear inside the rectangle. Restaurants inside the rectangle are selected and labeled in reading order, from top-to-bottom and left-to-right.

Press number keys `1` through `9` to show details for the matching restaurant in the current numbered group. Press `Esc` to dismiss the callout and show the selection rectangle again.

If more than nine restaurants are inside the rectangle, use Previous and Next to move between numbered groups.

## How it works

1. Create a `Map` with an `arcGISLightGray` basemap centered on Redlands.
2. Create a `ServiceFeatureTable` from the Redlands restaurants feature service.
3. Create a `FeatureLayer` from the service feature table and apply a `SimpleRenderer` with a circular marker symbol.
4. Display the map and a `GraphicsOverlay` in a `MapView`.
5. Use `MapViewReader` to convert the centered rectangle from screen coordinates to a map-space `Polygon`.
6. Query the restaurant feature table with `QueryParameters` using the rectangle polygon and an intersects spatial relationship.
7. Sort queried point features by their screen position so labels match reading order.
8. Select the queried features on the `FeatureLayer`.
9. Add numbered `TextSymbol` graphics for the current group of features to the graphics overlay.
10. Handle keyboard input with SwiftUI key press modifiers. Number keys show a `Callout` for the matching feature, Previous and Next move between groups, and `Esc` dismisses the callout.

## Relevant API

* FeatureLayer
* Graphic
* GraphicsOverlay
* Map
* MapView
* Polygon

## About the data

This sample uses a [Redlands restaurants](https://www.arcgis.com/home/item.html?id=46119989eccd46a58b8f3d7aedadeb90) feature layer covering food establishments in Redlands, California. Each feature represents a single restaurant.

## Additional information

The map view supports built-in keyboard shortcuts: arrow keys to pan, `+` and `-` to zoom, `Alt` + `Left Arrow` and `Alt` + `Right Arrow` to rotate, and `Alt` + `Up Arrow` to reset north. On macOS, use `Option` instead of `Alt`. See [Navigate a map view](https://developers.arcgis.com/swift/maps-2d/navigate-a-map-view/) for the complete list of built-in interactions.

## Tags

accessibility, accessible, identify, inclusive, keyboard, navigation, selection, WCAG
