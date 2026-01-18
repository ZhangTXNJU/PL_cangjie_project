package cjcj.memory_abstraction

import std.collection.{HashSet, HashMap, LinkedList, LinkedListNode}

class MemoryRecord <: ToString {
    MemoryRecord(let id: ObjectID, var start: UInt64, let size: UInt64, let obj: Object) {}

    prop end: UInt64 {
        get() {
            start + size
        }
    }

    public override func toString(): String {
        "object ${id.id}: [${start}, ${end})"
    }
}

class MemoryImpl <: Memory {
    public static redef prop maxAddress: UInt64 {
        get() {
            4096
        }
    }

    private let allocations: HashMap<ObjectID, LinkedListNode<MemoryRecord>> = HashMap()
    private let records: LinkedList<MemoryRecord> = LinkedList(
        [
            // Just pass whatever object here for the sentinels
            MemoryRecord(ObjectID(1), 0, 0, allocations),
            MemoryRecord(ObjectID(2), maxAddress, 0, allocations)
        ]
    )
    private var nextID: UInt64 = 10

    private func insertRecord(record: MemoryRecord): LinkedListNode<MemoryRecord> {
        var current = records.firstNode.getOrThrow()
        while (let Some(next) <- current.next) {
            if (record.start < next.value.start) {
                if (record.start < current.value.end) {
                    throw Exception("Memory overlap detected: ${record} is overlapping with ${current.value}")
                } else if (record.end > next.value.start) {
                    throw Exception("Memory overlap detected: ${record} is overlapping with ${next.value}")
                } else {
                    return records.addBefore(next, record)
                }
            }
            current = next
        }
        throw Exception("${record} exceeds max memory")
    }

    public override func allocate(object: Object, start: UInt64, size: UInt64): ObjectID {
        let id = ObjectID(nextID)
        nextID += 1
        let record = MemoryRecord(id, start, size, object)
        allocations.add(id, insertRecord(record))
        id
    }

    public override func move(id: ObjectID, newStart: UInt64): Unit {
        if (let Some(node) <- allocations.get(id)) {
            let record = records.remove(node)
            record.start = newStart
            insertRecord(record)
        } else {
            throw Exception("Object ${id.id} not found")
        }
    }

    public override func deallocate(id: ObjectID): Unit {
        if (let Some(entry) <- allocations.get(id)) {
            allocations.remove(id)
        } else {
            throw Exception("Object ${id.id} not found")
        }
    }

    public override func deallocateExcept(ids: Collection<ObjectID>): Unit {
        let retainedSet = HashSet(ids)
        for (entry in allocations.keys()) {
            if (!retainedSet.contains(entry)) {
                deallocate(entry)
            }
        }
    }

    public override func onGCBegin(): Unit {
        // No-op for this simple implementation
    }

    public override func onGCEnd(): Unit {
        // No-op for this simple implementation
    }
}
