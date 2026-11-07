// WheelFlipper: reverse scroll direction for mouse wheels only, leaving
// trackpad (and Magic Mouse) gestures untouched. Keep macOS "Natural
// scrolling" ON; this undoes it for discrete wheel events.

import AppKit
import ApplicationServices

// Trackpad and Magic Mouse scrolls carry a gesture phase or momentum phase.
// Classic mouse wheels (including "smooth scrolling" ones) carry neither.
func isMouseWheel(_ event: CGEvent) -> Bool {
    event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0
        && event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0
}

func reverse(_ event: CGEvent) {
    // Read everything first: setting the line delta makes macOS recompute
    // the point and fixed-point deltas, so those are written back after it.
    let d1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    let d2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
    let f1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
    let f2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
    let p1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    let p2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)

    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -d1)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -d2)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -f1)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -f2)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -p1)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -p2)
}

// The system-wide "Natural scrolling" switch (shared by trackpad and mouse).
// A missing key means the macOS default, which is on.
func naturalScrollingOn() -> Bool {
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    let value = CFPreferencesCopyAppValue("com.apple.swipescrolldirection" as CFString, kCFPreferencesAnyApplication)
    return value as? Bool ?? true
}

var eventTap: CFMachPort?
var tapSource: CFRunLoopSource?

// The single source of truth for whether wheel events get reversed. The tap
// is also disabled when this is false, but the callback checks it too so a
// late or re-enabled tap can never reverse while WheelFlipper is off.
var reversing = false

let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout:
        // macOS disables taps that stall; turn it back on if it should be on.
        // (.tapDisabledByUserInput is not re-enabled: that is macOS or this
        // app deliberately switching it off.)
        if reversing, let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
    case .scrollWheel where reversing && isMouseWheel(event):
        reverse(event)
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

func createTap() {
    let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: nil
    ) else {
        NSLog("WheelFlipper: failed to create event tap")
        return
    }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    eventTap = tap
    tapSource = source
}

// A tap created before Accessibility was revoked stays dead even after it is
// granted again, so it is thrown away and recreated.
func destroyTap() {
    if let source = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    if let tap = eventTap {
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
    }
    eventTap = nil
    tapSource = nil
}

// The SF Symbol with a diagonal slash through it, cut out of the symbol
// with a gap the way Apple's own ".slash" symbols are drawn.
func slashed(_ symbol: NSImage) -> NSImage {
    NSImage(size: symbol.size, flipped: false) { rect in
        symbol.draw(in: rect)
        let slash = NSBezierPath()
        slash.move(to: NSPoint(x: rect.minX + 1, y: rect.maxY - 1))
        slash.line(to: NSPoint(x: rect.maxX - 1, y: rect.minY + 1))
        slash.lineCapStyle = .round
        NSGraphicsContext.current?.compositingOperation = .clear
        slash.lineWidth = 4
        slash.stroke()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        slash.lineWidth = 1.5
        slash.stroke()
        return true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum State { case active, off, paused, noPermission }

    private let enabledKey = "enabled"
    private let gateKey = "onlyWithNaturalScrolling"
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Reverse Mouse Scrolling", action: #selector(toggleEnabled), keyEquivalent: "")
    private let gateItem = NSMenuItem(title: "Only When Natural Scrolling Is On", action: #selector(toggleGate), keyEquivalent: "")

    private var trusted = false
    private var natural = true

    private var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private var onlyWithNaturalScrolling: Bool {
        get { UserDefaults.standard.object(forKey: gateKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: gateKey) }
    }

    private var state: State {
        if !trusted || eventTap == nil { return .noPermission }
        if !enabled { return .off }
        if onlyWithNaturalScrolling && !natural { return .paused }
        return .active
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusLine.isEnabled = false
        for item in [permissionItem, toggleItem, gateItem] { item.target = self }

        let menu = NSMenu()
        menu.addItem(statusLine)
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(gateItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit WheelFlipper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)

        // System Settings announces Natural scrolling changes; the timer also
        // catches them, along with Accessibility being granted or revoked.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(poll),
            name: NSNotification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil)
        Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(poll), userInfo: nil, repeats: true)
        poll()
    }

    @objc private func poll() {
        let nowTrusted = AXIsProcessTrusted()
        let nowNatural = naturalScrollingOn()
        if nowTrusted != trusted {
            if nowTrusted { createTap() } else { reversing = false; destroyTap() }
        }
        guard nowTrusted != trusted || nowNatural != natural || statusItem.button?.image == nil else { return }
        trusted = nowTrusted
        natural = nowNatural
        apply()
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        apply()
    }

    @objc private func toggleGate() {
        onlyWithNaturalScrolling.toggle()
        apply()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func apply() {
        let current = state
        reversing = current == .active
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: reversing) }
        NSLog("WheelFlipper: %@", "\(current)")

        toggleItem.state = enabled ? .on : .off
        gateItem.state = onlyWithNaturalScrolling ? .on : .off
        permissionItem.isHidden = current != .noPermission

        let symbol = NSImage(systemSymbolName: current == .active ? "computermouse.fill" : "computermouse",
                             accessibilityDescription: "WheelFlipper")!
        let image = current == .noPermission ? slashed(symbol) : symbol
        image.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = current == .off

        let description: String
        switch current {
        case .active: description = "On: mouse scrolling reversed"
        case .off: description = "Off"
        case .paused: description = "Paused: Natural scrolling is off"
        case .noPermission: description = "Not working: Accessibility permission missing"
        }
        statusLine.title = description
        statusItem.button?.toolTip = "WheelFlipper — \(description)"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
