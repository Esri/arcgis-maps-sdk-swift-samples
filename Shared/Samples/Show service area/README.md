# Show service area

Find the service area within a network from a given point.

![Image of show service area sample](show-service-area.png)

## Use case

A service area shows locations that can be reached from a facility based off a certain impedance, such as travel time or distance. Barriers can increase impedance by either adding to the time it takes to pass through the barrier or by altogether preventing passage.

You might calculate the region around a hospital in which ambulances can service in 30 minutes or less.

## How to use the sample

In order to find any service areas at least one facility needs to be added to the map view.

* To add a facility, tap or click the facility button and then anywhere on the map.
* To add a barrier, tap or click the barrier button and then multiple locations on map. Tap or click the barrier button again to finish drawing barrier. Tapping or clicking any other button will also stop the barrier from drawing.
* To show service areas around facilities that were added, tap or click the Service Areas button.
* The reset button clears all graphics and resets the service area task.

## How it works

1. Create a new `ServiceAreaTask` from a network service.
2. Create default `ServiceAreaParameters` from the service area task.
3. Set the parameters to return polygons (true) to return all service areas.
4. Add a `ServiceAreaFacility` to the parameters.
5. Get the `ServiceAreaResult` by solving the service area task using the parameters.
6. Get any `ServiceAreaPolygons` that were returned using `ServiceAreaResult.resultPolygons(forFacilityAtIndex:)`.
7. Display the service area polygons as graphics in a `GraphicsOverlay` on the `MapView`.

## Relevant API

* PolylineBarrier
* ServiceAreaFacility
* ServiceAreaParameters
* ServiceAreaPolygon
* ServiceAreaResult
* ServiceAreaTask

## Tags

barriers, facilities, impedance, logistics, routing
