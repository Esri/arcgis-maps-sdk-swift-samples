# Set spatial reference

Specify a map's spatial reference.

![Image of set spatial reference](set-spatial-reference.png)

## Use case

Choosing the correct spatial reference is important for ensuring accurate projection of data points to a map.  

## How to use the sample

Pan and zoom around the map. Observe how the map is displayed using the World Bonne spatial reference.

## How it works

1. Instantiate a `Map` object using a spatial reference e.g. `Map(spatialReference: SpatialReference(wkid: WKID(54024))`.
2. Instantiate a `Basemap` object using an `ArcGISMapImageLayer` object.
3. Set the base map to the map.
4. Set the map to a `MapView` object.

The ArcGIS map image layer will now use the spatial reference set to the map (World Bonne (WKID: 54024)) and not its default spatial reference.

## Relevant API

* Map
* ArcGISMapImageLayer
* Basemap
* MapView
* SpatialReference

## Additional information

Operational layers will automatically project to this spatial reference when possible.

## Tags

project, WKID
