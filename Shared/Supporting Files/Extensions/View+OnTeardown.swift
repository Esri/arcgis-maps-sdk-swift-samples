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
    /// Adds a teardown action to perform when this view disappears.
    ///
    /// Other ``Sample/hasTeardown`` samples will be blocked from appearing
    /// until the action has completed. This prevents race conditions between
    /// samples that access shared state, such as `ArcGISEnvironment`.
    ///
    /// - Important: Failure to call this in a ``Sample/hasTeardown`` sample
    /// will block other teardown samples from appearing.
    ///
    /// - Parameter action: The action to perform.
    func onTeardown(perform action: @escaping () -> Void) -> some View {
        modifier(OnTeardown(action: .action(action)))
    }
    
    /// Adds an asynchronous teardown action to perform when this view disappears.
    ///
    /// Other ``Sample/hasTeardown`` samples will be blocked from appearing
    /// until the action has completed. This prevents race conditions between
    /// samples that access shared state, such as `ArcGISEnvironment`.
    ///
    /// - Important: Failure to call this in a ``Sample/hasTeardown`` sample
    /// will block other teardown samples from appearing.
    ///
    /// - Parameter action: The asynchronous action to perform.
    func onTeardown(perform action: @escaping () async -> Void) -> some View {
        modifier(OnTeardown(action: .actionAsync(action)))
    }
}

/// A type of action to perform.
private enum Action {
    case action(() -> Void)
    case actionAsync(() async -> Void)
}

/// A view modifier that runs a teardown action when the view disappears.
private struct OnTeardown: ViewModifier {
    /// The teardown action to perform.
    let action: Action
    
    /// The action to run when the teardown action has completed.
    @Environment(\.finishTeardown) private var finishTeardown
    
    func body(content: Content) -> some View {
        content
            .onDisappear {
                switch action {
                case .action(let action):
                    action()
                    finishTeardown()
                case .actionAsync(let action):
                    Task {
                        await action()
                        finishTeardown()
                    }
                }
            }
    }
}

extension EnvironmentValues {
    /// The action to run when a sample is done tearing down.
    ///
    /// Calling this allows a blocked ``Sample/hasTeardown`` sample to appear.
    @Entry var finishTeardown: () -> Void = {}
}
