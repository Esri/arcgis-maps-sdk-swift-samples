# Monitor changes to layer view state

Determine if a layer is currently being viewed.

![Image of monitor changes to layer view state](monitor-changes-to-layer-view-state.png)

## Use case

The view status includes information on the loading state of layers and whether layers are visible at a given scale. You might change how a layer is displayed in a layer list to communicate whether it is being viewed in the map. For example, you could show a loading spinner next to its name when the view status is LOADING, grey out the name when NOT_VISIBLE or OUT_OF_SCALE, show the name normally when ACTIVE, or with a warning or error icon when the status is WARNING or ERROR.

## How to use the sample

Tap the *Load layer* button to add a feature layer to the map. The current view status of the layer will display on the map. Zoom in and out of the map and note the layer disappears when the map is scaled outside of its min and max scale range. Control the layer's visibility with the *Hide layer* button. If you disconnect your device from the network and pan around the map, a warning will display. Reconnect to the network to remove the warning. The layer's current view status will update accordingly as you carry out these actions.

## How it works

1. Create an `ArcGISMap` with some operational layers.
2. Set the map on a `MapView`.
3. Listen to `LayerViewStateChangedEvents` from the map view.
4. Get the `Layer` for the event with `event.getLayer()` and the current view status with `event.getLayerViewStatus()`.

## Relevant API

* Layer
* LayerViewState
* Map
* MapView

## About the data

The [Satellite (MODIS) Thermal Hotspots and Fire Activity](https://runtime.maps.arcgis.com/home/item.html?id=b8f4033069f141729ffb298b7418b653) layer presents detectable thermal activity from MODIS satellites for the last 48 hours. [MODIS Global Fires](https://earthdata.nasa.gov/earth-observation-data/near-real-time/firms/active-fire-data) is a product of NASA’s [Earth Observing System Data and Information System (EOSDIS)](https://earthdata.nasa.gov/about), part of NASA's [Earth Science Data](https://science.nasa.gov/earth-science/earth-data/). EOSDIS integrates remote sensing and GIS technologies to deliver global MODIS hotspot/fire locations to natural resource managers and other stakeholders around the World.

## Additional information

The following are members of the `LayerViewStatus` enum:

* `ACTIVE`: The layer in the view is active.
* `NOT_VISIBLE`: The layer in the view is not visible.
* `OUT_OF_SCALE`: The layer in the view is out of scale. A status of `OUT_OF_SCALE` indicates that the view is zoomed outside of the scale range of the layer. If the view is zoomed too far in (e.g. to a street level), it is beyond the max scale defined for the layer. If the view has zoomed too far out (e.g. to global scale), it is beyond the min scale defined for the layer.
* `LOADING`: The layer in the view is loading. Once loading has completed, the layer will be available for display in the view. If there was a problem loading the layer, the status will be set to ERROR.
* `ERROR`: The layer in the view has an unrecoverable error. When the status is `ERROR`, the layer cannot be rendered in the view. For example, it may have failed to load, be an unsupported layer type, or contain invalid data.
* `WARNING`: The layer in the view has a non-breaking problem with its display, such as incomplete information (eg. by requesting more features than the max feature count of a service) or a network request failure.

## Tags

layer, load, map, status, view, visibility
