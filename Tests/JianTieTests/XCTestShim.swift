import Foundation

#if !canImport(XCTest)
@MainActor
open class XCTestCase {
    private var pendingExpectations: [XCTestExpectation] = []

    public init() {}
    open func setUpWithError() throws {}
    open func tearDownWithError() throws {}
    open func setUp() {}
    open func tearDown() {}

    open func expectation(description: String) -> XCTestExpectation {
        let exp = XCTestExpectation(description: description)
        pendingExpectations.append(exp)
        return exp
    }

    open func waitForExpectations(timeout seconds: TimeInterval, handler: ((Error?) -> Void)? = nil) {
        wait(for: pendingExpectations, timeout: seconds)
        pendingExpectations.removeAll()
    }

    open func wait(for expectations: [XCTestExpectation], timeout seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if expectations.allSatisfy({ $0.fulfilled }) {
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        if !expectations.allSatisfy({ $0.fulfilled }) {
            fatalError("Expectations failed to fulfill within \(seconds) seconds")
        }
    }
}

public final class XCTestExpectation: @unchecked Sendable {
    public let description: String
    public var expectedFulfillmentCount: Int = 1
    private let lock = NSLock()
    private var fulfillmentCount = 0

    public init(description: String) {
        self.description = description
    }

    public func fulfill() {
        lock.lock()
        defer { lock.unlock() }
        fulfillmentCount += 1
    }

    public var fulfilled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fulfillmentCount >= expectedFulfillmentCount
    }
}

public func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if valA != valB {
            fatalError("XCTAssertEqual failed: \"\(valA)\" is not equal to \"\(valB)\" - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertEqual threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if valA == valB {
            fatalError("XCTAssertNotEqual failed: \"\(valA)\" is equal to \"\(valB)\" - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertNotEqual threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let result = try expression()
        if !result {
            fatalError("XCTAssertTrue failed - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertTrue threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let result = try expression()
        if result {
            fatalError("XCTAssertFalse failed - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertFalse threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val = try expression()
        if val != nil {
            fatalError("XCTAssertNil failed: expected nil but got \(String(describing: val)) - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertNil threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val = try expression()
        if val == nil {
            fatalError("XCTAssertNotNil failed: expected non-nil value - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertNotNil threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertGreaterThan<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if !(valA > valB) {
            fatalError("XCTAssertGreaterThan failed: \"\(valA)\" is not greater than \"\(valB)\" - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertGreaterThan threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertGreaterThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if !(valA >= valB) {
            fatalError("XCTAssertGreaterThanOrEqual failed: \"\(valA)\" is not >= \"\(valB)\" - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertGreaterThanOrEqual threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertLessThan<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if !(valA < valB) {
            fatalError("XCTAssertLessThan failed: \"\(valA)\" is not less than \"\(valB)\" - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertLessThan threw error: \(error) at \(file):\(line)")
    }
}

public func XCTAssertLessThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if !(valA <= valB) {
            fatalError("XCTAssertLessThanOrEqual failed: \"\(valA)\" is not <= \"\(valB)\" - \(message()) at \(file):\(line)")
        }
    } catch {
        fatalError("XCTAssertLessThanOrEqual threw error: \(error) at \(file):\(line)")
    }
}

public func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    fatalError("XCTFail: \(message) at \(file):\(line)")
}
#endif
