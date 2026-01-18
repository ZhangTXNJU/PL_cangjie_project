package cjcj.executor

import cjcj.memory_abstraction.ObjectID
import cjcj.visitor.{TypeNode, ClassDecl}
import std.collection.HashMap

/**
 * Represents a runtime object instance
 */
public class ObjectInstance {
    private let objectId_: ObjectID
    private let classDecl_: ClassDecl
    private let fields_: HashMap<String, Value>

    public init(objectId: ObjectID, classDecl: ClassDecl) {
        objectId_ = objectId
        classDecl_ = classDecl
        fields_ = HashMap<String, Value>()
    }

    public prop objectId: ObjectID {
        get() {
            objectId_
        }
    }

    public prop classDecl: ClassDecl {
        get() {
            classDecl_
        }
    }

    public func getField(name: String): ?Value {
        fields_.get(name)
    }

    public func setField(name: String, value: Value): Unit {
        fields_.put(name, value)
    }

    public func hasField(name: String): Bool {
        fields_.containsKey(name)
    }

    public prop fields: HashMap<String, Value> {
        get() {
            fields_
        }
    }
}