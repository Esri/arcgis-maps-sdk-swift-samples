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

extension AddDynamicEntityLayerView {
    struct VehicleCallout: View {
        /// The dynamic entity that represents a vehicle.
        let dynamicEntity: DynamicEntity
        
        /// The name of the vehicle.
        @State private var name: String = ""
        
        /// The location of the vehicle.
        @State private var location: String = ""
        
        /// The speed of the vehicle.
        @State private var speed: Double = .nan
        
        /// The heading of the vehicle.
        @State private var heading: Double = .nan
        
        var body: some View {
            HStack {
                VStack(alignment: .center, spacing: 6) {
                    Text(name)
                        .bold()
                        .evaluateArcadeExpression("$feature.vehiclename", for: dynamicEntity) { evaluation in
                            name = evaluation.stringValue
                        }
                    Text(location)
                        .font(.caption2)
                        .evaluateArcadeExpression(
                            "concatenate(\"(\", Round($feature.point_x,6), \", \", Round($feature.point_y,6), \")\")",
                            for: dynamicEntity
                        ) { evaluation in
                            location = evaluation.stringValue
                        }
                }
                
                Divider()
                    .frame(maxHeight: 44)
                VStack(spacing: 6) {
                    Text(speed, format: .number.precision(.fractionLength(0)))
                        .bold()
                    Text("MPH")
                        .font(.caption2)
                }
                
                Divider()
                    .frame(maxHeight: 44)
                VStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle")
                        .rotationEffect(.degrees(heading))
                    Text(Measurement<UnitAngle>(value: heading, unit: .degrees).formatted())
                        .font(.caption2)
                }
            }
            .padding(10)
            .task {
                // Show initial heading and speed.
                updateHeadingAndSpeed()
                for await _ in dynamicEntity.changes {
                    // Update heading and speed as the dynamic entity changes.
                    updateHeadingAndSpeed()
                }
            }
        }
        
        /// Updates the heading and the speed from the dynamic entity.
        private func updateHeadingAndSpeed() {
            withAnimation {
                heading = dynamicEntity.attributes["heading"] as? Double ?? .nan
            }
            speed = dynamicEntity.attributes["speed"] as? Double ?? .nan
        }
    }
}

private extension Result<ArcadeEvaluationResult, Error> {
    /// The evaluation as a string. If the evaluation results in an error, `nil`,
    /// or a type other than a string, then an empty string is returned.
    var stringValue: String {
        switch self {
        case .success(let evaluationResult):
            if let resultString = evaluationResult.result(as: .string) as? String {
                return resultString
            }
            fallthrough
        default:
            return ""
        }
    }
}
