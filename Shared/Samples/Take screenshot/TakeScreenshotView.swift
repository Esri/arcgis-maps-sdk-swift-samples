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

struct TakeScreenshotView: View {
    /// The current draw status of the map.
    @State private var currentDrawStatus: DrawStatus = .inProgress
    /// The image to export.
    @State private var imageToExport: UIImage?
    /// The map with an imagery basemap centered on Hawaii.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISImageryStandard)
        map.initialViewpoint = Viewpoint(
            latitude: 20.78,
            longitude: -156.84,
            scale: 5_000_000
        )
        return map
    }()
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .onDrawStatusChanged { drawStatus in
                    withAnimation {
                        currentDrawStatus = drawStatus
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if imageToExport != nil {
                        imageExportOverlay
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        if currentDrawStatus == .completed {
                            Button("Take Screenshot") {
                                Task {
                                    // The map view proxy is used to export a
                                    // screenshot of the map view.
                                    imageToExport = try await mapViewProxy.exportImage()
                                }
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }
        }
    }
    
    /// A view to share an image.
    private var imageExportOverlay: some View {
        ZStack(alignment: .topTrailing) {
            PhotoView(
                photo: Photo(
                    image: Image(uiImage: imageToExport!),
                    caption: "A screenshot of the map."
                )
            )
            // An "x" button to close the image export view.
            Button {
                self.imageToExport = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }
            .padding(4)
        }
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(radius: 3)
        .padding()
    }
}

private extension TakeScreenshotView {
    /// A struct that represents a photo with a caption to be shared.
    struct Photo: Transferable {
        static var transferRepresentation: some TransferRepresentation {
            ProxyRepresentation(exporting: \.image)
        }
        
        let image: Image
        let caption: String
    }
    
    /// A view that displays an image to be shared.
    struct PhotoView: View {
        /// The photo to display.
        let photo: Photo
        /// A Boolean value that indicates whether the photo is in fullscreen.
        @State private var isShowingFullScreen = false
        
        var body: some View {
            VStack(spacing: 8) {
                if isShowingFullScreen {
                    Text(photo.caption)
                        .padding()
                }
                
                photo.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                if isShowingFullScreen {
                    // A share link to share the image.
                    ShareLink(
                        item: photo,
                        preview: SharePreview(
                            photo.caption,
                            image: photo.image
                        )
                    )
                    .padding()
                }
            }
            .onTapGesture {
                withAnimation(.default.speed(2)) {
                    isShowingFullScreen.toggle()
                }
            }
            .frame(
                width: isShowingFullScreen ? nil : 100,
                height: isShowingFullScreen ? nil : 100
            )
        }
    }
}

#Preview {
    TakeScreenshotView()
}
