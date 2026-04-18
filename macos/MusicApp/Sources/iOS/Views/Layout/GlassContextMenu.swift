import SwiftUI

struct GlassMenuItem {
    let label: String
    let icon: String
    var isDestructive: Bool = false
    var tint: Color? = nil
    let action: () -> Void
}

struct GlassContextMenuModifier<MenuContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let menuContent: () -> MenuContent

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.4) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    isPresented = true
                }
            }
    }
}

struct GlassContextMenuOverlay: View {
    @Binding var isPresented: Bool
    let items: [GlassMenuItem]

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.25)) {
                            isPresented = false
                        }
                    }

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                isPresented = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                item.action()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 15))
                                    .frame(width: 20)
                                Text(item.label)
                                    .font(.system(size: 15))
                                Spacer()
                            }
                            .foregroundStyle(
                                item.isDestructive ? .red :
                                item.tint ?? .white
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 260)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            .zIndex(100)
        }
    }
}

extension View {
    func glassContextMenu(isPresented: Binding<Bool>, items: [GlassMenuItem]) -> some View {
        self
            .onLongPressGesture(minimumDuration: 0.4) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    isPresented.wrappedValue = true
                }
            }
    }
}
