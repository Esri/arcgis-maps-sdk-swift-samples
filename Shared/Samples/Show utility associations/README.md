# Show utility associations

Create graphics for utility associations in a utility network.

![Show utility associations sample](show-utility-associations.png)

## Use case

Visualizing utility associations can help you to better understand trace results and the topology of your utility network. For example, connectivity associations allow you to model connectivity between two junctions that don't have geometric coincidence (are not in the same location); structural attachment associations allow you to model equipment that may be attached to structures; and containment associations allow you to model features contained within other features.

## How to use the sample

Pan and zoom around the map. Observe graphics that show utility associations between junctions.

## How it works

1. Create and load a `Map` with a web map item URL that contains a `UtilityNetwork`.
2. Get and load the first `UtilityNetwork` from the web map.
3. Create a `GraphicsOverlay` for the utility associations.
4. When the sample is opened and every time the viewpoint changes, do the following steps.
5. Get the extent of the map view's target geometry by using `MapView.onViewpointChanged(kind:)`.
6. Get the associations that are within the current extent using `UtilityNetwork.associations(forExtent:)`.
7. Get the `UtilityAssociation.Kind` for each association.
8. Create a `Graphic` using the `Geometry` property of the association and a preferred symbol.
9. Add the graphic to the graphics overlay.

## Relevant API

* GraphicsOverlay
* ServiceGeodatabase
* UtilityAssociation
* UtilityAssociation.Kind
* UtilityNetwork

## About the data

The [Naperville Electric Map](https://sampleserver7.arcgisonline.com/portal/home/item.html?id=be0e4637620a453584118107931f718b) web map contains a utility network used to run the subnetwork-based trace in this sample. Authentication is required and handled within the sample code.

## Tags

associating, association, attachment, connectivity, containment, relationships
