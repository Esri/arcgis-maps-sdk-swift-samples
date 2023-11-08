# Find route around barriers

Find a route that reaches all stops without crossing any barriers.

![Image of find route around barriers](find-route-around-barriers-1.png)
![Image of find route around barriers](find-route-around-barriers-2.png)

## Use case

You can define barriers to avoid unsafe areas, for example flooded roads, when planning the most efficient route to evacuate a hurricane zone. When solving a route, barriers allow you to define portions of the road network that cannot be traversed. You could also use this functionality to plan routes when you know an area will be inaccessible due to a community activity like an organized race or a market night.

In some situations, it is further beneficial to find the most efficient route that reaches all stops, reordering them to reduce travel time. For example, a delivery service may target a number of drop-off addresses, specifically looking to avoid congested areas or closed roads, arranging the stops in the most time-effective order.

## How to use the sample

Select "Stops" and tap on the map to add stops to the route. Select "Barriers" and tap on the map to add areas that can't be crossed by the route. Tap "Route" to find the route and display it. Tap the settings button to toggle preferences like find the best sequence or preserve the first or last stop. Additionally, tap the directions button to view a list of the directions.

## How it works

1. Create the route task by calling `RouteTask.init(url:)` with the URL to a Network Analysis route service.
2. Get the default route parameters for the service by calling `RouteTask.makeDefaultParameters()`.
3. When the user adds a stop, add it to the route parameters.
    1. Normalize the geometry; otherwise the route job would fail if the user included any stops over the 180th degree meridian.
    2. Create a composite symbol for the stop. This sample uses a blue marker and a text symbol.
    3. Create the graphic from the geometry and the symbol.
    4. Add the graphic to the stops graphics overlay.
4. When the user adds a barrier, create a polygon barrier and add it to the route parameters.
    1. Normalize the geometry (see **3i** above).
    2. Buffer the geometry to create a larger barrier from the tapped point by calling `GeometryEngine.buffer(around:distance:)`.
    3. Create the graphic from the geometry and the symbol.
    4. Add the graphic to the barriers overlay.
5. When ready to find the route, configure the route parameters.
    1. Set `RouteParameters.returnsDirections` to `true`.
    2. Create a `Stop` for each graphic in the stops graphics overlay. Add that stop to a list, then call `RouteParameters.setStops(_:)`.
    3. Create a `PolygonBarrier` for each graphic in the barriers graphics overlay. Add that barrier to a list, then call `RouteParameters.setPolygonBarriers(_:)`.
    4. If the user will accept routes with the stops in any order, set `RouteParameters.findsBestSequence` to `true` to find the most optimal route.
    5. If the user has a definite start point, set `RouteParameters.preservesFirstStop` to `true`.
    6. If the user has a definite final destination, set `RouteParameters.preservesLastStop` to `true`.
6. Calculate and display the route.
    1. Call `RouteTask.solveRoute(using:)` to get a `RouteResult`.
    2. Get the first returned route by calling `RouteResult.routes.first`.
    3. Get the geometry from the route as a polyline by accessing the `Route.geometry` property.
    4. Create a graphic from the polyline and a simple line symbol.
    5. Display the steps on the route, available from `Route.directionManeuvers`.

## Relevant API

* DirectionManeuver
* PolygonBarrier
* Route
* Route.directionManeuvers
* Route.geometry
* RouteParameters.clearPolygonBarriers
* RouteParameters.findsBestSequence
* RouteParameters.preservesFirstStop
* RouteParameters.preservesLastStop
* RouteParameters.returnsDirections
* RouteParameters.setPolygonBarriers
* RouteResult
* RouteResult.routes
* RouteTask
* Stop

## About the data

This sample uses an Esri-hosted sample street network for San Diego.

## Tags

barriers, best sequence, directions, maneuver, network analysis, routing, sequence, stop order, stops
