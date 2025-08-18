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
    /// The action to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// The view models for the on-demand resource requests.
    @State private var onDemandResources = SamplesApp.samples.compactMap { sample in
        sample.hasDependencies ? OnDemandResource(sample: sample) : nil
    }
    
    /// The current state of the "download all on-demand resources" request.
    @State private var downloadAllRequestState: OnDemandResource.RequestState?
    
    /// A Boolean value indicating whether confirm cancel alert is showing.
    @State private var confirmCancelAlertIsShowing = false
    
    /// A Boolean value indicating whether all of the `onDemandResources` have successfully downloaded.
    private var allResourcesAreDownloaded: Bool {
        onDemandResources.allSatisfy { $0.requestState == .downloaded }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        downloadAllRequestState = .inProgress
                    } label: {
                        Label {
                            Text("Download All")
                        } icon: {
                            RequestStateView(state: downloadAllRequestState)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(downloadAllRequestState != .notStarted || allResourcesAreDownloaded)
                    .task(id: downloadAllRequestState) {
                        if downloadAllRequestState == nil {
                            await setUpResources()
                        } else if downloadAllRequestState == .inProgress {
                            await downloadAll()
                        }
                    }
                    .onChange(of: allResourcesAreDownloaded) {
                        guard allResourcesAreDownloaded else { return }
                        downloadAllRequestState = .downloaded
                    }
                }
                
                ForEach(onDemandResources, id: \.sampleName) { resource in
                    DownloadOnDemandResourceView(resource: resource)
                }
            }
            .navigationTitle("Download Offline Resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if onDemandResources.allSatisfy({ $0.requestState != .inProgress }) {
                            dismiss()
                        } else {
                            confirmCancelAlertIsShowing = true
                        }
                    }
                    .alert("Cancel Downloads?", isPresented: $confirmCancelAlertIsShowing) {
                        Button("Resume", role: .cancel, action: {})
                        
                        Button("Confirm") {
                            for resource in onDemandResources where resource.requestState == .inProgress {
                                resource.cancel()
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    /// Sets up the on-demand resources' request states.
    private func setUpResources() async {
        await withTaskGroup { group in
            for resource in onDemandResources where resource.requestState == nil {
                group.addTask(operation: resource.setUp)
            }
        }
        
        if downloadAllRequestState == nil {
            downloadAllRequestState = .notStarted
        }
    }
    
    /// Downloads all of the on-demand resources that haven't started a request yet.
    private func downloadAll() async {
        await withTaskGroup { group in
            for resource in onDemandResources where resource.isDownloadable {
                group.addTask(operation: resource.download)
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
    /// The on-demand resource to download.
    let resource: OnDemandResource
    
    /// A Boolean value indicating whether on-demand resource is currently downloading.
    @State private var isDownloading = false
    
    var body: some View {
        Button {
            isDownloading = true
        } label: {
            Label {
                Text(resource.sampleName)
                
                if resource.requestState == .error, let error = resource.error {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                }
            } icon: {
                RequestStateView(state: resource.requestState)
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

/// Displays a view repenting a given `OnDemandResource.RequestState` case.
private struct RequestStateView: View {
    /// The on-demand resource request to display.
    let state: OnDemandResource.RequestState?
    
    var body: some View {
        if state == nil || state == .inProgress {
            ProgressView()
        } else if state == .downloaded {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "arrow.down.circle")
        }
    }
}
