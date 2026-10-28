# Update labels and symbols to scale for visual accessibility

Scale feature labels and symbols according to the system text-size setting.

![Screenshot of update labels and symbols to scale for visual accessibility sample](update-labels-and-symbols-to-scale-for-visual-accessibility.png)

## Use case

Use this pattern to improve map readability for users who increase text size in their operating system's accessibility settings. Feature labels scale automatically; use `View.dynamicTypeSize(_:)` to control this behavior. To scale feature symbols, observe system text-size changes and apply the scaling factor to the symbol sizes.

## How to use the sample

Tap **Scaling Controls** in the bottom bar to open the scrollable panel. It shows instructions, a legend for label and symbol scaling, and the current text scale and calculated symbol size. Turn **Scale Labels Automatically** off to use the default label size, or on to follow the system text size. Symbols and callout text continue to follow the system text size independently. Tap **Done** to return to the map.

To change text size, open **Settings** > **Accessibility** > **Display & Text Size** > **Larger Text**, adjust the slider, and return to the sample. Enable **Larger Accessibility Sizes** for more options. The panel and the navigation-bar **Text Size Help** also provide these instructions. Their **Try Opening Settings** button attempts to open Accessibility; the destination may vary, and you may need to navigate manually. If that attempt reports failure, the button tries the app settings instead. If both attempts report failure, follow the manual instructions.

Select a restaurant to show its name and WGS 84 coordinates to five decimal places in a callout. Select elsewhere to clear the callout. If loading fails, return to the sample to retry.

## How it works

1. Create a `Map` and a `FeatureLayer`.
2. Load the feature layer and the `restaurant` symbol from `Esri2DPointSymbolsStyle`.
3. Configure a `LabelDefinition` with a `TextSymbol` and add it to the loaded feature layer. Apply the symbol with a `SimpleRenderer` and add the layer to the map.
4. To scale labels, let the `MapView` use the system Dynamic Type size. To disable label scaling, use `View.dynamicTypeSize(_:)` with `.large`.
5. To scale symbols, read the system text-scale factor with `@ScaledMetric` and observe changes with `onChange(of:initial:_:)`. Scale `MultilayerPointSymbol.size` by the system text-scale factor.
6. Use the toggle to control system text scaling for labels without changing symbol scaling.
7. Identify a restaurant with `MapViewProxy.identify(on:screenPoint:tolerance:returnPopupsOnly:maximumResults:)` and show its name and WGS 84 coordinates in a callout.

## Relevant API

* View.dynamicTypeSize(_:)

## About the data

This sample uses a [Redlands restaurants](https://www.arcgis.com/home/item.html?id=46119989eccd46a58b8f3d7aedadeb90) feature layer covering food establishments in Redlands, California. Each feature represents a single restaurant.

The restaurant symbol comes from [Esri's 2D point symbol web style](https://www.arcgis.com/home/item.html?id=220936cc6ed342c9937abd8f180e7d1e). Internet access is required for the layer and symbol; the basemap uses the host app's configured API key.

## Additional information

On iOS, use `View.dynamicTypeSize(_:)` to control system text scaling for feature labels. Use `@ScaledMetric` and `onChange(of:initial:_:)` to scale symbols and respond to system text-size changes. Labels use their preferred position without deconfliction, so they may overlap, especially at larger text sizes. Coordinates use a fixed decimal separator regardless of the device locale.

The `App-prefs:ACCESSIBILITY` URL scheme is undocumented and may break or cause App Store rejection. A successful open request does not guarantee that Accessibility or Larger Text is displayed. The fallback uses the public `UIApplication.openSettingsURLString`, which opens the app settings rather than the Accessibility menu.

## Tags

accessibility, label, readability, scale, symbol, text, visual impairment
