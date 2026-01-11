//
//  ToastView.swift
//  LexiconFlow
//
//  Non-intrusive toast notification component with glassmorphism support
//

import SwiftUI

/// Style of the toast notification
enum ToastStyle {
    case success
    case error
    case info
    case warning

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .error: .red
        case .info: .blue
        case .warning: .orange
        }
    }
}

/// A glassmorphic toast notification view
struct ToastView: View {
    let message: String
    let style: ToastStyle

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.style.icon)
                .font(.title3)
                .foregroundStyle(self.style.color)

            Text(self.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            // Glass effect background
            if AppSettings.glassEffectsEnabled {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
        }
        .overlay {
            // Subtle border for better definition
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(self.style.color.opacity(0.3), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .padding(.horizontal, 24)
        .padding(.bottom, 16) // Bottom safe area offset usually handled by overlay placement
    }
}

/// ViewModifier for presenting toasts
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let style: ToastStyle
    let duration: TimeInterval

    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if self.isPresented {
                    ToastView(message: self.message, style: self.style)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            self.triggerHaptics()
                            self.dismissAfterDelay()
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: self.isPresented)
            .onChange(of: self.isPresented) { _, newValue in
                if newValue {
                    self.dismissAfterDelay()
                }
            }
    }

    private func dismissAfterDelay() {
        self.workItem?.cancel()

        let task = DispatchWorkItem {
            withAnimation {
                self.isPresented = false
            }
        }
        self.workItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + self.duration, execute: task)
    }

    private func triggerHaptics() {
        guard AppSettings.hapticEnabled else { return }
        switch self.style {
        case .success:
            HapticService.shared.triggerSuccess()
        case .error:
            HapticService.shared.triggerError()
        case .warning:
            HapticService.shared.triggerWarning()
        case .info:
            HapticService.shared.triggerLight()
        }
    }
}

extension View {
    /// Present a toast notification
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        style: ToastStyle = .info,
        duration: TimeInterval = 2.5
    ) -> some View {
        self.modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            style: style,
            duration: duration
        ))
    }
}

#Preview("Success") {
    Color.blue.ignoresSafeArea()
        .overlay(
            ToastView(message: "Sentences regenerated successfully!", style: .success)
                .padding(),
            alignment: .bottom
        )
}

#Preview("Error") {
    Color.gray.ignoresSafeArea()
        .overlay(
            ToastView(message: "Failed to connect to AI service.", style: .error)
                .padding(),
            alignment: .bottom
        )
}
