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
import SwiftUI

struct EditFeatureAttachmentsView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    @State private var tapPoint: CGPoint?
    
    @State var attachments: [Attachment] = []
    
    /// The current draw status of the map.
    @State private var currentDrawStatus: DrawStatus = .inProgress
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    @State private var loaded = false
    
    @State private var showingSheet = false
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .callout(placement: $model.calloutPlacement
                    .animation(model.calloutShouldOffset ? nil : .default.speed(2))
                ) { _ in
                    HStack {
                        VStack {
                            Text(model.calloutText)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                            Text(model.calloutDetailText)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(8)
                        Button("Detail", systemImage: "exclamationmark.circle.fill") {
                            showingSheet = true
                        }
                        .sheet(isPresented: $showingSheet) {
                            VStack {
                                Spacer()
                                List {
                                    ForEach(0...attachments.count, id: \.self) { index in
                                        if index == attachments.count {
                                            Button("Add Attachment") {
                                                print("here")
                                            }
                                        } else {
                                            HStack {
                                                Text("\(attachments[index].name)")
                                                    .font(.footnote)
                                                Spacer()
                                                Button("Download") {
                                                    Task {
                                                        do {
                                                            let data = try await attachments[index].data
                                                            print(data)
                                                        } catch {
                                                            self.error = error
                                                        }
                                                    }
                                                }
                                                .padding(8)
                                                .border(.black, width: 1)
                                                .font(.footnote)
                                                Button("Delete") {
                                                    Task {
                                                        do {
                                                            try await model.delete(attachment: attachments[index])
                                                        } catch {
                                                            self.error = error
                                                        }
                                                    }
                                                }
                                                .padding(8)
                                                .border(.black, width: 1)
                                                .font(.footnote)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                }
                .onDrawStatusChanged { drawStatus in
                    // Updates the state when the map's draw status changes.
                    if drawStatus == .completed {
                        loaded = true
                    }
                }
                .onSingleTapGesture { tap, _ in
                    self.tapPoint = tap
                }
                .task(id: tapPoint) {
                    guard let point = tapPoint else { return }
                    model.featureLayer.clearSelection()
                    do {
                        let result = try await mapProxy.identify(
                            on: model.featureLayer,
                            screenPoint: point,
                            tolerance: 5
                        )
                        guard let features = result.geoElements as? [ArcGISFeature],
                              let feature = features.first else {
                            return
                        }
                        model.selectedFeature = feature
                        model.selectFeature()
                        if let selectedFeature = model.selectedFeature {
                            let title = selectedFeature.attributes["typdamage"] as? String
                            try await selectedFeature.load()
                            guard let pngData = UIImage(named: "Layers-icon")?.pngData() else { return }
                            try await model.add(name: "Attachment.png", type: "png", dataElement: pngData)
                            let attachments = try await selectedFeature.attachments
                            self.attachments = attachments
                            print(attachments)
                            model.updateCalloutPlacement(to: point, using: mapProxy)
                            model.calloutText = title ?? "Callout"
                            model.calloutDetailText = " \(attachments.count) attachments"
                        }
                    } catch {
                        self.error = error
                    }
                }
                .overlay(alignment: .center) {
                    if !loaded {
                        ProgressView("Drawing…")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension EditFeatureAttachmentsView {
    @MainActor
    class Model: ObservableObject {
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(
                center: Point(x: 0, y: 0, spatialReference: .webMercator),
                scale: 100_000_000
            )
            return map
        }()
        
        /// The placement of the callout on the map.
        @Published var calloutPlacement: CalloutPlacement?
        
        @Published var selectedFeature: ArcGISFeature?
        
        /// The text shown on the callout.
        @Published var calloutText: String = ""
        
        /// The text shown on the callout.
        @Published var calloutDetailText: String = ""
        
        /// A Boolean value that indicates whether the callout placement should be offsetted for the map magnifier.
        @Published var calloutShouldOffset = false
        
        var featureLayer: FeatureLayer = {
            let featureTable = ServiceFeatureTable(url: .featureServiceURL)
            var featureLayer = FeatureLayer(featureTable: featureTable)
            return featureLayer
        }()
        
        init() {
            map.addOperationalLayer(featureLayer)
        }
        
        /// Updates the location of the callout placement to a given screen point.
        /// - Parameters:
        ///   - screenPoint: The screen point at which to place the callout.
        ///   - proxy: The proxy used to convert the screen point to a map point.
        func updateCalloutPlacement(to screenPoint: CGPoint, using proxy: MapViewProxy) {
            // Create an offset to offset the callout if needed, e.g. the magnifier is showing.
            let offset = calloutShouldOffset ? CGPoint(x: 0, y: -70) : .zero
            // Get the map location of the screen point from the map view proxy.
            if let location = proxy.location(fromScreenPoint: screenPoint) {
                calloutPlacement = .location(location, offset: offset)
            }
        }
        
        func selectFeature() {
            if let selectedFeature = selectedFeature {
                featureLayer.selectFeature(selectedFeature)
            }
        }
        
        func add(name: String, type: String, dataElement: Data) async throws {
            try await selectedFeature?.addAttachment(named: name, contentType: type, data: dataElement)
        }
        
        func delete(attachment: Attachment) async throws {
            try await selectedFeature?.deleteAttachment(attachment)
        }
        
        func edit(attachment: Attachment, named: String, typed: String, dataElement: Data) async throws {
            try await selectedFeature?.updateAttachment(attachment, name: named, contentType: typed, data: dataElement)
        }
        
        func applyEdits() async throws {
            if let serviceTable = featureLayer.featureTable as? ServiceFeatureTable {
                let edits = try await serviceTable.applyEdits()
                for edited in edits {
                    let result = edited.attachmentResults
                    print(result)
                }
            }
        }
    }
}

private extension URL {
    static let featureServiceURL =  URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!
}

#Preview {
    EditFeatureAttachmentsView()
}
