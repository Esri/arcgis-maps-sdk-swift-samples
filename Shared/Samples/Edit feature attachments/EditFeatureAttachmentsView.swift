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
    // MARK: - View
    
    /// The error shown in the error alert.
    @State private var error: Error?
    // The location that the user tapped on the map.
    @State private var tapPoint: CGPoint?
    // Value that shows loading indicator until features are loaded.
    @State private var loaded = false
    // Value for toggling whether the attachment sheet is showing.
    @State private var showingSheet = false
    
    @State private var images: [Image] = []
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
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
                            AttachmentSheetView(model: model)
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
                        model.setSelectedFeature(for: feature)
                        try await model.fetchAttachmentsAndUpdateFeature()
                        if let location = mapProxy.location(fromScreenPoint: point) {
                            model.updateCalloutPlacement(to: location)
                        }
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
    // MARK: - AttachmentSheetView
    
    struct AttachmentSheetView: View {
        /// The error shown in the error alert.
        @State private var error: Error?
        
        @ObservedObject var model: Model
        
        var body: some View {
            VStack {
                Spacer()
                List {
                    ForEach(0...$model.attachments.count, id: \.self) { index in
                        if index == model.attachments.count {
                            AddingAttachmentToFeatureView(onAdd: {
                                Task {
                                    do {
                                        if let data = UIImage(named: "PinBlueStar")?.pngData() {
                                            try await model.add(
                                                name: "Attachment2",
                                                type: "png",
                                                dataElement: data
                                            )
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
                                    } catch {
                                        self.error = error
                                    }
                                }
                            })
                        }
                    }
                }
            }
            .errorAlert(presentingError: $error)
        }
    }
}

private extension EditFeatureAttachmentsView {
    // MARK: - CalloutView
    
    struct CalloutView: View {
        // The model that holds the callout text and callout detail text.
        @ObservedObject var model: Model
        
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
}

private extension EditFeatureAttachmentsView {
    // MARK: - AttachmentView
    
    struct AttachmentView: View {
        // The attachment that is being displayed.
        var attachment: Attachment
        // The closure called when the delete button is tapped.
        let onDelete: ((Attachment) -> Void)
        // The image in the attachment.
        @State private var image: Image?
        
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
}

private extension EditFeatureAttachmentsView {
    // MARK: - AddingAttachmentToFeatureView
    
    struct AddingAttachmentToFeatureView: View {
        // The closure called when add button is tapped.
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
}

private extension EditFeatureAttachmentsView {
    // MARK: - Model
    
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
        
        // The currently selected map feature.
        private var selectedFeature: ArcGISFeature?
        
        // Holds the attachments of the currently selected feature.
        @Published var attachments: [Attachment] = []
        
        /// The text shown on the callout.
        @Published var calloutText: String = ""
        
        /// The text shown on the callout.
        @Published var calloutDetailText: String = ""
        
        /// A Boolean value that indicates whether the callout placement should be offset for the map magnifier.
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
        ///   - Location: The screen point at which to place the callout.
        func updateCalloutPlacement(to location: Point) {
            // Create an offset to offset the callout if needed, e.g. the magnifier is showing.
            let offset = calloutShouldOffset ? CGPoint(x: 0, y: -70) : .zero
            calloutPlacement = .location(location, offset: offset)
        }
        
        /// Selects the feature that is tapped.
        func setSelectedFeature(for feature: ArcGISFeature) {
            selectedFeature = feature
            if let selectedFeature = selectedFeature {
                featureLayer.selectFeature(selectedFeature)
            }
        }
        
        /// Updates the callout text for the selected feature.
        private func updateCalloutDetailsForSelectedFeature() {
            if let selectedFeature = selectedFeature {
                let title = selectedFeature.attributes["typdamage"] as? String
                calloutText = title ?? "Callout"
                calloutDetailText = "Number of attachments: \(attachments.count)"
            }
        }
        
        /// Adds a new attachment with the given parameters and synch this change with the server.
        /// - Parameters:
        ///   - name: The attachment name.
        ///   - type: The attachments data type.
        ///   - dataElement: The attachment data.
        func add(name: String, type: String, dataElement: Data) async throws {
            if let feature = selectedFeature {
                let result = try await feature.addAttachment(named: "Attachment.png", contentType: "png", data: dataElement)
                attachments.append(result)
                try await syncChanges()
                try await fetchAttachmentsAndUpdateFeature()
            }
        }
        
        /// Deletes the specified attachment and syncs the changes with the server.
        /// - Parameter attachment: The attachment to be deleted.
        func delete(attachment: Attachment) async throws {
            if let feature = selectedFeature {
                try await feature.deleteAttachment(attachment)
                try await syncChanges()
                try await fetchAttachmentsAndUpdateFeature()
            }
        }
        
        /// Applies edits and syncs attachments and features with server.
        private func syncChanges() async throws {
            if let table = selectedFeature?.table as? ServiceFeatureTable {
                _ = try await table.applyEdits()
            }
        }
        
        /// Fetches attachments for feature from server.
        private func fetchAndUpdateAttachments() async throws {
            if let feature = selectedFeature {
                let fetchAttachments = try await feature.attachments
                attachments = fetchAttachments
            }
        }
        
        /// Fetches attachments from server and updates the selected feature's callout with the details
        func fetchAttachmentsAndUpdateFeature() async throws {
            try await fetchAndUpdateAttachments()
            updateCalloutDetailsForSelectedFeature()
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
