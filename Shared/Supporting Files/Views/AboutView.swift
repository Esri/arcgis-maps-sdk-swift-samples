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
    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack {
                AboutList()
            }
        } else {
            NavigationView {
                AboutList()
            }
        }
    }
}

private struct VersionRow: View {
    let title: String
    let version: String
    let build: String
    
    init(title: String, version: String, build: String = "") {
        self.title = title
        self.version = version
        self.build = build
    }
    
    var versionText: Text {
        if !build.isEmpty {
            return Text("\(version) (\(build))")
        } else {
            return Text("\(version)")
        }
    }
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            versionText
                .foregroundColor(.secondary)
        }
    }
}

private extension Bundle {
    // The local package bundle ID is "ArcGIS"; the binary is "com.esri.ArcGIS".
    // By default, the project assumes the dependencies come from GitHub. If they
    // are not found, then for sure we are developing using local packages.
    static let arcGIS = Bundle(identifier: "com.esri.ArcGIS") ?? Bundle(identifier: "ArcGIS")!
    
    var name: String { object(forInfoDictionaryKey: "CFBundleName") as? String ?? "" }
    var shortVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
    var version: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "" }
}

private extension URL {
    static let developers = URL(string: "https://developers.arcgis.com/swift/")!
    static let esriCommunity = URL(string: "https://community.esri.com/t5/swift-maps-sdk-questions/bd-p/swift-maps-sdk-questions")!
    static let githubRepository = URL(string: "https://github.com/Esri/arcgis-maps-sdk-swift-samples")!
    static let toolkit = URL(string: "https://github.com/Esri/arcgis-maps-sdk-swift-toolkit")!
    static let apiReference = URL(string: "https://developers.arcgis.com/swift/api-reference/documentation/arcgis/")!
}

private struct AboutList: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    
    var copyrightText: Text {
        Text("Copyright © 2022 - 2024 Esri. All Rights Reserved.")
    }
    
    var body: some View {
        List {
            Section {
                VStack {
                    Image("ArcGIS SDK Logo", label: Text("App icon"))
                    Text(Bundle.main.name)
                        .font(.headline)
                    copyrightText
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color.clear)
                .frame(maxWidth: .infinity)
            }
            Section {
                VersionRow(title: "Version", version: Bundle.main.shortVersion)
                VersionRow(title: "SDK Version", version: Bundle.arcGIS.shortVersion, build: Bundle.arcGIS.version)
            }
            Section(header: Text("Powered By")) {
                Link("ArcGIS Maps SDK for Swift Toolkit", destination: .toolkit)
                Link("ArcGIS Maps SDK for Swift", destination: .developers)
            }
            Section(footer: Text("Browse and discuss in the Esri Community.")) {
                Link("Esri Community", destination: .esriCommunity)
            }
            Section(footer: Text("Log an issue in the GitHub repository.")) {
                Link("GitHub Repository", destination: .githubRepository)
            }
            Section(footer: Text("View details about the API.")) {
                Link("API Reference", destination: .apiReference)
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
