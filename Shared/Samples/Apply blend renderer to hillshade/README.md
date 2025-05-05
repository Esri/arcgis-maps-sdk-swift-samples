# Apply blend renderer to hillshade

Blend a hillshade with a raster by specifying the elevation data. The resulting raster looks similar to the original raster, but with some terrain shading, giving it a textured look.

![Image of apply blend renderer to hillshade](apply-blend-renderer-to-hillshade.png)

## Use case

`BlendRenderer` can be used to apply a color ramp to a hillshade to emphasize areas of high or low elevation. A `BlendRenderer` can also be used to add a hillshade effect to aerial or satellite imagery, thereby making changes in elevation more visible.


## How to use the sample

Choose and adjust the altitude, azimuth, slope type and color ramp type settings to update the image.

## How it works

1. Create a `Raster` object from a raster file.
2. Create a `RasterLayer` object from the raster.
3. Create a `Basemap` object from the raster layer and set it to the map.
4. Create another `Raster` object for elevation from a grayscale raster file.
5. Create a BlendRenderer object, specifying the elevation raster, color ramp, and other properties.
 - If you specify a non-null color ramp, use the elevation raster as the base raster in addition to the elevation raster parameter. That way, the color ramp is used instead of the satellite imagery.
6. Set the blend renderer to the raster layer.

## Relevant API

* BlendRenderer
* ColorRamp
* Raster
* RasterLayer

## About the data

This sample shows a [Shasta Raster](https://www.arcgis.com/home/item.html?id=7c4c679ab06a4df19dc497f577f111bd) and a [Shasta Elevation Raster](https://arcgisruntime.maps.arcgis.com/home/item.html?id=caeef9aa78534760b07158bb8e068462) hosted on ArcGIS Online.

## Tags

color ramp, elevation, hillshade, image, raster, raster layer, visualization
