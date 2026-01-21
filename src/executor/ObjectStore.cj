package cjcj.executor

import cjcj.memory_abstraction.ObjectID
import std.collection.HashMap

/**
 * Global object store that manages all object instances
 */
public class ObjectStore {
    private let objects_: HashMap<ObjectID, ObjectInstance>

    public init() {
        objects_ = HashMap<ObjectID, ObjectInstance>()
    }

    public func createObject(objectId: ObjectID, instance: ObjectInstance): Unit {
        objects_[objectId] = instance
    }

    public func getObject(objectId: ObjectID): ?ObjectInstance {
        objects_.get(objectId)
    }

    public func removeObject(objectId: ObjectID): Unit {
        objects_.remove(objectId)
    }

    public prop allObjects: HashMap<ObjectID, ObjectInstance> {
        get() {
            objects_
        }
    }

    public func clear(): Unit {
        objects_.clear()
    }
}