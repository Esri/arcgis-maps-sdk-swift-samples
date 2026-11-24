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

import SwiftUI

struct SampleMenuButtons: View {
    /// The sample to show the menu buttons for.
    let sample: Sample
    
    /// The names of the favorite samples loaded from user defaults.
    @AppFavorites private var favoriteNames
    
    /// A Boolean value indicating whether the sample is a favorite.
    private var sampleIsFavorite: Bool {
        favoriteNames.contains(sample.name)
    }
    
    var body: some View {
        Link(destination: sample.esriDeveloperURL) {
            Label("View on Esri Developer", systemImage: "link")
        }
        Link(destination: sample.gitHubURL) {
            Label("View on GitHub", systemImage: "link")
        }
        Divider()
        Button {
            if sampleIsFavorite {
                favoriteNames.removeAll(where: { $0 == sample.name })
            } else {
                favoriteNames.append(sample.name)
            }
        } label: {
            Label(sampleIsFavorite ? "Unfavorite" : "Favorite", systemImage: "star")
                .symbolVariant(sampleIsFavorite ? .slash : .none)
        }
    }
}
