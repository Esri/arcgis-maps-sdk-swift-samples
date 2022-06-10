# Download vector tiles to local cache

Download tiles from an online vector tile service.

![Screenshot of download vector tiles to local cache sample downloading](download-vector-tiles-to-local-cache-downloading.png)
![Screenshot of download vector tiles to local cache sample results](download-vector-tiles-to-local-cache-results.png)

## Use case

Field workers with limited network connectivity can use exported vector tiles as a basemap for use while offline.

## How to use the sample

When the vector tiled layer loads, zoom in to the extent you want to export. The red box shows the extent that will be exported. Click the "Export Vector Tiles" button to start the job. An error will show if the extent is larger than the maximum limit allowed. When finished, a dialog will show the exported result in a new map view.

## How it works

1. Create an `ExportVectorTilesTask`, passing in the `PortalItem` for the vector tiled layer. Since vector tiled layers are premium content, you must first authenticate with the Portal.
2. Create parameters for the export by using the task's method, `ExportVectorTilesTask.createDefaultExportVectorTilesParameters(areaOfInterest:maxScale:)`, specifying the area of interest and max scale.
3. Create an `ExportVectorTileJob` by using the task's method, `ExportVectorTilesTask.exportVectorTiles(parameters:vectorTileCacheURL:itemResourceCacheURL:)`, passing in the parameters and specifying a vector tile cache path and an item resource path. The resource path is required if you want to export the tiles with the style.
4. Start the job, then await the job's results.
5. Get the `VectorTileCache` and `ItemResourceCache` from the result's output and create an `ArcGISVectorTiledLayer`.
6. Create a `Map`, specifying a basemap with a base layer of the vector tiled layer.
7. Set the map's initial viewpoint to the area of interest and create a map view with the map.

## Relevant API

* ArcGISVectorTiledLayer
* ExportVectorTilesJob
* ExportVectorTilesParameters
* ExportVectorTilesResult
* ExportVectorTilesTask
* ItemResourceCache
* VectorTileCache

## Additional information

**NOTE:** Downloading Tiles for offline use requires authentication with the web map's server. To use this sample, you will require an [ArcGIS Online](https://www.arcgis.com) account.

Vector tiles have high drawing performance and smaller file size compared to regular tiled layers, due to consisting solely of points, lines, and polygons. However, in ArcGIS Runtime SDK they cannot be displayed in scenes. Visit the [ArcGiS Online Developer's portal](https://developers.arcgis.com/java/latest/guide/layer-types-described.htm#ESRI_SECTION1_0A26749D5D094DAAA9DC12B2F9559E9E) to Learn more about the characteristics of ArcGIS vector tiled layers.

## Tags

cache, download, offline, vector