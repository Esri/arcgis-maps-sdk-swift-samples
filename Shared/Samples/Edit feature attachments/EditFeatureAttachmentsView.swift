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
    /// The text shown on the callout.
    @State var calloutText: String = ""
    
    /// The text shown on the callout.
    @State var calloutDetailText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(calloutText)
                .font(.callout)
                .multilineTextAlignment(.leading)
            Text(calloutDetailText)
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

struct AddingAttachmentToFeatureView: View {
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

struct AttachmentSheetView: View {
    @State var attachments: [Attachment] = []
    let onAdd: (() -> Void)
    let onDelete: ((Attachment) -> Void)
    var body: some View {
        VStack {
            Spacer()
            List {
                ForEach(0...attachments.count, id: \.self) { index in
                    if index == attachments.count {
                        AddingAttachmentToFeatureView(onAdd: onAdd)
                    } else {
                        AttachmentView(attachment: attachments[index], onDelete: onDelete)
                    }
                }
            }
        }
    }
}

struct EditFeatureAttachmentsView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    @State private var tapPoint: CGPoint?
    
    @State private var attachments: [Attachment] = []
    
    /// The data model for the sample.
    @StateObject private var model = Model()
    
    @State private var loaded = false
    
    @State private var showingSheet = false
    
    @State private var isImporting = false
    
    @State private var text = ""
    
    @State private var images: [Image] = []
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .callout(placement: $model.calloutPlacement
                    .animation(model.calloutShouldOffset ? nil : .default.speed(2))
                ) { _ in
                    HStack {
                        CalloutView(calloutText: model.calloutText, calloutDetailText: model.calloutDetailText)
                            .padding(6)
                        Button("", systemImage: "exclamationmark.circle") {
                            showingSheet = true
                        }
                        .sheet(isPresented: $showingSheet) {
                            AttachmentSheetView(attachments: attachments, onAdd: {
                                Task {
                                    print("click")
                                    do {
                                        if let data = UIImage(named: "PinBlueStar")?.pngData() {
                                            print(data)
                                            try await model.add(name: "Attachment2", type: "png", dataElement: data)
                                            try await model.applyEdits()
                                        }
                                        try await model.updateForSelectedFeature()
                                    } catch {
                                        print(error)
                                        self.error = error
                                    }
                                }
                            }, onDelete: { attachment in
                                Task {
                                    do {
                                        print("delete")
                                        try await model.delete(attachment: attachment)
                                    } catch {
                                        print(error)
                                    }
                                }
                            })
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
                        model.tempURL = try model.createTemporaryDirectory()
                        let result = try await mapProxy.identify(on: model.featureLayer, screenPoint: point, tolerance: 5)
                        guard let features = result.geoElements as? [ArcGISFeature],
                              let feature = features.first else {
                            return
                        }
                        model.selectedFeature = feature
                        model.selectFeature()
                        if let selectedFeature = model.selectedFeature {
                            //                            guard let pngData = UIImage(named: "Layers-icon")?.pngData() else { return }
                            //                            try await model.add(name: "Attachment.png", type: "png", dataElement: pngData)
                            let fetchAttachments = try await model.updateForSelectedFeature()
                            attachments = fetchAttachments
                            model.updateCalloutPlacement(to: point, using: mapProxy)
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

/// The authentication model used to handle challenges and credentials.
private struct ChallengeHandler: ArcGISAuthenticationChallengeHandler {
    func handleArcGISAuthenticationChallenge(
        _ challenge: ArcGISAuthenticationChallenge
    ) async throws -> ArcGISAuthenticationChallenge.Disposition {
        // NOTE: Never hardcode login information in a production application.
        // This is done solely for the sake of the sample.
        return .continueWithCredential(
            try await TokenCredential.credential(for: challenge, username: "viewer01", password: "I68VGU^nMurF")
        )
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
            featureTable.featureRequestMode = .onInteractionCache
            var featureLayer = FeatureLayer(featureTable: featureTable)
            return featureLayer
        }()
        
        var tempURL: URL?
        
        init() {
            ArcGISEnvironment.apiKey = APIKey("AAPKf9d8312d139e441b9df7b9abc9ac392adrCnoMbvSgy7cN3WG0-W2WCP0l-vD2vJVTQzYexR_4HGdB8XQt1YGsDXOoiuCA_x")
            ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler = ChallengeHandler()
            map.addOperationalLayer(featureLayer)
        }
        
        func createTemporaryDirectory() throws -> URL {
            let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                "Attachments"
            )
            // Create and return the full, unique URL to the temporary folder.
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            return directoryURL
        }
        
        func storeAttachment(url: URL, attachment: Attachment) async throws {
            let data = try await attachment.data
            let attachmentURL = url.appending(path: attachment.name)
            do {
                try data.write(to: attachmentURL, options: [.atomic, .completeFileProtection])
            } catch {
                print(error.localizedDescription)
            }
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
        
        func updateForSelectedFeature() async throws -> [Attachment] {
            if let selectedFeature = selectedFeature {
                let title = selectedFeature.attributes["typdamage"] as? String
                try await selectedFeature.load()
                let fetchAttachments = try await selectedFeature.attachments
                calloutText = title ?? "Callout"
                calloutDetailText = "Number of attachments: \(fetchAttachments.count)"
                return fetchAttachments
            }
            return []
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
            if let serviceTable = featureLayer.featureTable as? ServiceFeatureTable, let feature = selectedFeature {
                print("applying")
                try await serviceTable.update(feature)
                let updatedServerResult = try await serviceTable.applyEdits()
                //                let edits = try await serviceTable.applyEdits()
                //                for edited in edits {
                //                    let result = edited.attachmentResults
                //                    print(result)
                //                }
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
