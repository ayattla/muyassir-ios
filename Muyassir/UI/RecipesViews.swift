import SwiftUI
import UniformTypeIdentifiers
import StoreKit

struct RecipeRoute: Hashable { let id: String }
struct RecipesRoute: Hashable {}
struct IncomingRoute: Hashable {}

struct RecipeCard: View {
    let recipe: Recipes.Recipe
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(Brand.accent).frame(width: 34, height: 34).background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                Text(recipe.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1).lineLimit(1)
                Spacer()
                if recipe.custom { Text("وصفتي").font(.plex(.caption2)).foregroundStyle(Brand.text3) }
            }
            Text(recipe.sub).font(.plex(.caption)).foregroundStyle(Brand.text2).lineLimit(2).multilineTextAlignment(.leading)
        }
        .padding(Space.m).frame(maxWidth: .infinity, alignment: .leading).card(Radius.m)
    }
}

struct RecipesView: View {
    @ObservedObject var recipes = Recipes.shared
    @ObservedObject var plus = Plus.shared
    @State private var building = false
    var body: some View {
        ScrollView {
            VStack(spacing: Space.m) {
                Text("سلسلة أدوات تعمل بلمسة واحدة. اختر وصفة ثم ملفاتك.").font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
                ForEach(Recipes.builtIn) { r in NavigationLink(value: RecipeRoute(id: r.id)) { RecipeCard(recipe: r) }.buttonStyle(PressStyle()).accessibilityIdentifier("recipe-\(r.id)") }
                HStack(spacing: 6) { Text("وصفاتي").font(.plex(.subheadline, .semibold)); PlusBadge() }
                if recipes.custom.isEmpty { Text("اصنع وصفة تناسب عملك المتكرر، مثل: صور الفواتير ← تحسين ← PDF ← ضغط.").font(.plex(.caption)).foregroundStyle(Brand.text3).multilineTextAlignment(.center) }
                ForEach(recipes.custom) { r in
                    HStack {
                        NavigationLink(value: RecipeRoute(id: r.id)) { RecipeCard(recipe: r) }.buttonStyle(PressStyle())
                        Button(role: .destructive) { recipes.delete(r.id) } label: { Image(systemName: "trash") }.accessibilityLabel("حذف الوصفة")
                    }
                }
                SecondaryButton(title: "وصفة جديدة", icon: "plus") { if plus.allow(.recipe) { building = true } }.accessibilityIdentifier("newRecipe")
            }
            .padding(Space.l).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(Brand.bg)
        .navigationTitle("الوصفات").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $building) { RecipeBuilder() }
    }
}

struct RecipeBuilder: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var input = "image"; @State private var steps: [Recipes.Step] = []
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("اسم الوصفة", text: $name) }
                Section("الملفات التي تبدأ بها") { Picker("", selection: $input) { ForEach(Recipes.inputs, id: \.0) { Text($0.1).tag($0.0) } }.pickerStyle(.segmented) }
                Section("الخطوات بالترتيب") {
                    if steps.isEmpty { Text("أضف خطوة من الأسفل").foregroundStyle(Brand.text3) }
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in Text("\(i + 1). " + Recipes.describe([s])) }.onDelete { steps.remove(atOffsets: $0) }
                }
                Section("أضف خطوة") { ForEach(Recipes.ops, id: \.0) { op in Button("+ \(op.1)") { steps.append(Recipes.Step(op: op.0, arg: Recipes.defaultArg[op.0] ?? 0)) } } }
            }
            .navigationTitle("وصفة جديدة").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { Recipes.shared.save(Recipes.Recipe(id: "c\(Int(Date().timeIntervalSince1970))", title: String(name.prefix(40)), sub: "", input: input, steps: steps)); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || steps.isEmpty)
                }
            }
        }
    }
}

/// Runs one recipe through the standard file-tool screen (picker, progress, results, Plus limits).
struct RecipeRunView: View {
    let id: String
    var body: some View {
        if let r = Recipes.shared.byId(id) {
            FileTool(tool: Recipes.asTool(r), types: Recipes.types(r), multiple: true, pickLabel: "اختر \(Recipes.inputName(r.input))", actionLabel: "تشغيل الوصفة", options: { ins in
                Panel(title: "الخطوات") {
                    ForEach(Array(r.steps.enumerated()), id: \.offset) { i, s in Text("\(i + 1). " + Recipes.describe([s])).font(.plex(.subheadline)) }
                    Hint(text: "\(ins.count) ملف. تعمل كل الخطوات على جهازك، وتحتسب الوصفة عملية واحدة.")
                }
            }) { ins, out, p in try Recipes.run(r, ins, out: out, p: p) }
        } else { Text("الوصفة غير موجودة") }
    }
}

/// «فتح في ميسر»: what to do with a file opened from another app.
struct IncomingView: View {
    @ObservedObject var incoming = Incoming.shared
    var body: some View {
        let kinds = Set(incoming.files.map(Incoming.kind))
        ScrollView {
            VStack(spacing: Space.m) {
                Panel(title: "\(incoming.files.count) \(incoming.files.count == 1 ? "ملف" : "ملفات") وصلت إلى ميسر") {
                    ForEach(incoming.files, id: \.self) { u in
                        HStack { Thumb(url: u); VStack(alignment: .leading) { Text(u.lastPathComponent).font(.plex(.subheadline)).lineLimit(1); Text("\(Incoming.kindLabel[Incoming.kind(u)] ?? "") • \(FilesX.human(FilesX.size(u)))").font(.plex(.caption)).foregroundStyle(Brand.text3) }; Spacer() }
                    }
                    Text("نسخت إلى جهازك فقط ولم ترفع إلى أي مكان.").font(.plex(.caption2)).foregroundStyle(Brand.text3).frame(maxWidth: .infinity)
                }
                let recipes = Recipes.shared.forKinds(kinds)
                if !recipes.isEmpty {
                    Text("وصفات بلمسة واحدة").font(.plex(.subheadline, .semibold))
                    ForEach(recipes) { r in NavigationLink(value: RecipeRoute(id: r.id)) { RecipeCard(recipe: r) }.buttonStyle(PressStyle()).simultaneousGesture(TapGesture().onEnded { incoming.handTo(incoming.files) }) }
                }
                Text("الأدوات المناسبة").font(.plex(.subheadline, .semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Space.s) {
                    ForEach(Incoming.toolsFor(kinds).compactMap { Tools.byId[$0] }) { t in
                        NavigationLink(value: t) { ToolRow(tool: t, compact: true) }.buttonStyle(PressStyle()).simultaneousGesture(TapGesture().onEnded { incoming.handTo(incoming.files) })
                    }
                }
            }
            .padding(Space.l).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(Brand.bg).accessibilityIdentifier("incoming")
        .navigationTitle("ماذا تريد أن تفعل؟").navigationBarTitleDisplayMode(.inline)
    }
}

/// First-run question: who are you? It only reorders the home screen; nothing is locked.
struct RoleCard: View {
    @AppStorage("role") private var role = ""
    var body: some View {
        VStack(spacing: Space.s) {
            Text("لنرتب ميسر لك").font(.plex(.headline, .semibold))
            Text("اختر ما يصفك لنقدم الأدوات التي تحتاجها أولا. يمكنك تغييره من الإعدادات.").font(.plex(.caption)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
            HStack { ForEach(Tools.roles, id: \.0) { r in Chip(text: r.1, selected: false) { role = r.0 } } }
            Button("تخط") { role = "none" }.font(.plex(.subheadline))
        }
        .padding(Space.l).frame(maxWidth: .infinity).card().accessibilityIdentifier("roleCard")
    }
}

/// Asks for an App Store rating once, after the third successful operation (never after an error).
enum ReviewAsk {
    @MainActor static func success() {
        let n = UserDefaults.standard.integer(forKey: "successes") + 1
        UserDefaults.standard.set(n, forKey: "successes")
        guard n == 3, let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }
}
