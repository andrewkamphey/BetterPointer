import SwiftUI

/// Spacing on an 8-point grid.
private enum Grid {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let rowHeight: CGFloat = 44
    static let section: CGFloat = 12
    static let swatch: CGFloat = 22
}

struct MenuView: View {
    @EnvironmentObject private var store: PointerStore
    @State private var newPresetName = ""
    @State private var editName = ""
    @State private var addingPreset = false
    @State private var typing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.bottom, Grid.section)

            if store.colorsSupported && !store.hasFullDiskAccess { fullDiskAccessBanner.padding(.bottom, Grid.section) }
            if let deleted = store.recentlyDeleted { undoBanner(deleted.preset).padding(.bottom, Grid.section) }

            // Flat sections split by hairlines: nothing boxed inside a box.
            section { presetsSection }
            section { sizeSection }
            section { colorSection }
            section { switchesSection }
            section { appRulesSection }
            section { footer }
        }
        .padding(Grid.m)
        .frame(width: 340)
        .background(keyboardShortcuts)
        .onAppear { store.refresh() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Grid.xs) {
            HStack {
                Text("Where's My Mouse?").font(.headline)
                Spacer()
                Text(String(format: "%.1f×", store.size)).font(Font.headline.monospacedDigit()).foregroundColor(.secondary)
            }
            Label(store.statusText, systemImage: "cursorarrow.motionlines")
                .font(.callout)
                .foregroundColor(.secondary)
                .accessibilityLabel("Now using \(store.statusText)")
        }
    }

    // MARK: Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: Grid.xs) {
            sectionTitle("Presets")
            ForEach(Array(store.allPresets.enumerated()), id: \.element.id) { index, preset in
                PresetRow(preset: preset, number: index + 1, isActive: store.activePresetID == preset.id)
            }

            if let editing = store.editingPreset {
                nameField(title: "Rename “\(editing.name)”", text: $editName, button: "Done", action: commitEdit)
                    .onAppear { editName = editing.name }
                    .onChange(of: editing.id) { _ in editName = editing.name }
            } else if let modified = store.modifiedSelectedPreset {
                HStack {
                    Text("Changed from “\(modified.name)”").font(.callout).foregroundColor(.secondary)
                    Spacer()
                    Button("Update") { store.updateSelectedPreset() }
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, Grid.xs)
            }

            if addingPreset {
                nameField(title: "New preset from the current pointer", text: $newPresetName, button: "Save", action: saveNew)
            } else {
                HStack {
                    Button {
                        addingPreset = true
                        typing = true
                    } label: {
                        Label("New preset", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    }
                    Button { RecipeMenu.show(store: store) } label: {
                        Label("Recipes", systemImage: "sparkles").frame(minHeight: 28)
                    }
                    .fixedSize()
                    .help("Add a ready-made look: seasonal, pop culture, colors from around the world")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, Grid.s)
            }
        }
    }

    private func nameField(title: String, text: Binding<String>, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Grid.xs) {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack(spacing: Grid.s) {
                TextField("Name", text: text, onEditingChanged: { typing = $0 }, onCommit: action)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                Button(button, action: action)
                    .controlSize(.large)
                    .disabled(trimmed(text.wrappedValue).isEmpty)
            }
        }
        .padding(.top, Grid.xs)
    }

    // MARK: Size, color, switches

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: Grid.s) {
            sectionTitle("Size")
            SizeSlider(size: Binding(get: { store.size }, set: { store.setSize($0) }), maxSize: store.maxSize)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Grid.s) {
            sectionTitle("Color")
            if store.colorsSupported {
                ColorRow(title: "Fill", color: store.fill, target: .fill, onPick: store.setFill)
                ColorRow(title: "Outline", color: store.outline, target: .outline, onPick: store.setOutline)
            } else {
                // macOS 11 has no pointer colors; everything else works.
                Label("Pointer colors need macOS 12 or later. Size, Super shake and app rules all work on your Mac.",
                      systemImage: "info.circle")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var switchesSection: some View {
        VStack(spacing: 0) {
            SwitchRow(title: "Extra large sizes", detail: "Up to 30× with a drawn pointer",
                      isOn: Binding(get: { store.extendedSizes }, set: { store.setExtendedSizes($0) }))
            Divider().padding(.leading, Grid.xs)
            SwitchRow(title: "Super shake", detail: "Shake to triple the pointer, at any size",
                      isOn: Binding(get: { store.superShakeEnabled }, set: { store.setSuperShake($0) }))
            Divider().padding(.leading, Grid.xs)
            SwitchRow(title: "macOS shake to find", detail: "Built into macOS; tops out around 4×",
                      isOn: Binding(get: { store.shakeToLocate }, set: { store.setShakeToLocate($0) }))
                .contextMenu { Button("Open Pointer settings…") { CursorController.openPointerSettings() } }
        }
    }

    // MARK: App rules

    private var appRulesSection: some View {
        VStack(alignment: .leading, spacing: Grid.s) {
            HStack {
                sectionTitle("App rules")
                Spacer()
                Toggle("App rules on", isOn: Binding(get: { store.appRulesEnabled }, set: { store.setAppRulesEnabled($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .help("Switch to an app's preset automatically. With no rule app open, it goes back to Default.")
            if store.appRules.isEmpty {
                Text("Add apps to a preset with its ＋ button. While that app is in use, your pointer switches to that preset.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Picker("Follow", selection: Binding(get: { store.ruleTrigger }, set: { store.setRuleTrigger($0) })) {
                    ForEach(RuleTrigger.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .help("Active app: follows the app you're using. Last opened: the most recently launched rule app wins.")
                ForEach(store.appRules) { rule in RuleRow(rule: rule) }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .controlSize(.large)
                .keyboardShortcut("q")
                .help("Quit Where's My Mouse (⌘Q)")
        }
    }

    // MARK: Banners

    private var fullDiskAccessBanner: some View {
        VStack(alignment: .leading, spacing: Grid.s) {
            Label("Colors need Full Disk Access", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundColor(.orange)
            Text("Size works without it. Add Where's My Mouse under Privacy & Security → Full Disk Access.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Grid.s) {
                Button("Open Settings") { CursorController.openFullDiskAccessSettings() }
                Button("Show App") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            }
        }
        .padding(Grid.s + Grid.xs)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
    }

    private func undoBanner(_ preset: Preset) -> some View {
        HStack {
            Text("Deleted “\(preset.name)”").font(.callout)
            Spacer()
            Button("Undo") { store.undoDelete() }
                .controlSize(.large)
                .keyboardShortcut("z")
        }
        .padding(.horizontal, Grid.s + Grid.xs)
        .padding(.vertical, Grid.s)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)))
    }

    // MARK: Keyboard

    /// ↑/↓ step through presets and ⌘1–⌘9 jump to one. Off while typing a name.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("Previous preset") { step(-1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("Next preset") { step(1) }.keyboardShortcut(.downArrow, modifiers: [])
            ForEach(Array(store.allPresets.prefix(9).enumerated()), id: \.element.id) { index, preset in
                Button(preset.name) { store.select(preset) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .disabled(typing)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func step(_ delta: Int) {
        let presets = store.allPresets
        guard !presets.isEmpty else { return }
        let current = presets.firstIndex { $0.id == store.activePresetID } ?? (delta > 0 ? -1 : presets.count)
        let next = min(max(current + delta, 0), presets.count - 1)
        store.select(presets[next])
    }

    // MARK: Helpers

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            content().padding(.vertical, Grid.section)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
    }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }

    private func saveNew() {
        let name = trimmed(newPresetName)
        guard !name.isEmpty else { return }
        store.saveNewPreset(named: name)
        newPresetName = ""
        addingPreset = false
        typing = false
    }

    private func commitEdit() {
        let name = trimmed(editName)
        guard !name.isEmpty else { return }
        store.commitEdit(name: name)
        typing = false
    }
}

// MARK: - Rows

private struct PresetRow: View {
    @EnvironmentObject private var store: PointerStore
    let preset: Preset
    let number: Int
    let isActive: Bool
    @State private var hovering = false
    private var isEditing: Bool { store.editingPresetID == preset.id }

    var body: some View {
        HStack(spacing: Grid.s) {
            Button { store.select(preset) } label: {
                HStack(spacing: Grid.s + 2) {
                    PointerSwatch(fill: preset.fill, outline: preset.outline)
                    Text(preset.name).font(.body.weight(isActive ? .semibold : .regular)).lineLimit(1)
                    ForEach(store.ruleApps(for: preset)) { rule in
                        if let icon = PointerStore.icon(forBundleID: rule.bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 16, height: 16).help(rule.appName)
                        }
                    }
                    Spacer(minLength: Grid.xs)
                }
                .frame(maxWidth: .infinity, minHeight: Grid.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Actions appear on hover; nothing is reserved for them otherwise.
            if hovering || isEditing {
                HStack(spacing: 0) {
                    iconButton("plus.app", help: "Add an app to “\(preset.name)”") { store.addApp(to: preset) }
                    if !preset.isBuiltIn {
                        iconButton("pencil", help: "Rename or update") { store.beginEditing(preset) }
                        iconButton("trash", help: "Delete") { store.delete(preset) }
                    }
                }
            }

            Text(sizeText)
                .font(Font.caption.weight(.bold).monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(isActive ? Color.accentColor : Color.primary.opacity(0.07)))
                .foregroundColor(isActive ? Color.white : Color.secondary)
        }
        .padding(.horizontal, Grid.s + 2)
        .background(RoundedRectangle(cornerRadius: 10).fill(rowBackground))
        // The selected preset is the one bordered thing in the menu.
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 2).opacity(isActive || isEditing ? 1 : 0))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Use “\(preset.name)”") { store.select(preset) }
            Button("Add an app…") { store.addApp(to: preset) }
            ForEach(store.ruleApps(for: preset)) { rule in
                Button("Remove \(rule.appName) from “\(preset.name)”") { store.removeAppRule(rule) }
            }
            if !preset.isBuiltIn {
                Button("Rename or update") { store.beginEditing(preset) }
                Button("Delete") { store.delete(preset) }
            }
        }
        .help(number <= 9 ? "⌘\(number)" : "")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.name), \(String(format: "%.1f", preset.size)) times\(isActive ? ", selected" : "")")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var sizeText: String {
        preset.size == preset.size.rounded() ? "\(Int(preset.size))×" : String(format: "%.1f×", preset.size)
    }

    private var rowBackground: Color {
        if isActive || isEditing { return Color.accentColor.opacity(0.12) }
        return hovering ? Color.primary.opacity(0.06) : .clear
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// A setting with a one-line explanation and a switch on the right.
private struct SwitchRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Grid.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .padding(.horizontal, Grid.xs)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}

private struct RuleRow: View {
    @EnvironmentObject private var store: PointerStore
    let rule: AppRule
    @State private var hovering = false

    var body: some View {
        let preset = store.allPresets.first { $0.id == rule.presetID }
        HStack(spacing: Grid.s) {
            Group {
                if let icon = PointerStore.icon(forBundleID: rule.bundleID) {
                    Image(nsImage: icon).resizable()
                } else {
                    Color.clear
                }
            }
            .frame(width: 20, height: 20)
            Text(rule.appName).lineLimit(1)
            Spacer(minLength: Grid.xs)
            Image(systemName: "arrow.right").font(.caption).foregroundColor(Color.secondary.opacity(0.6))
            HStack(spacing: 6) {
                if let preset { PointerSwatch(fill: preset.fill, outline: preset.outline).scaleEffect(0.7).frame(width: 16, height: 18) }
                Text(preset?.name ?? "Default").fontWeight(.semibold).lineLimit(1)
            }
            .frame(width: 110, alignment: .leading)
            Button { store.removeAppRule(rule) } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Take \(rule.appName) out of its preset")
            .accessibilityLabel("Remove rule for \(rule.appName)")
            .opacity(hovering ? 1 : 0)
        }
        .frame(minHeight: 36)
        .padding(.horizontal, Grid.xs + 2)
        .background(RoundedRectangle(cornerRadius: 8).fill(store.highlightedRuleID == rule.id ? Color.accentColor.opacity(0.18) : hovering ? Color.primary.opacity(0.06) : .clear))
        .opacity(store.appRulesEnabled ? 1 : 0.5)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Remove “\(rule.appName)”") { store.removeAppRule(rule) }
        }
    }
}

// MARK: - Controls

/// Size slider with a mark per whole size. Snaps to a whole size when released nearby.
private struct SizeSlider: View {
    @Binding var size: Double
    let maxSize: Double
    private var range: ClosedRange<Double> { 1...maxSize }
    private var marks: [Double] { Array(stride(from: 1, through: maxSize, by: 1)) }
    /// Label every size up to 10×; past that, 1× and every 5× so they fit.
    private func showsLabel(_ mark: Double) -> Bool { maxSize <= 10 || mark == 1 || Int(mark) % 5 == 0 }
    // Approximate inset of the slider track from its frame (half the knob width).
    private let knobInset: CGFloat = 10

    var body: some View {
        VStack(spacing: Grid.xs) {
            Slider(value: $size, in: range) { editing in
                if !editing, let mark = marks.first(where: { abs($0 - size) < 0.12 }), mark != size { size = mark }
            }
            .accentColor(isDrawn ? .purple : .accentColor)
            .accessibilityLabel("Pointer size")
            .accessibilityValue(String(format: "%.1f times", size))
            GeometryReader { geo in
                let track = geo.size.width - knobInset * 2
                let span = maxSize - 1
                ForEach(marks, id: \.self) { mark in
                    let current = abs(size - mark) < 0.05
                    Button { size = mark } label: {
                        VStack(spacing: 2) {
                            Rectangle().frame(width: 1, height: 4)
                            Text("\(Int(mark))×").font(.caption.weight(current ? .bold : .regular))
                                .opacity(showsLabel(mark) || current ? 1 : 0)
                        }
                        .frame(minWidth: 22, minHeight: 24)
                        .foregroundColor(current ? Color.accentColor : .secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Int(mark)) times")
                    .position(x: knobInset + track * (mark - 1) / span, y: 12)
                }
            }
            .frame(height: 24)

            if maxSize > drawnFrom {
                zones
                if isDrawn {
                    Label("Drawn pointer: arrow only, may trail slightly.", systemImage: "paintbrush")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Above 15× the window server won't scale the real pointer, so we draw one.
    private let drawnFrom = CursorController.overlayMinSize
    private var isDrawn: Bool { size >= drawnFrom }

    /// Two labeled bands under the ticks: the real macOS pointer, then the drawn one.
    private var zones: some View {
        GeometryReader { geo in
            let track = geo.size.width - knobInset * 2
            let split = knobInset + track * (drawnFrom - 0.5 - 1) / (maxSize - 1)
            HStack(spacing: 2) {
                zone("System pointer · 1–15×", color: .accentColor, active: !isDrawn)
                    .frame(width: split)
                zone("Drawn · 16–30×", color: .purple, active: isDrawn)
            }
        }
        .frame(height: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("1 to 15 times uses the system pointer; 16 to 30 times uses a drawn pointer")
    }

    private func zone(_ title: String, color: Color, active: Bool) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundColor(active ? .white : color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 5).fill(color.opacity(active ? 0.85 : 0.15)))
    }
}

private struct ColorRow: View {
    @EnvironmentObject private var store: PointerStore
    let title: String
    let color: RGBA
    let target: PointerStore.ColorTarget
    let onPick: (RGBA) -> Void

    private static let swatches: [(name: String, color: RGBA)] = [
        ("Black", .black), ("White", .white), ("Red", .red), ("Yellow", .yellow),
        ("Green", RGBA(red: 0.1, green: 0.8, blue: 0.2)), ("Blue", RGBA(red: 0, green: 0.45, blue: 1)),
        ("Pink", RGBA(red: 1, green: 0.4, blue: 0.75)),
    ]

    var body: some View {
        HStack(spacing: 6) {
            Text(title).frame(width: 58, alignment: .leading)
            ForEach(Self.swatches, id: \.name) { swatch in
                let selected = swatch.color.isClose(to: color)
                Button { onPick(swatch.color) } label: {
                    Circle()
                        .fill(swatch.color.color)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.5))
                        // Selection is a ring and a check, not color alone.
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).padding(-3).opacity(selected ? 1 : 0))
                        .overlay(Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(swatch.color.isDark ? .white : .black)
                            .opacity(selected ? 1 : 0))
                        .frame(width: Grid.swatch, height: Grid.swatch)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(swatch.name)
                .accessibilityLabel("\(swatch.name) \(title.lowercased())")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer(minLength: 0)
            Button { store.openColorPanel(for: target) } label: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.color)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.3)))
                    .overlay(Image(systemName: "eyedropper").font(.system(size: 10, weight: .bold))
                        .foregroundColor(color.isDark ? .white : .black).opacity(0.7))
                    .frame(width: 30, height: Grid.swatch)
            }
            .buttonStyle(.plain)
            .help("Any color…")
            .accessibilityLabel("Custom \(title.lowercased()) color")
        }
    }
}

/// Small preview of a pointer's fill and outline.
private struct PointerSwatch: View {
    let fill: RGBA
    let outline: RGBA

    var body: some View {
        ZStack {
            Image(systemName: "cursorarrow").font(.system(size: 19, weight: .black)).foregroundColor(outline.color)
            Image(systemName: "cursorarrow").font(.system(size: 14, weight: .regular)).foregroundColor(fill.color)
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
