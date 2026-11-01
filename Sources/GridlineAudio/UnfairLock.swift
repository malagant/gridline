import os

/// Dünner Wrapper um `os_unfair_lock` mit stabiler Adresse.
/// Der Audio-Thread nutzt nur `tryLock()`, blockiert also nie.
final class UnfairLock: @unchecked Sendable {
    private let pointer: UnsafeMutablePointer<os_unfair_lock>

    init() {
        pointer = .allocate(capacity: 1)
        pointer.initialize(to: os_unfair_lock())
    }

    deinit {
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }

    func lock() { os_unfair_lock_lock(pointer) }
    func unlock() { os_unfair_lock_unlock(pointer) }
    func tryLock() -> Bool { os_unfair_lock_trylock(pointer) }

    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
