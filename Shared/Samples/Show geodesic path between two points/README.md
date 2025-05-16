# Show geodesic path between two points

Calculate a geodesic path between two points and measure its distance.

![Image of show geodesic path between two points sample](show-geodesic-path-between-two-points.png)

## Use case

A geodesic distance provides an accurate, real-world distance between two points. Visualizing flight paths between cities is a common example of a geodesic operation since the flight path between two airports takes into account the curvature of the earth, rather than following the planar path between those points, which appears as a straight line on a projected map.

## How to use the sample

Click anywhere on the map. A line graphic will display the geodesic line between the two points. In addition, text that indicates the geodesic distance between the two points will be updated. Click elsewhere and a new line will be created.

## How it works

1. Create a `Point` and display it as a `Graphic` when the `MapView` is tapped.
2. Obtain a new point when another tap occurs on the `MapView` and add this point as a graphic.
3. Create a `Polyline` from the two points.
4. Execute `GeometryEngine.geodeticDensify(_:maxSegmentLength:lengthUnit:curveType:)` by passing in the created polyline then create a graphic from the returned `Geometry`.
5. Execute `GeometryEngine.geodeticDistance(from:to:distanceUnit:azimuthUnit:curveType:)` by passing in the two points and display the returned length on the screen.

## Relevant API

* GeometryEngine.geodeticDensify(_:maxSegmentLength:lengthUnit:curveType:)
* GeometryEngine.geodeticDistance(from:to:distanceUnit:azimuthUnit:curveType:)
* MapView.onSingleTapGesture(perform:)

## About the data

The Imagery basemap provides the global context for the displayed geodesic line.

## Tags

 densify, distance, geodesic, geodetic
