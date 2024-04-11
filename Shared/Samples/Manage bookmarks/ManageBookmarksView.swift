// Copyright 2024 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS
import SwiftUI

struct ManageBookmarksView: View {
    /// A map with an imagery basemap and a list of bookmarks.
    @State private var map: Map = {
        // Create a map with a basemap.
        let map = Map(basemapStyle: .arcGISImagery)
        
        // Add a list of bookmarks to the map.
        let defaultBookmarks = [
            Bookmark(
                name: "Grand Prismatic Spring",
                viewpoint: Viewpoint(latitude: 44.525, longitude: -110.838, scale: 6e3)
            ),
            Bookmark(
                name: "Guitar-Shaped Forest",
                viewpoint: Viewpoint(latitude: -33.867, longitude: -63.985, scale: 4e4)
            ),
            Bookmark(
                name: "Mysterious Desert Pattern",
                viewpoint: Viewpoint(latitude: 27.380, longitude: 33.632, scale: 6e3)
            ),
            Bookmark(
                name: "Strange Symbol",
                viewpoint: Viewpoint(latitude: 37.401, longitude: -116.867, scale: 6e3)
            )
        ]
        map.addBookmarks(defaultBookmarks)
        
        return map
    }()
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value indicating whether the bookmarks sheet is presented.
    @State private var bookmarksSheetIsPresented = false
    
    /// A Boolean value indicating whether the new bookmark alert is showing.
    @State private var newBookmarkAlertIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map, viewpoint: viewpoint)
                .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Add Bookmark", systemImage: "plus") {
                            newBookmarkAlertIsPresented = true
                        }
                        
                        Spacer()
                        
                        Button("Bookmarks", systemImage: "book") {
                            bookmarksSheetIsPresented = true
                        }
                        .halfSheet(isPresented: $bookmarksSheetIsPresented) {
                            BookmarksList(map: map) { bookmark in
                                do {
                                    try await mapViewProxy.setBookmark(bookmark)
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                    }
                }
                .task {
                    // Zoom to the map's first bookmark when the view appears.
                    do {
                        guard let initialBookmark = map.bookmarks.first else { return }
                        try await mapViewProxy.setBookmark(initialBookmark)
                    } catch {
                        self.error = error
                    }
                }
        }
        .newBookmarkAlert(isPresented: $newBookmarkAlertIsPresented) { name in
            // Create a new bookmark and add it to the map.
            guard !name.isEmpty else { return }
            let newBookmark = Bookmark(name: name, viewpoint: viewpoint)
            map.addBookmark(newBookmark)
        }
        .errorAlert(presentingError: $error)
    }
}

private extension ManageBookmarksView {
    /// A list of the bookmarks for a given map.
    struct BookmarksList: View {
        /// The map to get the bookmarks from.
        let map: Map
        
        /// The action to perform when a list row is tapped.
        let action: (Bookmark) async -> Void
        
        /// The action to dismiss the view.
        @Environment(\.dismiss) private var dismiss: DismissAction
        
        /// The list of the map's bookmarks.
        @State private var bookmarks: [Bookmark] = []
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(bookmarks, id: \.self) { bookmark in
                        Button {
                            dismiss()
                            Task {
                                await action(bookmark)
                            }
                        } label: {
                            HStack {
                                Text(bookmark.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        // Reorder the bookmarks on row move.
                        bookmarks.move(fromOffsets: fromOffsets, toOffset: toOffset)
                        map.removeAllBookmarks()
                        map.addBookmarks(bookmarks)
                    }
                    .onDelete { offsets in
                        // Delete the bookmarks at the given offsets on row deletion.
                        let bookmarksToRemove = offsets.map { bookmarks[$0] }
                        map.removeBookmarks(bookmarksToRemove)
                        bookmarks.remove(atOffsets: offsets)
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle("Bookmarks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Note: There is a bug in iOS 17 that prevents the `EditButton` from working
                        // on the first tap when it is embedded in a `NavigationView` in a `popover`.
                        EditButton()
                    }
                }
            }
            .navigationViewStyle(.stack)
            .onAppear {
                bookmarks = map.bookmarks
            }
        }
    }
    
    /// An alert that allows the user to enter a name for a new bookmark.
    struct NewBookmarkAlert: ViewModifier {
        /// A binding to a Boolean value that determines whether to present the alert.
        @Binding var isPresented: Bool
        
        /// The action to perform when the save button is pressed.
        let onSave: (String) -> Void
        
        /// The name for the new bookmark in the text field.
        @State private var newBookmarkName = ""
        
        func body(content: Content) -> some View {
            content
                .alert(
                    "Add bookmark",
                    isPresented: $isPresented,
                    actions: {
                        TextField("Name", text: $newBookmarkName)
                        
                        Button("Cancel", role: .cancel) {
                            newBookmarkName.removeAll()
                        }
                        
                        Button("Save") {
                            onSave(newBookmarkName)
                            newBookmarkName.removeAll()
                        }
                    }
                )
        }
    }
}

private extension View {
    /// Presents an alert to add a new bookmark.
    /// - Parameters:
    ///   - isPresented: A binding to a Boolean value that determines whether to present the alert.
    ///   - onSave: The action to perform when the save button is pressed.
    /// - Returns: A new `View`.
    func newBookmarkAlert(
        isPresented: Binding<Bool>,
        onSave: @escaping (String) -> Void
    ) -> some View {
        modifier(ManageBookmarksView.NewBookmarkAlert(isPresented: isPresented, onSave: onSave))
    }
    
    /// Presents a half sheet when a given binding to a Boolean value is true.
    /// - Parameters:
    ///   - isPresented: A binding to a Boolean value that determines whether to present the sheet.
    ///   - content: A closure that returns the content of the sheet.
    /// - Returns: A new `View`.
    func halfSheet<Content>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View where Content: View {
        Group {
            if #available(iOS 16, *) {
                self
                    .popover(isPresented: isPresented, arrowEdge: .bottom) {
                        content()
                            .presentationDetents([.medium, .large])
#if targetEnvironment(macCatalyst)
                            .frame(minWidth: 300, minHeight: 270)
#else
                            .frame(minWidth: 320, minHeight: 390)
#endif
                    }
            } else {
                self
                    .sheet(isPresented: isPresented, detents: [.medium, .large]) {
                        content()
                    }
            }
        }
    }
}

#Preview {
    NavigationView {
        ManageBookmarksView()
    }
}
