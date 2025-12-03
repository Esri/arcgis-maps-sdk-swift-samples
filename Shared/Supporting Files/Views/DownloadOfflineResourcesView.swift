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

import SwiftUI

/// A view with controls for downloading the app's on-demand resources.
struct DownloadOfflineResourcesView: View {
    /// The samples that require offline resources.
    let samples = SamplesApp.samples.filter(\.hasDependencies)
    
    /// The action to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// The progress of a download-all operation.
    @State private var downloadAllProgress: Progress?
    
    /// The view models for the on-demand resource requests.
    @State private var onDemandResources: [String: OnDemandResource] = [:]
    
    /// A Boolean value indicating whether all of the `onDemandResources` have successfully downloaded.
    private var allResourcesAreDownloaded: Bool { uniqueRequestStates == [.downloaded] }
    
    /// A Boolean value indicating whether there is an on going download-all operation.
    private var isDownloadingAll: Bool { downloadAllProgress != nil }
    
    /// A Boolean value indicating whether there is an in progress download.
    private var isDownloadingResource: Bool { uniqueRequestStates.contains(.inProgress) }
    
    /// The distinct request states of all on-demand resources.
    private var uniqueRequestStates: Set<OnDemandResource.RequestState> {
        onDemandResources.values.reduce(into: Set()) { result, resource in
            result.insert(resource.requestState)
        }
    }
    
    /// Returns the on-demand resource for the given sample.
    func resource(for sample: Sample) -> OnDemandResource? {
        return onDemandResources[sample.name]
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        downloadAllProgress = Progress()
                    } label: {
                        Label {
                            Text("Download All")
                        } icon: {
                            if let downloadAllProgress {
                                ProgressView(downloadAllProgress)
                                    .progressViewStyle(GaugeProgressViewStyle())
                            } else if allResourcesAreDownloaded {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(onDemandResources.isEmpty || isDownloadingAll || allResourcesAreDownloaded)
                }
                Section {
                    List(samples, id: \.name) { sample in
                        if let resource = resource(for: sample) {
                            DownloadOnDemandResourceView(name: sample.name, resource: resource)
                        }
                    }
                } footer: {
                    Text("**Note**: The system may purge downloads at any time.")
                }
            }
            .navigationTitle("Download Offline Resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isDownloadingResource {
                        Button("Cancel") {
                            for resource in onDemandResources.values where resource.requestState == .inProgress {
                                resource.cancel()
                            }
                            dismiss()
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                guard onDemandResources.isEmpty else { return }
                onDemandResources = await withTaskGroup { group in
                    for sample in samples {
                        group.addTask {
                            let resource = await OnDemandResource(tags: sample.odrTags)
                            return (sample.name, resource)
                        }
                    }
                    var resources: [String: OnDemandResource] = [:]
                    for await (name, resource) in group {
                        resources[name] = resource
                    }
                    return resources
                }
            }
            .task(id: isDownloadingAll) {
                guard isDownloadingAll else { return }
                await downloadAll()
            }
            .onChange(of: isDownloadingResource) {
                guard isDownloadingAll, !isDownloadingResource else { return }
                downloadAllProgress = nil
            }
        }
    }
    
    /// Downloads all of the on-demand resources that haven't started a request yet.
    /// - Note: The system may purge the resources at any time after the request object is deallocated.
    private func downloadAll() async {
        await withTaskGroup { group in
            for resource in onDemandResources.values {
                if resource.isDownloadable {
                    group.addTask(operation: resource.download)
                    downloadAllProgress?.addChildUnits(resource.progress)
                } else if resource.requestState == .inProgress {
                    downloadAllProgress?.addChildUnits(resource.progress)
                }
            }
        }
        
        // Automatically dismisses the view if all of the resources have downloaded successfully.
        if allResourcesAreDownloaded {
            dismiss()
        }
    }
}

/// A view for downloading an `OnDemandResource` and displaying its request state.
private struct DownloadOnDemandResourceView: View {
    /// The name of the resource.
    let name: String
    /// The on-demand resource to download.
    let resource: OnDemandResource
    
    /// A Boolean value indicating whether on-demand resource is currently downloading.
    @State private var isDownloading = false
    
    var body: some View {
        Button {
            isDownloading = true
        } label: {
            Label {
                Text(name)
                
                if resource.requestState == .error, let error = resource.error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                }
            } icon: {
                switch resource.requestState {
                case .inProgress:
                    ProgressView(resource.progress)
                        .progressViewStyle(GaugeProgressViewStyle())
                case .downloaded:
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                default:
                    Image(systemName: "arrow.down.circle")
                }
            }
        }
        .disabled(!resource.isDownloadable)
        .task(id: isDownloading) {
            guard isDownloading else { return }
            defer { isDownloading = false }
            
            await resource.download()
        }
    }
}

/// A circular gauge progress view style.
private struct GaugeProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        if let fractionCompleted = configuration.fractionCompleted {
            let gradientStops: [Gradient.Stop] = [
                .init(color: .accent, location: 0),
                .init(color: .accent, location: fractionCompleted),
                .init(color: .init(.tertiarySystemFill), location: fractionCompleted),
                .init(color: .init(.tertiarySystemFill), location: 1)
            ]
            let gradient = AngularGradient(gradient: .init(stops: gradientStops), center: .center)
            
            Image(systemName: "circle")
                .foregroundStyle(gradient)
                .rotationEffect(.degrees(-90))
        }
    }
}

private extension Progress {
    /// Adds a process object and its unit count as a suboperation of a progress tree.
    /// - Parameter progress: The progress instance to add to the progress tree.
    func addChildUnits(_ progress: Progress) {
        addChild(progress, withPendingUnitCount: progress.totalUnitCount)
        totalUnitCount += progress.totalUnitCount
    }
}
