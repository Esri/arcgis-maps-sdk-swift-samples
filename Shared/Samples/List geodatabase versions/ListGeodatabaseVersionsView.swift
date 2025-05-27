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

struct ListGeodatabaseVersionsView: View {
    /// The analysis error shown in the error alert.
    @State private var analysisError: Error?
    /// The task used to perform geoprocessing jobs.
    @State private var geoprocessingTask = GeoprocessingTask(
        url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/GDBVersions/GPServer/ListVersions")!
    )
    /// The geodatabase version information.
    @State private var geodatabaseVersionInfos: [GeodatabaseVersionInfo]?
    
    var body: some View {
        Form {
            if let geodatabaseVersionInfos {
                ForEach(geodatabaseVersionInfos, id: \.objectID) { version in
                    Section("OBJECTID: \(version.objectID)") {
                        LabeledContent("Name", value: version.name)
                            .lineLimit(1)
                            .textSelection(.enabled)
                        LabeledContent("Access", value: version.access)
                        LabeledContent("Created", value: version.created.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Last Modified", value: version.lastModified.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Is Owner", value: version.isOwner)
                        LabeledContent("Parent Version", value: version.parentVersionName)
                        if !version.description.isEmpty {
                            LabeledContent("Description", value: version.description)
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            do {
                let resultFeatures = try await fetchGeodatabaseVersions()
                geodatabaseVersionInfos = makeGeodatabaseVersionInfos(from: resultFeatures)
            } catch {
                analysisError = error
            }
        }
        .errorAlert(presentingError: $analysisError)
    }
    
    /// Fetches geodatabase versions using a geoprocessing job.
    private func fetchGeodatabaseVersions() async throws -> FeatureSet {
        // Creates and configures the job's parameters.
        let parameters = try await geoprocessingTask.makeDefaultParameters()
        
        // Creates and starts the job.
        let geoprocessingJob = geoprocessingTask.makeJob(parameters: parameters)
        geoprocessingJob.start()
        
        // Waits for the job to finish and retrieves the output.
        let result = try await withTaskCancellationHandler {
            try await geoprocessingJob.output
        } onCancel: {
            Task.detached {
                await geoprocessingJob.cancel()
            }
        }
        guard let versions = result.outputs["Versions"] as? GeoprocessingFeatures,
              let featureSet = versions.features else {
            fatalError("Expected geoprocessing results to contain 'Versions' output.")
        }
        return featureSet
    }
    
    /// Converts the features to an array of `GeodatabaseVersionInfo`.
    /// - Parameter featureSet: The features with version info from the job.
    /// - Returns: An array of `GeodatabaseVersionInfo`.
    private func makeGeodatabaseVersionInfos(from featureSet: FeatureSet) -> [GeodatabaseVersionInfo] {
        featureSet
            .features()
            .compactMap { version in
                GeodatabaseVersionInfo(from: version.attributes)
            }
            .sorted {
                $0.objectID < $1.objectID
            }
    }
    
    /// A structure representing geodatabase version information.
    private struct GeodatabaseVersionInfo {
        let objectID: Int64
        let name: String
        let access: String
        let created: Date
        let lastModified: Date
        let isOwner: String
        let parentVersionName: String
        let description: String
        
        init?(from dictionary: [String: Sendable]) {
            guard let access = dictionary["access"] as? String,
                  let created = dictionary["created"] as? Date,
                  let description = dictionary["description"] as? String,
                  let isOwner = dictionary["isowner"] as? String,
                  let lastModified = dictionary["lastmodified"] as? Date,
                  let name = dictionary["name"] as? String,
                  let objectID = dictionary["ObjectID"] as? Int64,
                  let parentVersionName = dictionary["parentversionname"] as? String else {
                return nil
            }
            
            self.objectID = objectID
            self.name = name
            self.access = access
            self.created = created
            self.lastModified = lastModified
            self.isOwner = isOwner
            self.parentVersionName = parentVersionName
            self.description = description
        }
    }
}
