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
    
    /// A Boolean value indicating whether a popover is visible.
    @State private var isPopoverVisible = false
    
    /// A Boolean value indicating whether a sheet is visible.
    @State private var isSheetVisible = false
    
    /// A Boolean value indicating whether the layout is transitioning from a sheet layout.
    @State private var isTransitioningFromSheet = false
    
    /// A Boolean value indicating whether the sheet or popover is presented.
    @Binding var isPresented: Bool
    
    /// The specified detents for the sheet.
    let detents: Set<Detent>
    
    /// The closure to execute when dismissing the sheet.
    let onDismiss: (() -> Void)?
    
    /// The sheet's content.
    let sheetContent: SheetContent
    
    /// A Boolean value indicating whether the device's layout is such that a sheet should be presented.
    private var isSheetLayout: Bool { horizontalSizeClass != .regular || verticalSizeClass != .regular }
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            makeContentWithSheet(content)
        } else {
            makeContentWithSheetWrapper(content)
        }
    }
}

private extension SheetModifier {
    /// Creates the given content with a popover and sheet modifier. Uses the native iOS 16 `presentationDetents`
    ///  modifier and `PresentationDetent` type to present a sheet.
    /// - Parameter content: The content that will present the sheet or popover.
    /// - Returns: The given content with popover and sheet modifiers to transition between a popover and a sheet
    /// when necessary.
    @available(iOS 16.0, *)
    func makeContentWithSheet(_ content: Content) -> some View {
        content
            .popover(
                isPresented: Binding(
                    get: { isPresented && !isSheetLayout && !isSheetVisible },
                    set: { isPresented = $0 }
                )
            ) {
                sheetContent
                    .frame(idealWidth: 320, idealHeight: 428)
                    .onAppear {
                        isPopoverVisible = true
                        isTransitioningFromSheet = false
                    }
                    .onDisappear {
                        isPopoverVisible = false
                        if !isPresented {
                            // Calls the on dismiss closure if the popover is
                            // not presented.
                            onDismiss?()
                        } else {
                            // Presents the sheet when transitioning from a
                            // popover layout.
                            isPresented = true
                        }
                        
                    }
            }
            .sheet(
                isPresented: Binding(
                    get: { isPresented && isSheetLayout && !isPopoverVisible },
                    set: { isPresented = $0 }
                )
            ) {
                sheetContent
//                    .presentationDetents(Set(
//                        detents.map {
//                            switch $0 {
//                            case .medium: return .medium
//                            case .large: return .large
//                            }
//                        }
//                    ))
                    .onAppear {
                        isSheetVisible = true
                        isTransitioningFromSheet = false
                    }
                    .onDisappear {
                        isSheetVisible = false
                        if isTransitioningFromSheet {
                            // Presents the sheet when transitioning from a
                            // sheet to popover layout.
                            isPresented = true
                        } else {
                            // Calls the on dismiss closure when the sheet disappears
                            // and is not transitioning to a popover.
                            onDismiss?()
                        }
                    }
            }
            .onChange(of: isSheetLayout) { _ in
                if isSheetLayout {
                    isTransitioningFromSheet = true
                }
            }
    }
    
    /// Creates the given content with a popover modifier and a `UIViewRepresentable` that presents a sheet
    /// using a `UISheetPresentationController` and `UISheetPresentationController.Detent`s.
    /// - Parameter content: The content that will present the sheet or popover.
    /// - Returns: The given content with the necessary modifiers and views to present a popover or sheet and
    /// transition between them when necessary.
    func makeContentWithSheetWrapper(_ content: Content) -> some View {
        ZStack {
            content
                .popover(
                    isPresented: Binding(
                        get: { isPresented && !isSheetLayout },
                        set: { isPresented = $0 }
                    )
                ) {
                    sheetContent
                        .frame(idealWidth: 320, idealHeight: 428)
                        .onAppear { isPopoverVisible = true }
                        .onDisappear {
                            isPopoverVisible = false
                            if !isPresented {
                                onDismiss?()
                            }
                        }
                }
            
            Sheet(
                isPresented: Binding(
                    get: { isPresented && !isPopoverVisible },
                    set: { isPresented = $0 }
                ),
                detents: detents.map {
                    switch $0 {
                    case .medium: return .medium()
                    case .large: return .large()
                    }
                },
                isSheetLayout: isSheetLayout
            ) {
                sheetContent
                    .onDisappear {
                        if !isPresented {
                            onDismiss?()
                        }
                    }
            }
            .fixedSize()
        }
    }
    
}

private struct Sheet<Content>: UIViewRepresentable where Content: View {
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
    
    func makeUIView(context: Context) -> UIView {
        UIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensures that the root view controller exists.
        guard let rootViewController = uiView.window?.rootViewController else { return }
        
        /// A Boolean value indicating whether the presented view controller is a hosting controller.
        let isPresentedControllerHostingType = rootViewController.presentedViewController is UIHostingController<Content>
        
        // Ensures that the device's layout is such that a sheet should be presented.
        guard isSheetLayout else {
            // Dismisses the sheet if it is being presented and a popover should
            // be presented instead.
            if isPresentedControllerHostingType {
                rootViewController.dismiss(animated: false)
            }
            return
        }
        
        /// A Boolean value indicating whether the sheet was already presenting.
        let wasPresenting = rootViewController.presentedViewController != nil
        
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
            rootViewController.present(model.hostingController, animated: model.isTransitioningFromPopover ? false : true)
            model.presentationAttempts += 1
        } else if !isPresented && wasPresenting && !model.hostingController.isBeingDismissed && !(rootViewController.presentedViewController is UIAlertController) {
            // Dismisses the view controller presented by the root view controller
            // if 'isPresented' is false, but was presenting before (popover), is
            // not currently being dismissed, and is not an alert.
            rootViewController.dismiss(animated: isPresentedControllerHostingType ? true : false)
            model.isTransitioningFromPopover = !isPresentedControllerHostingType
            model.presentationAttempts = 0
        } else if wasPresenting {
            // Updates the root view of the hosting controller if the sheet
            // was already presenting.
            model.hostingController.rootView = content
        }
    }
    
    /// A coordinator acting as the `UISheetPresentationControllerDelegate` for the sheet.
    class Coordinator: NSObject, UISheetPresentationControllerDelegate {
        /// The parent sheet.
        private var parent: Sheet
        
        init(_ parent: Sheet) {
            self.parent = parent
        }
        
        /// Updates the parent when the sheet is dismissed with a swipe.
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
        /// A Boolean value indicating whether the layout is transitioning from a popover layout.
        var isTransitioningFromPopover = false
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
