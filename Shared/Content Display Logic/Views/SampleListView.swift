//
//  SampleListView.swift
//  Samples (iOS)
//
//  Created by Ting Chen on 4/26/22.
//  Copyright © 2022 Esri. All rights reserved.
//

import SwiftUI

struct SampleListView: View {
    /// The list of samples to display.
    let samples: [Sample]
    
    /// The search term in the search bar.
    @Binding var searchTerm: String
    
    /// The samples to display in the list. Searching adjusts this value.
    var displayedSamples: [Sample] {
        if searchTerm.isEmpty {
            return samples
        } else {
            return samples.filter { $0.name.localizedCaseInsensitiveContains(searchTerm) }
        }
    }
    
    var body: some View {
        List(displayedSamples) { sample in
            NavigationLink(sample.name, destination: SampleDetailView(sample: sample))
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    print("Info button was tapped")
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }
}
