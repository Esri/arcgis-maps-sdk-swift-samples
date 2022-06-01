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
    @StateObject private var map = Map(basemapStyle: .arcGISTopographic)
    @State private var calloutPlacement: LocationCalloutPlacement?
    @State private var showCallout = false
    
    var body: some View {
        MapView(map: map)
            .onSingleTapGesture { offset, location in
                if calloutPlacement == nil {
                    calloutPlacement = LocationCalloutPlacement(location: location, offset: .zero, allowsOffsetRotation: false)
                } else {
                    calloutPlacement = nil
                }
            }
            .callout(placement: $calloutPlacement) { callout in
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
