# Apply dictionary renderer to feature layer

Convert features into graphics to show them with mil2525d symbols.

![Image of apply dictionary renderer to feature layer](ApplyDictionayRendererToFeatureLayer.png)

## Use case

A dictionary renderer uses a style file along with a rule engine to display advanced symbology. 
This is useful for displaying features using precise military symbology.

## How to use the sample

Pan and zoom around the map. Observe the displayed military symbology on the map.

## How it works

1. Create a `Geodatabase` using `Geodatabase(geodatabasePath)`.
2. Load the geodatabase using `Geodatabase.load()`.
3. Instantiate a `DictionarySymbolStyle`  using `DictionarySymbolStyle(dictionarySymbolStylePath)`.
4. Load the dictionarySymbolStyle  using `DictionarySymbolStyle.load()`.
5. Cycle through each `GeodatabaseFeatureTable` from the geodatabase using `Geodatabase.featureTables`.
6. Create a `FeatureLayer` from each table within the geodatabase using `FeatureLayer(GeodatabaseFeatureTable)`.
7. Load the feature layer with `FeatureLayer.load()`.
8. After the last layer has loaded, create a new `Envelope` from a union of the extents of all layers.
9. Set the envelope to be the `Viewpoint` of the map view using `MapView.setViewpoint(new Viewpoint(Envelope))`.
10. Add the feature layer to map using `Map.operationalLayers.add(FeatureLayer)`.
11. Create a `DictionaryRenderer(SymbolDictionary)` and assign it to the feature layer renderer `featureLayer.renderer = dictionaryRenderer`.

## Relevant API

* DictionaryRenderer
* DictionarySymbolStyle

## Offline data

Read more about how to set up the sample's offline data [here](https://github.com/Esri/arcgis-runtime-samples-qt#use-offline-data-in-the-samples).

Link | Local Location
---------|-------|
|[Mil2525d Stylx File](https://www.arcgis.com/home/item.html?id=c78b149a1d52414682c86a5feeb13d30)| `<userhome>`/ArcGIS/Runtime/Data/styles/mil2525d.stylx |
|[Military Overlay geodatabase](https://www.arcgis.com/home/item.html?id=e0d41b4b409a49a5a7ba11939d8535dc)| `<userhome>`/ArcGIS/Runtime/Data/geodatabase/militaryoverlay.geodatabase |

## Tags

military, symbol
