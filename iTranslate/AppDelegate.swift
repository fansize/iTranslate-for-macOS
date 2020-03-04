import Cocoa
import ServiceManagement
import KeyHolder
import Magnet
import GoogleReporter

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var lastChangeCount: Int = 0

    @IBOutlet weak var popover: NSPopover!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        showPopover(popover)
    
        GoogleReporter.shared.configure(withTrackerId: "UA-158042469-2")
        
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("statusIcon"))
            button.action = #selector(togglePopover)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { (t) in
            if self.lastChangeCount != self.pasteboard.changeCount {
                self.lastChangeCount = self.pasteboard.changeCount
                NotificationCenter.default.post(name: .NSPasteboardDidChange, object: self.pasteboard)
            }
        }
        
        // 设置快捷键
//        let recordView = RecordView()
//        recordView.tintColor = NSColor(red: 0.164, green: 0.517, blue: 0.823, alpha: 1)
//        let keyCombo = KeyCombo(doubledCocoaModifiers: .command)
//        recordView.keyCombo = keyCombo
//        recordView.delegate = self
//
//        let hotKey = HotKey(identifier: "KeyHolderExample", keyCombo: keyCombo!, target: self, action: #selector(AppDelegate.hotkeyCalled))
//        hotKey.register()

        
        // 新增开机启动代码
        let launcherAppId = "Tang.trans.LauncherTrans"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty

        SMLoginItemSetEnabled(launcherAppId as CFString, true)

        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        timer.invalidate()
    }
    
    // 设置快捷键
    @objc func hotkeyCalled() {
        print("HotKey called!!!!")
    }
    
    @objc func quitApp(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    @objc func showPopover(_ sender: AnyObject) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
        
    @objc func closePopover(_ sender: AnyObject) {
        popover.performClose(sender)
    }
        
    @objc func togglePopover(_ sender: AnyObject) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
}

extension NSNotification.Name {
    public static let NSPasteboardDidChange: NSNotification.Name = .init(rawValue: "pasteboardDidChangeNotification")
    // 向后台常驻程序传递信息，通知关闭后台程序
    static let killLauncher = Notification.Name("killLauncher")
}

extension NSTextField {
    open override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.isDisjoint(with: .command) {
            return super.performKeyEquivalent(with: event)
        }
        
        switch event.charactersIgnoringModifiers {
        case "a":
            return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: self.window?.firstResponder, from: self)
        case "c":
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: self.window?.firstResponder, from: self)
        case "v":
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: self.window?.firstResponder, from: self)
        case "x":
            return NSApp.sendAction(#selector(NSText.cut(_:)), to: self.window?.firstResponder, from: self)
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}



// MARK: - RecordView Delegate
extension AppDelegate: RecordViewDelegate {
    func recordViewShouldBeginRecording(_ recordView: RecordView) -> Bool {
        return true
    }

    func recordView(_ recordView: RecordView, canRecordKeyCombo keyCombo: KeyCombo) -> Bool {
        // You can customize validation
        return true
    }

    func recordViewDidClearShortcut(_ recordView: RecordView) {
        print("clear shortcut")
        HotKeyCenter.shared.unregisterHotKey(with: "KeyHolderExample")
    }

    func recordViewDidEndRecording(_ recordView: RecordView) {
        print("end recording")
    }

    func recordView(_ recordView: RecordView, didChangeKeyCombo keyCombo: KeyCombo) {
        HotKeyCenter.shared.unregisterHotKey(with: "KeyHolderExample")
        let hotKey = HotKey(identifier: "KeyHolderExample", keyCombo: keyCombo, target: self, action: #selector(AppDelegate.hotkeyCalled))
        hotKey.register()
    }
}
