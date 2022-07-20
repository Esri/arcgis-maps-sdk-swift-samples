// Copyright 2022 Esri
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

struct SampleInfoView: View {
    /// The current color scheme of the device.
    @Environment(\.colorScheme) private var colorScheme
    
    /// The current sample information displayed.
    @State private var informationMode: InformationMode = .readme
    
    /// The sample to view information for.
    let sample: Sample
    
    var body: some View {
        ZStack {
            WebView(htmlString: readmeHTML ?? errorHTML)
                .zIndex(informationMode == .readme ? 1 : 0)
            WebView(htmlString: codeHTML ?? errorHTML)
                .zIndex(informationMode == .code ? 1 : 0)
        }
        .edgesIgnoringSafeArea([.horizontal, .bottom])
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Information Mode", selection: $informationMode) {
                    ForEach(InformationMode.allCases, id: \.self) { mode in
                        Text(mode.label)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            ToolbarItem(placement: .bottomBar) {
                if informationMode == .code {
                    Text(sampleViewFileName)
                }
            }
        }
    }
}

// MARK: README

private extension SampleInfoView {
    /// The markdown text from the sample's README
    var readmeMarkdownText: String? {
        // Defines the regex pattern for images.
        let pattern = "!\\[.*\\]\\(.*\\)"
        // Ensures that the content of the README exists and gets the text where
        // images exist in the README.
        guard let content = try? String(contentsOf: sample.readmeURL, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(location: 0, length: content.count)
        // Returns the content of the README without any occurrences of images.
        return regex.stringByReplacingMatches(in: content, range: range, withTemplate: "")
    }
    
    /// The HTML to display the README.
    var readmeHTML: String? {
        guard let content = readmeMarkdownText else { return nil }
        let cssPath = Bundle.main.path(forResource: "info", ofType: "css")!
        let string = """
            <!doctype html>
            <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <link rel="stylesheet" href="\(cssPath)">
                </head>
                <body>
                    <div id="preview" sd-model-to-html="text">
                        <div id="content">\(content)</div>
                    </div>
                    <script
                        src="https://cdnjs.cloudflare.com/ajax/libs/showdown/2.1.0/showdown.min.js"
                        integrity="sha512-LhccdVNGe2QMEfI3x4DVV3ckMRe36TfydKss6mJpdHjNFiV07dFpS2xzeZedptKZrwxfICJpez09iNioiSZ3hA=="
                        crossorigin="anonymous"
                        referrerpolicy="no-referrer"
                    >
                    </script>
                    <script>
                        var conv = new showdown.Converter();
                        var text = document.getElementById('content').innerHTML;
                        document.getElementById('content').innerHTML = conv.makeHtml(text);
                    </script>
                </body>
            </html>
            """
        return string
    }
}

// MARK: Code

private extension SampleInfoView {
    /// The name of the sample's view file.
    var sampleViewFileName: String { "\(sample.nameInUpperCamelCase)View" }
    
    /// The code of the sample's view file.
    var sampleContent: String? {
        guard let path = Bundle.main.path(forResource: sampleViewFileName, ofType: "swift"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return content
    }
    
    /// The HTML to display the sample's source code.
    var codeHTML: String? {
        guard let content = sampleContent else { return nil }
        let cssPath = Bundle.main.path(forResource: "xcode", ofType: "css")!
        let jsPath = Bundle.main.path(forResource: "highlight.min", ofType: "js")!
        let html = """
            <!doctype html>
            <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <link rel="stylesheet" href="\(cssPath)">
                    <script src="\(jsPath)"></script>
                    <script>hljs.highlightAll();</script>
                </head>
                <body>
                    <pre><code class="Swift">\(content)</code></pre>
                </body>
            </html>
            """
        return html
    }
}

// MARK: Error HTML

private extension SampleInfoView {
    /// The HTML to display if there is an error displaying the README or code.
    var errorHTML: String {
        """
        <!doctype html>
        <html>
        <h1 style="text-align: center;">Unable to display "\(sample.name)" \(informationMode == .code ? "code" : "README").</h1>
        </html>
        """
    }
}

// MARK: Information Mode

private extension SampleInfoView {
    enum InformationMode: CaseIterable {
        case readme, code
        
        /// A human-readable label for the information mode.
        var label: String {
            switch self {
            case .readme: return "Info"
            case .code: return "Code"
            }
        }
    }
}
