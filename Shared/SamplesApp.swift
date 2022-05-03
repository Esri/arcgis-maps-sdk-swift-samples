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

import SwiftUI
import ArcGIS

@main
struct SamplesApp: App {
    /// The samples for this app.
    let samples: [Sample] = {
        do {
            let data = try Data(contentsOf: .samplesPlist)
            return try PropertyListDecoder().decode([Sample].self, from: data)
        } catch {
            fatalError("Error decoding samples at \(URL.samplesPlist): \(error)")
        }
    }()
    
    init() {
        license()
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView(samples: samples)
        }
    }
}

// MARK: - Sample Import

extension SamplesApp {
    /// Decodes an array of samples from the plist at the given URL.
    /// - Parameter url: The URL to the plist that defines samples.
    /// - Returns: An array of samples.
    func decodeSamples(at url: URL) -> [Sample] {
        do {
            let data = try Data(contentsOf: url)
            return try PropertyListDecoder().decode([Sample].self, from: data)
        } catch {
            fatalError("Error decoding sample at \(url): \(error)")
        }
    }
}

private extension URL {
    /// The URL to the `Samples.plist` file inside the bundle.
    static let samplesPlist = Bundle.main.url(forResource: "Samples", withExtension: "plist")!
}

// MARK: - License

extension SamplesApp {
    /// License the app with ArcGIS Runtime deployment license keys.
    /// - Note: An invalid key does not throw an exception, but simply fails to
    /// license the app, falling back to Developer Mode (which will display
    /// a watermark on the map view).
    func license() {
        if let licenseKey = String.licenseKey,
           let extensionLicenseKey = String.extensionLicenseKey {
            // Set both keys to access all samples, including utility network
            // capability.
            ArcGISRuntimeEnvironment.setLicense(licenseKey: licenseKey, extensions: [extensionLicenseKey])
        }
        // Authentication with an API key or named user is required to access
        // basemaps and other location services.
        ArcGISRuntimeEnvironment.apiKey = .iOS
    }
}
