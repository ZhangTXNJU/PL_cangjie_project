package cjcj.visitor

import cjcj.prettyPrinter.{PrettyPrinter, YamlPrintable, YamlPrinter}
import cjcj.scanner.Token
import std.collection.ArrayList
import std.deriving.Derive

@Derive[Equatable]
public struct NodeId <: Hashable {
    public let id: Int64

    // Default initializer with a default ID.
    public init() {
        this(0)
    }

    public NodeId(id: Int64) {
        this.id = id
    }

    public func hashCode(): Int64 {
        return id
    }
}

public abstract class Node <: Hashable & Equatable<Node> & YamlPrintable {
    private var id_: NodeId

    public Node(id: NodeId) {
        id_ = id
    }

    public func traverse<R>(v: Visitor<R>): R

    /*
     * Print the node and its children as a piece of Cangjie code.
     */
    public func prettyPrint(printer: PrettyPrinter): Unit

    public func yamlPrint(printer: YamlPrinter): Unit

    public func prettyPrint(): String {
        let printer: PrettyPrinter = PrettyPrinter()
        prettyPrint(printer)
        return printer.toString()
    }

    public func yamlPrint(): String {
        let printer: YamlPrinter = YamlPrinter()
        yamlPrint(printer)
        return printer.toString()
    }

    public mut prop id: NodeId {
        get() {
            id_
        }
        set(v) {
            id_ = v
        }
    }

    public func hashCode(): Int64 {
        id.hashCode()
    }

    public override operator func ==(other: Node): Bool {
        id == other.id
    }

    public override operator func !=(other: Node): Bool {
        !(this == other)
    }
}

public class Argument <: Node {
    private var expr_: Node

    public Argument(id: NodeId, expr: Node) {
        super(id)
        expr_ = expr
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        expr.prettyPrint(printer)
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "Argument")
        printer.printObject("expr", expr)
    }

    public mut prop expr: Node {
        get() {
            expr_
        }
        set(v) {
            expr_ = v
        }
    }
}

public class Program <: Node {
    private var decls_: ArrayList<Decl>

    public Program(id: NodeId, decls: ArrayList<Decl>) {
        super(id)
        decls_ = decls
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        decls.iterator().forEach(
            {
                d =>
                    d.prettyPrint(printer)
                    printer.append("\n")
            }
        )
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "Program")
        printer.printList("decls", decls)
    }

    public mut prop decls: ArrayList<Decl> {
        get() {
            decls_
        }
        set(v) {
            decls_ = v
        }
    }
}

public class Body <: Node {
    private var decls_: ArrayList<Decl>

    public init() {
        this(NodeId(), ArrayList())
    }

    public init(id: NodeId, decls: ArrayList<Decl>) {
        super(id)
        decls_ = decls
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append("{")
        printer.indent()
        printer.append("\n")
        decls.iterator().forEach(
            {
                d =>
                    d.prettyPrint(printer)
                    printer.append("\n")
            }
        )
        printer.unindent()
        printer.append("\n}")
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "Body")
        printer.printList("decls", decls)
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public mut prop decls: ArrayList<Decl> {
        get() {
            decls_
        }
        set(v) {
            decls_ = v
        }
    }
}

public class GenericConstraint <: Node {
    private var typeArgument_: TypeNode
    private var upperBounds_: ArrayList<TypeNode>

    public init(id: NodeId, typeArgument: TypeNode, upperBounds: ArrayList<TypeNode>) {
        super(id)
        typeArgument_ = typeArgument
        upperBounds_ = upperBounds
        if (upperBounds.size == 0) {
            throw IllegalArgumentException("GenericConstraint must have at least one upper bound.")
        }
    }

    public mut prop typeArgument: TypeNode {
        get() {
            typeArgument_
        }
        set(v) {
            typeArgument_ = v
        }
    }

    public mut prop upperBounds: ArrayList<TypeNode> {
        get() {
            upperBounds_
        }
        set(v) {
            upperBounds_ = v
        }
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        typeArgument.prettyPrint(printer)
        printer.append(" <: ")
        upperBounds[0].prettyPrint(printer)
        for (bound in upperBounds.iterator().skip(1)) {
            printer.append(" & ")
            bound.prettyPrint(printer)
        }
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "GenericConstraint")
        printer.printObject("typeArgument", typeArgument)
        printer.printList("upperBounds", upperBounds)
    }
}

public class GenericParam <: Node {
    private var parameters_: ArrayList<Token>

    public init(id: NodeId, parameters: ArrayList<Token>) {
        super(id)
        parameters_ = parameters
        if (parameters.size == 0) {
            throw IllegalArgumentException("GenericParam must have at least one parameter.")
        }
    }

    public mut prop parameters: ArrayList<Token> {
        get() {
            parameters_
        }
        set(v) {
            parameters_ = v
        }
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append("<")
        printer.append(parameters[0].toString())
        for (param in parameters.iterator().skip(1)) {
            printer.append(", ")
            printer.append(param.toString())
        }
        printer.append(">")
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "GenericParam")
        printer.printList("parameters", parameters)
    }
}

public class Modifier <: Node {
    private var keyword_: Token

    public init(id: NodeId, keyword: Token) {
        super(id)
        keyword_ = keyword
    }

    public mut prop keyword: Token {
        get() {
            keyword_
        }
        set(v) {
            keyword_ = v
        }
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(keyword.toString())
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "Modifier")
        printer.print("keyword", keyword)
    }
}
