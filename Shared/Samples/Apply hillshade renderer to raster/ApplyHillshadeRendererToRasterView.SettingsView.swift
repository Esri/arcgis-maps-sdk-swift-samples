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
        var renderer: Binding<HillshadeRenderer>
        
        @State private var altitude: Double
        @State private var azimuth: Double
        @State private var slopeType: HillshadeRenderer.SlopeType?
        
        init(renderer: Binding<HillshadeRenderer>) {
            self.renderer = renderer
            altitude = renderer.wrappedValue.altitude.converted(to: .degrees).value
            azimuth = renderer.wrappedValue.azimuth.converted(to: .degrees).value
            slopeType = renderer.wrappedValue.slopeType
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
                Section {
                    Picker("Slope Type", selection: $slopeType) {
                        Text("None")
                            .tag(Optional<HillshadeRenderer.SlopeType>.none)
                        Text("Degree")
                            .tag(HillshadeRenderer.SlopeType.degree)
                        Text("Percent Rise")
                            .tag(HillshadeRenderer.SlopeType.percentRise)
                        Text("Scaled")
                            .tag(HillshadeRenderer.SlopeType.scaled)
                    }
                }
            }
            .onChange(of: altitude) { updateRenderer() }
            .onChange(of: azimuth) { updateRenderer() }
            .onChange(of: slopeType) { updateRenderer() }
            .presentationDetents([.medium])
        }
        
        func updateRenderer() {
            renderer.wrappedValue = HillshadeRenderer(
                altitude: altitude,
                azimuth: azimuth,
                slopeType: slopeType
            )
        }
    }
}

#Preview {
    @Previewable @State var isPresented = false
    @Previewable @State var renderer = HillshadeRenderer(
        altitude: 10,
        azimuth: 20,
        slopeType: nil
    )
    
    VStack {
        Text("Preview")
    }
    .toolbar {
        ToolbarItem(placement: .bottomBar) {
            Button("Settings") {
                isPresented = true
            }
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                ApplyHillshadeRendererToRasterView.SettingsView(
                    renderer: $renderer
                )
            }
        }
    }
}
