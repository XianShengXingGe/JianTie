import XCTest
@testable import JianTieCore

private final class MockDoubleTapMonitor: DoubleTapMonitoring, @unchecked Sendable {
    let modifier: ModifierKey
    var isMonitoring: Bool = false
    var triggerHandler: (@Sendable () -> Void)?
    var stopCallCount = 0

    init(modifier: ModifierKey) {
        self.modifier = modifier
    }

    func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        self.isMonitoring = true
        self.triggerHandler = onTrigger
    }

    func stopMonitoring() {
        self.isMonitoring = false
        self.triggerHandler = nil
        self.stopCallCount += 1
    }

    func simulateTrigger() {
        triggerHandler?()
    }
}

private final class MockCarbonHotKeyMonitor: CarbonHotKeyMonitoring, @unchecked Sendable {
    var isRegistered: Bool = false
    var registeredKeyCode: UInt32?
    var registeredModifiers: KeyModifiers?
    var triggerHandler: (@Sendable () -> Void)?
    var unregisterCallCount = 0

    func register(keyCode: UInt32, modifiers: KeyModifiers, onTrigger: @escaping @Sendable () -> Void) -> Bool {
        self.isRegistered = true
        self.registeredKeyCode = keyCode
        self.registeredModifiers = modifiers
        self.triggerHandler = onTrigger
        return true
    }

    func unregister() {
        self.isRegistered = false
        self.registeredKeyCode = nil
        self.registeredModifiers = nil
        self.triggerHandler = nil
        self.unregisterCallCount += 1
    }

    func simulateTrigger() {
        triggerHandler?()
    }
}

final class HotKeyServiceTests: XCTestCase {

    func test_startMonitoring_withDoubleTap_startsDoubleTapMonitor() {
        var createdDoubleTapMonitors: [MockDoubleTapMonitor] = []
        let mockCarbon = MockCarbonHotKeyMonitor()

        let service = HotKeyService(
            initialTrigger: .doubleTap(modifier: .option),
            doubleTapMonitorFactory: { modifier in
                let monitor = MockDoubleTapMonitor(modifier: modifier)
                createdDoubleTapMonitors.append(monitor)
                return monitor
            },
            carbonHotKeyMonitor: mockCarbon
        )

        var triggerCount = 0
        service.startMonitoring {
            triggerCount += 1
        }

        XCTAssertTrue(service.isMonitoring)
        XCTAssertEqual(createdDoubleTapMonitors.count, 1)
        XCTAssertEqual(createdDoubleTapMonitors.first?.modifier, .option)
        XCTAssertTrue(createdDoubleTapMonitors.first?.isMonitoring == true)
        XCTAssertFalse(mockCarbon.isRegistered)

        // 模拟触发
        createdDoubleTapMonitors.first?.simulateTrigger()
        XCTAssertEqual(triggerCount, 1)
    }

    func test_startMonitoring_withKeyCombination_startsCarbonHotKey() {
        let mockCarbon = MockCarbonHotKeyMonitor()

        let service = HotKeyService(
            initialTrigger: .keyCombination(keyCode: 9, modifiers: [.command, .shift]),
            doubleTapMonitorFactory: { MockDoubleTapMonitor(modifier: $0) },
            carbonHotKeyMonitor: mockCarbon
        )

        var triggerCount = 0
        service.startMonitoring {
            triggerCount += 1
        }

        XCTAssertTrue(service.isMonitoring)
        XCTAssertTrue(mockCarbon.isRegistered)
        XCTAssertEqual(mockCarbon.registeredKeyCode, 9)
        XCTAssertEqual(mockCarbon.registeredModifiers, [.command, .shift])

        // 模拟触发
        mockCarbon.simulateTrigger()
        XCTAssertEqual(triggerCount, 1)
    }

    func test_updateTrigger_whenMonitoring_hotReloadsTrigger() {
        var createdDoubleTapMonitors: [MockDoubleTapMonitor] = []
        let mockCarbon = MockCarbonHotKeyMonitor()

        let service = HotKeyService(
            initialTrigger: .doubleTap(modifier: .command),
            doubleTapMonitorFactory: { modifier in
                let monitor = MockDoubleTapMonitor(modifier: modifier)
                createdDoubleTapMonitors.append(monitor)
                return monitor
            },
            carbonHotKeyMonitor: mockCarbon
        )

        var triggerCount = 0
        service.startMonitoring {
            triggerCount += 1
        }

        let firstMonitor = createdDoubleTapMonitors.first!
        XCTAssertTrue(firstMonitor.isMonitoring)

        // 动态切换为常规快捷键 ⌥V
        service.updateTrigger(.keyCombination(keyCode: 9, modifiers: [.option]))

        XCTAssertEqual(service.currentTrigger, .keyCombination(keyCode: 9, modifiers: [.option]))
        XCTAssertFalse(firstMonitor.isMonitoring)
        XCTAssertEqual(firstMonitor.stopCallCount, 1)
        XCTAssertTrue(mockCarbon.isRegistered)
        XCTAssertEqual(mockCarbon.registeredKeyCode, 9)
        XCTAssertEqual(mockCarbon.registeredModifiers, [.option])

        // 触发新快捷键
        mockCarbon.simulateTrigger()
        XCTAssertEqual(triggerCount, 1)

        // 再次动态切换为双击 Shift
        service.updateTrigger(.doubleTap(modifier: .shift))

        XCTAssertEqual(service.currentTrigger, .doubleTap(modifier: .shift))
        XCTAssertFalse(mockCarbon.isRegistered)
        XCTAssertEqual(mockCarbon.unregisterCallCount, 1)
        XCTAssertEqual(createdDoubleTapMonitors.count, 2)
        let secondMonitor = createdDoubleTapMonitors[1]
        XCTAssertEqual(secondMonitor.modifier, .shift)
        XCTAssertTrue(secondMonitor.isMonitoring)

        // 触发双击 Shift
        secondMonitor.simulateTrigger()
        XCTAssertEqual(triggerCount, 2)
    }

    func test_updateTrigger_whenNotMonitoring_updatesCurrentTriggerOnly() {
        var createdDoubleTapMonitors: [MockDoubleTapMonitor] = []
        let mockCarbon = MockCarbonHotKeyMonitor()

        let service = HotKeyService(
            initialTrigger: .doubleTap(modifier: .command),
            doubleTapMonitorFactory: { modifier in
                let monitor = MockDoubleTapMonitor(modifier: modifier)
                createdDoubleTapMonitors.append(monitor)
                return monitor
            },
            carbonHotKeyMonitor: mockCarbon
        )

        XCTAssertFalse(service.isMonitoring)
        service.updateTrigger(.keyCombination(keyCode: 9, modifiers: [.option]))

        XCTAssertEqual(service.currentTrigger, .keyCombination(keyCode: 9, modifiers: [.option]))
        XCTAssertTrue(createdDoubleTapMonitors.isEmpty)
        XCTAssertFalse(mockCarbon.isRegistered)
    }

    func test_stopMonitoring_stopsActiveMonitors() {
        var createdDoubleTapMonitors: [MockDoubleTapMonitor] = []
        let mockCarbon = MockCarbonHotKeyMonitor()

        let service = HotKeyService(
            initialTrigger: .doubleTap(modifier: .command),
            doubleTapMonitorFactory: { modifier in
                let monitor = MockDoubleTapMonitor(modifier: modifier)
                createdDoubleTapMonitors.append(monitor)
                return monitor
            },
            carbonHotKeyMonitor: mockCarbon
        )

        service.startMonitoring {}
        XCTAssertTrue(service.isMonitoring)

        service.stopMonitoring()
        XCTAssertFalse(service.isMonitoring)
        XCTAssertFalse(createdDoubleTapMonitors.first?.isMonitoring == true)
    }
}
