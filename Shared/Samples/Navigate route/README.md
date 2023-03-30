# Navigate route

Use a routing service to navigate between two points.

![Image of navigate route](navigate-route.png)

## Use case

Navigation is often used by field workers while traveling between two points to get live directions based on their location.

## How to use the sample

Tap "Navigate" to simulate traveling and to receive directions from a preset starting point to a preset destination. Tap "Reset" to start the simulation from the beginning.

## How it works

1. Create an `RouteTask` using a URL to an online route service.
2. Generate default `RouteParameters` using `RouteTask.makeDefaultParameters()`.
3. Set `returnsRoutes`, `returnsStops`, and `returnsDirections` on the parameters to `true`.
4. Assign all `Stop` objects to the route parameters using `RouteParameters.setStops(_:)`.
5. Solve the route using `RouteTask.solveRoute(using:)` to get a `RouteResult`.
6. Create an `RouteTracker` using the route result, and the index of the desired route to take.
7. Create a `RouteTrackerLocationDataSource` with the route tracker and a `SimulatedLocationDataSource` object to snap the location display to the route.
8. Use `RouteTracker.trackingStatus` to be notified of `TrackingStatus` changes, and use them to display updated route information. `TrackingStatus` includes a variety of information on the route progress, such as the remaining distance, remaining geometry or traversed geometry (represented by an `Polyline`), or the remaining time (`TimeInterval`), amongst others.
9. Use `RouteTracker.voiceGuidances` to be notified of new voice guidances. From the voice guidance, get the `VoiceGuidance.text` representing the directions and use a text-to-speech engine to output the maneuver directions.
10. You can also query the tracking status for the current `DirectionManeuver` index, retrieve that maneuver from the `Route`, and get its direction text to display in the GUI.
11. To establish whether the destination has been reached, get the `destinationStatus` from the tracking status. If the destination status is `reached` and the `remainingDestinationCount` is 1, you have arrived at the destination and can stop routing. If there are several destinations on your route and the remaining destination count is greater than 1, switch the route tracker to the next destination.

## Relevant API

* DestinationStatus
* DirectionManeuver
* Location
* LocationDataSource
* Route
* RouteParameters
* RouteTask
* RouteTracker
* RouteTrackerLocationDataSource
* SimulatedLocationDataSource
* Stop
* VoiceGuidance

## About the data

The route taken in this sample goes from the San Diego Convention Center, site of the annual Esri User Conference, to the Fleet Science Center, San Diego.

## Tags

directions, maneuver, navigation, route, turn-by-turn, voice
