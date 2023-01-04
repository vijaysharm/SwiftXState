
import Foundation

public protocol EventType: Hashable {}
public protocol StateType: Equatable {}
public protocol ContextType {}

public class Action<E: EventType, C: ContextType> {
    public var exec: (E, C?) -> Void {
        get {
            if let callback = self.callback {
                return callback
            } else {
                return self.main(event:context:)
            }
        }
    }
    
    public let queue: DispatchQueue?
    private let callback: ((E, C?) -> Void)?
    
    init(queue: DispatchQueue? = nil, _ callback: ((E, C?) -> Void)? = nil) {
        self.callback = callback
        self.queue = queue
    }
    
    private func main(event: E, context: C?) {}
}

public class Transition<S: StateType, E: EventType, C: ContextType> {
    public let target: S?
    public let actions: [Action<E, C>]
    public let condition: (E, C?) -> Bool
    
    init(
        target: S?,
        actions: [Action<E, C>] = [],
        condition: @escaping (E, C?) -> Bool = { _, _ in true }
    ) {
        self.target = target
        self.actions = actions
        self.condition = condition
    }
}

public class State<S: StateType, E: EventType, C: ContextType> {
    public let id: S
    public let on: [E: [Transition<S, E, C>]]
    public let enter: [Action<E, C>]
    public let exit: [Action<E, C>]
    
    init(
        id: S,
        on: [E: [Transition<S, E, C>]] = [:],
        enter: [Action<E, C>] = [],
        exit: [Action<E, C>] = []
    ) {
        self.id = id
        self.on = on
        self.enter = enter
        self.exit = exit
    }
    
    func can(transition event: E) -> Bool {
        return on.contains { $0.key == event }
    }
}

public struct TransitionResult<S: StateType, E: EventType, C: ContextType> {
    public let state: State<S, E, C>
    public let actions: [Action<E, C>]?
    public let context: C?
    public let changed: Bool
}

public final class Machine<S: StateType, E: EventType, C: ContextType> {
    public let initial: State<S, E, C>
    public let states: [State<S, E, C>]
    public let context: C?
    
    convenience init(
        initialType: S,
        states: [State<S, E, C>],
        context: C? = nil
    ) {
        let initial = states.first(where: { $0.id == initialType })
        self.init(initial: initial!, states: states, context: context)
    }
    
    init(
        initial: State<S, E, C>,
        states: [State<S, E, C>],
        context: C? = nil
    ) {
        self.initial = initial
        self.states = states
        self.context = context
    }
    
    func transition(
        currentState: State<S, E, C>,
        event: E
    ) -> TransitionResult<S, E, C> {
        guard let current = states.first(where: {$0.id == currentState.id}) else {
            print("State '\(currentState)' not found on machine")
            return unchanged(state: currentState)
        }
        
        guard let transitions = current.on[event] else {
            return unchanged(state: current)
        }
        
        let result = transitions
            .filter{ $0.condition(event, context) }
            .map{ (transition: Transition<S, E, C>) -> TransitionResult<S, E, C> in
                guard let target = transition.target == nil ? current.id : transition.target else {
                    return unchanged(state: current)
                }
                guard let next = states.first(where: {$0.id == target}) else {
                    return unchanged(state: current)
                }
                
                var actions: [Action<E, C>] = []
                actions.append(contentsOf: current.exit)
                actions.append(contentsOf: transition.actions)
                actions.append(contentsOf: next.enter)
                
                return TransitionResult<S, E, C>(
                    state: next,
                    actions: actions,
                    context: self.context,
                    changed: target != current.id
                )
            }
            .first
        
        guard let transition = result else {
            return unchanged(state: current)
        }
    
        return transition
    }
    
    private func unchanged(
        state: State<S, E, C>
    ) -> TransitionResult<S, E, C> {
        return TransitionResult(
            state: state,
            actions: nil,
            context: self.context,
            changed: false
        )
    }
}

public final class Service<S: StateType, E: EventType, C: ContextType> {
    private enum Status {
        case noStarted
        case running
        case stopped
    }
    
    private let machine: Machine<S, E, C>
    private var current: TransitionResult<S, E, C>
    private var listeners: [(TransitionResult<S, E, C>) -> Void] = []
    private var status: Status = .noStarted
    
    public var state: State<S, E, C> {
        get {
            return current.state
        }
    }
    
    convenience init(
        initial: S,
        states: [State<S, E, C>],
        context: C? = nil
    ) {
        let initial = states.first(where: { $0.id == initial })
        self.init(initial: initial!, states: states, context: context)
    }
    
    convenience init(
        initial: State<S, E, C>,
        states: [State<S, E, C>],
        context: C? = nil
    ) {
        self.init(machine: Machine<S, E, C>(initial: initial, states: states, context: context))
    }
    
    init(machine: Machine<S, E, C>) {
        self.machine = machine
        self.current = TransitionResult(
            state: machine.initial,
            actions: machine.initial.enter,
            context: machine.context,
            changed: false
        )
    }
    
    @discardableResult
    public func subscribe(_ listener: @escaping (TransitionResult<S, E, C>) -> Void) -> () -> Void {
        listeners.append(listener)
        let itemIndex = listeners.count - 1
        listener(current)
        
        return { [self] in
            if (itemIndex < listeners.count) {
                self.listeners.remove(at: itemIndex)
            }
        }
    }
    
    @discardableResult
    public func start(event: E) -> Service {
        status = .running
        current.actions?.forEach { action in
            guard let queue = action.queue else {
                action.exec(event, current.context)
                return
            }
            
            queue.async { [self] in
                action.exec(event, current.context)
            }
        }
        return self;
    }
    
    @discardableResult
    public func stop() -> Service {
        status = .stopped
        listeners.removeAll()
        return self;
    }
    
    public func send(event: E) {
        guard status == .running else {
            fatalError("Sending event without calling .start()")
        }
        
        current = machine.transition(currentState: current.state, event: event)
        
        var notified: [(TransitionResult<S, E, C>) -> Void] = []
        current.actions?.forEach{ action in
            guard let queue = action.queue else {
                action.exec(event, current.context)
                return
            }
            
            queue.async { [self] in
                action.exec(event, current.context)
            }
        }
        notified.append(contentsOf: listeners)
        notified.forEach{ $0(current) }
    }
}

