# Set max extent

Limit the view of a map to a particular area.

![Image of set max extent](set-max-extent.png)

## Use case

When showing map information relevant to only a certain area, you may wish to constrain the user's ability to pan or zoom away.

## How to use the sample

The application loads with a map whose maximum extent has been set to the borders of Colorado. Note that you won't be able to pan far from the Colorado border or zoom out beyond the minimum scale set by the max extent. Use the toggle switch to disable the max extent to freely pan/zoom around the map.

## How it works

1. Create a `Map` object.
2. Create an envelop of the maximum extent.
3. Set the envelope to the map's `maxExtent` property.
4. Set the map to a `MapView` object.
5. Set `maxExtent` to `nil` to disable the maximum extent of the map.

## Relevant API

* Envelope
* Map

## Tags

extent, limit panning, map, mapview, max extent, zoom
