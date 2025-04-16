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

extension EnvironmentValues {
    /// The view model for requesting App Store reviews.
    @Entry var requestReviewModel = RequestReviewModel()
}

/// A view model for requesting App Store reviews.
final class RequestReviewModel {
    /// The number of times a sample has been opened by the user.
    @AppStorage("sampleOpenCount") private var sampleOpenCount = 0
    
    /// The last version that an App Store review was requested.
    @AppStorage("lastRequestedReviewVersion") var lastRequestedReviewVersion: String?
    
    /// A Boolean value indicating whether an App Store review can be requested.
    ///
    /// This is `true` if all the following conditions are met:
    /// - The project was not compiled using the `Debug` Build Configuration.
    /// - A sample is not currently showing.
    /// - A sample has been opened since the app has been launched.
    /// - There have been at least four total sample launches.
    /// - A review has not yet been requested for the current bundle version.
    var canRequestReview: Bool {
#if DEBUG
        false
#else
        !sampleIsShowing &&
        sampleOpenedSinceLaunch &&
        sampleOpenCount > 3 &&
        lastRequestedReviewVersion != Bundle.main.shortVersion
#endif
    }
    
    /// A Boolean value indicating whether a sample is displayed.
    var sampleIsShowing = false {
        didSet {
            if sampleIsShowing {
                sampleOpenedSinceLaunch = true
                sampleOpenCount += 1
            }
        }
    }
    
    /// A Boolean value indicating whether a sample has been opened since the
    /// app has been launched.
    private var sampleOpenedSinceLaunch = false
}
