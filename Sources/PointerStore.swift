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
    /// The custom preset being edited, if any.
    @Published var editingPresetID: UUID?
    /// Presets shown in the Touch Bar, in the order they were added.
    @Published private(set) var touchBarPresetIDs: [UUID] = []

    private static let presetsKey = "customPresets"
    private static let touchBarKey = "touchBarPresetIDs"
    private static let sizeKey = "size"
    private var persistSizeWork: DispatchWorkItem?
    private var applyColorsWork: DispatchWorkItem?
    private let colorPanel = ColorPanelBridge()
    private var touchBar: TouchBarController!
    private var lastTouchBarActiveID: UUID?

    init() {
        // The system only keeps up to 4×, so restore a larger size ourselves.
        let systemSize = CursorController.size
        let savedSize = UserDefaults.standard.double(forKey: Self.sizeKey)
        if savedSize > CursorController.systemMaxSize, systemSize >= CursorController.systemMaxSize - 0.01 {
            CursorController.setSize(savedSize, persist: false)
            size = savedSize
        } else {
            size = systemSize
        }
        fill = CursorController.fill ?? .black
        outline = CursorController.outline ?? .white
        loadPresets()
        touchBarPresetIDs = (UserDefaults.standard.stringArray(forKey: Self.touchBarKey) ?? []).compactMap(UUID.init)
        touchBar = TouchBarController { [weak self] preset in self?.apply(preset) }
        updateTouchBar()
    }

    var allPresets: [Preset] { Preset.builtIns + customPresets }

    var activePresetID: UUID? {
        allPresets.first { $0.matches(size: size, fill: fill, outline: outline) }?.id
    }

    var editingPreset: Preset? { customPresets.first { $0.id == editingPresetID } }

    /// Re-reads system state, e.g. after the user changed it in System Settings.
    func refresh() {
        size = CursorController.size
        fill = CursorController.fill ?? fill
        outline = CursorController.outline ?? outline
        hasFullDiskAccess = CursorController.hasFullDiskAccess
        launchAtLogin = SMAppService.mainApp.status == .enabled
        updateTouchBarIfActiveChanged()
    }

    // MARK: Live adjustments

    func setSize(_ newSize: Double) {
        size = newSize
        CursorController.setSize(newSize, persist: false)
        updateTouchBarIfActiveChanged()
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
        scheduleColorApply()
    }

    func setOutline(_ color: RGBA) {
        outline = color
        scheduleColorApply()
    }

    /// Coalesces rapid color changes (e.g. dragging in the color panel).
    private func scheduleColorApply() {
        applyColorsWork?.cancel()
        let work = DispatchWorkItem { [fill, outline] in CursorController.setColors(fill: fill, outline: outline) }
        applyColorsWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        updateTouchBarIfActiveChanged()
    }

    func apply(_ preset: Preset) {
        setSize(preset.size)
        fill = preset.fill
        outline = preset.outline
        applyColorsWork?.cancel()
        CursorController.setColors(fill: fill, outline: outline)
        updateTouchBarIfActiveChanged()
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
        savePresets()
    }

    func beginEditing(_ preset: Preset) {
        apply(preset)
        editingPresetID = preset.id
    }

    /// Saves the current pointer settings and the new name into the preset being edited.
    func commitEdit(name: String) {
        guard let index = customPresets.firstIndex(where: { $0.id == editingPresetID }) else { return }
        customPresets[index].name = name
        customPresets[index].size = size
        customPresets[index].fill = fill
        customPresets[index].outline = outline
        editingPresetID = nil
        savePresets()
        updateTouchBar()
    }

    func delete(_ preset: Preset) {
        customPresets.removeAll { $0.id == preset.id }
        if editingPresetID == preset.id { editingPresetID = nil }
        savePresets()
        if touchBarPresetIDs.contains(preset.id) { toggleTouchBar(preset) }
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

    // MARK: Touch Bar

    func isInTouchBar(_ preset: Preset) -> Bool { touchBarPresetIDs.contains(preset.id) }

    func toggleTouchBar(_ preset: Preset) {
        if let index = touchBarPresetIDs.firstIndex(of: preset.id) {
            touchBarPresetIDs.remove(at: index)
        } else {
            touchBarPresetIDs.append(preset.id)
        }
        UserDefaults.standard.set(touchBarPresetIDs.map(\.uuidString), forKey: Self.touchBarKey)
        updateTouchBar()
    }

    private func updateTouchBar() {
        let presets = touchBarPresetIDs.compactMap { id in allPresets.first { $0.id == id } }
        lastTouchBarActiveID = activePresetID
        touchBar.update(presets: presets, activeID: lastTouchBarActiveID)
    }

    /// Moves the Touch Bar checkmark only when the matching preset changes.
    private func updateTouchBarIfActiveChanged() {
        if activePresetID != lastTouchBarActiveID { updateTouchBar() }
    }

    // MARK: Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("BetterPointer: launch at login change failed: \(error)")
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
