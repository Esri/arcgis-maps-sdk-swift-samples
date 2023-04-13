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

import SwiftUI
import UIKit.UIDevice

struct SampleList: View {
    /// A Boolean value that indicates whether the user is searching.
    @Environment(\.isSearching) private var isSearching
    
    /// All samples that will be displayed in the list.
    let samples: [Sample]
    
    /// The search query in the search bar.
    @Binding var query: String
    
    /// A Boolean value that indicates whether to present the about view.
    @State private var isAboutViewPresented = false
    
    /// A string representation of the selected sample.
    @State var selection: String?
    
    /// The samples to display in the list. Searching adjusts this value.
    private var displayedSamples: [Sample] {
        if !isSearching {
            return samples
        } else {
            if query.isEmpty {
                return samples
            } else {
                return samples.filter { $0.name.localizedCaseInsensitiveContains(query) }
            }
        }
    }
    
    var body: some View {
        List(displayedSamples, id: \.name, selection: $selection) { sample in
            SampleRow(sample: sample, selection: selection)
        }
        .navigationTitle("Samples")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAboutViewPresented.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .sheet(isPresented: $isAboutViewPresented) {
                    AboutView()
                }
            }
        }
    }
}

private extension SampleList {
    struct SampleRow: View {
        /// The sample displayed in the row.
        let sample: Sample
        
        /// A string representation of the selected sample.
        let selection: String?
        
        /// The current device type.
        let deviceType = UIDevice.current.userInterfaceIdiom
        
        /// A Boolean value indicating whether to show the sample's description
        @State private var isShowingDescription = false
        
        var sampleForegroundColor: Color {
            selection == sample.name ? .white.opacity(0.8) : .secondary
        }
        
        var descriptionTextColor: Color {
            selection == sample.name ? .white : .accentColor
        }
        
        var selectionColorIsAccentColor: Bool {
            if #available(iOS 16, *), deviceType != .phone {
                return true
            } else {
                return false
            }
        }
        
        var body: some View {
            NavigationLink {
                SampleDetailView(sample: sample)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(sample.name)
                        if isShowingDescription {
                            Text(sample.description)
                                .font(.caption)
                                .foregroundColor(selectionColorIsAccentColor ? sampleForegroundColor : .secondary)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    Spacer()
                    Button {
                        isShowingDescription.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .symbolVariant(isShowingDescription ? .fill : .none)
                            .foregroundColor(selectionColorIsAccentColor ? descriptionTextColor : .accentColor)
                    }
                    .buttonStyle(.borderless)
                }
                .animation(.easeOut(duration: 0.2), value: isShowingDescription)
            }
        }
    }
}
