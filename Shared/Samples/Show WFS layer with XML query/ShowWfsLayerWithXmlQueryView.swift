import ArcGIS
import SwiftUI

struct ShowWfsLayerWithXmlQueryView: View {
    @State private var model = Model()
    
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map)
                .overlay(alignment: .center) {
                    if model.isLoading {
                        ProgressView(
                            """
                            Loading query
                            data...
                            """
                        )
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(radius: 50)
                        .multilineTextAlignment(.center)
                    }
                }
                .task {
                    do {
                        try await model.loadData()
                        if let extent = model.statesTable.extent, !model.hasSetInitialViewpoint {
                            model.hasSetInitialViewpoint = true
                            await mapView.setViewpoint(Viewpoint(boundingGeometry: extent), duration: 2.0)
                        }
                        model.isLoading = false
                    } catch {
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
        }
    }
}

private extension ShowWfsLayerWithXmlQueryView {
    @MainActor
    @Observable
    class Model {
        var map = Map(basemapStyle: .arcGISTopographic)
        
        var hasSetInitialViewpoint = false
        
        var statesTable = WFSFeatureTable(
            url: URL(string: "https://dservices2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/services/Seattle_Downtown_Features/WFSServer?service=wfs&request=getcapabilities")!,
            tableName: "Seattle_Downtown_Features:Trees"
        )
        
        var isLoading = false
        
        func loadData() async throws {
            isLoading = true
            statesTable.axisOrder = .noSwap
            statesTable.featureRequestMode = .manualCache
            
            try await statesTable.load()
            let layer = FeatureLayer(featureTable: statesTable)
            map.addOperationalLayer(layer)
            let xmlQuery = """
                <wfs:GetFeature service="WFS" version="2.0.0" outputFormat="application/gml+xml; version=3.2"
                  xmlns:Seattle_Downtown_Features="https://dservices2.arcgis.com/ZQgQTuoyBrtmoGdP/arcgis/services/Seattle_Downtown_Features/WFSServer"
                  xmlns:wfs="http://www.opengis.net/wfs/2.0"
                  xmlns:fes="http://www.opengis.net/fes/2.0"
                  xmlns:gml="http://www.opengis.net/gml/3.2">
                  <wfs:Query typeNames="Seattle_Downtown_Features:Trees">
                    <fes:Filter>
                      <fes:PropertyIsEqualTo>
                        <fes:ValueReference>Seattle_Downtown_Features:SCIENTIFIC</fes:ValueReference>
                        <fes:Literal>Tilia cordata</fes:Literal>
                      </fes:PropertyIsEqualTo>
                    </fes:Filter>
                  </wfs:Query>
                </wfs:GetFeature>
                """
            _ = try await statesTable.populateFromService(usingXMLRequest: xmlQuery, clearCache: true)
        }
    }
}

#Preview {
    ShowWfsLayerWithXmlQueryView()
}
