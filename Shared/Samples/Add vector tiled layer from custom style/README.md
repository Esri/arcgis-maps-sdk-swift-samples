# Add vector tiled layer from custom style

Load an ArcGIS vector tiled layers using custom styles.

![Custom styled ArcGIS vector tiled layer](vector-tiled-layer-custom-1.png)
![Offline custom style](vector-tiled-layer-custom-2.png)

## Use case

Vector tile basemaps can be created in ArcGIS Pro and published as offline packages or online services. You can create a custom style tailored to your needs and easily apply them to your map. `AGSArcGISVectorTiledLayer` has many advantages over traditional raster based basemaps (`AGSArcGISTiledLayer`), including smooth scaling between different screen DPIs, smaller package sizes, and the ability to rotate symbols and labels dynamically.

## How to use the sample

Pan and zoom to explore the vector tile basemap. Select a theme to see it applied to the vector tile basemap.

## How it works

1. Construct an `AGSArcGISVectorTiledLayer` with the URL of a custom style from AGOL.
2. Alternatively, construct an `AGSArcGISVectorTiledLayer` by taking a portal item offline and apply it to an offline vector tile package:     
    i. Create an `AGSPortalItem` using the URL of a custom style.  
    ii. Create an `AGSExportVectorTilesTask` using the portal item.  
    iii. Get the `AGSExportVectorTilesJob` using `AGSExportVectorTilesTask.exportStyleResourceCacheJob(withDownloadDirectory:)`.  
    iv. Start the job using  `AGSExportVectorTilesJob.start(statusHandler:completion:)`.  
    v. Construct an `AGSVectorTileCache` using the name of the local vector tile package.  
    vi. Once the job is complete, construct an `AGSArcGISVectorTiledLayer` using the vector tile cache and the `AGSItemResourceCache` from the job's result.  
3. Create an `AGSBasemap` from the `AGSArcGISVectorTiledLayer`.
4. Assign the `AGSBasemap` to the map's `basemap`.

## Relevant API

* ArcGISVectorTiledLayer
* ExportVectorTilesTask
* ItemResourceCache
* Map
* VectorTileCache

## Offline data

This sample uses the [Dodge City OSM](https://www.arcgis.com/home/item.html?id=f4b742a57af344988b02227e2824ca5f) vector tile package. It is downloaded from ArcGIS Online automatically.

## Tags

tiles, vector, vector basemap, vector tile package, vector tiled layer, vector tiles, vtpk
