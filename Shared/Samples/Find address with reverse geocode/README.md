# Find address with reverse geocode

Use an online service to find the address for a tapped point.

![Image of find address with reverse geocode](find-address-with-reverse-geocode.png)

## Use case

You might use a geocoder to find a customer's delivery address based on the location returned by their device's GPS.

## How to use the sample

Tap the map to see the nearest address displayed in a callout.

## How it works

1. Create a `LocatorTask` object using a URL to a geocoder service.
2. Create an instance of `ReverseGeocodeParameters` and set `ReverseGeocodeParameters.maxResults` to 1.
3. Pass the `ReverseGeocodeParameters` into `LocatorTask.reverseGeocode(forLocation:parameters:)` and get the matching results from the `GeocodeResult`.
4. Show the results using a `PictureMarkerSymbol` and add the symbol to a `Graphic` in the `GraphicsOverlay`.

## Relevant API

* GeocodeResult
* LocatorTask
* ReverseGeocodeParameters

## Additional information

This sample uses the World Geocoding Service. For more information, see the [Geocoding service](https://developers.arcgis.com/documentation/mapping-apis-and-services/search/services/geocoding-service/) help topic on the ArcGIS Developer website.

## Tags

address, geocode, locate, reverse geocode, search
