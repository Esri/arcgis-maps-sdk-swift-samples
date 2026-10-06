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

extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView {
    /// Instructions for trying Dynamic Type scaling in the sample.
    struct TextSizeTip: Tip {
        /// The identifier of the action that opens accessibility settings.
        static let openSettingsActionID = "openSettings"
        
        var title: Text {
            Text("Try a larger text size")
        }
        
        var message: Text? {
            UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView
                .textSizeInstructions
        }
        
        var image: Image? {
            Image(systemName: "textformat.size")
        }
        
        var actions: [Action] {
            Action(
                id: Self.openSettingsActionID,
                title: "Open Accessibility Settings"
            )
        }
    }
    
    /// The platform-specific instructions shared by the tip and help sheet.
    nonisolated static var textSizeInstructions: Text {
#if targetEnvironment(macCatalyst)
        Text(
            """
            Text-size support \
            depends on the system and app settings.
            
            Open System Settings > Accessibility > Display > Text size \
            to scale restaurant labels and symbols.
            
            Select a restaurant to view its name and coordinates.
            """
        )
#else
        Text(
            """
            Open Settings > Accessibility > Display & Text Size > \
            Larger Text.
            
            Enable Larger Accessibility Sizes for additional \
            sizes, then return to see restaurant labels and symbols scale.
            
            Select a restaurant to view its name and coordinates.
            """
        )
#endif
    }
}
