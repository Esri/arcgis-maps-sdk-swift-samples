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
    
    /// The KML multi-track loaded from the KMZ file.
    @State private var multiTrack: KMLMultiTrack?
    
    /// A Boolean value indicating whether the recenter button is enabled.
    @State private var isRecenterEnabled = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// Represents the various states of the sample.
    private enum SampleState {
        /// The sample is navigating without recording.
        case navigating
        /// A KML track is being recorded.
        case recording
        /// The KML multi-track is being saved, loaded, and viewed.
        case viewingMultiTrack
        /// The sample is being reset.
        case reseting
    }
    
    /// The current state of the sample.
    @State private var state = SampleState.navigating
    
    /// The text shown in the status bar. This describes the current state of the sample.
    private var statusText: String {
        return switch state {
        case .recording: "Recording KML track. Elements added: \(model.trackElements.count)"
        case .viewingMultiTrack: "Saved KML multi-track to 'HikingTracks.kmz'."
        default: "Tap record to capture KML track elements."
        }
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
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
                                state = .reseting
                            }
                            
                            Spacer()
                            
                            TrackPicker(tracks: multiTrack.tracks) { geometry in
                                await mapViewProxy.setViewpointGeometry(geometry.extent, padding: 25)
                            }
                        } else {
                            Button("Recenter", systemImage: "location.north.circle") {
                                model.locationDisplay.autoPanMode = .navigation
                            }
                            .disabled(!isRecenterEnabled)
                            
                            Spacer()
                            
                            Button(state == .recording ? "Stop Recording" : "Record Track") {
                                if state == .recording {
                                    state = .navigating
                                    model.addTrack()
                                } else {
                                    state = .recording
                                }
                            }
                            
                            Spacer()
                            
                            Button("Save", systemImage: "square.and.arrow.down") {
                                state = .viewingMultiTrack
                            }
                            .disabled(model.tracks.isEmpty)
                        }
                    }
                }
                .task(id: state) {
                    // Runs the asynchronous action associated with the sample state.
                    do {
                        switch state {
                        case .navigating:
                            break
                        case .recording:
                            for await location in model.locationDisplay.$location where location != nil {
                                model.addTrackElement(at: location!.position)
                            }
                        case .viewingMultiTrack:
                            await model.locationDisplay.dataSource.stop()
                            
                            try await model.saveKMLMultiTrack()
                            multiTrack = try await model.loadKMLMultiTrack()
                        case .reseting:
                            model.reset()
                            multiTrack = nil
                            
                            await mapViewProxy.setViewpointScale(model.locationDisplay.initialZoomScale)
                            try await model.startNavigation()
                        }
                    } catch {
                        self.error = error
                    }
                }
                .task {
                    // Starts the navigation when the sample opens.
                    do {
                        try await model.startNavigation()
                    } catch {
                        self.error = error
                    }
                    
                    // Monitors the auto pan mode to determine if recenter button should be enabled.
                    for await autoPanMode in model.locationDisplay.$autoPanMode {
                        isRecenterEnabled = autoPanMode != .navigation
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
        let tracks: [KMLTrack]
        
        /// The closure to perform when the selected track has changed.
        let onSelectionChanged: (Geometry) async -> Void
        
        /// The track selected by the picker.
        @State private var selectedTrack: KMLTrack?
        
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
                
                await onSelectionChanged(geometry)
            }
        }
    }
}

#Preview {
    CreateKMLMultiTrackView()
}
