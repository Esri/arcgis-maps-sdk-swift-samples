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
        /// The renderer that this view updates.
        @Binding var renderer: HillshadeRenderer
        /// The altitude angle of the renderer.
        @State private var altitude: Double = 0
        /// The azimuth angle of the renderer.
        @State private var azimuth: Double = 0
        /// The slope type of the renderer.
        @State private var slopeType: HillshadeRenderer.SlopeType?
        
        var body: some View {
            NavigationStack {
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
                                .tag(nil as HillshadeRenderer.SlopeType?)
                            Text("Degree")
                                .tag(Optional(HillshadeRenderer.SlopeType.degree))
                            Text("Percent Rise")
                                .tag(Optional(HillshadeRenderer.SlopeType.percentRise))
                            Text("Scaled")
                                .tag(Optional(HillshadeRenderer.SlopeType.scaled))
                        }
                    }
                }
                .frame(idealWidth: 320, idealHeight: 380)
                .onAppear {
                    // Initialize the state when the view appears.
                    altitude = renderer.altitude.converted(to: .degrees).value
                    azimuth = renderer.azimuth.converted(to: .degrees).value
                    slopeType = renderer.slopeType
                }
                .onChange(of: altitude) { updateRenderer(previousRenderer: renderer) }
                .onChange(of: azimuth) { updateRenderer(previousRenderer: renderer) }
                .onChange(of: slopeType) { updateRenderer(previousRenderer: renderer) }
                .presentationDetents([.medium])
                .navigationTitle("Hillshade Renderer Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        
        /// Updates the renderer to the latest state.
        func updateRenderer(previousRenderer: HillshadeRenderer) {
            renderer = HillshadeRenderer(
                altitude: altitude,
                azimuth: azimuth,
                slopeType: slopeType,
                zFactor: previousRenderer.zFactor,
                pixelSizeFactor: previousRenderer.pixelSizeFactor,
                pixelSizePower: previousRenderer.pixelSizePower,
                outputBitDepth: previousRenderer.outputBitDepth
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
//            .sheet(isPresented: $isPresented) {
            .popover(isPresented: $isPresented) {
                ApplyHillshadeRendererToRasterView.SettingsView(
                    renderer: $renderer
                )
            }
        }
    }
}
