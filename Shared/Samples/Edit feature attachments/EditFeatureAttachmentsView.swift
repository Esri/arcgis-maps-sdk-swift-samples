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
    @State private var isLoaded = false
    // Value for toggling whether the attachment sheet is showing.
    @State private var isAttachmentSheetPresented = false
    
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
                            isAttachmentSheetPresented = true
                        }
                        .sheet(isPresented: $isAttachmentSheetPresented) {
                            AttachmentSheetView(model: model)
                        }
                        .padding(8)
                    }
                }
                .onDrawStatusChanged { drawStatus in
                    // Updates the state when the map's draw status changes.
                    if drawStatus == .completed {
                        isLoaded = true
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
                        try await model.setSelectedFeature(for: feature)
                        if let location = mapProxy.location(fromScreenPoint: point) {
                            model.updateCalloutPlacement(to: location)
                        }
                    } catch {
                        self.error = error
                    }
                }
                .overlay(alignment: .center) {
                    if !isLoaded {
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
        
        /// The data model for the sample.
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
                                        guard let pngData = UIImage(
                                            named: "PinBlueStar"
                                        )?.pngData() else {
                                            return
                                        }
                                        try await model.add(
                                            name: "Attachment2",
                                            type: "png",
                                            dataElement: pngData
                                        )
                                    } catch {
                                        self.error = error
                                    }
                                }
                            })
                        } else {
                            let attachment = model.attachments[index]
                            AttachmentView(attachment: attachment, onDelete: { attachment in
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
        /// The data model for the sample.
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
        let attachment: Attachment
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
                        if let uiImage = UIImage(data: result) {
                            image = Image(uiImage: uiImage)
                        }
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

#Preview {
    EditFeatureAttachmentsView()
}
