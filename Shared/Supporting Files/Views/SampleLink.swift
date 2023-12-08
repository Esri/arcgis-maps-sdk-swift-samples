// Copyright 2023 Esri
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

struct SampleLink: View {
    /// The sample to present.
    private let sample: Sample
    
    /// The text to bold in the sample's name and description.
    private let textToBold: String
    
    /// Creates a link that presents a given sample.
    /// - Parameters:
    ///   - sample: The sample to present.
    ///   - textToBold: The text to bold in the sample's name and description.
    init(_ sample: Sample, textToBold: String = "") {
        self.sample = sample
        self.textToBold = textToBold
    }
    
    var body: some View {
        NavigationLink {
            SampleDetailView(sample: sample)
                .id(sample.name)
        } label: {
            SampleRow(
                name: sample.name.boldingFirstOccurrence(of: textToBold),
                description: sample.description.boldingFirstOccurrence(of: textToBold)
            )
        }
    }
}

private extension SampleLink {
    struct SampleRow: View {
        /// The name string of the sample with attributes.
        let name: AttributedString
        
        /// The description string of the sample with attributes.
        let description: AttributedString
        
        /// A Boolean value indicating whether the sample's description is showing.
        @State private var isShowingDescription = false
        
        /// The names of the favorited samples loaded from user defaults.
        @AppStorage(UserDefaults.favoritedSamplesKey) private var favoritedNames: [String] = []
        
        /// A Boolean value indicating whether the sample is favorited.
        private var isFavorited: Bool {
            favoritedNames.contains(String(name.characters))
        }
        
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                    
                    if isShowingDescription {
                        Text(description)
                            .font(.caption)
                            .opacity(0.75)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                Spacer()
                
                if isFavorited {
                    Image(systemName: "star.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12)
                }
                
                Label {} icon: {
                    Image(systemName: "info.circle")
                        .symbolVariant(isShowingDescription ? .fill : .none)
                        .imageScale(.medium)
                }
                .onTapGesture {
                    isShowingDescription.toggle()
                }
            }
            .contextMenu {
                Button {
                    if isFavorited {
                        if let index = favoritedNames.firstIndex(of: String(name.characters)) {
                            favoritedNames.remove(at: index)
                        }
                    } else {
                        favoritedNames.append(String(name.characters))
                    }
                } label: {
                    if isFavorited {
                        Label("Unfavorite", systemImage: "star.slash")
                    } else {
                        Label("Favorite", systemImage: "star")
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: isShowingDescription)
        }
    }
}

private extension String {
    /// Bolds the first occurrence of substring within the string using markdown.
    /// - Parameter substring: The substring to bold.
    /// - Returns: The attributed string with the bolded substring.
    func boldingFirstOccurrence(of substring: String) -> AttributedString {
        if let range = localizedStandardRange(of: substring.trimmingCharacters(in: .whitespacesAndNewlines)),
           let boldedString = try? AttributedString(markdown: replacingCharacters(in: range, with: "**\(self[range])**")) {
            return boldedString
        } else {
            return AttributedString(self)
        }
    }
}
