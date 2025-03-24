# ArcGIS Maps SDK for Swift Samples [![](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/arcgis-maps-swift-samples/id1630449018)

This repository contains Swift sample code demonstrating the capabilities of the [ArcGIS Maps SDK for Swift](https://developers.arcgis.com/swift/) and how to use those capabilities in your own app. The project can be opened in Xcode and run on a simulator or a device.  Or you can [download the app from the App Store](https://apps.apple.com/us/app/arcgis-maps-swift-samples/id1630449018) on your iOS device.

## Features

* Maps - Open, create, interact with and save maps
* Scenes - Visualize 3D environments and symbols
* Layers - Display vector and raster data in maps and scenes
* Augmented Reality - View data overlaid on the real world through your device's camera
* Visualization - Show graphics, popups, callouts, sketches, and style maps with symbols and renderers
* Edit and Manage Data - Add, delete, and edit features and attachments, and taking data offline
* Search and Query - Find addresses, places, and points of interest
* Routing and Logistics - Calculate routes between locations and around barriers
* Analysis - Perform spatial analysis via geoprocessing tasks and services
* Cloud and Portal - Search for web maps and securely connect to your portal
* Utility Networks - Work with utility networks, performing traces and exploring network elements

## Requirements

* [ArcGIS Maps SDK for Swift](https://developers.arcgis.com/swift/) 200.7 (or newer)
* [ArcGIS Maps SDK for Swift Toolkit](https://github.com/Esri/arcgis-maps-sdk-swift-toolkit) 200.7 (or newer)
* Xcode 16.0 (or newer)

The *ArcGIS Maps SDK for Swift Samples app* has a *Target SDK* version of *16.0*, meaning that it can run on devices with *iOS 16.0* or newer.

## Building Samples Using Swift Package Manager

1. **Fork** and then **clone** the repository
1. **Open** the `Samples.xcodeproj` **project** file
    > The project has been configured to use the arcgis-maps-sdk-swift-toolkit package, which provides the ArcGISToolkit framework as well as the ArcGIS framework.
1. **Run** the `Samples` app target

> To add the Swift packages to your own projects, consult the documentation for the [ArcGIS Maps SDK for Swift Toolkit](https://github.com/Esri/arcgis-maps-sdk-swift-toolkit#swift-package-manager) and [ArcGIS Maps SDK for Swift](https://github.com/Esri/arcgis-maps-sdk-swift#instructions).

## Configuring API Keys

> [!IMPORTANT]
> To run this app and access ArcGIS Location Services, follow these steps to obtain an **API key** access token and store it in a secrets file stored in the project file's directory, `$(SRCROOT)/.secrets`.

1. Go to the [Create an API key](https://developers.arcgis.com/documentation/security-and-authentication/api-key-authentication/tutorials/create-an-api-key/) tutorial to obtain the API key access token. Ensure that the following privileges are enabled:

* Location services > Basemaps
* Location services > Geocoding
* Location services > Routing

2. Create a hidden secrets file in the project file's directory.

  ```sh
  touch .secrets
  ```

3. Add your API key to the aforementioned secrets file. Adding an API key allows you to access ArcGIS location services, such as the basemap styles service.

  ```sh
  echo ARCGIS_API_KEY_IOS=your-api-key >> .secrets
  ```

  > Replace 'your-api-key' with your API Key access token.

Please see [Configure App Secrets](Documentation/ConfigureAppSecrets.md) for adding license string and other details.

## Additional Resources

* Unfamiliar with SwiftUI? Check out Apple's [SwiftUI documentation](https://developer.apple.com/documentation/swiftui/).
* Want to start a new project? [Setup](https://developers.arcgis.com/swift/get-started) your development environment
* New to the API? Explore the documentation: [Guide](https://developers.arcgis.com/swift/) | [API Reference](https://developers.arcgis.com/swift/api-reference/documentation/arcgis/)
* Got a question? Ask the community on our [forum](https://community.esri.com/t5/swift-maps-sdk-questions/bd-p/swift-maps-sdk-questions)

## Contributing

Esri welcomes contributions from anyone and everyone. Please see our [guidelines for contributing](https://github.com/esri/contributing).

Find a bug or want to request a new feature? Please let us know by [creating an issue](https://github.com/Esri/arcgis-maps-sdk-swift-samples/issues/new).

## Licensing

Copyright 2022 - 2024 Esri

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

A copy of the license is available in the repository's [LICENSE](LICENSE?raw=1) file.
