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

import ArcGIS
import SwiftUI

struct TraceUtilityNetworkView: View {
    @State private var map = {
        let map = Map(item: PortalItem.napervilleElectricalNetwork)
        map.basemap = Basemap(style: .arcGISStreetsNight)
        return map
    }()
    
    var body: some View {
        MapView(map: map)
            .onDisappear {
                ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
            }
            .task {
                try? await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            }
    }
}

private extension ArcGISCredential {
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: .sampleServer7,
                username: "viewer01",
                password: "I68VGU^nMurF"
            )
        }
    }
}

private extension Item.ID {
    static var napervilleElectricalNetwork: Item.ID {
        .init("471eb0bf37074b1fbb972b1da70fb310")!
    }
}

private extension PortalItem {
    static var napervilleElectricalNetwork: PortalItem {
        .init(
            portal: .arcGISOnline(connection: .authenticated),
            id: .napervilleElectricalNetwork
        )
    }
}

private extension URL {
    static var sampleServer7: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/portal/sharing/rest")!
    }
}
