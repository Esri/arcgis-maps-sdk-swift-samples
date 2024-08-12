#!/usr/bin/env bash
# Copyright 2024 Esri
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# set -xv # uncomment for debugging

# Variables ::
build_destination="generic/platform=iOS Simulator"
log_name=.xcodebuild.log

# Delete derived data. Otherwise, SwiftLint won't find any files to analyze.
rm -rf ~/Library/Developer/Xcode/DerivedData

# Go to project root directory.
cd "$(dirname "$0")/../.."

echo "Building '$log_name'"
xcodebuild -project Samples.xcodeproj -scheme Samples -destination "$build_destination" > $log_name

swiftlint analyze --compiler-log-path $log_name

rm $log_name
