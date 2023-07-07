# Set visibility of subtype sublayer

Display a composite layer of all the subtype values in a feature class.

![Image of Set visibility of subtype sublayer sample](set-visibility-of-subtype-sublayer.png)

## Use case

This is useful for controlling labeling, visibility, and symbology of a given subtype as though they are distinct layers on the map.

## How to use the sample

The sample loads with the sublayer visible on the map. Toggle its visibility by tapping the first switch. Toggle between the sublayer's original renderer and an alternate renderer using the second switch. Tap the
 "Set Current to Minimum Scale" button to set the sublayer's minimum scale to the current map scale.

## How it works

1. Create a `SubtypeFeatureLayer` from a `ServiceFeatureTable` that defines a subtype, and add it to the `Map`.
2. Get a `SubtypeSublayer` from the subtype feature layer using its name.
3. Enable the sublayer's labels and define them with `LabelDefinition`.
    * Use `SimpleLabelExpression` to set the expression for label definitions.
4. Make a switch to toggle the sublayer's visibility.
5. Create an alternate renderer by making a `SimpleRenderer`.
6. Get the current map scale and make it the minimum map scale.

## Relevant API

* LabelDefinition
* ServiceFeatureTable
* SimpleLabelExpression
* SubtypeFeatureLayer
* SubtypeSublayer

## About the data

The [feature service layer](https://sampleserver7.arcgisonline.com/server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer/0) in this sample represents an electric network in Naperville, Illinois, which contains a utility network with asset classification for different devices.

## Additional information

Help regarding the Arcade label expression script for defining a label definition can be found on the [ArcGIS Developers](https://developers.arcgis.com/arcade/) site.

## Tags

asset group, feature layer, labeling, sublayer, subtype, symbology, utility network, visible scale range
