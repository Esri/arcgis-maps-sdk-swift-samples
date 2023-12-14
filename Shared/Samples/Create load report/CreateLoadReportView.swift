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

struct CreateLoadReportView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        LoadReportView(model: model)
            .task {
                await model.setup()
            }
            .errorAlert(presentingError: $model.error)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Run") {
                        Task {
                            await model.createLoadReport()
                        }
                    }
                    .disabled(!model.allowsCreateLoadReport)
                }
            }
            .overlay(alignment: .center) {
                if let status = model.statusText {
                    ZStack {
                        Color.clear.background(.ultraThinMaterial)
                        VStack {
                            Text(status)
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        .padding()
                        .background(.ultraThickMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 50)
                    }
                }
            }
    }
}

#Preview {
    NavigationView {
        CreateLoadReportView()
    }
}
