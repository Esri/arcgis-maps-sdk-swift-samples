// Copyright 2024 Esri
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

struct ApplyDictionaryRendererToGraphicsOverlayView: View {
    /// A scene with a topographic basemap.
    @State private var scene = Scene(basemapStyle: .arcGISTopographic)
    
    /// The graphics overlay for displaying the message graphics on the scene.
    @State private var graphicsOverlay = GraphicsOverlay()
    
    /// The camera for zooming the scene view to the message graphics.
    @State private var camera: Camera?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        SceneView(scene: scene, camera: $camera, graphicsOverlays: [graphicsOverlay])
            .task {
                do {
                    // Sets up the graphics overlay when the sample opens.
                    graphicsOverlay.renderer = try await makeMIL2525DRenderer()
                    try graphicsOverlay.addGraphics(makeMessageGraphics())
                    
                    // Sets the camera to look at the graphics in the graphics overlay.
                    guard let extent = graphicsOverlay.extent else { return }
                    camera = Camera(
                        lookingAt: extent.center,
                        distance: 15_000,
                        heading: 0,
                        pitch: 70,
                        roll: 0
                    )
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
    
    /// Creates a dictionary renderer for styling with MIL-STD-2525D symbols.
    /// - Returns: A new `DictionaryRenderer` object.
    private func makeMIL2525DRenderer() async throws -> DictionaryRenderer {
        // Creates a dictionary symbol style from a dictionary style portal item.
        let portalItem = PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: .jointMilitarySymbologyDictionaryStyle
        )
        let dictionarySymbolStyle = DictionarySymbolStyle(portalItem: portalItem)
        try await dictionarySymbolStyle.load()
        
        // Uses the "Ordered Anchor Points" for the symbol style draw rule.
        let drawRuleConfiguration = dictionarySymbolStyle.configurations.first { $0.name == "model" }
        drawRuleConfiguration?.value = "ORDERED ANCHOR POINTS"
        
        return DictionaryRenderer(dictionarySymbolStyle: dictionarySymbolStyle)
    }
    
    /// Creates graphics from messages in an XML file.
    /// - Returns: An array of new `Graphic` objects.
    private func makeMessageGraphics() throws -> [Graphic] {
        // Gets the data from the local XML file.
        let messagesData = try Data(contentsOf: .mil2525dMessagesXMLFile)
        let parser = MessageParser(data: messagesData)
        
        if parser.parse() {
            // Creates graphics from the parsed messages.
            return parser.messages.compactMap { message in
                guard let messageWKID = message.wkid,
                      let wkid = WKID(messageWKID) else { return nil }
                let spatialReference = SpatialReference(wkid: wkid)
                let points = message.controlPoints.map { x, y in
                    Point(x: x, y: y, spatialReference: spatialReference)
                }
                return Graphic(geometry: Multipoint(points: points), attributes: message.other)
            }
        } else if let error = parser.parserError {
            throw error
        } else {
            return []
        }
    }
}

// MARK: Message Parser

private extension ApplyDictionaryRendererToGraphicsOverlayView {
    /// A parser for the XML file containing the MIL-STD-2525D messages.
    final class MessageParser: XMLParser, XMLParserDelegate {
        /// The parsed messages.
        private(set) var messages: [Message] = []
        
        /// The values of the message element currently being parsed.
        private var currentMessage: Message?
        
        /// The characters of the XML element currently being parsed.
        private var currentElementContents = ""
        
        override init(data: Data) {
            super.init(data: data)
            self.delegate = self
        }
        
        /// Creates a new `currentMessage` when a message start tag is encountered.
        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            if elementName == "message" {
                currentMessage = Message()
            }
            currentElementContents.removeAll()
        }
        
        /// Adds the characters of the current element to `currentElementContents`.
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentElementContents.append(contentsOf: string)
        }
        
        /// Adds the contents of the current element to the `currentMessage` when an end tag is encountered.
        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            switch elementName {
            case "_control_points":
                currentMessage?.controlPoints = currentElementContents.split(separator: ";")
                    .map { pair in
                        let coordinates = pair.split(separator: ",")
                        return (x: Double(coordinates.first!)!, y: Double(coordinates.last!)!)
                    }
            case "message":
                messages.append(currentMessage!)
                currentMessage = nil
            case "messages":
                break
            case "_wkid":
                currentMessage?.wkid = Int(currentElementContents)
            default:
                currentMessage?.other[elementName] = currentElementContents
            }
            
            currentElementContents.removeAll()
        }
    }
    
    /// The parsed values from an XML message element.
    struct Message {
        /// The x and y values of the control points element.
        var controlPoints: [(x: Double, y: Double)] = []
        /// The value of the wkid element.
        var wkid: Int?
        /// The other elements and their values.
        var other: [String: any Sendable] = [:]
    }
}

// MARK: Helper Extensions

private extension PortalItem.ID {
    /// The ID for the "Joint Military Symbology MIL-STD-2525D" dictionary style portal item on ArcGIS Online.
    static var jointMilitarySymbologyDictionaryStyle: Self {
        .init("d815f3bdf6e6452bb8fd153b654c94ca")!
    }
}

private extension URL {
    /// The URL to the local XML file containing messages with MIL-STD-2525D fields.
    static var mil2525dMessagesXMLFile: URL {
        Bundle.main.url(forResource: "Mil2525DMessages", withExtension: "xml")!
    }
}
