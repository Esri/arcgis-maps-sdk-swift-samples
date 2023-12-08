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
    /// The sample to display.
    private let sample: Sample
    
    /// The sample row to show as the link's label.
    @ViewBuilder private var label: SampleRow
    
    init(_ sample: Sample) {
        self.sample = sample
        label = SampleRow(
            name: AttributedString(sample.name),
            description: AttributedString(sample.description)
        )
    }
    
    var body: some View {
        NavigationLink {
            SampleDetailView(sample: sample)
                .id(sample.name)
        } label: {
            label
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
            ZStack {
                if isFavorited {
                    HStack {
                        Image(systemName: "star.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 8)
                            .padding(.leading, -13)
                        Spacer()
                    }
                }
                
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
                    Label {} icon: {
                        Image(systemName: "info.circle")
                            .symbolVariant(isShowingDescription ? .fill : .none)
                            .imageScale(.medium)
                    }
                    .onTapGesture {
                        isShowingDescription.toggle()
                    }
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

extension SampleLink {
    /// Bolds given text found in the sample link's label.
    /// - Parameter text: The text to bold.
    /// - Returns: A new `SampleLink` with the bolded text.
    func bolding(_ text: String) -> SampleLink {
        var sampleLink = self
        sampleLink.label = SampleRow(
            name: sample.name.boldingFirstOccurrence(of: text),
            description: sample.description.boldingFirstOccurrence(of: text)
        )
        return sampleLink
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
