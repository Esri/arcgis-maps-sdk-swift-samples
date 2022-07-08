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

extension View {
    /// Presents a sheet with the specified detent and content.
    /// - Parameters:
    ///   - isPresented: A binding to a Boolean value that determines whether the sheet it presented.
    ///   - detents: A set of supported detents for the sheet. If there is more than one detent, the sheet
    ///   can be dragged to resize it.
    ///   - onDismiss: A closure to execute when dismissing the sheet.
    ///   - content: A closure returning the content of the sheet.
    @ViewBuilder
    func sheet<Content>(
        isPresented: Binding<Bool>,
        detents: Set<Detent>,
        onDismiss: (() -> Void)? = nil,
        content: @escaping () -> Content
    ) -> some View where Content: View {
        modifier(
            SheetModifier(
                isPresented: isPresented,
                detents: detents,
                onDismiss: onDismiss,
                sheetContent: content()
            )
        )
    }
}

/// A detent for sheet presentation.
enum Detent {
    /// A medium sheet presentation detent.
    case medium
    /// A large sheet presentation detent.
    case large
}

private struct SheetModifier<SheetContent>: ViewModifier where SheetContent: View {
    /// The current horizontal size class of the environment.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    
    /// A Boolean value indicating whether the popover is dismissed.
    @State private var isPopoverDismissed = true
    
    /// A Boolean value indicating whether the sheet is presented.
    @Binding var isPresented: Bool
    
    /// The specified detents for the sheet.
    let detents: Set<Detent>
    
    /// The closure to execute when dismissing the sheet.
    let onDismiss: (() -> Void)?
    
    /// The content of the sheet.
    let sheetContent: SheetContent
    
    /// The current presentation style based on the horizontal size class.
    private var currentPresentationStyle: PresentationStyle? {
        if horizontalSizeClass == .compact {
            return .sheet
        } else {
            return .popover
        }
    }
    
    /// The possible presentation styles.
    private enum PresentationStyle {
        case popover, sheet
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *), horizontalSizeClass == .compact {
            //            let presentationDetents: Set<PresentationDetent> = Set(
            //                detents.map {
            //                    switch $0 {
            //                    case .medium: return .medium
            //                    case .large: return .large
            //                    }
            //                }
            //            )
            //            content
            //                .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            //                    NavigationView {
            //                        sheetContent
            //                            .presentationDetents(presentationDetents)
            //                            .navigationBarTitleDisplayMode(.inline)
            //                            .toolbar {
            //                                ToolbarItem(placement: .navigationBarTrailing) {
            //                                    Button("") {
            //                                        isPresented.toggle()
            //                                    }
            //                                    .buttonStyle(xMarkButtonStyle())
            //                                }
            //                            }
            //                    }
            //                }
        } else {
            ZStack {
                content
                    .popover(isPresented: Binding(get: {
                        isPresented && currentPresentationStyle == .popover
                    }, set: { newIsPresented in
                        isPresented = newIsPresented
                    }), attachmentAnchor: .point(.bottom)) {
                        NavigationView {
                            sheetContent
                                .navigationBarTitleDisplayMode(.inline)
                                .onAppear {
                                    isPopoverDismissed = false
                                }
                                .onDisappear {
                                    isPopoverDismissed = true
                                    // Calls on dismiss if the current
                                    // presentation style is a popover.
                                    // Avoids calling on dismiss when
                                    // transitioning from sheet to popover.
                                    if currentPresentationStyle == .popover {
                                        onDismiss?()
                                    }
                                }
                        }
                        .navigationViewStyle(.stack)
                        .frame(minWidth: 320, minHeight: 450)
                    }
                    .onChange(of: horizontalSizeClass) { _ in
                        // Hides the sheet/popover when the horizontal size
                        // class changes from regular to compact.
                        if isPresented && horizontalSizeClass == .regular {
                            isPresented = false
                        }
                    }
                if currentPresentationStyle == .sheet && isPopoverDismissed {
                    let presentationDetents: [UISheetPresentationController.Detent] = detents.map {
                        switch $0 {
                        case .medium: return .medium()
                        case .large: return .large()
                        }
                    }
                    Sheet(isPresented: $isPresented, detents: presentationDetents, onDismiss: onDismiss) {
                        NavigationView {
                            sheetContent
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button("") {
                                            isPresented.toggle()
                                        }
                                        .buttonStyle(xMarkButtonStyle())
                                    }
                                }
                        }
                        .navigationViewStyle(.stack)
                    }
                    .fixedSize()
                }
            }
        }
    }
}

private class SheetModel<Content>: ObservableObject where Content: View {
    /// The hosting controller for the content of the sheet.
    @Published var hostingController: UIHostingController<Content>?
    
    /// Creates the hosting controller with the given content.
    func makeHostingController(content: Content) {
        hostingController = UIHostingController(rootView: content)
    }
}

private struct Sheet<Content>: UIViewRepresentable where Content: View {
    /// The current horizontal size class of the environment.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    
    /// A Boolean value indicating whether the sheet is presented.
    @Binding var isPresented: Bool
    
    /// A sheet model used to refer to the hosting controller.
    @StateObject var model = SheetModel<Content>()
    
    /// The specified detents for the sheet.
    let detents: [UISheetPresentationController.Detent]
    
    /// The closure to execute when dismissing the sheet.
    let onDismiss: (() -> Void)?
    
    /// The content of the sheet.
    @ViewBuilder var content: Content
    
    func makeUIView(context: Context) -> UIView {
        // Creates the hosting controller, displaying the content of the sheet.
        model.makeHostingController(content: content)
        return UIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensures the root view controller and hosting controller exist.
        guard let rootViewController = uiView.window?.rootViewController,
              let hostingController = model.hostingController else {
            return
        }
        // Detects if the sheet was already presenting.
        let wasPresenting = rootViewController.presentedViewController != nil
        
        // Ensures the horizontal size class is compact.
        guard horizontalSizeClass == .compact else {
            // Dismisses the sheet if otherwise.
            rootViewController.dismiss(animated: false)
            return
        }
        
        if isPresented && !wasPresenting {
            // Sets the delegate and detents for the hosting controller.
            hostingController.sheetPresentationController?.delegate = context.coordinator
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = detents
            }
            // Presents the hosting controller.
            rootViewController.present(hostingController, animated: true)
        } else if !isPresented && wasPresenting {
            // Dismisses the sheet.
            rootViewController.dismiss(animated: true, completion: onDismiss)
        } else if wasPresenting {
            // Updates the root view of the hosting controller if the sheet
            // is already presenting.
            hostingController.rootView = content
        }
    }
    
    func makeCoordinator() -> Coordinator {
        // Initializes the coordinator.
        Coordinator(isPresented: $isPresented, onDismiss: onDismiss)
    }
    
    /// The `UISheetPresentationControllerDelegate` for the sheet.
    class Coordinator: NSObject, UISheetPresentationControllerDelegate {
        /// A Boolean value indicating whether the sheet is presented.
        @Binding var isPresented: Bool
        
        /// The closure to execute when dismissing the sheet.
        let onDismiss: (() -> Void)?
        
        init(isPresented: Binding<Bool>, onDismiss: (() -> Void)?) {
            _isPresented = isPresented
            self.onDismiss = onDismiss
        }
        
        /// Sets `isPresenting` to false when the sheet is dismissed with a swipe and executes `onDismiss`.
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            isPresented = false
            onDismiss?()
        }
    }
}

/// A button style that styles a button's label image with an x-mark circle. Fills the x-mark circle image when the
/// button is pressed.
private struct xMarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: configuration.isPressed ? "xmark.circle.fill" : "xmark.circle")
            .foregroundColor(.accentColor)
    }
}
