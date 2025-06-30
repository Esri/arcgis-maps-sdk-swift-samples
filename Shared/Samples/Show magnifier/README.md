# Show magnifier

Tap and hold on a map to show a magnifier.

![Image of show magnifier sample](show-magnifier.png)

## Use case

Due to the limited screen size of some mobile devices, it may be difficult to identify individual features on a map where there is a high density of information, or the scale is very small. This can be the case when a mobile device is used for navigation, and the user wishes to magnify a particular area to better identify a road intersection.

## How to use the sample

Tap and hold on the map to show a magnifier, then drag across the map to move the magnifier. You can also pan the map while holding the magnifier, by dragging the magnifier to the edge of the map.

## How it works

1. Create a new `MapView`, and set a `Map` on it.
2. Enable or diabled the magnifier using `magnifierDisabled(_:)` modifier. Enabling this will set the magnifier to be shown on the `Map` when the user performs a long press gesture. Note: The magnifier is enabled by default.
3. Optionally, use the `magnifierEdgePanningDisabled(_:)` modifier to allow the map to be panned automatically when the magnifier gets near the edge of the `Map`.

## Relevant API

* Map
* MapView
* MapView.magnifierDisabled(_:)
* MapView.magnifierEdgePanningDisabled(_:)

## Tags

magnify, map, zoom
