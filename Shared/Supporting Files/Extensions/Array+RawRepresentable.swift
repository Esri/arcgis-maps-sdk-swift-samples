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

import Foundation

/// An extension allowing an array to be used with the app storage property wrapper.
extension Array: RawRepresentable where Element == String {
    /// Creates a new array from a given raw value.
    /// - Parameter rawValue: The raw value of the array to create.
    public init(rawValue: String) {
        if let data = rawValue.data(using: .utf8),
           let result = try? JSONDecoder().decode([Element].self, from: data) {
            self = result
        } else {
            self = []
        }
    }
    
    /// The raw value of the array.
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}
