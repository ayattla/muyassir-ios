import SwiftUI
import UIKit

/// Shared frame for every tool: inline title, favourite star, readable width on iPad.
struct ToolScreen<Content: View>: View {
    let tool: Tool
    @ViewBuilder var content: Content
    @EnvironmentObject var store: Store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(tool.sub).font(.plex(.subheadline)).foregroundStyle(.secondary)
                content
            }
            .padding(16).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tool.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleFavorite(tool.id) } label: {
                    Image(systemName: store.favorites.contains(tool.id) ? "star.fill" : "star").foregroundStyle(store.favorites.contains(tool.id) ? Brand.saffron : .secondary)
                }.accessibilityLabel(store.favorites.contains(tool.id) ? "إزالة من المفضلة" : "إضافة إلى المفضلة")
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("تم") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
        }
    }
}

struct Panel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title { Text(title).font(.plex(.headline, .semibold)) }
            content
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct NumField: View {
    let label: String
    @Binding var text: String
    var suffix: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.plex(.caption, .medium)).foregroundStyle(.secondary)
            HStack {
                TextField("0", text: Binding(get: { text }, set: { v in text = String(v.map { c in ("٠"..."٩").contains(String(c)) ? Character(String(c.unicodeScalars.first!.value - 0x0660)) : (c == "٫" ? "." : c) }) }))
                    .keyboardType(.decimalPad).font(.plex(.body)).accessibilityLabel(label).accessibilityIdentifier(label)
                if let suffix { Text(suffix).font(.plex(.footnote)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 12).frame(minHeight: 46)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct Field: View {
    let label: String
    @Binding var text: String
    var lines: Int = 1
    var kind: UIKeyboardType = .default
    var secure = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.plex(.caption, .medium)).foregroundStyle(.secondary)
            Group {
                if secure { SecureField("", text: $text) }
                else if lines > 1 { TextField("", text: $text, axis: .vertical).lineLimit(lines...max(lines, 12)) }
                else { TextField("", text: $text).keyboardType(kind) }
            }
            .accessibilityLabel(label).accessibilityIdentifier(label)
            .font(.plex(.body)).padding(.horizontal, 12).padding(.vertical, 11).frame(minHeight: 46)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

extension String { var num: Double { Double(trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")) ?? 0 } }

func fmt(_ v: Double, _ d: Int = 2) -> String {
    if v.isNaN || v.isInfinite { return "—" }
    let f = NumberFormatter(); f.locale = Locale(identifier: "en_US"); f.numberStyle = .decimal; f.maximumFractionDigits = d; f.minimumFractionDigits = 0
    return f.string(from: NSNumber(value: v)) ?? "\(v)"
}
func money(_ v: Double, _ unit: String = "ريال") -> String {
    let f = NumberFormatter(); f.locale = Locale(identifier: "en_US"); f.numberStyle = .decimal; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
    return "\(f.string(from: NSNumber(value: v)) ?? "\(v)") \(unit)"
}

struct ResultCard: View {
    var main: (String, String)?
    var rows: [(String, String)] = []
    var note: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let main {
                Text(main.0).font(.plex(.subheadline, .semibold)).foregroundStyle(Color(hex: 0xB7BFDB))
                Text(main.1).font(.plex(.title, .bold)).foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(2)
                if !rows.isEmpty { Divider().overlay(Color.white.opacity(0.2)) }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack { Text(r.0).foregroundStyle(Color(hex: 0xB7BFDB)); Spacer(); Text(r.1).foregroundStyle(.white).fontWeight(.semibold) }.font(.plex(.subheadline))
            }
            if let note { Text(note).font(.plex(.caption)).foregroundStyle(Color(hex: 0x9AA3C2)) }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryButton: View {
    let title: String; var icon: String? = nil; var enabled = true; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label { Text(title).font(.plex(.headline, .semibold)) } icon: { if let icon { Image(systemName: icon) } }
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14)).disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String; var icon: String? = nil; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label { Text(title).font(.plex(.subheadline, .semibold)) } icon: { if let icon { Image(systemName: icon) } }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 14))
    }
}

struct Seg: View {
    let options: [String]; @Binding var selection: Int
    var body: some View {
        Picker("", selection: $selection) { ForEach(options.indices, id: \.self) { Text(options[$0]).tag($0) } }.pickerStyle(.segmented)
    }
}

struct Hint: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(Brand.lapis)
            Text(text).font(.plex(.footnote)).foregroundStyle(.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.lapis.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct EmptyStateView: View {
    let icon: String, title: String, text: String
    var body: some View {
        ContentUnavailableView { Label(title, systemImage: icon) } description: { Text(text) }
    }
}

struct Chip: View {
    let text: String; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.plex(.subheadline, .semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Brand.lapis : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }.buttonStyle(.plain)
    }
}

struct LabelValue: View {
    let label: String, value: String; var strong = false
    var body: some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(strong ? .bold : .regular) }.font(.plex(.subheadline))
    }
}

struct TextResult: View {
    let text: String; var label = "النتيجة"
    var body: some View {
        Panel(title: label) {
            Text(text.isEmpty ? "—" : text).font(.plex(.body)).textSelection(.enabled)
            HStack {
                SecondaryButton(title: "نسخ", icon: "doc.on.doc") { UIPasteboard.general.string = text }
                ShareLink(item: text) { Label("مشاركة", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.bordered)
            }
        }
    }
}

struct ToolRow: View {
    let tool: Tool; var compact = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tool.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Tools.color(tool))
                .frame(width: 42, height: 42).background(Tools.color(tool).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title).font(.plex(.subheadline, .semibold)).foregroundStyle(.primary)
                if !compact { Text(tool.sub).font(.plex(.caption)).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// Share sheet for files (works on iPhone and iPad).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
