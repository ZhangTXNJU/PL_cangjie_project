package cjcj.executor

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.scanner.Token
import cjcj.memory_abstraction.{ObjectID, memory}
import std.convert.*
import std.collection.{HashMap, HashSet, ArrayList}

class Lab1TodoException <: Exception {
    public init(message: String) {
        super("Lab 1 TODO: " + message)
    }
}

/** 
 * Evaluator Visitor
 *
 * Lab1 TODO: We have given the simplest form, each `Node` will return a `Value` after evaluation.
 * But is this sufficient? Do you need to add something new to handle ASTs that don't return a value?
 *
 * You may need to modify the member variables and/or generic parameters of the Evaluator class.
 */
public open class Evaluator <: Visitor<Value> {
    private let objectStore_: ObjectStore
    private let globalEnvironment_: HashMap<String, Value>

    public init() {
        objectStore_ = ObjectStore()
        globalEnvironment_ = HashMap<String, Value>()
    }

    public override func visit(program: Program): Value {
        // Execute all declarations
        for (decl in program.decls) {
            decl.traverse(this)
        }
        // Return unit value
        Value.from(())
    }

    // This is just an example of how to implement the visit method for BinaryExpr.
    // You may need to modify, split, or completely rewrite it depending on your design.
    public override func visit(expr: BinaryExpr): Value {
        let left = expr.left.traverse(this)
        let right = expr.right.traverse(this)
        try {
            match (expr.oper.kind) {
                case TokenKind.ADD => match ((left, right)) {
                    case (VInteger(a), VInteger(b)) => Value.from(a + b)
                    case (VString(a), VString(b)) => Value.from(a + b)
                    case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.ADD_TYPE_MISMATCH,
                        "cannot add left = ${left}, right = ${right}", expr)
                }
                case TokenKind.SUB => match ((left, right)) {
                    case (VInteger(a), VInteger(b)) => Value.from(a - b)
                    case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.SUB_TYPE_MISMATCH,
                        "cannot subtract left = ${left}, right = ${right}", expr)
                }
                case TokenKind.MUL => match ((left, right)) {
                    case (VInteger(a), VInteger(b)) => Value.from(a * b)
                    case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.MUL_TYPE_MISMATCH,
                        "cannot multiply left = ${left}, right = ${right}", expr)
                }
                case TokenKind.DIV => match ((left, right)) {
                    case (VInteger(a), VInteger(b)) =>
                        if (b == 0) {
                            throw CjcjRuntimeErrorWithLocation(ErrorCode.DIV_BY_ZERO,
                                "division by zero", expr)
                        } else {
                            Value.from(a / b)
                        }
                    case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.DIV_TYPE_MISMATCH,
                        "cannot divide left = ${left}, right = ${right}", expr)
                }
                case TokenKind.EXP => match ((left, right)) {
                    case (VInteger(a), VInteger(b)) =>
                        if (b < 0) {
                            throw CjcjRuntimeErrorWithLocation(ErrorCode.EXP_NEGATIVE_POWER,
                                "negative exponent not supported", expr)
                        } else {
                            var result: Int64 = 1
                            for (i in 0..b) {
                                result *= a
                            }
                            Value.from(result)
                        }
                    case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.EXP_TYPE_MISMATCH,
                        "cannot exponentiate left = ${left}, right = ${right}", expr)
                }
                case _ => throw Lab1TodoException("Unimplemented Binary Operator `${expr.oper.kind}`")
            }
        } catch (e: OverflowException) {
            match (e.message) {
                case "add" => throw CjcjRuntimeErrorWithLocation(ErrorCode.ADD_OVERFLOW,
                    "overflow add: left = ${left}, right = ${right}", expr)
                case _ => throw Lab1TodoException("You need to handle overflow of ${e.message}")
            }
        }
    }

    public override func visit(expr: UnaryExpr): Value {
        let right = expr.right.traverse(this)

        match (expr.oper.kind) {
            case TokenKind.SUB => match (right) {
                case VInteger(i) => Value.from(-i)
                case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.NEG_TYPE_MISMATCH,
                    "Cannot negate non-integer value", expr)
            }
            case TokenKind.NOT => match (right) {
                case VBoolean(b) => Value.from(!b)
                case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.NOT_TYPE_MISMATCH,
                    "Cannot apply '!' to non-boolean value", expr)
            }
            case _ => throw Lab1TodoException("Unsupported unary operator: ${expr.oper.kind}")
        }
    }

    public override func visit(par: ParenExpr): Value {
        return par.parenthesizedExpr.traverse(this)
    }

    public override func visit(lit: LitConstExpr): Value {
        match (lit.literal.kind) {
            case TokenKind.INTEGER_LITERAL => Value.from(Int64.parse(lit.literal.value))
            case TokenKind.STRING_LITERAL =>
                // Remove quotes from string literal
                let strVal = lit.literal.value
                let content = strVal[1..strVal.size - 1]
                Value.from(content)
            case TokenKind.BOOL_LITERAL =>
                match (lit.literal.value) {
                    case "true" => Value.from(true)
                    case "false" => Value.from(false)
                    case _ => throw Lab1TodoException("Invalid boolean literal")
                }
            case TokenKind.UNIT_LITERAL => Value.from(())
            case _ => throw Lab1TodoException("Unsupported literal type: ${lit.literal.kind}")
        }
    }

    public override func visit(expr: AssignExpr): Value {
        // Evaluate the right-hand side
        let value = expr.right.traverse(this)

        // The left side should be a reference expression
        if (expr.left is RefExpr) {
            let refExpr = (expr.left as RefExpr).getOrThrow()
            let varName = refExpr.identifier.value

            // Store in global environment
            globalEnvironment_[varName] = value
            return value
            return value
        } else {
            throw CjcjRuntimeErrorWithLocation(ErrorCode.ASSIGN_TYPE_MISMATCH,
                "Left side of assignment must be a variable reference", expr)
        }
    }

    public override func visit(ref: RefExpr): Value {
        let varName = ref.identifier.value

        // Look up in global environment
        match (globalEnvironment_.get(varName)) {
            case Some(value) => return value
            case None => throw CjcjRuntimeErrorWithLocation(ErrorCode.UNDEFINED_VAR,
                "Undefined variable: ${varName}", ref)
        }
    }

    public override func visit(block: Block): Value {
        var ret = Value.VUnit
        for (stmt in block.nodes.iterator()) {
            ret = stmt.traverse(this)
        }
        return ret
    }

    public override func visit(expr: IfExpr): Value {
        let condition = expr.condition.traverse(this)

        match (condition) {
            case VBoolean(true) => return expr.ifBlock.traverse(this)
            case VBoolean(false) => return expr.elseBranch.traverse(this)
            case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.IF_TYPE_MISMATCH,
                "If condition must be boolean", expr)
        }
    }

    public override func visit(expr: WhileExpr): Value {
        var result = Value.from(())

        while (true) {
            let condition = expr.condition.traverse(this)
            match (condition) {
                case VBoolean(true) => result = expr.block.traverse(this)
                case VBoolean(false) => break
                case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.WHILE_TYPE_MISMATCH,
                    "While condition must be boolean", expr)
            }
        }

        return result
    }

    public override func visit(call: CallExpr): Value {
        // Check if it's a built-in function call
        if (call.callee is RefExpr) {
            let refExpr = (call.callee as RefExpr).getOrThrow()
            let funcName = refExpr.identifier.value

            if (funcName == "gc") {
                // Built-in gc() function
                performGarbageCollection()
                return Value.from(())
            } else if (funcName == "refEq") {
                // Built-in refEq() function
                if (call.arguments.size != 2) {
                    throw CjcjRuntimeErrorWithLocation(ErrorCode.CALL_ARG_COUNT_MISMATCH,
                        "refEq expects 2 arguments", call)
                }
                let arg1 = call.arguments[0].expr.traverse(this)
                let arg2 = call.arguments[1].expr.traverse(this)

                match ((arg1, arg2)) {
                    case (VObject(id1), VObject(id2)) => return Value.from(id1 == id2)
                    case _ => return Value.from(false)
                }
            } else if (funcName == "panic") {
                // Built-in panic() function
                if (call.arguments.size != 1) {
                    throw CjcjRuntimeErrorWithLocation(ErrorCode.CALL_ARG_COUNT_MISMATCH,
                        "panic expects 1 argument", call)
                }
                let arg = call.arguments[0].expr.traverse(this)
                match (arg) {
                    case VString(msg) => throw CjcjRuntimeErrorWithLocation(ErrorCode.CALL_ARG_TYPE_MISMATCH, msg, call)
                    case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.CALL_ARG_TYPE_MISMATCH, "panic", call)
                }
            } else {
                // Check if it's a constructor call (class name)
                let objectId = createObject(funcName)
                return Value.from(objectId)
            }
        } else {
            throw CjcjRuntimeErrorWithLocation(ErrorCode.CALLEE_NOT_FUNCTION,
                "Cannot call non-function value", call)
        }
    }

    public override func visit(_: ReturnExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Return Expression")
    }

    public override func visit(jmp: JumpExpr): Value {
        throw Lab1TodoException("Jump Expression Evaluation Not Implemented")
    }

    public override func visit(decl: VarDecl): Value {
        let varName = decl.identifier.value

        // Evaluate initializer if present
        var value = Value.from(())
        match (decl.initializer) {
            case Some(initExpr) => value = initExpr.traverse(this)
            case None => value = value
        }

        // Store in global environment
        globalEnvironment_[varName] = value

        return value
    }

    public override func visit(_: FuncParam): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Paramters")
    }

    public override func visit(_: FuncDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Declaration")
    }

    public override func visit(mainDecl: MainDecl): Value {
        return mainDecl.block.traverse(this)
    }

    public override func visit(classDecl: ClassDecl): Value {
        // Class declarations are processed at compile time, just return unit
        return Value.from(())
    }

    public override func visit(body: Body): Value {
        var result = Value.from(())
        for (node in body.decls) {
            result = node.traverse(this)
        }
        return result
    }

    public override func visit(arg: Argument): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Argument")
    }

    public override func visit(_: TypeNode): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Type Node")
    }

    public override func visit(_: PrimitiveType): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Primitive Types")
    }

    public override func visit(_: RefType): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Reference Type")
    }

    public override func visit(_: VariableReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Variable Reference (ASG)")
    }

    public override func visit(_: FuncReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Reference (ASG)")
    }

    public override func visit(_: ClassReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Class Reference (ASG)")
    }

    public override func visit(_: VarDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Variable Declaration with" + "References Stored (ASG)")
    }

    public override func visit(_: FuncDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Function Declaration with" + "References Stored (ASG)")
    }

    public override func visit(_: MainDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Main Declaration with" + "References Stored (ASG)")
    }

    public override func visit(_: ClassDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Class Declaration with" + "References Stored (ASG)")
    }

    public override func visit(memberAccess: MemberAccess): Value {
        // Evaluate the base object
        let baseValue = memberAccess.baseExpr.traverse(this)

        match (baseValue) {
            case VObject(objId) =>
                // Access member of object
                match (objectStore_.getObject(objId)) {
                    case Some(obj) =>
                        let memberName = memberAccess.field.value
                        match (obj.getField(memberName)) {
                            case Some(fieldValue) => fieldValue
                            case None => throw CjcjRuntimeErrorWithLocation(ErrorCode.UNDEFINED_VAR,
                                "Undefined field: ${memberName}", memberAccess)
                        }
                    case None => throw CjcjRuntimeErrorWithLocation(ErrorCode.UNDEFINED_VAR,
                        "Object not found", memberAccess)
                }
            case _ => throw CjcjRuntimeErrorWithLocation(ErrorCode.UNDEFINED_VAR,
                "Cannot access member of non-object value", memberAccess)
        }
    }

    public override func visit(_: PrimitiveTypeExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Primitive type expression")
    }

    public override func visit(_: RefExprWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Reference expression with reference")
    }

    public override func visit(_: ThisSuperExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : This Super expression")
    }

    public override func visit(_: ThisSuperReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : This Super reference")
    }

    public override func visit(_: CallExprWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Call expression with reference")
    }

    public override func visit(_: MemberAccessWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Member access with reference")
    }

    public override func visit(_: InterfaceDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Declaration")
    }

    public override func visit(_: InterfaceDeclWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Declaration with reference")
    }

    public override func visit(_: InterfaceReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Reference")
    }

    private func createObject(className: String): ObjectID {
        // For now, create a simple object with no fields
        // In a full implementation, we would look up the class declaration
        // and allocate memory for all fields
        let objectId = memory.allocate(Object(), 0, 0)
        let instance = ObjectInstance(objectId, None) // Simplified for now
        objectStore_.createObject(objectId, instance)
        return objectId
    }

    private func performGarbageCollection(): Unit {
        // Simple mark-and-sweep garbage collection
        memory.onGCBegin()

        // Mark phase: mark all reachable objects
        let marked = HashSet<ObjectID>()

        // Mark objects in global environment
        for (value in globalEnvironment_.values()) {
            markObject(value, marked)
        }

        // Sweep phase: collect unmarked objects
        let allObjects = objectStore_.allObjects
        let toRemove = ArrayList<ObjectID>()

        for (objId in allObjects.keys()) {
            if (!marked.contains(objId)) {
                toRemove.add(objId)
            }
        }

        // Remove unreachable objects
        for (objId in toRemove) {
            objectStore_.removeObject(objId)
            memory.deallocate(objId)
        }

        memory.onGCEnd()
    }

    private func markObject(value: Value, marked: HashSet<ObjectID>): Unit {
        match (value) {
            case VObject(objId) =>
                if (!marked.contains(objId)) {
                    marked.add(objId)
                    // Mark all objects referenced by this object's fields
                    match (objectStore_.getObject(objId)) {
                        case Some(obj) =>
                            for (fieldValue in obj.fields.values()) {
                                markObject(fieldValue, marked)
                            }
                        case None => ()
                    }
                }
            case _ =>
                // Other values don't contain object references
                ()
        }
    }
}
