// Copyright 2024 Esri
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
import ArcGISToolkit
import SwiftUI

extension SearchForWebMapView {
    /// A map view that shows an alert when there is an error loading the map.
    struct SafeMapView: View {
        /// The map shown in the map view.
        let map: Map
        
        /// A Boolean value indicating whether the map is being loaded.
        @State private var mapIsLoading = false
        
        /// The error shown in the error alert.
        @State private var error: Error?
        
        var body: some View {
            ZStack {
                MapView(map: map)
                    .onLayerViewStateChanged { _, state in
                        // Show an alert for an error loading any of the layers.
                        guard let error = state.error else { return }
                        self.error = error
                    }
                    .task {
                        mapIsLoading = true
                        defer { mapIsLoading = false }
                        
                        // Show an alert for an error loading the map.
                        do {
                            try await map.load()
                        } catch {
                            self.error = error
                        }
                    }
                
                if mapIsLoading {
                    ProgressView()
                }
            }
            .errorAlert(presentingError: $error)
        }
    }
    
    /// A view that shows a given portal item's info in a row.
    struct PortalItemRowView: View {
        /// The portal item to display in the row.
        let item: PortalItem
        
        var body: some View {
            VStack {
                HStack {
                    AsyncImage(url: item.thumbnail?.url) { image in
                        image
                            .resizable()
                    } placeholder: {
                        Color(.lightGray)
                    }
                    .frame(width: 110, height: 75)
                    .border(.primary)
                    .padding([.leading, .top], 10)
                    
                    Text(item.title)
                    
                    Spacer()
                }
                
                Divider()
                    .overlay(.black)
                
                HStack {
                    if let modificationDate = item.modificationDate {
                        Text(modificationDate, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                    } else {
                        Text("Date: Unknown")
                    }
                    
                    Divider()
                        .overlay(.black)
                    
                    Text(item.owner)
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                }
                .font(.footnote)
                .padding(.top, 2)
                .padding([.horizontal, .bottom], 10)
            }
            .background(Color(.systemGray5))
            .border(Color(.darkGray))
            .padding(.top, 8)
            .padding(.horizontal)
        }
    }
}
