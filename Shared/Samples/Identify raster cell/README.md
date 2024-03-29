# Identify raster cell

Get the cell value of a local raster at the tapped location and display the result in a callout.

![Image of identify raster cell](identify-raster-cell.png)

## Use case

You may want to identify a raster layer to get its exact cell value in case the approximate value conveyed by its symbology is not sufficient. The information available for the raster cell depends on the type of raster layer being identified. For example, a 3-band satellite or aerial image might provide 8-bit RGB values, whereas a digital elevation model (DEM) would provide floating point z values. By identifying a raster cell of a DEM, you can retrieve the precise elevation of a location.

## How to use the sample

Tap an area of the raster to identify it and see the raw raster cell information displayed in a callout. Tap and hold to see a magnifier and the cell information updated dynamically as you drag.

## How it works

1. Get the screen point on the map where a user tapped or long pressed and dragged from the `MapView`.
2. On tap or long press drag:
  * Call `MapViewProxy.identify(on:screenPoint:tolerance:returnPopupsOnly:maximumResults:)` passing in the screen point, tolerance, and maximum number of results per layer.
  * Await the result of the identify and then get the `GeoElement` from the layer result.
  * Create a callout at the calculated map point and populate the callout content with text from the `RasterCell.attributes`.

## Relevant API

* GeoViewProxy
* IdentifyLayerResult
* RasterCell
* RasterCell.attributes
* RasterLayer

## About the data

The data shown is an NDVI classification derived from MODIS imagery between 27 Apr 2020 and 4 May 2020. It comes from the [NASA Worldview application](https://worldview.earthdata.nasa.gov/). In a normalized difference vegetation index, or [NDVI](https://en.wikipedia.org/wiki/Normalized_difference_vegetation_index), values range between -1 and +1 with the positive end of the spectrum showing green vegetation.

## Tags

band, cell, cell value, continuous, discrete, identify, NDVI, pixel, pixel value, raster
