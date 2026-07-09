// Copyright 2026 Esri
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
import TipKit

extension NavigateMapAndIdentifyFeaturesWithKeyboardView {
    /// A TipKit tip that explains the centered rectangle.
    struct AreaOfInterestTip: Tip {
        var title: Text {
            Text("Use the rectangle as the search area")
        }
        
        var message: Text? {
            Text(
                 """
                 Use the arrow keys ← → ↑ ↓ on the keyboard to pan map. Pan until the restaurants you want to inspect are inside the rectangle. Press 1–9 on the keyboard to select a highlighted restaurant in the rectangle and view its details.
                 """
            )
        }
        
        var image: Image? {
            Image(systemName: "rectangle.dashed")
        }
    }
    
    struct EnableKeyboardAccessTip: Tip {
        /// The ID of the action that opens the Settings app.
        static let openSettingsActionID = "openSettings"
        
        var title: Text {
            Text("Enable Full Keyboard Access")
        }
        
        var message: Text? {
            Text(
                """
                To use a hardware keyboard with your mobile device you need to enable Full Keyboard Access.
                You can do this by opening the Settings app and navigating to:
                
                Accessibility > Keyboards & Typing.
                """
            )
        }
        
        var image: Image? {
            Image(systemName: "keyboard")
        }
        
        var actions: [Action] {
            Action(
                id: Self.openSettingsActionID,
                title: "Open Accessibility Settings"
            )
        }
    }
}
