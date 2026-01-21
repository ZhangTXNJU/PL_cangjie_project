package cjcj.memory_abstraction

import std.deriving.Derive

@Derive[Hashable, Equatable, ToString]
public struct ObjectID {
    public let id: UInt64

    // Default construct an illegal dummy ID
    public init() {
        id = 0
    }

    init(id: UInt64) {
        this.id = id
    }
}

sealed interface Memory {
    func allocate(object: Object, start: UInt64, size: UInt64): ObjectID

    func move(id: ObjectID, newStart: UInt64): Unit

    func deallocate(id: ObjectID): Unit

    // Vararg, can be called in the form of deallocateExcept(id1, id2, ...)
    // https://cangjie-lang.cn/docs?url=%2F1.0.4%2Fuser_manual%2Fsource_zh_cn%2Ffunction%2Ffunction_call_desugar.html
    func deallocateExcept(ids: Array<ObjectID>): Unit {
        let collection: Collection<ObjectID> = ids
        deallocateExcept(collection)
    }

    func deallocateExcept(ids: Collection<ObjectID>): Unit

    /*
     * Should be called when garbage collection begins
     */
    func onGCBegin(): Unit

    /*
     * Should be called after garbage collection ends
     */
    func onGCEnd(): Unit

    /*
     * Maximum addressable memory size
     * The address space is [0, maxAddress)
     * The program guarantees to use memory of at most maxAddress / 2 units
     */
    static prop maxAddress: UInt64
}

public let memory: Memory = MemoryImpl()
