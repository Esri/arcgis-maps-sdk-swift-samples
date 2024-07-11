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

extension EditFeatureAttachmentsView {
    // MARK: - Model
    
    @MainActor
    class Model: ObservableObject {
        let map = Map(basemapStyle: .arcGISOceans)
        
        /// The currently selected map feature.
        var selectedFeature: ArcGISFeature?
        
        /// The placement of the callout on the map.
        @Published var calloutPlacement: CalloutPlacement?
        
        /// Holds the attachments of the currently selected feature.
        @Published var attachments: [Attachment] = []
        
        /// The text shown on the callout.
        @Published private(set) var calloutText = ""
        
        /// The text shown on the callout.
        @Published private(set) var calloutDetailText = ""
        
        /// The feature layer populated with data by the feature table using the remote service url.
        let featureLayer = FeatureLayer(featureTable: ServiceFeatureTable(url: .featureServiceURL))
        
        init() {
            map.addOperationalLayer(featureLayer)
        }
        
        /// Selects the tapped feature.
        /// - Parameter feature: The selected feature.
        func selectFeature(_ feature: ArcGISFeature) async throws {
            selectedFeature = feature
            featureLayer.selectFeature(feature)
            try await fetchAttachmentsAndUpdateFeature()
        }
        
        /// Updates the callout text for the selected feature.
        private func updateCalloutDetailsForSelectedFeature() {
            if let selectedFeature {
                let title = selectedFeature.attributes["typdamage"] as? String
                calloutText = title ?? "Callout"
                calloutDetailText = "Number of attachments: \(attachments.count)"
            }
        }
        
        /// Adds a new attachment with the given parameters and syncs this change with the server.
        /// - Parameters:
        ///   - name: The attachment name.
        ///   - type: The attachments data type.
        ///   - dataElement: The attachment data.
        func addAttachment(named name: String, type: String, dataElement: Data) async throws {
            if let selectedFeature, let table = selectedFeature.table as? ServiceFeatureTable,
               table.hasAttachments {
                _ = try await selectedFeature.addAttachment(
                    named: "Attachment.png",
                    contentType: "png",
                    data: dataElement
                )
                _ = try await table.applyEdits()
                try await fetchAttachmentsAndUpdateFeature()
            }
        }
        
        /// Deletes the specified attachment and syncs the changes with the server.
        /// - Parameter attachment: The attachment to be deleted.
        func deleteAttachment(_ attachment: Attachment) async throws {
            if let selectedFeature, let table = selectedFeature.table as? ServiceFeatureTable,
               table.hasAttachments {
                try await selectedFeature.deleteAttachment(attachment)
                _ = try await table.applyEdits()
                try await fetchAttachmentsAndUpdateFeature()
            }
        }
        
        /// Fetches attachments for the selected feature from the server.
        private func fetchAndUpdateAttachments() async throws {
            if let selectedFeature, let table = selectedFeature.table as? ServiceFeatureTable,
               table.hasAttachments {
                let fetchAttachments = try await selectedFeature.attachments
                attachments = fetchAttachments
            }
        }
        
        /// Fetches attachments from server and updates the selected feature's callout with the details.
        private func fetchAttachmentsAndUpdateFeature() async throws {
            try await fetchAndUpdateAttachments()
            updateCalloutDetailsForSelectedFeature()
        }
    }
}

private extension URL {
    static var featureServiceURL: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!
    }
}
