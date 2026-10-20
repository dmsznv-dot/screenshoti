import AppKit
import SwiftUI

/// An in-place palette: every color control stays inside this bounded popover.
struct CompactColorPalette: View {
    @Binding var color: Color
    let title: String
    var onEditingChanged: (UUID, Bool) -> Void = { _, _ in }
    @State private var inputID = UUID()
    @ObservedObject private var preferences = AppPreferences.shared
    @State private var isPresented = false
    @State private var hexValue = ""
    @State private var invalidHex = false

    private static let presets = [
        "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE", "32ADE6",
        "007AFF", "5856D6", "AF52DE", "FF2D55", "A2845E", "FFFFFF",
        "000000", "48484A", "8E8E93", "C7C7CC", "FFD5D2", "CBEAFF"
    ]

    var body: some View {
        Button {
            hexValue = Self.hex(for: color)
            invalidHex = false
            isPresented.toggle()
        } label: {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 4).fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.25)))
                    .frame(width: 21, height: 21)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .padding(3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue("#" + Self.hex(for: color))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 6), spacing: 8) {
                    ForEach(Self.presets, id: \.self) { hex in
                        Button {
                            if let selected = Self.parseHex(hex) { color = selected }
                            hexValue = hex
                            invalidHex = false
                        } label: {
                            RoundedRectangle(cornerRadius: 5).fill(Self.parseHex(hex) ?? .black)
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.2)))
                                .overlay {
                                    if Self.hex(for: color) == hex {
                                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(hex == "000000" || hex == "48484A" || hex == "5856D6" || hex == "007AFF" ? .white : .black)
                                    }
                                }
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("#" + hex)
                        .accessibilityAddTraits(Self.hex(for: color) == hex ? .isSelected : [])
                    }
                }
                HStack(spacing: 6) {
                    Text("#").foregroundStyle(.secondary)
                    TextField("RRGGBB", text: $hexValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(applyHex)
                        .accessibilityLabel(preferences.language == .ru ? "HEX-код цвета" : "Hex color")
                    Button(preferences.language == .ru ? "Применить" : "Apply", action: applyHex)
                        .controlSize(.small)
                }
                if invalidHex {
                    Text(preferences.language == .ru ? "Введите 6 символов: 0–9, A–F." : "Enter 6 characters: 0–9, A–F.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            .padding(16)
            .frame(width: 230)
            .onDisappear { onEditingChanged(inputID, false) }
        }
        .onChange(of: isPresented) { _, presented in onEditingChanged(inputID, presented) }
        .onDisappear { onEditingChanged(inputID, false) }
        .onChange(of: color) { _, newColor in
            hexValue = Self.hex(for: newColor)
            invalidHex = false
        }
    }

    private func applyHex() {
        guard let parsed = Self.parseHex(hexValue) else { invalidHex = true; return }
        color = parsed
        hexValue = Self.hex(for: parsed)
        invalidHex = false
    }

    private static func parseHex(_ text: String) -> Color? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, value.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains($0) }),
              let rgb = UInt32(value, radix: 16) else { return nil }
        return Color(red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255)
    }

    private static func hex(for color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return "000000" }
        return String(format: "%02X%02X%02X", Int((rgb.redComponent * 255).rounded()),
                      Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
    }
}

private enum FontCatalog {
    static let families = NSFontManager.shared.availableFontFamilies.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

/// Bind to defaults while creating text, or to an annotation while editing it.
struct FontControls: View {
    var onSizeEditingChanged: (Bool) -> Void = { _ in }
    @Binding var fontName: String
    @Binding var fontSize: CGFloat
    var onEditingChanged: (UUID, Bool) -> Void = { _, _ in }
    @State private var inputID = UUID()
    @FocusState private var sizeFocused: Bool
    @ObservedObject private var preferences = AppPreferences.shared

    private var boundedSize: Binding<Double> {
        Binding(get: { Double(fontSize) }, set: { value in
            guard value.isFinite else { return }
            fontSize = min(AnnotationItem.fontSizeRange.upperBound, max(AnnotationItem.fontSizeRange.lowerBound, CGFloat(value)))
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(preferences.language == .ru ? "Шрифт" : "Font").foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Picker(preferences.language == .ru ? "Шрифт" : "Font", selection: $fontName) {
                    Text(preferences.language == .ru ? "Системный жирный" : "System Bold").tag(AnnotationItem.systemFontName)
                    ForEach(FontCatalog.families, id: \.self) { family in
                        Text(family).tag(family)
                    }
                    if fontName != AnnotationItem.systemFontName && !FontCatalog.families.contains(fontName) {
                        Text(fontName).tag(fontName)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 180)
            }
            HStack {
                Text(preferences.language == .ru ? "Размер" : "Size").foregroundStyle(.secondary)
                Spacer(minLength: 8)
                TextField(preferences.language == .ru ? "Размер шрифта" : "Font size", value: boundedSize,
                          format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .focused($sizeFocused)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                Text("pt").font(.caption).foregroundStyle(.secondary)
                Stepper(preferences.language == .ru ? "Размер шрифта" : "Font size", value: boundedSize, in: 8...144, step: 1)
                    .labelsHidden().fixedSize()
            }
            Slider(value: boundedSize, in: 8...144, step: 1, onEditingChanged: onSizeEditingChanged)
                .accessibilityLabel(preferences.language == .ru ? "Размер шрифта" : "Font size")
        }
        .font(.system(size: 12))
        .onChange(of: sizeFocused) { _, focused in onEditingChanged(inputID, focused) }
        .onDisappear { onEditingChanged(inputID, false); onSizeEditingChanged(false) }
    }
}
