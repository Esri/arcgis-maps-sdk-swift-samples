// Copyright 2022 Esri
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

extension View {
    /// Adds an action to perform when this view detects data emitted by the
    /// given async sequence. If `action` is `nil`, then the async sequence is not observed.
    /// The `action` closure is captured the first time the view appears.
    /// - Parameters:
    ///   - sequence: The async sequence to observe.
    ///   - action: The action to perform when a value is emitted by `sequence`.
    ///   The value emitted by `sequence` is passed as a parameter to `action`.
    ///   The `action` is called on the `MainActor`.
    /// - Returns: A view that triggers `action` when `sequence` emits a value.
    @MainActor @ViewBuilder func onReceive<S>(
        _ sequence: S,
        perform action: ((S.Element) -> Void)?
    ) -> some View where S: AsyncSequence {
        if let action = action {
            task {
                do {
                    for try await element in sequence {
                        action(element)
                    }
                } catch {}
            }
        } else {
            self
        }
    }
}
