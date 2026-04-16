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

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    
    private var copyrightText: Text {
        Text("Copyright © 2022 - 2026 Esri. All Rights Reserved.")
    }
    
    private let arcGISVersion = Bundle.arcGIS.version.isEmpty
    ? Bundle.arcGIS.shortVersion
    : "\(Bundle.arcGIS.shortVersion) (\(Bundle.arcGIS.version))"
    
    /// A Boolean value indicating whether the download offline resources cover is presented.
    @State private var isResourceDownloaderPresented = false
    /// The API key entered in the alert.
    @State private var apiKeyInput = ""
    
    // MARK: Debug
    
    /// A Boolean value indicating whether the API key alert is presented.
    @State private var isAPIKeyAlertPresented = false
    /// A Boolean value indicating whether the API key expiration date alert is presented.
    @State private var isExpirationDateAlertPresented = false
    /// The expiration date of the API key in-use.
    @State private var apiKeyExpirationDate: Date?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack {
                        Image("ArcGIS SDK Logo", label: Text("App icon"))
                        Text(Bundle.main.name)
                            .font(.headline)
                        copyrightText
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity)
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                    LabeledContent("SDK Version", value: arcGISVersion)
                    Link("Write Review", destination: .writeReview)
                }
                Section("Powered By") {
                    Link("ArcGIS Maps SDK for Swift Toolkit", destination: .toolkit)
                    Link("ArcGIS Maps SDK for Swift", destination: .developers)
                }
                Section {
                    Link("Esri Community", destination: .esriCommunity)
                } footer: {
                    Text("Browse and discuss in the Esri Community.")
                }
                Section {
                    Link("GitHub Repository", destination: .githubRepository)
                } footer: {
                    Text("Log an issue in the GitHub repository.")
                }
                Section {
                    Link("API Reference", destination: .apiReference)
                } footer: {
                    Text("View details about the API.")
                }
#if !targetEnvironment(macCatalyst)
                Section {
                    Button("Download Offline Resources") {
                        isResourceDownloaderPresented = true
                    }
                    .fullScreenCover(isPresented: $isResourceDownloaderPresented) {
                        DownloadOfflineResourcesView()
                    }
                }
#endif
#if DEBUG
                debugSection
#endif
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension Bundle {
    // The local package bundle ID is "arcgis.ArcGIS"; the binary is
    // "com.esri.ArcGIS".
    // By default, the project assumes the dependencies come from GitHub. If
    // they are not found, then for sure we are developing using local packages.
    static let arcGIS = Bundle(identifier: "com.esri.ArcGIS") ?? Bundle(identifier: "arcgis.ArcGIS")!
    
    var name: String { object(forInfoDictionaryKey: "CFBundleName") as? String ?? "" }
    var version: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "" }
}

private extension URL {
    static let developers = URL(string: "https://developers.arcgis.com/swift/")!
    static let esriCommunity = URL(string: "https://community.esri.com/t5/swift-maps-sdk-questions/bd-p/swift-maps-sdk-questions")!
    static let githubRepository = URL(string: "https://github.com/Esri/arcgis-maps-sdk-swift-samples")!
    static let toolkit = URL(string: "https://github.com/Esri/arcgis-maps-sdk-swift-toolkit")!
    static let apiReference = URL(string: "https://developers.arcgis.com/swift/api-reference/documentation/arcgis/")!
    static let writeReview = URL(string: "https://apps.apple.com/app/id1630449018?action=write-review")!
}

private extension AboutView {
    /// A section for debugging purposes.
    var debugSection: some View {
        Section {
            Button("Enter API Key") {
                isAPIKeyAlertPresented = true
            }
            .alert("Enter API Key", isPresented: $isAPIKeyAlertPresented) {
                TextField("Enter API Key Here", text: $apiKeyInput, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textEditorStyle(.plain)
                Button("Cancel", role: .cancel) {}
                Button("Submit") {
                    ArcGISEnvironment.apiKey = APIKey(apiKeyInput)!
                }
                .disabled(apiKeyInput.isEmpty)
                Button("Reset") {
                    ArcGISEnvironment.apiKey = .iOS
                    apiKeyInput.removeAll()
                }
            }
            
            Button("Verify Expiration Date") {
                // An alert shows the expiration date for the API key in-use.
                // Compare it with the date in the Swift Sample Viewer Release
                // portal item.
                Task {
                    apiKeyExpirationDate = try await getAPIKeyExpirationDate()
                    isExpirationDateAlertPresented = true
                }
            }
            .alert("API Key Expiration Date", isPresented: $isExpirationDateAlertPresented) {
            } message: {
                Text(
                    apiKeyExpirationDate == nil
                    ? "Failed to get expiration date"
                    : apiKeyExpirationDate!.formatted(date: .abbreviated, time: .omitted)
                )
            }
        } footer: {
            Text("The section above is for testing purposes only.")
        }
    }
    
    /// Gets the expiration date of the API key in-use by making a request to
    /// the ArcGIS REST API.
    func getAPIKeyExpirationDate() async throws -> Date? {
        guard let apiKey = ArcGISEnvironment.apiKey else { return nil }
        
        struct APIResponse: Decodable {
            let appInfo: AppInfo
            
            struct AppInfo: Decodable {
                let expirationDate: Date
            }
        }
        
        // An endpoint to get the current authenticated user identified by the
        // API key access token. The response contains an `appInfo` object,
        // which has the expiration date of the API key.
        // https://developers.arcgis.com/rest/users-groups-and-items/self/
        let (data, _) = try await ArcGISEnvironment.urlSession.data(
            from: URL(string: "https://www.arcgis.com/sharing/rest/Community/self")!,
            queryParameters: ["f": "json", "token": apiKey.rawValue]
        )
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let jsonResponse = try decoder.decode(APIResponse.self, from: data)
        let expirationDate = jsonResponse.appInfo.expirationDate
        return expirationDate
    }
}
