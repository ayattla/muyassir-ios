import SwiftUI
import UIKit

/// Shared frame for every tool: inline title, favourite star, readable width on iPad.
struct ToolScreen<Content: View>: View {
    let tool: Tool
    @ViewBuilder var content: Content
    @EnvironmentObject var store: Store
    var body: some View {
        ScrollView {
            VStack(spacing: Space.m) {
                // Centred header: the tool's mark and what it does.
                VStack(spacing: 6) {
                    Image(systemName: tool.icon).font(.system(size: 24, weight: .semibold)).foregroundStyle(Brand.tone(Tools.hex(tool)))
                        .frame(width: 52, height: 52).background(Brand.toneSoft(Tools.hex(tool)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(tool.sub).font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.bottom, Space.xs)
                VStack(alignment: .leading, spacing: Space.m) { content }
            }
            .padding(Space.l).padding(.bottom, Space.xxl).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Brand.bg)
        .navigationTitle(tool.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleFavorite(tool.id) } label: {
                    Image(systemName: store.favorites.contains(tool.id) ? "star.fill" : "star").foregroundStyle(store.favorites.contains(tool.id) ? Brand.saffron : Brand.text3)
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
        VStack(alignment: .leading, spacing: Space.m) {
            if let title { Text(title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1).frame(maxWidth: .infinity) }
            content
        }
        .padding(Space.l).frame(maxWidth: .infinity, alignment: .leading).card()
    }
}

struct NumField: View {
    let label: String
    @Binding var text: String
    var suffix: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.plex(.caption, .medium)).foregroundStyle(Brand.text2)
            HStack {
                TextField("0", text: Binding(get: { text }, set: { v in text = String(v.map { c in ("٠"..."٩").contains(String(c)) ? Character(String(c.unicodeScalars.first!.value - 0x0660)) : (c == "٫" ? "." : c) }) }))
                    .keyboardType(.decimalPad).font(.plex(.body)).accessibilityLabel(label).accessibilityIdentifier(label)
                if let suffix { Text(suffix).font(.plex(.footnote)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 12).frame(minHeight: 46)
            .background(Brand.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.border, lineWidth: 1))
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
            Text(label).font(.plex(.caption, .medium)).foregroundStyle(Brand.text2)
            Group {
                if secure { SecureField("", text: $text) }
                else if lines > 1 { TextField("", text: $text, axis: .vertical).lineLimit(lines...max(lines, 12)) }
                else { TextField("", text: $text).keyboardType(kind) }
            }
            .accessibilityLabel(label).accessibilityIdentifier(label)
            .font(.plex(.body)).padding(.horizontal, 12).padding(.vertical, 11).frame(minHeight: 46)
            .background(Brand.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.border, lineWidth: 1))
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
        VStack(spacing: Space.s) {
            if let main {
                Text(main.0).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text2)
                Text(main.1).font(.plex(.title, .bold)).foregroundStyle(Brand.accent).minimumScaleFactor(0.6).lineLimit(2)
                if !rows.isEmpty { Divider().overlay(Brand.accent.opacity(0.15)) }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack { Text(r.0).foregroundStyle(Brand.text2); Spacer(); Text(r.1).foregroundStyle(Brand.text1).fontWeight(.semibold) }.font(.plex(.subheadline))
            }
            if let note { Text(note).font(.plex(.caption)).foregroundStyle(Brand.text3) }
        }
        .multilineTextAlignment(.center)
        .padding(Space.l).frame(maxWidth: .infinity)
        .background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Brand.accent.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

struct PrimaryButton: View {
    let title: String; var icon: String? = nil; var enabled = true; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label { Text(title).font(.plex(.headline, .semibold)) } icon: { if let icon { Image(systemName: icon) } }
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent).tint(Brand.accent).buttonBorderShape(.roundedRectangle(radius: Radius.m)).disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String; var icon: String? = nil; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label { Text(title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1) } icon: { if let icon { Image(systemName: icon).foregroundStyle(Brand.accent) } }
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Brand.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Brand.borderStrong, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
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
            Image(systemName: "info.circle").foregroundStyle(Brand.text3)
            Text(text).font(.plex(.footnote)).foregroundStyle(Brand.text2)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.sunken, in: RoundedRectangle(cornerRadius: Radius.m))
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
                .background(selected ? Brand.accent : Brand.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Brand.borderStrong, lineWidth: 1))
                .foregroundStyle(selected ? Brand.onAccent : Brand.text1)
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
    let tool: Tool; var compact = false; var plain = false
    var body: some View {
        let row = HStack(spacing: 12) {
            Image(systemName: tool.icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Brand.tone(Tools.hex(tool)))
                .frame(width: 38, height: 38).background(Brand.toneSoft(Tools.hex(tool)), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1)
                if !compact { Text(tool.sub).font(.plex(.caption)).foregroundStyle(Brand.text2).lineLimit(2) }
            }
            Spacer(minLength: 0)
            if !plain { Image(systemName: "chevron.backward").font(.caption).foregroundStyle(Brand.text3) }
        }.contentShape(Rectangle())
        if plain { row } else { row.padding(12).card(Radius.m) }
    }
}

/// Grid card: centred icon, name and purpose.
struct ToolCard: View {
    let tool: Tool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: tool.icon).font(.system(size: 21, weight: .semibold)).foregroundStyle(Brand.tone(Tools.hex(tool)))
                .frame(width: 46, height: 46).background(Brand.toneSoft(Tools.hex(tool)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(tool.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1).lineLimit(2)
            Text(tool.sub).font(.plex(.caption2)).foregroundStyle(Brand.text2).lineLimit(2, reservesSpace: true)
        }
        .multilineTextAlignment(.center).padding(Space.m).frame(maxWidth: .infinity, minHeight: 150).card().contentShape(Rectangle())
    }
}

/// Share sheet for files (works on iPhone and iPad).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
