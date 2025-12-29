import SwiftUI
import AppKit
import Combine

private let welcomeMessages = [
    "Your first shot of inspiration is served.",
    "Freshly brewed text, just for you.",
    "Order's up: Your day starts here.",
    "Barista: Small text, big focus."
]

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var inputWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    @AppStorage("baristaText") private var baristaText: String = "" // Default doesn't matter, we seed in init
    
    override init() {
        super.init()
        
        // Seed if empty
        if UserDefaults.standard.string(forKey: "baristaText") == nil {
             UserDefaults.standard.set(welcomeMessages.randomElement()!, forKey: "baristaText")
        }
        
        setupStatusItem()
        setupInputWindow()
        
        // Observe text changes to update button title
        NotificationCenter.default.addObserver(self, selector: #selector(updateTitle), name: UserDefaults.didChangeNotification, object: nil)
        
        // Observe SourceManager for remote updates
        SourceManager.shared.$currentItem
            .map { $0?.text }
            .receive(on: RunLoop.main)
            .sink { [weak self] newText in
                if let text = newText {
                    self?.updateStatusItem(text: text)
                }
            }
            .store(in: &cancellables)
            
        updateTitle()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupInputWindow() {
        let inputView = BaristaView()
        
        let hostingController = NSHostingController(rootView: inputView)

        
        let window = BaristaWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingController.view
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.inputWindow = window
    }
    
    @objc private func updateTitle() {
        updateStatusItem(text: UserDefaults.standard.string(forKey: "baristaText"))
    }
    
    private var scrollingTimer: Timer?
    private var currentScrollText: String = ""
    private var scrollOffset: Int = 0
    private let maxDisplayLength = 100
    private var pauseTicks: Int = 10 // 2 seconds (0.2 * 10)
    private var currentPauseTick: Int = 0
    private var currentEndPauseTick: Int = 0
    
    private func updateStatusItem(text: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Stop previous scrolling
            self.stopScrolling()
            
            guard let text = text, !text.isEmpty else {
                self.statusItem.button?.title = ""
                return
            }
            
            if text.count > self.maxDisplayLength {
                self.currentScrollText = text
                self.startScrolling()
            } else {
                self.statusItem.button?.title = text
            }
        }
    }
    
    private func stopScrolling() {
        scrollingTimer?.invalidate()
        scrollingTimer = nil
        scrollOffset = 0
        currentPauseTick = 0
        currentEndPauseTick = 0
    }

    private func startScrolling() {
        updateScrollingTitle()
        currentPauseTick = 0
        currentEndPauseTick = 0
        
        scrollingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.scrollLogic()
        }
        // Ensure timer runs during menu tracking
        if let timer = scrollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func scrollLogic() {
        let maxOffset = currentScrollText.count - maxDisplayLength
        
        // 1. Pause at Start
        if scrollOffset == 0 {
            if currentPauseTick < pauseTicks {
                currentPauseTick += 1
                return
            }
        }
        
        // 2. Pause at End
        if scrollOffset == maxOffset {
             if currentEndPauseTick < pauseTicks {
                currentEndPauseTick += 1
                return
            }
            // End pause finished, reset to start
            scrollOffset = 0
            currentPauseTick = 0
            currentEndPauseTick = 0
            updateScrollingTitle()
            return
        }
        
        // 3. Scroll
        scrollOffset += 1
        updateScrollingTitle()
    }

    private func updateScrollingTitle() {
        // Safe slicing
        guard scrollOffset + maxDisplayLength <= currentScrollText.count else { return }
        
        let startIndex = currentScrollText.index(currentScrollText.startIndex, offsetBy: scrollOffset)
        let endIndex = currentScrollText.index(startIndex, offsetBy: maxDisplayLength)
        let visibleText = String(currentScrollText[startIndex..<endIndex])
        
        statusItem.button?.title = visibleText
    }
    
    private var eventMonitors: [Any] = []

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let window = inputWindow else { return }
        
        if window.isVisible {
            closeWindow()
        } else {
            showWindow(sender)
        }
    }
    
    private func showWindow(_ button: NSStatusBarButton) {
        SourceManager.shared.pauseTimer()
        guard let window = inputWindow else { return }
        
        if button.window?.frame != nil {
             let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
             let windowSize = window.frame.size
             
             let x = buttonRect.maxX - windowSize.width
             let y = buttonRect.minY - windowSize.height - 5
             
             window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        startEventMonitor()
    }
    
    private func closeWindow() {
        SourceManager.shared.resumeTimer()
        inputWindow?.orderOut(nil)
        stopEventMonitor()
    }
    
    private func startEventMonitor() {
        stopEventMonitor()
        
        // Monitor global events (outside app)
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            guard let self = self, let _ = self.inputWindow else { return }
            self.closeWindow()
        }) {
            eventMonitors.append(monitor)
        }
        
        // Monitor local events (inside app)
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            guard let self = self, let window = self.inputWindow else { return event }
            
            if event.window != window {
                self.closeWindow()
            }
            
            return event
        }) {
            eventMonitors.append(monitor)
        }
    }
    
    private func stopEventMonitor() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }
}
