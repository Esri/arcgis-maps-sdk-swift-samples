# Show shapefile metadata

Read a shapefile and display its metadata.

![Image of show shapefile metadata sample](show-shapefile-metadata.png)

## Use Case

Display metadata for the shapefile currently being viewed—such as tags, credits, and a summary.

## How to Use the Sample

Open the sample to automatically view the shapefile’s metadata.

## How It Works

1. Load the shapefile using the `ShapefileFeatureTable` with the assets URL.
2. Access the shapefile metadata through the `info` property of the feature table.
3. Retrieve and display the thumbnail image from `fileInfo.thumbnail`.
4. Display the shapefile's `summary`, `credits`, and `tags` from the metadata.

## Relevant API

* ShapefileFeatureTable
* ShapefileFeatureTable.info
* ShapefileInfo
* ShapefileInfo.credits
* ShapefileInfo.summary
* ShapefileInfo.tags
* ShapefileInfo.thumbnail

## Offline data

[Aurora Colorado Shapefiles](https://www.arcgis.com/home/item.html?id=d98b3e5293834c5f852f13c569930caa) is available as an item hosted on ArcGIS Online].

## About the data

This sample uses a shapefile showing bike trails in Aurora, CO. The [Aurora Colorado Shapefiles](https://www.arcgis.com/home/item.html?id=d98b3e5293834c5f852f13c569930caa) are available as an item on ArcGIS Online.

## Tags

credits, description, metadata, package, shape file, shapefile, summary, symbology, tags, visualization
