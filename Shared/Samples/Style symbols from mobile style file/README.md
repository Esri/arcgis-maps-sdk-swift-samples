# Style symbols from mobile style file

Combine multiple symbols from a mobile style file into a single symbol.

![Image of style symbols from mobile style file 1](style-symbols-from-mobile-style-file-1.png)
![Image of style symbols from mobile style file 2](style-symbols-from-mobile-style-file-2.png)

## Use case

You may choose to display individual elements of a dataset like a water infrastructure network (such as valves, nodes, or endpoints) with the same basic shape, but wish to modify characteristics of elements according to some technical specifications. Multilayer symbols lets you add or remove components or modify the colors to create advanced symbol styles.

## How to use the sample

Tap "Symbol" and select a symbol from each section to create a face emoji. A preview of the symbol is updated as selections are made. The color of the symbol can be set using the color picker and size can be set using the slider. Tap the map to create a point graphic using the customized emoji symbol, and tap "Clear" to clear all graphics from the display.

## How it works

1. Create a new symbol style from a stylx file using `SymbolStyle(url:)`.
2. Get a set of default search parameters using `SymbolStyle.defaultSearchParameters` and use those to retrieve a list of all symbols within the style file using `SymbolStyle.searchSymbols(using:)`.
3. Get the `SymbolStyleSearchResult`s, which contains the symbols, as well as their names, keys, and categories.
4. Use a `Array` of keys of the desired symbols to build a composite symbol using `SymbolStyle.symbol(forKeys:)`.
5. Create a `Graphic` using the `Symbol`.

## Relevant API

* MultilayerPointSymbol
* MultilayerSymbol
* SymbolLayer
* SymbolStyle
* SymbolStyleSearchParameters

## Offline data

A mobile style file (created using ArcGIS Pro) provides the symbols used by the sample.

## About the data

The mobile style file used in this sample was created using ArcGIS Pro, and is hosted on [ArcGIS Online](https://www.arcgis.com/home/item.html?id=1bd036f221f54a99abc9e46ff3511cbf). It contains symbol layers that can be combined to create emojis.

## Additional information

While each of these symbols can be created from scratch, a more convenient workflow is to author them using ArcGIS Pro and store them in a mobile style file (.stylx). ArcGIS Runtime can read symbols from a mobile style, and you can modify and combine them as needed in your app.

## Tags

advanced symbology, mobile style, multilayer, stylx
