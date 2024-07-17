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
    /// The data model for the sample.
    @StateObject private var model = Model()
    /// The location that the user tapped on the screen.
    @State private var screenPoint: CGPoint?
    /// The location that the user tapped on the map.
    @State private var mapPoint: Point?
    /// A Boolean value indicating whether the attachment sheet is showing.
    @State private var attachmentSheetIsPresented = false
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .callout(placement: $model.calloutPlacement.animation(.default.speed(2))) { _ in
                    if model.selectedFeature != nil {
                        HStack {
                            CalloutView(model: model)
                                .padding(6)
                            Button {
                                attachmentSheetIsPresented = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                            .sheet(isPresented: $attachmentSheetIsPresented) {
                                NavigationStack {
                                    AttachmentSheetView(model: model)
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                .onSingleTapGesture { screenPoint, mapPoint in
                    self.mapPoint = mapPoint
                    self.screenPoint = screenPoint
                }
                .task(id: screenPoint) {
                    guard let screenPoint, let mapPoint else { return }
                    model.featureLayer.clearSelection()
                    do {
                        let result = try await mapProxy.identify(
                            on: model.featureLayer,
                            screenPoint: screenPoint,
                            tolerance: 2
                        )
                        guard let feature = result.geoElements.first as? ArcGISFeature else {
                            model.calloutPlacement = nil
                            model.selectedFeature = nil
                            return
                        }
                        try await model.selectFeature(feature)
                        model.calloutPlacement = .location(mapPoint)
                    } catch {
                        model.calloutPlacement = nil
                        model.selectedFeature = nil
                        self.error = error
                    }
                }
        }
        .errorAlert(presentingError: $error)
    }
}

// MARK: - AttachmentSheetView

private extension EditFeatureAttachmentsView {
    struct AttachmentSheetView: View {
        /// The error shown in the error alert.
        @State private var error: Error?
        /// The data model for the sample.
        @ObservedObject var model: Model
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        var body: some View {
            Form {
                Section {
                    List {
                        ForEach(model.attachments, id: \.id) { attachment in
                            AttachmentView(attachment: attachment, onDelete: { attachment in
                                Task {
                                    do {
                                        try await model.deleteAttachment(attachment)
                                    } catch {
                                        self.error = error
                                    }
                                }
                            })
                        }
                    }
                }
                Section {
                    AddAttachmentView(onAdd: {
                        Task {
                            do {
                                guard let pngData = UIImage(named: "PinBlueStar")?.pngData() else { return }
                                try await model.addAttachment(
                                    named: "Attachment",
                                    type: "png",
                                    dataElement: pngData
                                )
                            } catch {
                                self.error = error
                            }
                        }
                    })
                }
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .errorAlert(presentingError: $error)
        }
    }
}

// MARK: - CalloutView

private extension EditFeatureAttachmentsView {
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

// MARK: - AttachmentView

private extension EditFeatureAttachmentsView {
    struct AttachmentView: View {
        // The attachment that is being displayed.
        let attachment: Attachment
        // The closure called when the delete button is tapped.
        let onDelete: ((Attachment) -> Void)
        // The image in the attachment.
        @State private var image: Image?
        
        var body: some View {
            HStack {
                Text(attachment.name)
                    .font(.title3)
                Spacer()
                Button {
                    Task {
                        let result = try await attachment.data
                        if let uiImage = UIImage(data: result) {
                            image = Image(uiImage: uiImage)
                        } else {
                            image = Image(systemName: "exclamationmark.triangle")
                        }
                    }
                } label: {
                    if let image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                }
            }
            .swipeActions {
                Button("Delete") {
                    onDelete(attachment)
                }
                .tint(.red)
            }
        }
    }
}

// MARK: - AddAttachmentView

private extension EditFeatureAttachmentsView {
    struct AddAttachmentView: View {
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
