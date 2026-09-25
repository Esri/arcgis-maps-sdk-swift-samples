# Update labels and symbols to scale for visual accessibility

Scale feature labels and symbols according to the system text-size setting.

## Use case

Improve map readability for users who increase text size in accessibility settings. Use SwiftUI Dynamic Type to scale restaurant labels and symbols, with independent control over label scaling.

## How to use the sample

The tip on the map provides instructions and an **Open Accessibility Settings** action. On iOS, navigate to **Accessibility** > **Display & Text Size** > **Larger Text**. Enable **Larger Accessibility Sizes** for additional sizes, then return to the sample. On Mac Catalyst, navigate to **Accessibility** > **Display** > **Text size**; support depends on the system and app settings. The legend and current values remain visible at the bottom of the map.

Turn off **Scale Labels** in the bottom toolbar to restore labels to their base size. Symbols continue to follow Dynamic Type. Select a restaurant to show its name and WGS 84 coordinates. Select elsewhere to clear the selection and callout.

## How it works

1. Create a `Map` and add a `FeatureLayer` for the restaurants.
2. Apply a `SimpleMarkerSymbol` using a `SimpleRenderer`.
3. Add a `LabelDefinition` with an `ArcadeLabelExpression` for the name and a `TextSymbol`, enable labels, and load the layer.
4. Use `@ScaledMetric(relativeTo: .body)` to obtain a Dynamic Type scale factor. Observe changes with `onChange(of:initial:_:)`, including the initial value.
5. Multiply the marker's base size and outline width by the scale factor. Scale the label's text symbol only when the label-scaling toggle is enabled. Store these settings in an `@Observable` model.
6. Identify a restaurant with `MapViewProxy.identify(on:screenPoint:tolerance:returnPopupsOnly:maximumResults:)`, and select the feature.
7. Project its location to WGS 84 with `GeometryEngine.project(_:into:)` and show its name and coordinates in a callout. Use semantic fonts so callout text responds to Dynamic Type independently of the label toggle.

## Relevant API

- ArcadeLabelExpression
- FeatureLayer
- GeometryEngine
- LabelDefinition
- MapViewProxy
- SimpleMarkerSymbol
- SimpleRenderer
- TextSymbol

## About the data

This sample uses a [Redlands restaurants](https://www.arcgis.com/home/item.html?id=46119989eccd46a58b8f3d7aedadeb90) feature layer covering food establishments in Redlands, California. Each feature represents a single restaurant.

## Additional information

ArcGIS Maps SDK for Swift 300.1 does not expose WPF's `GeoView.UseSystemTextScale` API. This sample explicitly scales restaurant label text symbols instead; the toggle does not change basemap labels.

Dynamic Type scaling depends on the text style. The displayed percentage is relative to the default Body text size, not a universal operating-system percentage. Label and marker base sizes are 12 points, and the marker outline's base width is 1.5 points. Sizes are always recalculated from these base values to avoid cumulative scaling.

iOS does not provide a public URL for opening Larger Text settings directly. The tip uses the same best-effort Accessibility settings link as the keyboard-navigation sample. This undocumented link may not reach the intended page on every iOS version; use the manual navigation instructions if needed. An alert provides those instructions if opening the URL fails. SwiftUI observes text-size changes without a manual notification subscription.

## Tags

accessibility, Dynamic Type, label, readability, scale, symbol, text, visual impairment
