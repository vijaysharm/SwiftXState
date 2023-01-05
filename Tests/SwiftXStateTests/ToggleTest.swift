
import Foundation

import XCTest
@testable import SwiftXState

final class ToggleTest: XCTestCase {
    enum StateId: StateType {
        case inactive
        case active
    }

    enum Event: EventType {
        case `init`
        case toggle
    }

    struct DataType: ContextType {}
    
    private let inactive = State<StateId, Event, DataType>(
        id: .inactive,
        on: [
            .toggle: [Transition(target: .active)],
        ]
    )

    private let active = State<StateId, Event, DataType>(
        id: .active,
        on: [
            .toggle: [Transition(target: .inactive)],
        ]
    )
    
    private var service: Service<StateId, Event, DataType>!
    
    override func setUp() {
        let machine = Machine<StateId, Event, DataType>(
            initial: inactive,
            states: [inactive, active]
        )
    
        service = Service<StateId, Event, DataType>(machine: machine)
    }

    func testToggle() {
        XCTAssertEqual(inactive.id, service.state.id)
        
        service.start(event: .`init`)
        XCTAssertEqual(inactive.id, service.state.id)
        
        service.send(event: .toggle)
        XCTAssertEqual(active.id, service.state.id)
      
        service.send(event: .toggle)
        XCTAssertEqual(inactive.id, service.state.id)
        
        service.send(event: .toggle)
        XCTAssertEqual(active.id, service.state.id)
    }
}
