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

import ArcGIS
import SwiftUI

struct ShowDeviceLocationHistoryView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// A Boolean value indicating whether the tracking button is disabled.
    @State private var trackingButtonIsDisabled = true
    
    /// A Boolean value indicating whether to track the simulated location.
    @State private var isTracking = false
    
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
            .locationDisplay(model.locationDisplay)
            .task {
                do {
                    try await model.startLocationDataSource()
                    trackingButtonIsDisabled = false
                } catch {
                    // Shows an alert with an error if starting the data source fails.
                    self.error = error
                }
            }
            .task(id: isTracking) {
                guard isTracking else { return }
                await model.processingLocationChanges()
            }
            .onDisappear {
                model.stopLocationDataSource()
                isTracking = false
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Toggle(isTracking ? "Tracking Enabled" : "Tracking Disabled", isOn: $isTracking)
                        .disabled(trackingButtonIsDisabled)
                }
            }
            .errorAlert(presentingError: $error)
    }
}

private extension ShowDeviceLocationHistoryView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with a light gray basemap style.
        let map = Map(basemapStyle: .arcGISLightGrayBase)
        
        /// A location display using a simulated location data source.
        let locationDisplay: LocationDisplay
        
        /// The graphics overlays used in this sample.
        let graphicsOverlays: [GraphicsOverlay]
        
        /// The markers for traveled location points.
        private let locationGraphic = Graphic()
        
        /// The line graphic for traveled path.
        private let trackGraphic = Graphic()
        
        /// A polyline builder to make the line graphic.
        private let trackBuilder = PolylineBuilder(spatialReference: .webMercator)
        
        /// A multipoint builder to make the point graphics.
        private let multipointBuilder = MultipointBuilder(spatialReference: .webMercator)
        
        init() {
            locationDisplay = LocationDisplay(dataSource: Self.makeSimulatedLocationDataSource())
            locationDisplay.autoPanMode = .recenter
            
            let trackOverlay = GraphicsOverlay(graphics: [trackGraphic])
            trackOverlay.renderer = SimpleRenderer(
                symbol: SimpleLineSymbol(
                    style: .solid,
                    color: .tintColor.withAlphaComponent(0.5),
                    width: 3
                )
            )
            
            let locationsOverlay = GraphicsOverlay(graphics: [locationGraphic])
            locationsOverlay.renderer = SimpleRenderer(
                symbol: SimpleMarkerSymbol(
                    style: .circle,
                    color: .red,
                    size: 5
                )
            )
            
            graphicsOverlays = [trackOverlay, locationsOverlay]
        }
        
        /// Starts the location data source.
        func startLocationDataSource() async throws {
            guard locationDisplay.dataSource.status != .started else { return }
            try await locationDisplay.dataSource.start()
        }
        
        /// Stops the location data source.
        func stopLocationDataSource() {
            Task { [weak self] in
                await self?.locationDisplay.dataSource.stop()
            }
        }
        
        /// A helper method to visualize the traveled path.
        /// - Parameter lastPosition: The last location point from the
        /// location data source.
        private func processLocationUpdate(lastPosition: Point) {
            multipointBuilder.points.append(lastPosition)
            locationGraphic.geometry = multipointBuilder.toGeometry()
            trackBuilder.add(lastPosition)
            trackGraphic.geometry = trackBuilder.toGeometry()
        }
        
        /// Starts to process location updates produced by the async stream
        /// using the `for-await-in` syntax.
        func processingLocationChanges() async {
            for await location in locationDisplay.dataSource.locations {
                processLocationUpdate(lastPosition: location.position)
            }
        }
        
        /// Makes the simulated location data source for the sample.
        /// - Returns: A simulated location data source in Los Angeles, CA.
        private static func makeSimulatedLocationDataSource() -> SimulatedLocationDataSource {
            // swiftlint:disable:next force_try
            let routePolyline = try! Polyline.fromJSON(polylineJSONString)
            // Densify the simulated path to make it smoother.
            let densifiedRoute = GeometryEngine.geodeticDensify(
                routePolyline,
                maxSegmentLength: 50.0,
                lengthUnit: .meters,
                curveType: .geodesic
            ) as! Polyline
            return SimulatedLocationDataSource(polyline: densifiedRoute)
        }
        
        /// A JSON for the simulated path.
        private static var polylineJSONString: String {
            """
            {"paths":[[ [-13185646.046666779,4037971.5966668758],
            [-13185586.780000051,4037827.6633333955],[-13185514.813333312,4037709.1299999417],
            [-13185569.846666701,4037522.8633330846],[-13185591.01333339,4037378.9299996048],
            [-13185629.113333428,4037283.6799995075],[-13185770.93000024,4037425.4966663187],
            [-13185821.730000293,4037546.146666442],[-13185880.996667018,4037704.8966666036],
            [-13185948.730000421,4037874.2300001099],[-13185974.130000448,4037946.1966668498],
            [-13186120.180000596,4037958.896666863],[-13186264.113334076,4037984.296666889],
            [-13186336.080000836,4038001.2300002342],[-13186314.91333415,4037757.8133333195],
            [-13186272.580000773,4037560.9633331187],[-13186187.913334005,4037463.59666635],
            [-13186431.33000092,4037404.3299996229],[-13186676.863334503,4037290.0299995062],
            [-13187625.130002158,4038589.6633341513],[-13187333.030001862,4038756.8800009824],
            [-13187091.730001617,4038617.1800008402],[-13186791.163334643,4038805.5633343654],
            [-13186721.313334571,4038801.3300010278],[-13186833.49666802,4038195.9633337436],
            [-13186977.677439401,4037699.8176972247],[-13186784.921301765,4037820.4541915278],
            [-13186749.517113185,4038150.8932846226],[-13186649.860878762,4038288.5762400767],
            [-13186556.760975549,4038323.9804286221],[-13186472.839936033,4038481.3323777127],
            [-13186373.183701571,4038489.1999751539],[-13186344.335844241,4038242.6819215398],
            [-13186126.665647998,4038308.245233661],[-13185814.584282301,4038358.0733508728],
            [-13185651.987268206,4038116.8003622484],[-13185203.534213299,4038048.6145176427],
            [-13184576.748949422,4038150.8932845518],[-13184251.55492135,4037833.5668537691],
            [-13184146.653621957,4037524.1080205571],[-13183949.963685593,4037621.1417224966],
            [-13183687.71043711,4037781.1162040718],[-13183480.530370807,4037875.5273735262],
            [-13182307.629999243,4037859.7460188437],[-13181376.039484169,4037820.9297473822],
            [-13180716.162869323,4038364.3575478429],[-13180182.439136729,4038810.7446696493],
            [-13178474.523192419,4040237.2426458625],[-13178321.134040033,4039740.6894803117],
            [-13177958.020228144,4039140.1550991111],[-13177073.512224896,4037459.5898928214],
            [-13177757.842101147,4037589.9384406791],[-13178386.308314031,4037799.427178307],
            [-13180095.012208173,4037811.6550856642],[-13180126.165447287,4036845.9046731163],
            [-13179806.844746364,4036324.0879179495],[-13180928.361354485,4035887.9425703473],
            [-13181598.155995468,4035428.432293402],[-13182984.47513606,4034447.105261297],
            [-13182229.264383668,4033222.8051626245],[-13182058.735615831,4033339.8690072047],
            [-13181939.035180708,4033691.2477038498],[-13182116.65518121,4033861.1450956347],
            [-13181792.305615077,4034085.1007484416],[-13182027.845180977,4034467.3698799671],
            [-13181877.254310986,4034644.9898804692],[-13181630.130832028,4034517.5668366305],
            [-13181386.868657427,4034424.8955320208],[-13181228.555178719,4034652.7124891868],
            [-13181379.14604871,4034942.3103160923],[-13181267.168222306,4035189.4337950516],
            [-13181074.103004368,4035015.6750989081],[-13180807.673003616,4034934.5877073747],
            [-13180618.469090037,4034814.8872722536],[-13180599.162568243,4035374.7764042714],
            [-13181047.073873857,4035494.476839392],[-13181317.365178969,4035413.3894478586],
            [-13180765.198655669,4035143.0981427468],[-13180328.871263131,4034892.1133594285],
            [-13180270.951697765,4035258.9372735149],[-13180325.009958787,4035718.4324922049],
            [-13180707.279090302,4035695.2646660525],[-13181413.897788007,4035536.9511873648],
            [-13181618.54691902,4035807.2424924765],[-13181884.976919774,4036065.949884512],
            [-13182159.129529245,4035861.3007534989],[-13182174.57474668,4035668.2355355616],
            [-13182417.83692128,4035664.374231203],[-13182784.660835361,4035409.5281435261],
            [-13182997.032575091,4035255.0759691764],[-13182618.624747934,4034679.7416197238]
            ]],"spatialReference":{"wkid":102100,"latestWkid":3857}}
            """
        }
    }
}

#Preview {
    NavigationView {
        ShowDeviceLocationHistoryView()
    }
}
