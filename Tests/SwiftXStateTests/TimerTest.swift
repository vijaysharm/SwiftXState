import Foundation
import XCTest
@testable import SwiftXState

final class TimerTest: XCTestCase {
    class DataType: ContextType {
        public var t = 0
        public var timer: Timer? = nil
    }

    enum TimerStates: StateType {
        case idle
        case running
        case paused
    }

    enum TimerEvents: EventType {
        case `init`
        case start
        case pause
        case reset
    }
    
    private var service: Service<TimerStates, TimerEvents, DataType>!
    private var data: DataType!
    
    override func setUp() {
        data = DataType()
        service = Service<TimerStates, TimerEvents, DataType>(
            initial: .idle,
            states: [
                State(
                    id: .idle,
                    on: [.start: [Transition(target: .running)]],
                    enter: [Action() { _, context in
                        guard let context = context else { return }
                        context.t = 0
                        context.timer?.invalidate()
                        context.timer = nil
                    }]
                ),
                State(
                    id: .running,
                    on: [.pause: [Transition(target: .paused)]],
                    enter: [Action() { _, context in
                        guard let context = context else { return }
                        context.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                            context.t += 1
                        }
                    }]
                ),
                State(
                    id: .paused,
                    on: [
                        .reset: [Transition(target: .idle)],
                        .start: [Transition(target: .running)]
                    ],
                    enter: [Action() { _, context in
                        guard let context = context else { return }
                        context.timer?.invalidate()
                        context.timer = nil
                    }]
                )
            ],
            context: data
        )
    }
    
    func testTimer() {
        XCTAssertEqual(.idle, service.state.id)
        
        service.start(event: .`init`)
        XCTAssertEqual(.idle, service.state.id)
        
        service.send(event: .start)
        XCTAssertEqual(.running, service.state.id)
        
        _ = XCTWaiter.wait(for: [expectation(description: "Wait for n seconds")], timeout: 2.0)
        XCTAssertNotEqual(0, data.t)
        
        service.send(event: .pause)
        XCTAssertEqual(.paused, service.state.id)
    }
}
