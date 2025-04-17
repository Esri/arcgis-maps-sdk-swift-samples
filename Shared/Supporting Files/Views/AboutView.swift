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

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    
    private var copyrightText: Text {
        Text("Copyright © 2022 - 2025 Esri. All Rights Reserved.")
    }
    
    let arcGISVersion = Bundle.arcGIS.version.isEmpty
    ? Bundle.arcGIS.shortVersion
    : "\(Bundle.arcGIS.shortVersion) (\(Bundle.arcGIS.version))"
    
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
    // The local package bundle ID is "ArcGIS"; the binary is "com.esri.ArcGIS".
    // By default, the project assumes the dependencies come from GitHub. If they
    // are not found, then for sure we are developing using local packages.
    static let arcGIS = Bundle(identifier: "com.esri.ArcGIS") ?? Bundle(identifier: "ArcGIS")!
    
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
