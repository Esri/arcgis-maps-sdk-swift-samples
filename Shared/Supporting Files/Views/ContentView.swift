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

import StoreKit
import SwiftUI

struct ContentView: View {
    /// The action to request an App Store review.
    @Environment(\.requestReview) private var requestReview
    
    /// The view model for requesting App Store reviews.
    @Environment(\.requestReviewModel) private var requestReviewModel
    
    /// The visibility of the leading columns in the navigation split view.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    /// A Boolean value indicating whether to present the about view.
    @State private var isAboutViewPresented = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CategoriesView(columnVisibility: $columnVisibility)
                .navigationTitle("Categories")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("About", systemImage: "info.circle") {
                            isAboutViewPresented = true
                        }
                        .sheet(isPresented: $isAboutViewPresented) {
                            AboutView()
                        }
                    }
                }
                .task {
                    // Requests an App Store review.
                    guard requestReviewModel.canRequestReview else {
                        return
                    }
                    
                    try? await Task.sleep(for: .seconds(2))
                    
                    if !requestReviewModel.sampleIsShowing, !Task.isCancelled {
                        requestReview()
                        requestReviewModel.lastRequestedReviewVersion = Bundle.main.shortVersion
                    }
                }
        } content: {
            Text("No Category Selected")
        } detail: {
            NavigationStack {
                Text("No Sample Selected")
            }
        }
        .environment(\.requestReviewModel, requestReviewModel)
    }
}
