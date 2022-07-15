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
    
    /// The current vertical size class of the environment.
    @Environment(\.verticalSizeClass) private var verticalSizeClass: UserInterfaceSizeClass?
    
    /// A Boolean value indicating whether the sheet or popover is presented.
    @Binding var isPresented: Bool {
        didSet {
            if !isPresented {
                onDismiss?()
            }
        }
    }
    
    /// The specified detents for the sheet.
    let detents: Set<Detent>
    
    /// The closure to execute when dismissing the sheet.
    let onDismiss: (() -> Void)?
    
    /// The content of the sheet.
    let sheetContent: SheetContent
    
    /// A Boolean value indicating whether the device's layout is such that a sheet should be presented.
    private var isSheetLayout: Bool { horizontalSizeClass != .regular || verticalSizeClass != .regular }
    
    /// The view containing the content of the sheet.
    private var sheetContentView: some View {
        NavigationView {
            sheetContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isPresented.toggle()
                        }
                    }
                }
        }
    }
    
    @State private var popoverIsVisible = false
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            // TODO: Complete iOS 16.0 implementation.
            //            content
            //                .sheet(
            //                    isPresented: Binding(
            //                        get: { isPresented && isSheetLayout },
            //                        set: { isPresented = $0 }
            //                    ),
            //                    onDismiss: onDismiss) {
            //                        NavigationView {
            //                            sheetContent
            //                                .presentationDetents(Set(
            //                                    detents.map {
            //                                        switch $0 {
            //                                        case .medium: return .medium
            //                                        case .large: return .large
            //                                        }
            //                                    }
            //                                ))
            //                                .navigationBarTitleDisplayMode(.inline)
            //                                .toolbar {
            //                                    ToolbarItem(placement: .confirmationAction) {
            //                                        Button("Done") {
            //                                            isPresented.toggle()
            //                                        }
            //                                    }
            //                                }
            //                        }
            //                    }
            //                    .popover(
            //                        isPresented: Binding(
            //                            get: { isPresented && !isSheetLayout },
            //                            set: { isPresented = $0 }
            //                        ),
            //                        attachmentAnchor: .point(.bottom)
            //                    ) {
            //                        sheetContentView
            //                            .navigationViewStyle(.stack)
            //                            .frame(idealWidth: 320, idealHeight: 428)
            //                    }
        } else {
            ZStack {
                content
                    .popover(
                        isPresented: Binding(
                            get: { isPresented && !isSheetLayout },
                            set: { isPresented = $0 }
                        ),
                        attachmentAnchor: .point(.bottom)
                    ) {
                        sheetContentView
                            .navigationViewStyle(.stack)
                            .frame(idealWidth: 320, idealHeight: 428)
                            .onAppear { popoverIsVisible = true }
                            .onDisappear { popoverIsVisible = false }
                    }
                
                Sheet(
                    isPresented: Binding(
                        get: { isPresented && !popoverIsVisible },
                        set: { isPresented = $0 }
                    ),
                    detents: detents.map {
                        switch $0 {
                        case .medium: return .medium()
                        case .large: return .large()
                        }
                    },
                    onDismiss: onDismiss,
                    isSheetLayout: isSheetLayout
                ) {
                    sheetContentView
                        .navigationViewStyle(.stack)
                }
                .fixedSize()
            }
        }
    }
}

private struct Sheet<Content>: UIViewControllerRepresentable where Content: View {
    /// A Boolean value indicating whether the sheet is presented.
    @Binding private var isPresented: Bool
    
    /// A Boolean value indicating whether the device's layout is such that a sheet should be presented.
    private let isSheetLayout: Bool
    
    /// The content of the sheet.
    private let content: Content
    
    /// A sheet model used to refer to the hosting controller.
    @StateObject private var model: SheetModel<Content>
    
    /// Initializes the sheet.
    /// - Parameters:
    ///   - isPresented: A Boolean value indicating whether the sheet is presented.
    ///   - detents: The specified detents for the sheet.
    ///   - onDismiss: The closure to execute when dismissing the sheet.
    ///   - isSheetLayout: A Boolean value indicating whether the device's layout is such that a sheet should be presented.
    ///   - content: The content of the sheet.
    init(
        isPresented: Binding<Bool>,
        detents: [UISheetPresentationController.Detent],
        onDismiss: (() -> Void)?,
        isSheetLayout: Bool,
        content: @escaping () -> Content
    ) {
        _isPresented = isPresented
        self.isSheetLayout = isSheetLayout
        self.content = content()
        _model = StateObject(
            wrappedValue: SheetModel<Content>(
                detents: detents,
                onDismiss: onDismiss,
                content: content()
            )
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ rootViewController: UIViewController, context: Context) {
        /// A Boolean value indicating whether the sheet was already presenting.
        let wasPresenting = rootViewController.presentedViewController != nil
        
        // Ensures that the device's layout is such that a sheet should be presented.
        guard isSheetLayout else {
            // Dismisses the sheet if it is being presented and a popover should
            // be presented instead.
            if rootViewController.presentedViewController is UIHostingController<Content> {
                rootViewController.dismiss(animated: false)
            }
            return
        }
        
        if isPresented && !wasPresenting && model.presentationAttempts < 2 {
            // Presents the hosting controller if the sheet should be presented,
            // was not presenting before, and the number of presentation attempts
            // is less than two.
            
            // Sets the delegate and detents for the hosting controller.
            model.hostingController.sheetPresentationController?.delegate = context.coordinator
            if let sheet = model.hostingController.sheetPresentationController {
                sheet.detents = model.detents
            }
            // Presents the hosting controller.
            rootViewController.present(model.hostingController, animated: true)
            // Increments the number of presentation attempts.
            model.presentationAttempts += 1
        } else if !isPresented && wasPresenting {
            // Dismisses the sheet and resets number of presentation attempts.
            rootViewController.dismiss(animated: true)
            model.presentationAttempts = 0
        } else if wasPresenting {
            // Updates the root view of the hosting controller if the sheet
            // was already presenting.
            model.hostingController.rootView = content
        }
    }
    
    /// A coordinator acting as the `UISheetPresentationControllerDelegate` for the sheet.
    class Coordinator: NSObject, UISheetPresentationControllerDelegate {
        /// The coordinator's parent.
        private var parent: Sheet
        
        init(_ parent: Sheet) {
            self.parent = parent
        }
        
        /// Sets `isPresenting` to false when the sheet is dismissed with a swipe and executes `onDismiss`.
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            parent.isPresented = false
            parent.model.onDismiss?()
            parent.model.presentationAttempts = 0
        }
    }
}

private extension Sheet {
    class SheetModel<Content>: ObservableObject where Content: View {
        /// The number of attempts the view controller has made to present the hosting controller.
        var presentationAttempts = 0
        /// The hosting controller for the content of the sheet.
        let hostingController: UIHostingController<Content>
        /// The specified detents for the sheet.
        let detents: [UISheetPresentationController.Detent]
        /// The closure to execute when dismissing the sheet.
        let onDismiss: (() -> Void)?
        
        init(
            detents: [UISheetPresentationController.Detent],
            onDismiss: (() -> Void)?,
            content: Content
        ) {
            self.detents = detents
            self.onDismiss = onDismiss
            hostingController = UIHostingController(rootView: content)
        }
    }
}
