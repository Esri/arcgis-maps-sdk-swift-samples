# ArcGIS Runtime SDK for Swift Samples

This repository contains Swift sample code demonstrating the capabilities of (⚠️ link subject to change) [ArcGIS Runtime SDK for Swift](https://developers.arcgis.com/ios/) and how to use them in your own app. The project can be opened in Xcode and run on a simulator or a device. Or you can (⚠️ link subject to change) [download the app from the App Store](https://itunes.apple.com/us/app/arcgis-runtime-sdk-for-ios/id1180714771) on your iOS device.

## Requirements

* (⚠️ link subject to change) [ArcGIS Runtime SDK for Swift](https://developers.arcgis.com/ios/) 200.0.0 (or newer)
* (⚠️ link subject to change) [ArcGIS Runtime Toolkit for Swift](https://github.com/ArcGIS/arcgis-runtime-toolkit-swift) 100.13.0 (or newer)
* Xcode 13.0 (or newer)

The *ArcGIS Runtime SDK Samples app* has a *Target SDK* version of *15.0*, meaning that it can run on devices with *iOS 15.0* or newer.

## Building Samples Using Swift API Manually 

1. **Fork** and then **clone** the repository
1. **Configure** the Swift API locally following the instructions in internal Swift API repo, section `Adding the ArcGIS library to your App`
1. **Open** the `arcgis-ios-sdk-samples.xcodeproj` **project** file
1. **Run** the `arcgis-ios-sdk-samples` app target

## Configure API key

To build this app locally, follow the steps to add an API key to a secrets file stored in the project file's directory, `$(SRCROOT)/.secrets`.

1. Create a hidden secrets file in the project file's directory.

  ```bash
  touch .secrets
  ```

2. Add your **API Key** to the secrets file aforementioned. Adding an API key allows you to access a set of ready-to-use services, including basemaps. Acquire the keys from your [dashboard](https://developers.arcgis.com/dashboard). Visit the developer's website to learn more about [API keys](https://developers.arcgis.com/documentation/mapping-apis-and-services/security/api-keys/).

  ```bash
  echo ARCGIS_API_KEY_iOS=your-api-key >> .secrets
  ```

  > Replace 'your-api-key' with your keys.

Please see [Configure App Secrets](Documentation/ConfigureAppSecrets.md) for adding license key and other details.

## Issues

Find a bug or want to request a new feature? Please let us know by submitting an issue.

## Contributing

Esri welcomes contributions from anyone and everyone. Please see our [guidelines for contributing](https://github.com/esri/contributing).

## Licensing

Copyright 2022 Esri

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

A copy of the license is available in the repository's [LICENSE](https://github.com/Esri/arcgis-runtime-samples-swift/blob/main/LICENSE) file.
