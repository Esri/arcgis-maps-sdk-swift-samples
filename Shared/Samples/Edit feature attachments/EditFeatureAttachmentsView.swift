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

private struct CalloutView: View {
    @ObservedObject var model: EditFeatureAttachmentsView.Model
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.calloutText)
                .font(.callout)
                .multilineTextAlignment(.leading)
            Text(model.calloutDetailText)
                .font(.footnote)
                .multilineTextAlignment(.leading)
        }
    }
}

private struct AttachmentView: View {
    var attachment: Attachment
    @State var image: Image?
    let onDelete: ((Attachment) -> Void)
    
    var body: some View {
        HStack {
            Text("\(attachment.name)")
                .font(.title3)
            Spacer()
            Button {
                Task {
                    let result = try await attachment.data
                    image = Image(uiImage: UIImage(data: result)!)
                }
            } label: {
                if let image = image {
                    image
                } else {
                    Image(systemName: "icloud.and.arrow.down.fill")
                }
            }
        }.swipeActions {
            Button("Delete") {
                onDelete(attachment)
            }
            .tint(.red)
        }
    }
}

private struct AddingAttachmentToFeatureView: View {
    let onAdd: (() -> Void)
    var body: some View {
        HStack {
            Spacer()
            Button {
                onAdd()
            } label: {
                Label("Add Attachment", systemImage: "paperclip")
            }
            Spacer()
        }
    }
}

struct EditFeatureAttachmentsView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    @State private var tapPoint: CGPoint?
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    @State private var loaded = false
    
    @State private var showingSheet = false
    
    @State private var images: [Image] = []
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .callout(placement: $model.calloutPlacement
                    .animation(model.calloutShouldOffset ? nil : .default.speed(2))
                ) { _ in
                    HStack {
                        CalloutView(model: model)
                            .padding(6)
                        Button("", systemImage: "exclamationmark.circle") {
                            showingSheet = true
                        }
                        .sheet(isPresented: $showingSheet) {
                            VStack {
                                Spacer()
                                List {
                                    ForEach(0...$model.attachments.count, id: \.self) { index in
                                        if index == model.attachments.count {
                                            AddingAttachmentToFeatureView(onAdd: {
                                                Task {
                                                    do {
                                                        if let data = UIImage(named: "PinBlueStar")?.pngData() {
                                                            try await model.add(name: "Attachment2", type: "png", dataElement: data)
                                                            try await model.updateAttachments()
                                                            model.updateForSelectedFeature()
                                                            model.updateCalloutPlacement(to: tapPoint!, using: mapProxy)
                                                        }
                                                    } catch {
                                                        self.error = error
                                                    }
                                                }
                                            })
                                        } else {
                                            AttachmentView(attachment: model.attachments[index], onDelete: { attachment in
                                                Task {
                                                    do {
                                                        try await model.delete(attachment: attachment)
                                                        try await model.updateAttachments()
                                                        model.updateForSelectedFeature()
                                                        model.updateCalloutPlacement(to: tapPoint!, using: mapProxy)
                                                    } catch {
                                                        print(error)
                                                    }
                                                }
                                            })
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
                        let result = try await mapProxy.identify(on: model.featureLayer, screenPoint: point, tolerance: 5)
                        guard let features = result.geoElements as? [ArcGISFeature],
                              let feature = features.first else {
                            return
                        }
                        model.selectedFeature = feature
                        model.selectFeature()
                        try await model.updateAttachments()
                        model.updateForSelectedFeature()
                        model.updateCalloutPlacement(to: point, using: mapProxy)
                    } catch {
                        self.error = error
                    }
                }
                .overlay(alignment: .center) {
                    if !loaded {
                        ProgressView("Loading…")
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
        
        @Published var attachments: [Attachment] = []
        
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
        
        func updateForSelectedFeature() {
            if let selectedFeature = selectedFeature {
                let title = selectedFeature.attributes["typdamage"] as? String
                calloutText = title ?? "Callout"
                calloutDetailText = "Number of attachments: \(attachments.count)"
            }
        }
        
        func add(name: String, type: String, dataElement: Data) async throws {
            if let feature = selectedFeature {
                let result = try await feature.addAttachment(named: "Attachment.png", contentType: "png", data: dataElement)
                attachments.append(result)
                try await doneAction()
            }
        }
        
        func delete(attachment: Attachment) async throws {
            if let feature = selectedFeature {
                try await feature.deleteAttachment(attachment)
                try await doneAction()
            }
        }
        
        func edit(attachment: Attachment, named: String, typed: String, dataElement: Data) async throws {
            try await selectedFeature?.updateAttachment(attachment, name: named, contentType: typed, data: dataElement)
        }
        
        func doneAction() async throws {
            if let table = selectedFeature?.table as? ServiceFeatureTable {
                let result = try await table.applyEdits()
            }
        }
        
        func updateAttachments() async throws {
            if let feature = selectedFeature {
                let fetchAttachments = try await feature.attachments
                attachments = fetchAttachments
            }
        }
    }
}

private extension URL {
    static let featureServiceURL = URL(
        string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0"
    )!
}

#Preview {
    EditFeatureAttachmentsView()
}
