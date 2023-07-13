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

extension CreateLoadReportView {
    struct LoadReportView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        var body: some View {
            Form {
                Section("Phases, Total Customers(C), Total Load(L)") {
                    ForEach(model.includedPhases, id: \.name) { phase in
                        HStack {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .imageScale(.large)
                                .clipped()
                                .onTapGesture {
                                    model.deletePhase(phase)
                                }
                            Text("Phase: \(phase.name)")
                            Spacer()
                            Text(model.summaryForPhase(phase))
                        }
                    }
                    .onDelete { indexSet in
                        model.deletePhase(atOffsets: indexSet)
                    }
                }
                if !model.excludedPhases.isEmpty {
                    Section("More Phases") {
                        ForEach(model.excludedPhases, id: \.name) { phase in
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                    .imageScale(.large)
                                    .clipped()
                                Text(phase.name)
                            }
                            .onTapGesture {
                                model.addPhase(phase)
                            }
                        }
                    }
                }
            }
        }
    }
}
