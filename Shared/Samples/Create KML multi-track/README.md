# Create KML multi-track

Create, save, and preview a KML multi-track captured from a location data source.

![Create KML multi-track sample](create-kml-multi-track.png)

## Use case

When capturing location data for outdoor activities such as hiking or skiing, it can be useful to record and share your path. This sample demonstrates how you can collect individual KML tracks during a navigation session, then combine and export them as a KML multi-track.

## How to use the sample

Tap "Record Track" to start recording your current path on the simulated trail. Tap "Stop Recording" to end recording and capture a KML track. Repeat these steps to capture multiple KML tracks in a single session. Tap the save button to convert the recorded tracks into a KML multi-track and save it to a local `.kmz` file. Then, use the picker to select a track from the saved KML multi-track. Tap the Delete button to remove the local file and reset the sample.

## How it works

1. Create a `Map` with a basemap style and a `GraphicsOverlay` to display the path geometry for your navigation route.
2. Create a `SimulatedLocationDataSource` to drive the `LocationDisplay`.
3. As you receive `Location` updates, add each point to a list of `KMLTrackElement` objects while recording.
4. Once recording stops, create a `KMLTrack` using one or more `KMLTrackElement` objects.
5. Combine one or more `KMLTrack` objects into a `KMLMultiTrack`.
6. Save the `KMLMultiTrack` inside a `KMLDocument`, then export the document to a `.kmz` file.
7. Load the saved `.kmz` file into a `KMLDataset` and locate the `KMLDocument` in the dataset's `rootNodes`. From the document's `childNodes`, get the `KMLPlacemark` and retrieve the `KMLMultiTrack` geometry.
8. Retrieve the geometry of each track in the `KMLMultiTrack` by iterating through the list of tracks and obtaining the respective `KMLTrack.geometry`.

## Relevant API

* KMLDataset
* KMLDocument
* KMLMultiTrack
* KMLPlacemark
* KMLTrack
* KMLTrackElement
* LocationDisplay
* SimulatedLocationDataSource

## Tags

export, hiking, KML, KMZ, multi-track, record, track
