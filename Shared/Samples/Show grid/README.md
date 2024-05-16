# Show grid

Display coordinate system grids including latitude, longitude, MGRS, UTM and USNG on a map view. Also, toggle label visibility and change the color of grid lines and grid labels.

![Image of Show grid sample](show-grid.png)

## Use case

Grids are often used on printed maps, but can also be helpful on digital maps, to identify locations on a map.

## How to use the sample

Tap the button in the toolbar to open the grid settings view. You can select type of grid from grid types (LatLong, MGRS, UTM and USNG) and modify its properties like grid visibility, grid color, label visibility, label color, label position, label format and label unit.

## How it works

1. Create an instance of one of the `Grid` types.
2. Grid lines and labels can be styled per grid level with `grid.lineSymbols[0]` and `grid.textSymbols[0]` subscripts on the grid.
3. The label position, format, unit and visibility can be specified with `labelPosition`, `labelFormat`, `labelUnit` and `isVisible` on the `Grid`.
4. For the `LatitudeLongitudeGrid` type, you can specify a label format of `decimalDegrees` or `degreesMinutesSeconds`.
5. To set the grid, assign it to the map view using the `grid(_:)` modifier.

## Relevant API

* Grid
* LatitudeLongitudeGrid
* MapView
* MGRSGrid
* SimpleLineSymbol
* TextSymbol
* USNGGrid
* UTMGrid

## Tags

coordinates, degrees, graticule, grid, latitude, longitude, MGRS, minutes, seconds, USNG, UTM
