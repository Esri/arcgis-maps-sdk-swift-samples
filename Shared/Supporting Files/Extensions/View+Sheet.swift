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
    ///   - isPresented: A `Binding` to a Boolean value that determines whether the sheet is presented.
    ///   - detents: A set of supported detents for the sheet. If there is more than one detent, the sheet
    ///   can be dragged to resize it.
    ///   - selection: A `Binding` to the currently selected detent.
    ///   - dragIndicatorVisibility: The preferred visibility of the drag indicator.
    ///   - idealWidth: The ideal width of the popover.
    ///   - idealHeight: The ideal height of the popover.
    ///   - onDismiss: A closure to execute when dismissing the sheet.
    ///   - content: A closure returning the content of the sheet.
    /// - Note: This modifier can have conflict with modal presentation views, such as an alert.
    /// When the sheet is presented, it may cause the "already presenting" problem.
    func sheet<Content>(
        isPresented: Binding<Bool>,
        detents: [Detent],
        selection: Binding<Detent>? = nil,
        dragIndicatorVisibility: Visibility = .automatic,
        idealWidth: CGFloat = 320,
        idealHeight: CGFloat = 428,
        onDismiss: (() -> Void)? = nil,
        content: @escaping () -> Content
    ) -> some View where Content: View {
        modifier(
            SheetModifier(
                isPresented: isPresented,
                detents: detents,
                selection: selection ?? .none,
                dragIndicatorVisibility: dragIndicatorVisibility,
                idealWidth: idealWidth,
                idealHeight: idealHeight,
                onDismiss: onDismiss,
                sheetContent: content()
            )
        )
    }
}

// MARK: Detent

/// A detent for sheet presentation.
enum Detent {
    /// A medium sheet presentation detent.
    case medium
    /// A large sheet presentation detent.
    case large
}

// MARK: Environment

private struct DragIndicatorVisibilityEnvironmentKey: EnvironmentKey {
    static let defaultValue: Visibility = .automatic
}

private struct IsSheetLayoutEnvironmentKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    /// The preferred visibility of the drag indicator.
    var dragIndicatorVisibility: Visibility {
        get { self[DragIndicatorVisibilityEnvironmentKey.self] }
        set { self[DragIndicatorVisibilityEnvironmentKey.self] = newValue }
    }
    
    /// A Boolean value indicating whether the device's layout is such that a sheet should be presented.
    var isSheetLayout: Bool {
        get { self[IsSheetLayoutEnvironmentKey.self] }
        set { self[IsSheetLayoutEnvironmentKey.self] = newValue }
    }
}

// MARK: Sheet Modifier

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
    let detents: [Detent]
    
    /// A `Binding` to the currently selected detent.
    let selection: Binding<Detent>?
    
    /// The preferred visibility of the drag indicator.
    let dragIndicatorVisibility: Visibility
    
    /// The ideal width of the popover.
    let idealWidth: CGFloat
    
    /// The ideal height of the popover.
    let idealHeight: CGFloat
    
    /// The closure to execute when dismissing the sheet.
    let onDismiss: (() -> Void)?
    
    /// The sheet's content.
    let sheetContent: SheetContent
    
    /// A Boolean value indicating whether the device's layout is such that a sheet should be presented.
    private var isSheetLayout: Bool { horizontalSizeClass != .regular || verticalSizeClass != .regular }
    
    func body(content: Content) -> some View {
        makeContentWithSheetWrapper(content)
    }
}

// MARK: iOS 15

private extension Detent {
    /// A medium or large `UISheetPresentationController.Detent` based on the `Detent`.
    var sheetDetent: UISheetPresentationController.Detent {
        switch self {
        case .medium: return .medium()
        case .large: return .large()
        }
    }
    
    /// A medium or large `UISheetPresentationController.Detent.Identifier` based on the `Detent`.
    var sheetDetentIdentifier: UISheetPresentationController.Detent.Identifier {
        switch self {
        case .medium: return .medium
        case .large: return .large
        }
    }
}

private extension UISheetPresentationController.Detent.Identifier {
    /// A `Detent` based on the `UISheetPresentationController.Detent.Identifier`. Is `nil` if
    /// the identifier is not medium or large.
    var detent: Detent? {
        switch self {
        case .medium: return .medium
        case .large: return .large
        default: return nil
        }
    }
}

private extension SheetModifier {
    /// Creates the given content with a popover modifier and a `UIViewRepresentable` that presents a sheet
    /// using a `UISheetPresentationController` and `UISheetPresentationController.Detent`s.
    /// - Parameter content: The content that will present the sheet or popover.
    /// - Returns: The given content with the necessary modifiers and views to present a popover or sheet and
    /// transition between them when necessary.
    func makeContentWithSheetWrapper(_ content: Content) -> some View {
        ZStack {
            content
                .task(id: isPresented) {
                    if isPresented {
                        // Sleep to prevent appearing when other content is disappearing.
                        try? await Task.sleep(nanoseconds: 1000)
                        
                        if isSheetLayout {
                            isSheetVisible = true
                        } else {
                            isPopoverVisible = true
                        }
                    } else {
                        isSheetVisible = false
                        isPopoverVisible = false
                    }
                }
                .popover(isPresented: $isPopoverVisible) {
                    sheetContent
                        .frame(idealWidth: idealWidth, idealHeight: idealHeight)
                        .onDisappear {
                            isPopoverVisible = false
                            isPresented = false
                            onDismiss?()
                        }
                }
            
            Sheet(
                isPresented: $isSheetVisible,
                detents: detents.map { $0.sheetDetent },
                selection: Binding(
                    get: {
                        selection?.wrappedValue.sheetDetentIdentifier
                    },
                    set: {
                        if let newSelection = $0?.detent {
                            selection?.wrappedValue = newSelection
                        }
                    }
                )
            ) {
                sheetContent
                    .onDisappear {
                        isSheetVisible = false
                        isPresented = false
                        onDismiss?()
                    }
            }
            .fixedSize()
            .environment(\.dragIndicatorVisibility, dragIndicatorVisibility)
            .environment(\.isSheetLayout, isSheetLayout)
        }
    }
}

// MARK: Sheet Wrapper

private struct Sheet<Content>: UIViewRepresentable where Content: View {
    /// The preferred visibility of the drag indicator.
    @Environment(\.dragIndicatorVisibility) private var dragIndicatorVisibility
    
    /// A Boolean value indicating whether the device's layout is such that a sheet should be presented.
    @Environment(\.isSheetLayout) private var isSheetLayout
    
    /// A Boolean value indicating whether the sheet is presented.
    @Binding private var isPresented: Bool
    
    /// The specified detents for the sheet.
    private let detents: [UISheetPresentationController.Detent]
    
    /// The identifier of the currently selected detent.
    @Binding private var selection: UISheetPresentationController.Detent.Identifier?
    
    /// The content of the sheet.
    private let content: Content
    
    /// A sheet model used to refer to the hosting controller.
    @StateObject private var model: SheetModel
    
    /// Initializes the sheet.
    /// - Parameters:
    ///   - isPresented: A Boolean value indicating whether the sheet is presented.
    ///   - detents: The specified detents for the sheet.
    ///   - selection: The identifier of the currently selected detent.
    ///   - content: The content of the sheet.
    init(
        isPresented: Binding<Bool>,
        detents: [UISheetPresentationController.Detent],
        selection: Binding<UISheetPresentationController.Detent.Identifier?>,
        content: @escaping () -> Content
    ) {
        _isPresented = isPresented
        self.detents = detents
        _selection = selection
        self.content = content()
        _model = StateObject(
            wrappedValue: SheetModel(
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
        let presentedControllerIsHosting = rootViewController.presentedViewController is UIHostingController<Content>
        
        /// A Boolean value indicating whether the presented view controller is an alert controller.
        let presentedControllerIsAlert = rootViewController.presentedViewController is UIAlertController
        
        /// A Boolean value indicating whether the sheet was already presenting.
        let wasPresenting = rootViewController.presentedViewController != nil && presentedControllerIsHosting
        
        /// A Boolean value indicating whether the hosting controller is being dismissed.
        let hostingControllerIsBeingDismissed = model.hostingController.isBeingDismissed
        
        // Ensures that the device's layout is such that a sheet should be presented and
        // the hosting controller's sheet presentation controller exists.
        guard isSheetLayout,
              let sheet = model.hostingController.sheetPresentationController else {
            // Dismisses the sheet if it is being presented and a popover should
            // be presented instead.
            if presentedControllerIsHosting && !hostingControllerIsBeingDismissed {
                rootViewController.dismiss(animated: false)
            }
            return
        }
        
        if isPresented && !wasPresenting {
            // Sets the sheet presentation controller's delegate.
            sheet.delegate = context.coordinator
            // Configures the hosting controller's sheet presentation controller.
            configureSheetPresentationController(sheet)
            // Presents the hosting controller.
            rootViewController.present(model.hostingController, animated: !model.isTransitioningFromPopover)
        } else if !isPresented && wasPresenting && !hostingControllerIsBeingDismissed && !presentedControllerIsAlert {
            // Dismisses the view controller presented by the root view controller
            // if 'isPresented' is false, but was presenting before (popover), is
            // not currently being dismissed, and is not an alert.
            rootViewController.dismiss(animated: presentedControllerIsHosting)
            model.isTransitioningFromPopover = !presentedControllerIsHosting
        } else if wasPresenting {
            // Updates the sheet presentation controller and the root view of the hosting
            // controller if the sheet was already presenting.
            configureSheetPresentationController(sheet)
            Task {
                model.hostingController.rootView = content
            }
        }
    }
    
    /// Configures the given sheet presentation controller's detents, selected detent identifier, and drag indicator visibility.
    /// - Parameter sheet: The `UISheetPresentationController` to configure.
    private func configureSheetPresentationController(_ sheet: UISheetPresentationController) {
        sheet.detents = detents
        sheet.selectedDetentIdentifier = selection
        switch dragIndicatorVisibility {
        case .automatic:
            sheet.prefersGrabberVisible = detents.count > 1
        case .visible:
            sheet.prefersGrabberVisible = true
        case .hidden:
            sheet.prefersGrabberVisible = false
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
            parent.selection = presentationController.presentedViewController.sheetPresentationController?.selectedDetentIdentifier
        }
        
        /// Updates the selection of the parent when the sheet presentation controller's selected detent identifier changes.
        func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {
            parent.selection = sheetPresentationController.selectedDetentIdentifier
        }
    }
}

private extension Sheet {
    class SheetModel: ObservableObject {
        /// A Boolean value indicating whether the layout is transitioning from a popover layout.
        var isTransitioningFromPopover = false
        /// The hosting controller for the content of the sheet.
        let hostingController: UIHostingController<Content>
        
        init(content: Content) {
            hostingController = UIHostingController(rootView: content)
        }
    }
}
