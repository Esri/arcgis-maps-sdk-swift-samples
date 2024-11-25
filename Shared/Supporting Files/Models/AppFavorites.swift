// Copyright 2023 Esri
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

import SwiftUI

/// A property wrapper for accessing and setting the names of the favorite samples.
@propertyWrapper
struct AppFavorites: DynamicProperty {
    /// The favorite sample names JSON string loaded from user defaults.
    @AppStorage("favoriteSampleNames") private var favoriteNamesJSON = ""
    
    var wrappedValue: [String] {
        get { .init(jsonString: favoriteNamesJSON) }
        nonmutating set { favoriteNamesJSON = newValue.jsonString }
    }
}

/// An extension allowing an array to be used with the app storage property wrapper.
private extension Array<String> {
    /// Creates a new array from a given raw value.
    /// - Parameter jsonString: The JSON representation of the array to create.
    init(jsonString: String) {
        if let data = jsonString.data(using: .utf8),
           let result = try? JSONDecoder().decode([Element].self, from: data) {
            self = result
        } else {
            self = []
        }
    }
    
    /// The JSON representation of the array.
    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self) else { return "[]" }
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: data, as: UTF8.self)
    }
}
