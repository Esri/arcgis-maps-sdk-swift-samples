// Copyright 2022 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS
import SwiftUI

@main
struct SamplesApp: App {
    init() {
        license()
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - License

extension SamplesApp {
    /// Licenses the app with an ArcGIS Maps SDK license string.
    /// - Note: An invalid string does not throw an exception, but simply fails to
    /// license the app, falling back to Developer Mode (which will display
    /// a watermark on the map view).
    func license() {
        if let licenseStringLiteral = String.licenseKey,
           let licenseKey = LicenseKey(licenseStringLiteral) {
            // Sets the license with an extension if one is included. Both are
            // required to access all samples, including utility network
            // capabilities.
            if let extensionLicenseStringLiteral = String.extensionLicenseKey,
               let extensionLicenseKey = LicenseKey(extensionLicenseStringLiteral) {
                _ = try? ArcGISEnvironment.setLicense(
                    with: licenseKey,
                    extensions: [extensionLicenseKey]
                )
            } else {
                _ = try? ArcGISEnvironment.setLicense(with: licenseKey)
            }
        }
        // Authentication with an API key or named user is required to access
        // basemaps and other location services.
        ArcGISEnvironment.apiKey = .iOS
    }
}
