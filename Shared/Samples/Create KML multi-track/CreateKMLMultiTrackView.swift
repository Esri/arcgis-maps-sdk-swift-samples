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

struct CreateKMLMultiTrackView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The asynchronous action currently being run.
    @State private var asyncAction: AsyncAction? = .startNavigation
    
    /// The text shown in the status bar. This describes the current state of the sample.
    @State private var statusText = ""
    
    /// The KML multi-track loaded from the KMZ file.
    @State private var multiTrack: KMLMultiTrack?
    
    /// A Boolean value indicating whether the recenter button is enabled.
    @State private var recenterIsEnabled = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(
                map: model.map,
                graphicsOverlays: [model.trackElementGraphicsOverlay, model.trackGraphicsOverlay]
            )
            .locationDisplay(model.locationDisplay)
            .overlay(alignment: .top) {
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    if let multiTrack {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            asyncAction = .reset
                        }
                        
                        Spacer()
                        
                        TrackPicker(multiTrack: multiTrack, mapViewProxy: mapViewProxy)
                    } else {
                        Button("Recenter", systemImage: "location.north.circle") {
                            model.locationDisplay.autoPanMode = .navigation
                        }
                        .disabled(!recenterIsEnabled)
                        
                        Spacer()
                        
                        Button(asyncAction == .recordTrack ? "Stop Recording" : "Record Track") {
                            if asyncAction == .recordTrack {
                                asyncAction = nil
                                model.addTrack()
                            } else {
                                asyncAction = .recordTrack
                            }
                        }
                        .disabled(asyncAction != nil && asyncAction != .recordTrack)
                        
                        Spacer()
                        
                        Button("Save", systemImage: "square.and.arrow.down") {
                            asyncAction = .saveKMLMultiTrack
                        }
                        .disabled(asyncAction != nil || model.tracks.isEmpty)
                    }
                }
            }
            .task(id: asyncAction) {
                // Runs the asynchronous action.
                guard let asyncAction else {
                    return
                }
                defer { self.asyncAction = nil }
                
                do {
                    switch asyncAction {
                    case .recordTrack:
                        for await location in model.locationDisplay.$location where location != nil {
                            model.addTrackElement(atPoint: location!.position)
                            statusText = "Recording KML track. Elements added: \(model.trackElements.count)"
                        }
                        
                        statusText = "Tap record to capture KML track elements."
                    case .saveKMLMultiTrack:
                        await model.locationDisplay.dataSource.stop()
                        
                        try await model.saveKMLMultiTrack()
                        multiTrack = try await model.loadKMLMultiTrack()
                        
                        statusText = "Saved KML multi-track to 'HikingTracks.kmz'."
                    case .reset:
                        model.reset()
                        multiTrack = nil
                        await mapViewProxy.setViewpointScale(model.locationDisplay.initialZoomScale)
                        
                        fallthrough
                    case .startNavigation:
                        try await model.startNavigation()
                        statusText = "Tap record to capture KML track elements."
                    }
                } catch {
                    self.error = error
                }
            }
            .task {
                // Monitors the auto pan mode to determine if recenter button should be enabled.
                for await autoPanMode in model.locationDisplay.$autoPanMode {
                    recenterIsEnabled = autoPanMode != .navigation
                }
            }
            .errorAlert(presentingError: $error)
        }
    }
}

private extension CreateKMLMultiTrackView {
    /// A picker for selecting a track from a KML multi-track.
    struct TrackPicker: View {
        /// The KML tracks options shown in the picker.
        private let tracks: [KMLTrack]
        
        /// The proxy for setting map view's viewpoint to the selected track's geometry.
        private let mapViewProxy: MapViewProxy
        
        /// The track selected by the picker.
        @State private var selectedTrack: KMLTrack?
        
        init(multiTrack: KMLMultiTrack, mapViewProxy: MapViewProxy) {
            tracks = multiTrack.tracks
            self.mapViewProxy = mapViewProxy
        }
        
        var body: some View {
            Picker("Track", selection: $selectedTrack) {
                Text("All Tracks")
                    .tag(nil as KMLTrack?)
                
                ForEach(Array(tracks.enumerated()), id: \.offset) { offset, track in
                    Text("KML Track #\(offset + 1)")
                        .tag(track)
                }
            }
            .task(id: selectedTrack) {
                guard let geometry = selectedTrack?.geometry
                        ?? GeometryEngine.union(of: tracks.map(\.geometry)) else {
                    return
                }
                
                await mapViewProxy.setViewpointGeometry(geometry.extent, padding: 25)
            }
        }
    }
    
    /// An asynchronous action associated with the sample.
    enum AsyncAction {
        case startNavigation
        case recordTrack
        case saveKMLMultiTrack
        case reset
    }
}

#Preview {
    CreateKMLMultiTrackView()
}
