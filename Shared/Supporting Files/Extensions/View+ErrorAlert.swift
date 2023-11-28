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

extension View {
    /// Presents an alert with a given error's `localizedDescription` as the message.
    /// - Parameter error: A binding to an optional `Error` that will present the alert when
    /// it is not `nil`. When the user taps "OK", this value is set to `nil`, and the alert is dismissed.
    ///
    /// If the given `error` is a `CancellationError`, it is ignored, and the alert is not presented.
    func errorAlert(presentingError error: Binding<Error?>) -> some View {
        /// A binding to a Boolean value indicating whether to present the alert.
        let isPresented: Binding<Bool>
        if error.wrappedValue != nil && !(error.wrappedValue is CancellationError) {
            isPresented = .constant(true)
        } else {
            isPresented = .constant(false)
        }
        
        return alert("Error", isPresented: isPresented, presenting: error.wrappedValue) { _ in
            Button("OK") {
                error.wrappedValue = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
