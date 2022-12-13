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
import WebKit

struct WebView: UIViewRepresentable {
    /// The HTML to load in the web view.
    let htmlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        // Creates the web view's configuration.
        let webConfiguration = WKWebViewConfiguration()
        // Sets the data detector types to links.
        webConfiguration.dataDetectorTypes = .link
        // Creates a web view with the configuration.
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        // Sets the web view's navigation delegate.
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Loads the given HTML string.
        webView.loadHTMLString(htmlString, baseURL: URL(fileURLWithPath: Bundle.main.bundlePath))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            switch navigationAction.navigationType {
            case .linkActivated:
                if let url = navigationAction.request.url, UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            default:
                decisionHandler(.allow)
            }
        }
    }
}
