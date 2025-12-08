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

import Foundation

/// A wrapper class that manages on-demand resource request.
@MainActor
@Observable
final class OnDemandResource {
    /// The state of an on-demand resource request.
    enum RequestState {
        /// A request that has been set up but not started.
        case notStarted
        /// A request that has started and is downloading.
        case inProgress
        /// A request that has completed successfully.
        case downloaded
        /// A request that was cancelled.
        case cancelled
        /// A request that ends in an error while downloading resources.
        case error
    }
    
    /// The progress of the on-demand resource request.
    let progress = Progress(totalUnitCount: 100)
    
    /// A Boolean value indicating whether a resource request can be initiated.
    var isDownloadable: Bool {
        requestState != .inProgress && requestState != .downloaded
    }
    
    /// The current state of the on-demand resource request.
    private(set) var requestState: RequestState
    
    /// The error occurred in downloading resources.
    private(set) var error: (any Error)?
    
    /// The on-demand resource request.
    private var request: NSBundleResourceRequest
    
    /// A task for monitoring `request.progress` to update `self.progress`.
    ///
    /// This is needed because passing `request.progress` to a `ProgressView` can cause race condition crashes.
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    
    /// Initializes a request with a set of Resource Tags.
    init(tags: Set<String>) async {
        let request = NSBundleResourceRequest(tags: tags)
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        self.request = request
        
        let isResourceAvailable = await request.conditionallyBeginAccessingResources()
        requestState = isResourceAvailable ? .downloaded : .notStarted
    }
    
    deinit {
        progressTask?.cancel()
    }
    
    /// Cancels the on-demand resource request.
    func cancel() {
        progressTask?.cancel()
        request.endAccessingResources()
        requestState = .cancelled
    }
    
    /// Starts the on-demand resource request.
    func download() async {
        guard isDownloadable else { return }
        
        // Recreates the request if a download has been attempted before so
        // beginAccessingResources() can be called again without crashing.
        if requestState == .cancelled || requestState == .error {
            request = NSBundleResourceRequest(tags: request.tags)
            request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
            
            error = nil
        }
        
        // Monitors `request.progress` to update `self.progress`.
        progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // A stream is used here because `progress.publisher` doesn't always produce values.
            let stream = AsyncStream { continuation in
                let observation = request.progress
                    .observe(\.fractionCompleted, options: [.initial, .new]) { _, change in
                        guard let newValue = change.newValue else { return }
                        continuation.yield(newValue)
                    }
                continuation.onTermination = { _ in
                    observation.invalidate()
                }
            }
            
            for await fractionCompleted in stream {
                self.progress.completedUnitCount = Int64(fractionCompleted * 100)
            }
        }
        
        do {
            requestState = .inProgress
            try await request.beginAccessingResources()
            requestState = .downloaded
        } catch {
            if (error as NSError).code != NSUserCancelledError {
                self.error = error
                requestState = .error
            } else {
                cancel()
            }
        }
        
        progressTask?.cancel()
    }
}

extension NSBundleResourceRequest: @unchecked @retroactive Sendable {}
