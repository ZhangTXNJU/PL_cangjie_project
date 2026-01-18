package cjcj.visitor

import cjcj.prettyPrinter.{PrettyPrinter, YamlPrinter}
import cjcj.scanner.*
import std.ast.Position
import std.collection.ArrayList

/*
    TODO: Make this abstract and try to remove the default constructors of the nodes that maybe we
    can avoid.
 */
public open class TypeNode <: Node {
    private var typeParameterName_: Token = Token()
    private var typeName_: Token = Token()

    public init() {
        this(NodeId())
    }

    public init(id: NodeId) {
        super(id)
    }

    public init(id: NodeId, typeParameterName: Token, typeName: Token) {
        super(id)
        typeParameterName_ = typeParameterName
        typeName_ = typeName
    }

    public open override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public open override func prettyPrint(_: PrettyPrinter): Unit {
    }

    public open override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("typeParameterName", typeParameterName)
        printer.print("typeName", typeName)
    }

    public mut prop typeParameterName: Token {
        get() {
            typeParameterName_
        }
        set(v) {
            typeParameterName_ = v
        }
    }

    public mut prop typeName: Token {
        get() {
            typeName_
        }
        set(v) {
            typeName_ = v
        }
    }
}

public class PrimitiveType <: TypeNode {
    public init(id: NodeId, typeParameterName: Token, typeName: Token) {
        super(
            id,
            typeParameterName,
            if (isPrimitive(typeName)) {
                typeName
            } else {
                throw IllegalArgumentException("${typeName.value} is not a primitive type.")
            }
        )
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        super.prettyPrint(printer)
        printer.append(typeName.value)
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "PrimitiveType")
        super.yamlPrint(printer)
    }

    private func isPrimitive(typeName: Token): Bool {
        TokenKindHelper.CHAR_LANG_TYPES.iterator().any({t => t == typeName.kind})
    }
}

public class RefType <: TypeNode {
    private var typeArguments_: ArrayList<TypeNode>

    public init(id: NodeId, typeParameterName: Token, typeName: Token, typeArguments: ArrayList<TypeNode>) {
        super(id, typeParameterName, typeName)
        typeArguments_ = typeArguments
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        super.prettyPrint(printer)
        printer.append(typeName.value)
        if (typeArguments_.size > 0) {
            printer.append("<")
            typeArguments_[0].prettyPrint(printer)
            for (typeArg in typeArguments_.iterator().skip(1)) {
                printer.append(", ")
                typeArg.prettyPrint(printer)
            }
            printer.append(">")
        }
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "RefType")
        super.yamlPrint(printer)
        printer.printList("typeArguments", typeArguments_)
    }

    public mut prop typeArguments: ArrayList<TypeNode> {
        get() {
            typeArguments_
        }
        set(v) {
            typeArguments_ = v
        }
    }
}

public class FuncType <: TypeNode {
    static let ARROW_TOKEN = Token(TokenKind.ARROW, "->", Position())

    private var paramTypes_: ArrayList<TypeNode>
    private var returnType_: TypeNode

    public init(id: NodeId, typeParameterName: ?Token, paramTypes: ArrayList<TypeNode>, returnType: TypeNode) {
        super(id, typeParameterName.getOrDefault({=> ARROW_TOKEN}), ARROW_TOKEN)
        paramTypes_ = paramTypes
        returnType_ = returnType
    }

    public mut prop paramTypes: ArrayList<TypeNode> {
        get() {
            paramTypes_
        }
        set(v) {
            paramTypes_ = v
        }
    }

    public mut prop returnType: TypeNode {
        get() {
            returnType_
        }
        set(v) {
            returnType_ = v
        }
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        super.prettyPrint(printer)
        printer.append("(")
        for ((i, paramType) in paramTypes_.iterator().enumerate()) {
            paramType.prettyPrint(printer)
            if (i < paramTypes_.size - 1) {
                printer.append(", ")
            }
        }
        printer.append(") -> ")
        returnType_.prettyPrint(printer)
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "FuncType")
        super.yamlPrint(printer)
        printer.printList("paramTypes", paramTypes_)
        printer.printObject("returnType", returnType_)
    }
}

public class TupleType <: TypeNode {
    static let TUPLE_TOKEN = Token(TokenKind.UNIT_LITERAL, "()", Position())

    private var elementTypes_: ArrayList<TypeNode>

    public init(id: NodeId, typeParameterName: ?Token, elementTypes: ArrayList<TypeNode>) {
        super(id, typeParameterName.getOrDefault({=> TUPLE_TOKEN}), TUPLE_TOKEN)
        elementTypes_ = elementTypes
    }

    public mut prop elementTypes: ArrayList<TypeNode> {
        get() {
            elementTypes_
        }
        set(v) {
            elementTypes_ = v
        }
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        super.prettyPrint(printer)
        printer.append("(")
        for ((i, elemType) in elementTypes_.iterator().enumerate()) {
            elemType.prettyPrint(printer)
            if (i < elementTypes_.size - 1) {
                printer.append(", ")
            }
        }
        printer.append(")")
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "TupleType")
        super.yamlPrint(printer)
        printer.printList("elementTypes", elementTypes_)
    }
}
