import AppKit

/// Watches the mouse for a quick side-to-side shake. Polls the pointer position, so it
/// needs no permissions and sees movement over every app.
final class ShakeDetector {
    private var timer: Timer?
    private var samples: [(time: TimeInterval, x: CGFloat)] = []
    private var lastShake: TimeInterval = 0
    private let onShake: () -> Void

    // A shake: at least 4 direction changes within 0.6s, each leg at least 30pt.
    private let window: TimeInterval = 0.6
    private let minReversals = 4
    private let minLeg: CGFloat = 30

    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        samples.removeAll()
    }

    private func sample() {
        let now = ProcessInfo.processInfo.systemUptime
        samples.append((now, NSEvent.mouseLocation.x))
        samples.removeAll { now - $0.time > window }
        guard samples.count > 4 else { return }

        // Collapse the path into legs between direction changes and count the long ones.
        var reversals = 0
        var legStart = samples[0].x
        var direction: CGFloat = 0
        for i in 1..<samples.count {
            let dx = samples[i].x - samples[i - 1].x
            guard abs(dx) > 0.5 else { continue }
            let d: CGFloat = dx > 0 ? 1 : -1
            if direction != 0, d != direction {
                if abs(samples[i - 1].x - legStart) >= minLeg { reversals += 1 }
                legStart = samples[i - 1].x
            }
            direction = d
        }
        if reversals >= minReversals {
            lastShake = now
            samples.removeAll()
            onShake()
        }
    }
}

/// Super shake: briefly grows the pointer to 3× its size (at least 10×, at most 30×),
/// holds while the shaking continues, then eases back. Never saves the boosted size.
final class SuperShake {
    private let detector: ShakeDetector
    private var animation: Timer?
    private var baseSize: Double = 1
    private var peak: Double = 1
    private var phaseStart: TimeInterval = 0
    private var holdUntil: TimeInterval = 0
    private(set) var isBoosting = false

    private let growTime = 0.12
    private let holdTime = 0.9
    private let shrinkTime = 0.4

    init(currentSize: @escaping () -> Double) {
        var boost: (() -> Void)?
        detector = ShakeDetector { boost?() }
        boost = { [weak self] in self?.boost(from: currentSize()) }
    }

    func setEnabled(_ on: Bool) {
        if on { detector.start() } else { detector.stop(); finish() }
    }

    private func boost(from size: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        if isBoosting {
            holdUntil = now + holdTime // still shaking: keep it big
            return
        }
        isBoosting = true
        baseSize = size
        peak = min(CursorController.extendedMaxSize, max(size * 3, 10))
        phaseStart = now
        holdUntil = now + growTime + holdTime
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(timer, forMode: .common)
        animation = timer
    }

    private func step() {
        let now = ProcessInfo.processInfo.systemUptime
        let size: Double
        if now < phaseStart + growTime {
            size = baseSize + (peak - baseSize) * ease((now - phaseStart) / growTime)
        } else if now < holdUntil {
            size = peak
        } else if now < holdUntil + shrinkTime {
            size = peak + (baseSize - peak) * ease((now - holdUntil) / shrinkTime)
        } else {
            finish()
            return
        }
        CursorController.setSize(size, persist: false)
    }

    /// Stops without restoring, e.g. when the user picks a new size mid-boost.
    func cancel() {
        animation?.invalidate()
        animation = nil
        isBoosting = false
    }

    private func finish() {
        animation?.invalidate()
        animation = nil
        if isBoosting { CursorController.setSize(baseSize, persist: false) }
        isBoosting = false
    }

    /// Smooth start and end (ease in-out cubic).
    private func ease(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
}
