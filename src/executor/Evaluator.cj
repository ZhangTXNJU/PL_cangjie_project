package cjcj.executor

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.scanner.Token
import cjcj.memory_abstraction.{ObjectID, memory}
import std.convert.*
import std.collection.HashMap

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

    public open override func visit(program: Program): Value {
        // Execute all declarations
        for (decl in program.decls) {
            decl.traverse(this)
        }
        // Return unit value
        Value.from(())
    }

    // This is just an example of how to implement the visit method for BinaryExpr.
    // You may need to modify, split, or completely rewrite it depending on your design.
    public open override func visit(expr: BinaryExpr): Value {
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

    public open override func visit(expr: UnaryExpr): Value {
        throw Lab1TodoException("Unary Expression Evaluation Not Implemented")
    }

    public open override func visit(par: ParenExpr): Value {
        throw Lab1TodoException("Parenthesized Expression Evaluation Not Implemented")
    }

    public open override func visit(lit: LitConstExpr): Value {
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

    public open override func visit(expr: AssignExpr): Value {
        // Evaluate the right-hand side
        let value = expr.right.traverse(this)

        // The left side should be a reference expression
        if (expr.left is RefExpr) {
            let refExpr = (expr.left as RefExpr).getOrThrow()
            let varName = refExpr.identifier.value

            // Store in global environment
            globalEnvironment_[varName] = value
            return value
        } else {
            throw CjcjRuntimeErrorWithLocation(ErrorCode.INVALID_ASSIGNMENT,
                "Left side of assignment must be a variable reference", expr)
        }
    }

    public open override func visit(ref: RefExpr): Value {
        let varName = ref.identifier.value

        // Look up in global environment
        if (let Some(value) <- globalEnvironment_.get(varName)) {
            return value
        } else {
            throw CjcjRuntimeErrorWithLocation(ErrorCode.UNDEFINED_VAR,
                "Undefined variable: ${varName}", ref)
        }
    }

    public open override func visit(block: Block): Value {
        var ret = Value.VUnit
        for (stmt in block.nodes.iterator()) {
            ret = stmt.traverse(this)
        }
        return ret
    }

    public open override func visit(expr: IfExpr): Value {
        throw Lab1TodoException("If Expression Evaluation Not Implemented")
    }

    public open override func visit(expr: WhileExpr): Value {
        throw Lab1TodoException("While Expression Evaluation Not Implemented")
    }

    public open override func visit(call: CallExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Call Expression")
    }

    public open override func visit(_: ReturnExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Return Expression")
    }

    public open override func visit(jmp: JumpExpr): Value {
        throw Lab1TodoException("Jump Expression Evaluation Not Implemented")
    }

    public open override func visit(decl: VarDecl): Value {
        let varName = decl.identifier.value

        // Evaluate initializer if present
        var value = Value.from(())
        match (decl.initializer) {
            case Some(initExpr) => value = initExpr.traverse(this)
            case None => {}
        }

        // Store in global environment
        globalEnvironment_[varName] = value

        return value
    }

    public open override func visit(_: FuncParam): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Paramters")
    }

    public open override func visit(_: FuncDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Declaration")
    }

    public open override func visit(mainDecl: MainDecl): Value {
        return mainDecl.block.traverse(this)
    }

    public open override func visit(_: ClassDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Class Declaration")
    }

    public open override func visit(body: Body): Value {
        var result = Value.from(())
        for (node in body.decls) {
            result = node.traverse(this)
        }
        return result
    }

    public open override func visit(arg: Argument): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Argument")
    }

    public open override func visit(_: TypeNode): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Type Node")
    }

    public open override func visit(_: PrimitiveType): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Primitive Types")
    }

    public open override func visit(_: RefType): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Reference Type")
    }

    public open override func visit(_: VariableReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Variable Reference (ASG)")
    }

    public open override func visit(_: FuncReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Function Reference (ASG)")
    }

    public open override func visit(_: ClassReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Class Reference (ASG)")
    }

    public open override func visit(_: VarDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Variable Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: FuncDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Function Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: MainDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Main Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: ClassDeclWithRef): Value {
        throw UnsupportedException(
            "Unimplemented method for Visitor : Class Declaration with" + "References Stored (ASG)")
    }

    public open override func visit(_: MemberAccess): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Member Access")
    }

    public open override func visit(_: PrimitiveTypeExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Primitive type expression")
    }

    public open override func visit(_: RefExprWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Reference expression with reference")
    }

    public open override func visit(_: ThisSuperExpr): Value {
        throw UnsupportedException("Unimplemented method for Visitor : This Super expression")
    }

    public open override func visit(_: ThisSuperReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : This Super reference")
    }

    public open override func visit(_: CallExprWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Call expression with reference")
    }

    public open override func visit(_: MemberAccessWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Member access with reference")
    }

    public open override func visit(_: InterfaceDecl): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Declaration")
    }

    public open override func visit(_: InterfaceDeclWithRef): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Declaration with reference")
    }

    public open override func visit(_: InterfaceReference): Value {
        throw UnsupportedException("Unimplemented method for Visitor : Interface Reference")
    }
}
