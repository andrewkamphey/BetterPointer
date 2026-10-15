import AppKit
import ServiceManagement

/// Current pointer settings, saved presets, and the actions the menu performs.
@MainActor
final class PointerStore: ObservableObject {
    @Published private(set) var size: Double
    @Published private(set) var fill: RGBA
    @Published private(set) var outline: RGBA
    @Published private(set) var customPresets: [Preset] = []
    @Published private(set) var hasFullDiskAccess = CursorController.hasFullDiskAccess
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var shakeToLocate = CursorController.shakeToLocate
    /// The custom preset being edited, if any.
    @Published var editingPresetID: UUID?
    /// The preset last picked from the list (or by an app rule).
    @Published private(set) var selectedPresetID: UUID?
    /// Shows 11×–15× on the size slider.
    @Published private(set) var extendedSizes = UserDefaults.standard.bool(forKey: extendedSizesKey)
    /// Apps that switch the pointer to a preset while they're open.
    @Published private(set) var appRules: [AppRule] = []
    @Published private(set) var appRulesEnabled = UserDefaults.standard.object(forKey: appRulesEnabledKey) as? Bool ?? true
    @Published private(set) var ruleTrigger = UserDefaults.standard.string(forKey: ruleTriggerKey).flatMap(RuleTrigger.init) ?? .activeApp

    private static let presetsKey = "customPresets"
    private static let sizeKey = "size"
    private static let extendedSizesKey = "extendedSizes"
    private static let appRulesKey = "appRules"
    private static let appRulesEnabledKey = "appRulesEnabled"
    private static let ruleTriggerKey = "ruleTrigger"
    /// The app whose rule is currently applied, if any.
    @Published private(set) var activeRuleBundleID: String?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var persistSizeWork: DispatchWorkItem?
    private var applyColorsWork: DispatchWorkItem?
    private let colorPanel = ColorPanelBridge()
    /// Set for README screenshots: shows fixed values and never touches the system.
    private var isSnapshot = false
    /// Set while a preset is being applied, so that isn't mistaken for an edit.
    private var isApplyingPreset = false

    init() {
        // The system only keeps up to 4×, so restore a larger size ourselves.
        let systemSize = CursorController.size
        let savedSize = UserDefaults.standard.double(forKey: Self.sizeKey)
        if savedSize > CursorController.systemMaxSize,
           systemSize >= CursorController.systemMaxSize - 0.01 || savedSize >= CursorController.overlayMinSize {
            CursorController.setSize(savedSize, persist: false)
            size = savedSize
        } else {
            size = systemSize
        }
        fill = CursorController.fill ?? .black
        outline = CursorController.outline ?? .white
        loadPresets()
        selectedPresetID = activePresetID
        if !extendedSizes, size > CursorController.standardMaxSize { extendedSizes = true }
        loadAppRules()
        observeRunningApps()
    }

    /// A store showing `preset` as the current pointer, for rendering screenshots.
    init(snapshotOf preset: Preset, presets: [Preset] = [], rules: [AppRule] = []) {
        size = preset.size
        fill = preset.fill
        outline = preset.outline
        customPresets = presets
        appRules = rules
        selectedPresetID = preset.id
        hasFullDiskAccess = true
        isSnapshot = true
    }

    var allPresets: [Preset] { Preset.builtIns + customPresets }

    var activePresetID: UUID? {
        allPresets.first { $0.matches(size: size, fill: fill, outline: outline) }?.id
    }

    var editingPreset: Preset? { customPresets.first { $0.id == editingPresetID } }

    /// Re-reads system state, e.g. after the user changed it in System Settings.
    func refresh() {
        guard !isSnapshot else { return }
        size = CursorController.size
        fill = CursorController.fill ?? fill
        outline = CursorController.outline ?? outline
        hasFullDiskAccess = CursorController.hasFullDiskAccess
        launchAtLogin = SMAppService.mainApp.status == .enabled
        shakeToLocate = CursorController.shakeToLocate
    }

    // MARK: Live adjustments

    func setSize(_ newSize: Double) {
        size = newSize
        syncEditingPreset()
        CursorController.setSize(newSize, persist: false)
        persistSizeWork?.cancel()
        let work = DispatchWorkItem {
            CursorController.setSize(newSize, persist: true)
            UserDefaults.standard.set(newSize, forKey: Self.sizeKey)
        }
        persistSizeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func setFill(_ color: RGBA) {
        fill = color
        syncEditingPreset()
        scheduleColorApply()
    }

    func setOutline(_ color: RGBA) {
        outline = color
        syncEditingPreset()
        scheduleColorApply()
    }

    /// Coalesces rapid color changes (e.g. dragging in the color panel).
    private func scheduleColorApply() {
        applyColorsWork?.cancel()
        let work = DispatchWorkItem { [fill, outline] in CursorController.setColors(fill: fill, outline: outline) }
        applyColorsWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    func apply(_ preset: Preset) {
        selectedPresetID = preset.id
        isApplyingPreset = true
        defer { isApplyingPreset = false }
        setSize(preset.size)
        fill = preset.fill
        outline = preset.outline
        applyColorsWork?.cancel()
        CursorController.setColors(fill: fill, outline: outline)
    }

    /// While a preset is being edited, every change to the pointer saves into it live.
    private func syncEditingPreset() {
        guard !isApplyingPreset, let index = customPresets.firstIndex(where: { $0.id == editingPresetID }) else { return }
        customPresets[index].size = size
        customPresets[index].fill = fill
        customPresets[index].outline = outline
        savePresets()
    }

    enum ColorTarget { case fill, outline }

    func openColorPanel(for target: ColorTarget) {
        colorPanel.show(initial: target == .fill ? fill : outline, title: target == .fill ? "Pointer Fill" : "Pointer Outline") { [weak self] color in
            target == .fill ? self?.setFill(color) : self?.setOutline(color)
        }
    }

    // MARK: Presets

    func saveNewPreset(named name: String) {
        let preset = Preset(name: name, size: size, fill: fill, outline: outline)
        customPresets.append(preset)
        selectedPresetID = preset.id
        savePresets()
    }

    /// A preset picked from the list. Picking a different one ends any edit in progress,
    /// so "Update" can't save another preset's look into the one being edited.
    func select(_ preset: Preset) {
        if editingPresetID != preset.id { editingPresetID = nil }
        apply(preset)
    }

    /// When a ruled app is in control but the pointer is on a different preset, the rule
    /// and that preset, so the menu can offer to pin it. Picking a preset never changes rules by itself.
    var pinSuggestion: (rule: AppRule, preset: Preset)? {
        guard appRulesEnabled, let bundleID = activeRuleBundleID,
              let rule = appRules.first(where: { $0.bundleID == bundleID }),
              let preset = allPresets.first(where: { $0.id == activePresetID }),
              rule.presetID != preset.id else { return nil }
        return (rule, preset)
    }

    func acceptPinSuggestion() {
        guard let suggestion = pinSuggestion else { return }
        setPreset(suggestion.preset.id, for: suggestion.rule)
        if let rule = appRules.first(where: { $0.id == suggestion.rule.id }) { flash(rule) }
    }

    /// The user's own preset picked last, when the pointer has since been changed away from it.
    var modifiedSelectedPreset: Preset? {
        guard let preset = customPresets.first(where: { $0.id == selectedPresetID }),
              !preset.matches(size: size, fill: fill, outline: outline) else { return nil }
        return preset
    }

    /// Saves the current pointer into the preset picked last.
    func updateSelectedPreset() {
        guard let index = customPresets.firstIndex(where: { $0.id == selectedPresetID }) else { return }
        customPresets[index].size = size
        customPresets[index].fill = fill
        customPresets[index].outline = outline
        savePresets()
    }

    func beginEditing(_ preset: Preset) {
        apply(preset)
        editingPresetID = preset.id
    }

    /// Finishes editing; size and colors were already saved live, so only the name remains.
    func commitEdit(name: String) {
        guard let index = customPresets.firstIndex(where: { $0.id == editingPresetID }) else { return }
        customPresets[index].name = name
        editingPresetID = nil
        savePresets()
    }

    /// What a delete removed, so it can be undone for a few seconds.
    struct DeletedPreset {
        let preset: Preset
        let index: Int
        let ruleIDs: [UUID]
    }
    @Published private(set) var recentlyDeleted: DeletedPreset?
    private var undoExpiry: DispatchWorkItem?

    func delete(_ preset: Preset) {
        guard let index = customPresets.firstIndex(where: { $0.id == preset.id }) else { return }
        let ruleIDs = appRules.filter { $0.presetID == preset.id }.map(\.id)
        customPresets.remove(at: index)
        if editingPresetID == preset.id { editingPresetID = nil }
        savePresets()
        if !ruleIDs.isEmpty {
            appRules = appRules.map { var r = $0; if r.presetID == preset.id { r.presetID = Self.defaultPresetID }; return r }
            saveAppRules()
        }
        recentlyDeleted = DeletedPreset(preset: preset, index: index, ruleIDs: ruleIDs)
        undoExpiry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recentlyDeleted = nil }
        undoExpiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    /// Puts the last deleted preset back where it was, with its app rules.
    func undoDelete() {
        guard let deleted = recentlyDeleted else { return }
        customPresets.insert(deleted.preset, at: min(deleted.index, customPresets.count))
        savePresets()
        if !deleted.ruleIDs.isEmpty {
            appRules = appRules.map { var r = $0; if deleted.ruleIDs.contains(r.id) { r.presetID = deleted.preset.id }; return r }
            saveAppRules()
        }
        recentlyDeleted = nil
        undoExpiry?.cancel()
    }

    /// One line for the top of the menu: which app (if any) chose the pointer, and which preset.
    var statusText: String {
        let presetName = allPresets.first { $0.id == activePresetID }?.name ?? "Custom"
        if appRulesEnabled, let id = activeRuleBundleID, let rule = appRules.first(where: { $0.bundleID == id }) {
            return "\(rule.appName) → \(presetName)"
        }
        return presetName
    }

    private func loadPresets() {
        guard let json = UserDefaults.standard.string(forKey: Self.presetsKey),
              let presets = try? JSONDecoder().decode([Preset].self, from: Data(json.utf8)) else { return }
        customPresets = presets
    }

    /// Stored as a JSON string so presets are readable with `defaults read`.
    private func savePresets() {
        guard let data = try? JSONEncoder().encode(customPresets) else { return }
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: Self.presetsKey)
    }

    // MARK: Size range

    var maxSize: Double { extendedSizes ? CursorController.extendedMaxSize : CursorController.standardMaxSize }

    func setExtendedSizes(_ on: Bool) {
        extendedSizes = on
        UserDefaults.standard.set(on, forKey: Self.extendedSizesKey)
        if !on, size > CursorController.standardMaxSize { setSize(CursorController.standardMaxSize) }
    }

    // MARK: App rules

    static let defaultPresetID = Preset.builtIns.first { $0.name == "Default" }!.id

    func setRuleTrigger(_ trigger: RuleTrigger) {
        ruleTrigger = trigger
        UserDefaults.standard.set(trigger.rawValue, forKey: Self.ruleTriggerKey)
        evaluateAppRules(force: true)
    }

    func setAppRulesEnabled(_ on: Bool) {
        appRulesEnabled = on
        UserDefaults.standard.set(on, forKey: Self.appRulesEnabledKey)
        if on { evaluateAppRules(force: true) } else { activeRuleBundleID = nil }
    }

    /// Asks for an app in /Applications and adds a rule for it.
    func addAppRule() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app"
        panel.prompt = "Add Rule"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        // One rule per app: picking an app that already has one points at that rule instead.
        if let existing = appRules.first(where: { $0.bundleID == bundleID }) {
            flash(existing)
            return
        }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        appRules.append(AppRule(bundleID: bundleID, appName: name, presetID: Self.defaultPresetID))
        saveAppRules()
        evaluateAppRules(force: true)
    }

    /// Briefly highlights a rule row, e.g. when its app was picked again.
    @Published private(set) var highlightedRuleID: UUID?

    private func flash(_ rule: AppRule) {
        highlightedRuleID = rule.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.highlightedRuleID == rule.id { self?.highlightedRuleID = nil }
        }
    }

    /// The apps pinned to a preset by rules.
    func ruleApps(for preset: Preset) -> [AppRule] { appRules.filter { $0.presetID == preset.id } }

    func setPreset(_ presetID: UUID, for rule: AppRule) {
        guard let index = appRules.firstIndex(where: { $0.id == rule.id }) else { return }
        appRules[index].presetID = presetID
        saveAppRules()
        evaluateAppRules(force: true)
    }

    func removeAppRule(_ rule: AppRule) {
        appRules.removeAll { $0.id == rule.id }
        saveAppRules()
        evaluateAppRules(force: true)
    }

    static func icon(forBundleID bundleID: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    private func loadAppRules() {
        guard let json = UserDefaults.standard.string(forKey: Self.appRulesKey),
              let rules = try? JSONDecoder().decode([AppRule].self, from: Data(json.utf8)) else { return }
        appRules = rules
    }

    private func saveAppRules() {
        guard let data = try? JSONEncoder().encode(appRules) else { return }
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: Self.appRulesKey)
    }

    private func observeRunningApps() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.evaluateAppRules() }
            })
        }
        evaluateAppRules() // a rule app may already be open
    }

    /// Picks the rule app per `ruleTrigger`; with no rule app left, back to Default.
    private func evaluateAppRules(force: Bool = false) {
        guard appRulesEnabled else { return }
        let ruled = Dictionary(appRules.map { ($0.bundleID, $0) }, uniquingKeysWith: { first, _ in first })
        let running = NSWorkspace.shared.runningApplications.filter { ruled[$0.bundleIdentifier ?? ""] != nil }
        let bundleID: String?
        switch ruleTrigger {
        case .lastOpened:
            bundleID = running.max { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }?.bundleIdentifier
        case .activeApp:
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if let front, ruled[front] != nil {
                bundleID = front
            } else if let current = activeRuleBundleID, running.contains(where: { $0.bundleIdentifier == current }) {
                bundleID = current // an app without a rule keeps the last ruled app's preset
            } else {
                bundleID = nil
            }
        }
        guard force || bundleID != activeRuleBundleID else { return }
        let hadRule = activeRuleBundleID != nil
        activeRuleBundleID = bundleID
        if let bundleID, let rule = ruled[bundleID] {
            if let preset = allPresets.first(where: { $0.id == rule.presetID }) ?? allPresets.first(where: { $0.id == Self.defaultPresetID }) {
                apply(preset)
            }
        } else if hadRule, let preset = allPresets.first(where: { $0.id == Self.defaultPresetID }) {
            apply(preset)
        }
    }

    // MARK: Shake to locate

    func setShakeToLocate(_ on: Bool) {
        CursorController.setShakeToLocate(on)
        shakeToLocate = CursorController.shakeToLocate
    }

    // MARK: Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("WheresMyMouse: launch at login change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// Drives the shared NSColorPanel. The menu window closes when the panel takes
/// focus, so the panel reports to this long-lived object rather than a view.
final class ColorPanelBridge: NSObject {
    private var onChange: ((RGBA) -> Void)?

    func show(initial: RGBA, title: String, onChange: @escaping (RGBA) -> Void) {
        self.onChange = nil
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.title = title
        panel.color = initial.nsColor
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        self.onChange = onChange
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard let color = RGBA(nsColor: sender.color) else { return }
        onChange?(color)
    }
}
