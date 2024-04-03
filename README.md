# ArcGIS Maps SDK for Swift Samples

This repository contains Swift sample code demonstrating the capabilities of the [ArcGIS Maps SDK for Swift](https://developers.arcgis.com/swift/) and how to use those capabilities in your own app. The project can be opened in Xcode and run on a simulator or a device.

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

* [ArcGIS Maps SDK for Swift](https://developers.arcgis.com/swift/) 200.4 (or newer)
* [ArcGIS Maps SDK for Swift Toolkit](https://github.com/Esri/arcgis-maps-sdk-swift-toolkit) 200.4 (or newer)
* Xcode 15.0 (or newer)

The *ArcGIS Maps SDK for Swift Samples app* has a *Target SDK* version of *15.0*, meaning that it can run on devices with *iOS 15.0* or newer.

## Building Samples Using Swift Package Manager

1. **Fork** and then **clone** the repository
1. **Open** the `Samples.xcodeproj` **project** file
    > The project has been configured to use the arcgis-maps-sdk-swift-toolkit package, which provides the ArcGISToolkit framework as well as the ArcGIS framework.
1. **Run** the `Samples` app target

> To add the Swift packages to your own projects, consult the documentation for the [ArcGIS Maps SDK for Swift Toolkit](https://github.com/Esri/arcgis-maps-sdk-swift-toolkit#swift-package-manager) and [ArcGIS Maps SDK for Swift](https://github.com/Esri/arcgis-maps-sdk-swift#instructions).

## Configuring API Keys

> [!IMPORTANT]
> Acquire the keys from your [dashboard](https://developers.arcgis.com/dashboard). Visit the developer's website to learn more about [API keys](https://developers.arcgis.com/documentation/mapping-apis-and-services/security/api-keys/).

To run this app and access specific, ready-to-use services such as basemap layer, follow the steps to add an API key to a secrets file stored in the project file's directory, `$(SRCROOT)/.secrets`.

1. Create a hidden secrets file in the project file's directory.

  ```sh
  touch .secrets
  ```

2. Add your **API Key** to the aforementioned secrets file. Adding an API key allows you to access a set of ready-to-use services, including basemaps.

  ```sh
  echo ARCGIS_API_KEY_IOS=your-api-key >> .secrets
  ```

  > Replace 'your-api-key' with your keys.

Please see [Configure App Secrets](Documentation/ConfigureAppSecrets.md) for adding license key and other details.

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
