//
//  ShowCalloutView.swift
//  Samples (iOS)
//
//  Created by Christopher Lee on 5/31/22.
//  Copyright © 2022 Esri. All rights reserved.
//

import SwiftUI
import ArcGIS

struct ShowCalloutView: View {
    /// A map with a topographic basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISTopographic)
    /// A location callout placement.
    @State private var calloutPlacement: LocationCalloutPlacement?
    
    var body: some View {
        MapView(map: map)
            .onSingleTapGesture { _, mapPoint in
                // Sets the callout placement location to the tap location
                // if callout placement is nil.
                // If not nil, sets the callout placement to nil.
                calloutPlacement = calloutPlacement == nil ? LocationCalloutPlacement(
                    location: mapPoint,
                    offset: .zero,
                    allowsOffsetRotation: false
                ) : nil
            }
            .callout(placement: $calloutPlacement.animation()) { callout in
                VStack(alignment: .leading) {
                    Text("Location")
                        .font(.headline)
                    Text("x: \(String(format: "%.2f", callout.location.x)), y: \(String(format: "%.2f", callout.location.y))")
                        .font(.callout)
                }
                .padding(5)
            }
    }
}
