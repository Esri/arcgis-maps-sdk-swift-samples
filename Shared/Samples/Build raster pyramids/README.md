# Build raster pyramids

Build and delete raster pyramids to compare the display performance of a raster.

![Image for Build raster pyramids sample](build-raster-pyramids.png)

## Use case

Raster pyramids improve display performance by storing progressively lower-resolution versions of a raster dataset. They allow the resolution appropriate for the display scale to be read instead of repeatedly resampling the full-resolution raster. For example, a field worker viewing a raster offline can preemptively build pyramids once to make subsequent navigation more responsive. Building pyramids takes time and additional disk space, but those costs can be offset by faster display when the map is viewed at different scales.

A hybrid raster format (such as geospatial PDF) containing vector data can particularly benefit from pyramids, because the vector data otherwise needs to be rasterized as the display scale changes.

## How to use the sample

The sample initially displays a geospatial PDF raster without pyramids. Pan and zoom to observe its display performance.

Tap the "build" button and wait for the build to complete. Pan and zoom again to compare performance of the raster with pyramids.

Tap the "delete" button to delete the pyramids and recreate the raster layer without them. Repeat the same navigation to compare the two states.

Tap the "zoom" button to set the viewpoint to the raster's full resolution viewpoint.

## How it works

1. Create and load a geospatial PDF `Raster` from the local file.
2. Create a `RasterLayer` from the raster, add it to the map's operational layers, and set the initial viewpoint to its extent.
3. Get the `pyramids` property after loading the raster.
  * Use `RasterPyramids.activeBuildOperation` to determine if an operation is already running.
4. When the build button is tapped, create `BuildRasterPyramidsParameters` and call `RasterPyramids.build(using:)` method.
  * Start a `BuildRasterPyramidsOperation` that generates raster pyramids files alongside the raster file.
  * Wait for the operation to complete.
    * A successful `result` contains `RasterPyramidInfo` about the pyramid set that was built.
    * If the operation fails or is canceled, the corresponding error is reported.
5. When the delete button is tapped, call `RasterPyramids.delete()` method to remove the external pyramids. Recreate and re-add the raster layer.

## Relevant API

* BuildRasterPyramidsOperation
* BuildRasterPyramidsParameters
* Raster
* RasterLayer
* RasterPyramidInfo
* RasterPyramids

## About the data

The sample uses an open source [Park Map - Yosemite National Park](https://www.arcgis.com/home/item.html?id=a5b6e3c425f34631bba1bfbf859d5052) geospatial PDF containing vector cartography and raster to show the various features of Yosemite.

## Additional information

Pyramids only need to be built once for a raster dataset and can be reused when the raster is opened again. This sample allows deleting the pyramids to demonstrate the performance difference. The raster pyramids APIs build and delete external `.ovr` pyramid files; they do not delete embedded pyramids within the raster.

For more information, see

* [Build and manage raster pyramids](https://developers.arcgis.com/swift/layers/add-raster-data/#build-and-manage-raster-pyramids) on Esri Developer website
* [Raster pyramids](https://doc.esri.com/en/arcgis-pro/latest/help/data/imagery/raster-pyramids.html) in the ArcGIS Pro documentation

## Tags

GeoPDF, geospatial PDF, image, offline, optimization, overview, PDF, performance, pyramids, raster, vector
