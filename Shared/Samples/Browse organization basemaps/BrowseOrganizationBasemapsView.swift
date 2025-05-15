// Copyright 2025 Esri
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

struct BrowseOrganizationBasemapsView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    var body: some View {
        Form {
            switch model.basemaps {
            case .success(let basemaps):
                ForEach(basemaps, id: \.item?.id?.rawValue) { basemap in
                    Button {
                        model.selectedItem = .init(basemap: basemap)
                    } label: {
                        HStack {
                            Text(basemap.title)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            case .failure:
                urlEntryView
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Error searching specified portal.")
                )
            case nil:
                if model.isConnecting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    urlEntryView
                }
            }
        }
        .sheet(item: $model.selectedItem) { selectedItem in
            NavigationStack {
                MapView(map: Map(basemap: selectedItem.basemap))
                    .navigationTitle(selectedItem.basemap.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                model.selectedItem = nil
                            }
                        }
                    }
            }
            .interactiveDismissDisabled()
            .highPriorityGesture(DragGesture())
            .pagePresentation()
        }
        .animation(.default, value: model.isConnecting)
    }
    
    @ViewBuilder private var urlEntryView: some View {
        Section {
            HStack {
                TextField("Portal URL", text: $model.portalURLString)
                    .onSubmit { Task { await model.connectToPortal() } }
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                Button("Connect") {
                    Task { await model.connectToPortal() }
                }
                .disabled(model.portalURL == nil)
            }
        }
    }
}

/// A value that represents an item selected by the user.
private struct SelectedItem: Identifiable {
    /// The basemap that was selected.
    let basemap: Basemap
    
    var id: ObjectIdentifier {
        ObjectIdentifier(basemap)
    }
}

private extension Basemap {
    /// The title of the item, or "unknown" when the `item` is `nil`.
    var title: String { item?.title ?? "unknown" }
}

extension BrowseOrganizationBasemapsView {
    @MainActor
    @Observable
    class Model {
        /// The URL string entered by the user.
        var portalURLString = "https://www.arcgis.com"
        
        /// The fetched portal content.
        var basemaps: Result<[Basemap], Error>?
        
        /// A Boolean value indicating if a portal connection is in progress.
        var isConnecting = false
        
        /// The selected item.
        fileprivate var selectedItem: SelectedItem?
        
        /// The URL to the portal.
        var portalURL: URL? { URL(string: portalURLString) }
        
        /// Connects to the portal and finds a batch of web maps.
        func connectToPortal() async {
            precondition(portalURL != nil)
            
            isConnecting = true
            defer { isConnecting = false }
            
            do {
                let portal = Portal(url: portalURL!)
                try await portal.load()
                basemaps = .success(try await portal.basemaps)
            } catch {
                basemaps = .failure(error)
            }
        }
    }
}

#Preview {
    BrowseOrganizationBasemapsView()
}
