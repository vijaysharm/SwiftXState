import Foundation

import XCTest
@testable import SwiftXState

final class LightSwitchTest: XCTestCase {
    enum States: StateType {
        case green
        case yellow
        case red
    }

    enum Event: EventType {
        case `init`
        case timer
    }

    struct DataType: ContextType {}
    
    private let green = State<States, Event, DataType>(
        id: .green,
        on: [
            .timer: [Transition(target: .yellow)],
        ]
    )

    private let yellow = State<States, Event, DataType>(
        id: .yellow,
        on: [
            .timer: [Transition(target: .red)],
        ]
    )

    private let red = State<States, Event, DataType>(
        id: .red,
        on: [
            .timer: [Transition(target: .green)],
        ]
    )
    
    private var service: Service<States, Event, DataType>!
    
    override func setUp() {
        let machine = Machine<States, Event, DataType>(
            initial: green,
            states: [green, yellow, red]
        )

        service = Service<States, Event, DataType>(machine: machine)
    }
    
    func testLightSwitch() {
        XCTAssertEqual(green.id, service.state.id)
        
        service.start(event: .`init`)
        XCTAssertEqual(green.id, service.state.id)
        
        service.send(event: .timer)
        XCTAssertEqual(yellow.id, service.state.id)
        
        service.send(event: .timer)
        XCTAssertEqual(red.id, service.state.id)
        
        service.send(event: .timer)
        XCTAssertEqual(green.id, service.state.id)
    }
}
