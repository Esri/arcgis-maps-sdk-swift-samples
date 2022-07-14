// Copyright 2022 Esri
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

import Combine
import Foundation

@MainActor
/// A wrapper class that manages on-demand resource request.
final class OnDemandResource: ObservableObject {
    /// The state of an on-demand resource request.
    enum RequestState {
        /// A request that has not started.
        case notStarted
        /// A request that has started and is downloading.
        case inProgress(Double)
        /// A request that has completed successfully.
        case downloaded
        /// A request that was cancelled.
        case cancelled
        /// A request that ends in an error while downloading resources.
        case error
    }
    
    /// The current state of the on-demand resource request.
    @Published private(set) var requestState: RequestState = .notStarted
    
    /// The error occured in downloading resources.
    @Published private(set) var error: Error?
    
    /// The on-demand resource request.
    private let request: NSBundleResourceRequest
    
    /// The progress of the on-demand resource request.
    var progress: Progress { request.progress }
    
    /// Initializes a request with a set of Resource Tags.
    init(tags: Set<String>) {
        request = NSBundleResourceRequest(tags: tags)
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        request.progress
            .publisher(for: \.fractionCompleted, options: .new)
            .map { $0 < 1 ? .inProgress($0) : .downloaded }
            .assign(to: &$requestState)
    }
    
    /// Cancels the on-demand resource request.
    func cancel() {
        request.progress.cancel()
        request.endAccessingResources()
        requestState = .cancelled
    }
    
    /// Starts the on-demand resource request.
    func download() async {
        // Initiates download when it is not being/already downloaded.
        // Checks if the resource is already on device.
        let isResourceAvailable = await request.conditionallyBeginAccessingResources()
        if !isResourceAvailable {
            do {
                requestState = .inProgress(0)
                try await request.beginAccessingResources()
                requestState = .downloaded
            } catch {
                requestState = .error
                self.error = error
            }
        }
    }
}
