# Style graphics with symbols

Use a symbol style to display a graphic on a graphics overlay.

![Screenshot of style graphics with symbols sample](style-graphics-with-symbols.png)

## Use case

Allows you to customize a graphic by assigning a unique symbol. For example, you may wish to display individual graphics for different landmarks across a region, and to style each one with a unique symbol.  

## How to use the sample

Pan and zoom around the map. Observe the graphics on the map.

## How it works

1. Create a `GraphicsOverlay` object.
2. Create a `Symbol` such as `SymbolFillSymbol`, `SymbolLineSymbol`, `SimpleMarkerSymbol`, or `TextSymbol`.
3. Create a `Graphic`, specifying a `Geometry`, attributes, and a `Symbol`.
4. Add the `Graphic` to the `GraphicsOverlay`.
5. Create a `MapView` view with the `GraphicsOverlay` object.

## Relevant API

* Geometry
* Graphic
* GraphicsOverlay
* SimpleFillSymbol
* SimpleLineSymbol
* SimpleMarkerSymbol
* TextSymbol

## Additional information

To set a symbol style across a number of graphics (e.g. showing trees as graphics sharing a symbol in a park), see the "Add graphics with renderer" sample.

## Tags

display, fill, graphics, line, marker, overlay, point, symbol