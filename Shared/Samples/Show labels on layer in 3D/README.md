# Show labels on layer in 3D

Display custom labels in a 3D scene.

![Image of Show labels on layer in 3D sample](show-labels-on-layer-in-3D.png)

## Use case

Labeling features is useful to visually display information or attributes on a scene. For example, city officials or maintenance crews may want to show installation dates of features of a gas network.

## How to use the sample

Pan and zoom to explore the scene. Notice the labels showing installation dates of features in the 3D gas network.

## How it works

1. Create a scene from a `PortalItem`.
2. Add the scene to a `SceneView` and load it.
3. After loading is complete, obtain the `FeatureLayer` from one of the `GroupLayer`s in the scene's operational layers.
4. Create a `TextSymbol` to use for displaying the label text.
5. Create a `LabelDefinition` using an `ArcadeLabelExpression`.
6. Add the definition to the feature layer with `featureLayer.addLabelDefinition(labelDefinition)`.
7. Lastly, enable labels on the layer using `featureLayer.labelsAreEnabled`.

## Relevant API

* ArcadeLabelExpression
* FeatureLayer
* LabelDefinition
* Scene
* SceneView
* TextSymbol

## About the data

This sample shows a [New York City infrastructure](https://www.arcgis.com/home/item.html?id=850dfee7d30f4d9da0ebca34a533c169) scene hosted on ArcGIS Online.

## Tags

3D, arcade, attribute, buildings, label, model, scene, symbol, text, URL, visualization
