import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Palette

public extension Color {
    /// Warm accent used for primary actions and the PR celebration.
    static let cadenceAccent = Color(red: 0.98, green: 0.45, blue: 0.16)
    /// Strength-training data.
    static let cadenceStrength = Color(red: 0.36, green: 0.42, blue: 0.95)
    /// Running data.
    static let cadenceRunning = Color(red: 0.13, green: 0.72, blue: 0.62)
    /// Daily activity from Apple Health (steps, energy, exercise).
    static let cadenceActivity = Color(red: 0.93, green: 0.27, blue: 0.42)

    static var cardBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Platform helpers

/// Small shims so the same view code compiles for iOS and macOS. The macOS
/// build exists purely so the package can be type-checked and unit-tested
/// without a simulator; the shipped app is iOS.
extension View {
    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func emailField() -> some View {
        #if os(iOS)
        keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    func groupedList() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.inset)
        #endif
    }

    @ViewBuilder
    func wheelPicker() -> some View {
        #if os(iOS)
        pickerStyle(.wheel)
        #else
        pickerStyle(.menu)
        #endif
    }

    /// Full-screen on iPhone, a regular sheet elsewhere.
    @ViewBuilder
    func workoutCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}
