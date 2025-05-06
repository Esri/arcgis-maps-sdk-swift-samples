//
//  HillshadeRendererSettingsView.swift
//  Samples
//
//  Created by Ryan Olson on 5/6/25.
//  Copyright © 2025 Esri. All rights reserved.
//

import ArcGIS
import SwiftUI

extension ApplyHillshadeRendererToRasterView {
    struct SettingsView: View {
        let renderer: HillshadeRenderer
        
        @State private var altitude: Double
        @State private var azimuth: Double
        @State private var slopeType: HillshadeRenderer.SlopeType?
        
        init(renderer: HillshadeRenderer) {
            self.renderer = renderer
            self.altitude = renderer.altitude.converted(to: .degrees).value
            self.azimuth = renderer.azimuth.converted(to: .degrees).value
            self.slopeType = renderer.slopeType
        }
        
        var body: some View {
            Form {
                Section {
                    LabeledContent("Altitude", value: altitude, format: .number)
                    Slider(value: $altitude, in: 0...360, step: 1)
                }
                Section {
                    LabeledContent("Azimuth", value: azimuth, format: .number)
                    Slider(value: $azimuth, in: 0...360, step: 1)
                }
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    VStack {
        Text("Preview")
    }
    .sheet(isPresented: .constant(true)) {
//    .popover(isPresented: .constant(true)) {
        ApplyHillshadeRendererToRasterView.SettingsView(
            renderer: HillshadeRenderer(altitude: 10, azimuth: 20, slopeType: nil)
        )
    }
}
