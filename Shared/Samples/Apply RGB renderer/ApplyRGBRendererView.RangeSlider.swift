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

extension ApplyRGBRendererView {
    /// A slider with two thumbs for selecting a range of values.
    struct RangeSlider: View {
        @Binding var lowerValue: Double
        @Binding var upperValue: Double
        
        let range: ClosedRange<Double>
        let step: Double
        
        private let thumbSize: CGFloat = 20
        
        var body: some View {
            GeometryReader { geometry in
                let width = geometry.size.width - thumbSize
                let height = geometry.size.height
                let lowerRatio = CGFloat((lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound))
                let upperRatio = CGFloat((upperValue - range.lowerBound) / (range.upperBound - range.lowerBound))
                let lowerX = lowerRatio * width
                let upperX = upperRatio * width
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 4)
                        .padding(.horizontal, thumbSize / 2)
                    
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: upperX - lowerX, height: 4)
                        .offset(x: lowerX + thumbSize / 2)
                    
                    Group {
                        thumbView
                            .position(x: lowerX + thumbSize / 2, y: height / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        let newValue = Double((gesture.location.x - thumbSize / 2) / width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                        lowerValue = min(max(range.lowerBound, newValue), upperValue)
                                        lowerValue = (lowerValue / step).rounded() * step
                                    }
                            )

                        thumbView
                            .position(x: upperX + thumbSize / 2, y: height / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        let newValue = Double((gesture.location.x - thumbSize / 2) / width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                        upperValue = max(min(range.upperBound, newValue), lowerValue)
                                        upperValue = (upperValue / step).rounded() * step
                                    }
                            )
                    }
                }
            }
            .frame(height: thumbSize)
        }
        
        var thumbView: some View {
            Circle()
                .fill(Color.white)
                .shadow(radius: 1)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(Circle().stroke(Color.gray.opacity(0.5)))
        }
    }
}
