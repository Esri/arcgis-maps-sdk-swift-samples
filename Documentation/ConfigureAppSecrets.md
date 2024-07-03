# Configure App Secrets

As a best-practice principle, our project conceals app secrets from source code by generating and compiling an `AppSecrets.swift` source code file at build time using a custom build rule. The same pattern can be applied to your app development as well.

This build rule looks for a secrets file stored in the project's root directory, `$(SRCROOT)/.secrets`.

Note: License keys are not required for development. Without licensing or licensing with invalid keys do not throw an exception, but simply fail to license the app, falling back to Developer Mode (which will display a watermark on the map and scene views). Apply the license keys when your app is ready for deployment.

1. Create a hidden secrets file in your project's root directory.

  ```sh
  touch .secrets
  ```

2. Add your **License String** to the secrets file. Licensing the app will remove the 'Licensed for Developer Use Only' watermark. Licensing the app is optional in development but required for production. Add your **Extension License String** and **API Key** access token to the secrets file if needed. Learn more about how to [Get a license](https://developers.arcgis.com/swift/license-and-deployment/get-a-license/).

  ```sh
  echo ARCGIS_LICENSE_KEY=your-license-key >> .secrets
  echo ARCGIS_EXTENSION_LICENSE_KEY=your-extension-license-key >> .secrets
  echo ARCGIS_API_KEY_IOS=your-api-key >> .secrets
  ```

  > Replace 'your-license-key', 'your-extension-license-key' and 'your-api-key' with your keys.

Visit the developer's website to learn more about [Deployment](https://developers.arcgis.com/swift/license-and-deployment/) and [Security and authentication](https://developers.arcgis.com/documentation/security-and-authentication/).

To learn more about `masquerade`, consult the [documentation](https://github.com/Esri/data-collection-ios/tree/main/docs#masquerade) of Esri's Data Collection app.
