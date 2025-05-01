// Copyright 2025 Esri
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

import ArcGIS
import SwiftUI

struct AnalyzeHotspotsView: View {
    /// The map displayed by the map view.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(
            center: Point(x: -13671170.647485, y: 5693633.356735, spatialReference: .webMercator),
            scale: 57_779
        )
        return map
    }()
    
    /// The task used to perform geoprocessing jobs.
    @State private var geoprocessingTask = GeoprocessingTask(
        url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/911CallsHotspot/GPServer/911%20Calls%20Hotspot")!
    )
    /// The error thrown by geoprocessing job.
    @State private var analysisError: Error?
    /// A Boolean value indicating whether the geoprocessing job is running.
    @State private var isAnalyzing: Bool = false
    /// A Boolean value that indicates whether the analysis sheet is presented.
    @State private var isAnalysisSheetPresented = false
    /// The from date for the analysis.
    @State private var fromDate = Self.minDate
    /// The to date for the analysis.
    @State private var toDate = Self.maxDate
    
    /// The date range for the analysis.
    var dateRange: ClosedRange<Date> { fromDate...toDate }
    
    /// The minimum date for the analysis.
    static var minDate: Date {
        Calendar.current.date(from: DateComponents(year: 1998, month: 1, day: 1))!
    }
    /// The maximum date for the analysis.
    static var maxDate: Date {
        Calendar.current.date(from: DateComponents(year: 1998, month: 05, day: 31))!
    }
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map)
                .task(id: dateRange) {
                    map.removeAllOperationalLayers()
                    // Creates and configures the job's parameters.
                    let parameters = makeParameters(
                        spatialReference: map.spatialReference,
                        dateRange: dateRange
                    )
                    // Creates and runs the job.
                    let geoprocessingJob = geoprocessingTask.makeJob(parameters: parameters)
                    isAnalyzing = true
                    geoprocessingJob.start()
                    do {
                        let result = try await withTaskCancellationHandler {
                            try await geoprocessingJob.output
                        } onCancel: {
                            Task.detached {
                                await geoprocessingJob.cancel()
                            }
                        }
                        guard let mapImageLayer = result.mapImageLayer else {
                            return
                        }
                        try await mapImageLayer.load()
                        map.addOperationalLayer(mapImageLayer)
                        isAnalyzing = false
                        if let extent = mapImageLayer.fullExtent {
                            await mapView.setViewpointGeometry(extent)
                        }
                    } catch {
                        analysisError = error
                    }
                }
                .toolbar {
                    if isAnalyzing {
                        ToolbarItem(placement: .topBarTrailing) {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("Analysis") {
                            isAnalysisSheetPresented.toggle()
                        }
                        .popover(isPresented: $isAnalysisSheetPresented) {
                            analysisForm
                                .frame(idealWidth: 250, idealHeight: 150)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                .errorAlert(presentingError: $analysisError)
        }
    }
    
    /// The form for customizing the analysis.
    var analysisForm: some View {
        Form {
            Section {
                let displayedComponents: DatePicker<Label>.Components = .date
                DatePicker(
                    "From",
                    selection: $fromDate,
                    in: Self.minDate...toDate,
                    displayedComponents: displayedComponents
                )
                DatePicker(
                    "To",
                    selection: $toDate,
                    in: fromDate...Self.maxDate,
                    displayedComponents: displayedComponents
                )
            }
        }
    }
    
    /// Creates the parameters for a geoprocessing job.
    /// - Parameters:
    ///   - spatialReference: The process and output spatial reference.
    ///   - dateRange: The minimum and maximum dates.
    /// - Returns: A new geoprocessing parameters object
    func makeParameters(
        spatialReference: SpatialReference?,
        dateRange: ClosedRange<Date>
    ) -> GeoprocessingParameters {
        // Creates the query string.
        let format = Date.ISO8601FormatStyle()
            .year()
            .month()
            .day()
        let fromDateString = dateRange.lowerBound.formatted(format)
        let toDateString = dateRange.upperBound.formatted(format)
        let queryString = "(\"DATE\" > date '\(fromDateString) 00:00:00' AND \"DATE\" < date '\(toDateString) 00:00:00')"
        
        // Creates and configures the parameters.
        let parameters = GeoprocessingParameters(executionType: .asynchronousSubmit)
        parameters.processSpatialReference = spatialReference
        parameters.outputSpatialReference = spatialReference
        parameters.setInputValue(GeoprocessingString(value: queryString), forKey: "Query")
        return parameters
    }
}

#Preview {
    AnalyzeHotspotsView()
}
