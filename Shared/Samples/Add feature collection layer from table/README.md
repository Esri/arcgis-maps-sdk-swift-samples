# Add feature collection layer from table

Create a Feature Collection Layer from a Feature Collection Table, and add it to a map.

![Image of Add feature collection layer from table sample](add-feature-collection-layer-from-table.png)

## Use case

A Feature Collection allows easily importing external data (such as CSV files), as well as creating custom schema for data that is in non-standardized format. This data can then be used to populate a Feature Collection Table, and displayed in a Feature Collection Layer using the attributes and geometries provided in the external data source. For example, an electricity supplier could use this functionality to visualize existing location data of coverage areas (polygons), power stations (points), transmission lines (polylines), and others.

## How to use the sample

When launched, this sample displays a `FeatureCollectionLayer` with a `Point`, `Polyline` and `Polygon` geometry. Pan and zoom to explore the scene.

## How it works

1. Create a `FeatureCollectionTable` for the `Point`, `Polyline`, and `Polygon` geometry types.
    1. Create the schema for each feature collection table by creating an array of `Field`s.
    2. Create a `FeatureCollectionTable` with the fields created.
    3. Create a `SimpleRenderer` from various symbols.
    4. Create a new point feature using `makeFeature(attributes:geometry:)`.
    5. Add the feature to the `FeatureCollectionTable`.
2. Create a `FeatureCollection` from the `FeatureCollectionTable`s.
3. Create a `FeatureCollectionLayer` using the tables.
4. Add the feature collection layer to the map's operational layers.

## Relevant API

* Feature
* FeatureCollection
* FeatureCollectionLayer
* FeatureCollectionTable
* Field
* SimpleRenderer

## Tags

collection, feature, layers, table
