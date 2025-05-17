# Take screenshot

Take a screenshot of the map.

![Image of Take screenshot sample](take-screenshot.png)

## Use case

GIS users may want to export a screenshot of a map to enable sharing as an image or printing.

## How to use the sample

Pan and zoom to find an interesting location, then use the button to take a screenshot. The screenshot will be displayed. You can share the screenshot by tapping the share button.

## How it works

1. Wait for the `MapView` to finish drawing.
2. Call `exportImage()` to get a `UIImage`.

## Relevant API

* DrawStatus
* GeoViewProxy.exportImage()

## Tags

capture, export, image, print, screen capture, screenshot, share, shot
