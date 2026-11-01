#if canImport(os)
import os
#else
import Glibc
#endif

/// Kleiner Lock mit stabiler Adresse: `os_unfair_lock` auf Apple, `pthread_mutex` auf Linux.
/// Der Audio-Thread nutzt nur `tryLock()`, blockiert also nie.
final class UnfairLock: @unchecked Sendable {
    #if canImport(os)
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
    #else
    private let pointer: UnsafeMutablePointer<pthread_mutex_t>

    init() {
        pointer = .allocate(capacity: 1)
        pointer.initialize(to: pthread_mutex_t())
        pthread_mutex_init(pointer, nil)
    }

    deinit {
        pthread_mutex_destroy(pointer)
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }

    func lock() { pthread_mutex_lock(pointer) }
    func unlock() { pthread_mutex_unlock(pointer) }
    func tryLock() -> Bool { pthread_mutex_trylock(pointer) == 0 }
    #endif

    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
