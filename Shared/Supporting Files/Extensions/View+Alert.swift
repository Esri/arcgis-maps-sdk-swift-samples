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
    /// Show an alert with the title "Error", the error's `localizedDescription`
    /// as the message, and an OK button.
    /// - Parameters:
    ///   - isPresented: A binding to a Boolean value that determines whether
    ///   to present the alert. When the user taps one of the alert’s actions,
    ///   the system sets this value to false and dismisses the alert.
    ///   - error: An error to be shown in the alert.
    func alert(isPresented: Binding<Bool>, presentingError error: Error?) -> some View {
        alert("Error", isPresented: isPresented, presenting: error) { _ in
            EmptyView()
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
