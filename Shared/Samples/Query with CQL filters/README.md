# Query with CQL filters

Query data from an OGC API feature service using CQL filters.

![Screenshot of Query with CQL filters sample](query-with-cql-filters.png)

## Use case

CQL (Common Query Language) is an OGC-created query language used to query for subsets of features. Use CQL filters to narrow geometry results from an OGC feature table.

## How to use the sample

Configure a CQL query by setting the where clause, max features count, and time extent. Tap the "Apply" button to see the query applied to the OGC API features shown on the map.

## How it works

1. Create an `OGCFeatureCollectionTable` object using a URL to an OGC API feature service and a collection ID.
2. Create a `QueryParameters` object.
3. Set the parameters' `whereClause` and `maxFeatures` properties.
4. Create a `TimeExtent` object using `Date` objects for the start time and end time being queried. Set the `timeExtent` property on the parameters.
5. Populate the feature table using `populateFromService(using:clearCache:outFields:)` with the custom query parameters created in the previous steps.
6. Set the map view's viewpoint to view the newly queried features

## Relevant API

* OGCFeatureCollectionTable
* QueryParameters
* TimeExtent

## About the data

The [Daraa, Syria test data](https://demo.ldproxy.net/daraa) is OpenStreetMap data converted to the Topographic Data Store schema of NGA.

## Additional information

See the [OGC API website](https://ogcapi.ogc.org) for more information on the OGC API family of standards. See the [CQL documentation](https://portal.ogc.org/files/96288#cql-core) to learn more about the common query language.

## Tags

browse, catalog, common query language, CQL, feature table, filter, OGC, OGC API, query, service, web
