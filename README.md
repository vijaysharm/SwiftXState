# SwiftXState

State machines for the modern swift development.

## Super quick start

```
enum StateId: StateType {
    case inactive
    case active
}

enum Event: EventType {
    case `init`
    case toggle
}

struct DataType: ContextType {}

let inactive = State<StateId, Event, DataType>(
    id: .inactive,
    on: [
        .toggle: [Transition(target: .active)],
    ]
)

let active = State<StateId, Event, DataType>(
    id: .active,
    on: [
        .toggle: [Transition(target: .inactive)],
    ]
)

service = Service<StateId, Event, DataType>(initial: inactive, states: [inactive, active])

service.start(event: .`init`)
XCTAssertEqual(.inactive, service.state.id)

service.send(event: .toggle)
XCTAssertEqual(.active, service.state.id)

service.send(event: .toggle)
XCTAssertEqual(.inactive, service.state.id)
```
