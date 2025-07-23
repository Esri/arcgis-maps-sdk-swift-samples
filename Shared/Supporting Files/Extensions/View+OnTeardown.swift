// Copyright 2025 Esri
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
    /// Adds an asynchronous teardown action to perform when this view disappears.
    ///
    /// Other ``Sample/hasTeardown`` samples will be blocked from appearing
    /// until the action has completed. This prevents race conditions between
    /// samples that access shared state, such as `ArcGISEnvironment`.
    /// - Parameter action: The action to perform.
    /// - Important: Failure to call this in a ``Sample/hasTeardown`` sample
    /// will block other teardown samples from appearing.
    func onTeardown(perform action: @escaping () async -> Void) -> some View {
        modifier(OnTeardown(action: action))
    }
}

/// A view modifier that runs an asynchronous teardown action when the view disappears.
private struct OnTeardown: ViewModifier {
    /// The teardown action to perform.
    let action: () async -> Void
    
    /// The action to run when the teardown action has completed.
    @Environment(\.onTearDownCompleted) private var onTearDownCompleted
    
    func body(content: Content) -> some View {
        content
            .onDisappear {
                Task {
                    await action()
                    onTearDownCompleted()
                }
            }
    }
}

extension EnvironmentValues {
    /// The action to run when a view is done tearing down.
    @Entry var onTearDownCompleted: () -> Void = {}
}
