# Show device location

Show your current position on the map, as well as switch between different types of auto-pan modes.

![Screenshot of show device location sample with auto-pan mode off](show-device-location-off.png)
![Screenshot of show device location sample with compass navigation auto-pan mode](show-device-location-compass-navigation.png)

## Use case

When using a map within a GIS application, it may be helpful for a user to know their own location within a map, whether that's to aid the user's navigation or to provide an easy means of identifying/collecting geospatial information at their location.

## How to use the sample

Tap the "Location Settings" button to open the settings interface.

Toggle "Show Location" to change the visibility of the location indicator in the map view. It will be asked by the system to provide permission to use the device's location, if the user have not yet used location services in this app.

Change the "Auto-Pan Mode" to choose if and how the SDK will position the map view's viewpoint to keep the location indicator in-frame. A menu will appear with the following options to change the `LocationDisplay.AutoPanMode`:

* Off: Starts the location display with no auto-pan mode set.
* Re-Center: Starts the location display with auto-pan mode set to `recenter`.
* Navigation: Starts the location display with auto-pan mode set to `navigation`.
* Compass Navigation: Starts the location display with auto-pan mode set to `compassNavigation`.

## How it works

1. Create a `LocationDisplay` object with a `SystemLocationDataSource()`.
2. Use the `locationDisplay(_:)` map view modifier to set the location display for the map view.
3. Use the `LocationDisplay.AutoPanMode` property to change how the map behaves when location updates are received.
4. Use the `start()` and `stop()` methods on the location display's data source as necessary.

## Relevant API

* LocationDataSource
* LocationDisplay
* LocationDisplay.AutoPanMode
* MapView
* MapView.locationDisplay(_:)
* SystemLocationDataSource

## Additional information

Location permissions are required for this sample.

**Note**: As of iOS 8, you are required to request the user's permission to enable location services. You must include either `NSLocationWhenInUseUsageDescription` or `NSLocationAlwaysUsageDescription` along with a brief description of how you use location services in the Info plist of your project.

## Tags

compass, GPS, location, map, mobile, navigation