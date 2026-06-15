# Navigate map view and identify features with keyboard

Perform map navigation and identify nearby features using only the keyboard.

![Screenshot of navigate map view and identify features with keyboard sample](navigate-map-view-and-identify-features-with-keyboard.png)

## Use case

Keyboard access is an important part of building inclusive GIS applications. Users who cannot or prefer not to use touch or pointer input need a way to move around the map, discover features, and read feature details from the keyboard.

This sample shows restaurants in Redlands, California. Restaurants inside the centered area-of-interest rectangle are selected and labeled with number keys so they can be identified without tapping the map.

## How to use the sample

Use keyboard navigation to pan and zoom the map until restaurants appear inside the rectangle. Restaurants inside the rectangle are selected and labeled in reading order, from top-to-bottom and left-to-right.

Press number keys `1` through `9` to show details for the matching restaurant. Press `Esc` to dismiss the callout and show the selection rectangle again.

If more than nine restaurants are inside the rectangle, an overflow message is shown. Only the first nine restaurants can be identified with number keys.

## How it works

1. Create a `Map` with an `ArcGISLightGray` basemap centered on Redlands.
2. Create a `ServiceFeatureTable` from the Redlands restaurants feature service.
3. Create a `FeatureLayer` from the service feature table and apply a `SimpleRenderer` with a circular marker symbol.
4. Display the map and a `GraphicsOverlay` in a `MapView`.
5. Use `MapViewReader` to convert the centered rectangle from screen coordinates to a map-space `Envelope`.
6. Query the restaurant feature table with `QueryParameters` using the rectangle envelope and an intersects spatial relationship.
7. Sort queried point features by their screen position so labels match reading order.
8. Select the queried features on the `FeatureLayer`.
9. Add numbered `TextSymbol` graphics for the first nine features to the graphics overlay.
10. Handle keyboard input with SwiftUI key press modifiers. Number keys show a `Callout` for the matching feature, and `Esc` dismisses it.

## Relevant API

* Envelope
* FeatureLayer
* Graphic
* GraphicsOverlay
* Map
* MapView

## About the data

This sample uses a Redlands restaurants feature service hosted by Esri.

## Tags

accessibility, accessible, identify, inclusive, keyboard, navigation, selection, Envelope, FeatureLayer, Graphic, GraphicsOverlay, Map, MapView, WCAG
