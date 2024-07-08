//
//  EditFeatureAttachmentsView.Model.swift
//  Samples
//
//  Created by Christopher Webb on 7/8/24.
//  Copyright © 2024 Esri. All rights reserved.
//

import ArcGIS
import SwiftUI

extension EditFeatureAttachmentsView {
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
        
        // The currently selected map feature.
        private var selectedFeature: ArcGISFeature?
        
        /// The placement of the callout on the map.
        @Published var calloutPlacement: CalloutPlacement?
        
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
        /// - Parameter Location: The screen point at which to place the callout.
        func updateCalloutPlacement(to location: Point) {
            // Create an offset to offset the callout if needed, e.g. the magnifier is showing.
            let offset = calloutShouldOffset ? CGPoint(x: 0, y: -70) : .zero
            calloutPlacement = .location(location, offset: offset)
        }
        
        /// Selects the feature that is tapped.
        /// - Parameter feature: The feature to set as the selected feature.
        func setSelectedFeature(for feature: ArcGISFeature) async throws {
            selectedFeature = feature
            featureLayer.selectFeature(selectedFeature!)
            try await fetchAttachmentsAndUpdateFeature()
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
                let result = try await feature.addAttachment(
                    named: "Attachment.png",
                    contentType: "png",
                    data: dataElement
                )
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
        private func fetchAttachmentsAndUpdateFeature() async throws {
            try await fetchAndUpdateAttachments()
            updateCalloutDetailsForSelectedFeature()
        }
    }
}

private extension URL {
    // MARK: - URLs
    
    static let featureServiceURL = URL(
        string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0"
    )!
}
