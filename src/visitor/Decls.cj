package cjcj.visitor

import cjcj.prettyPrinter.{PrettyPrinter, YamlPrinter}
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import std.collection.ArrayList

public abstract class Decl <: Node & Equatable<Decl> {
    protected var identifier_: Token = Token()
    protected var keyword_: Token = identifier_
    protected var declType_: ?TypeNode = None
    protected var modifiers_: ArrayList<Modifier>
    protected var genericParam_: ?GenericParam = None
    protected var genericConstraint_: ArrayList<GenericConstraint>

    init() {
        this(NodeId())
    }

    // FuncParam
    init(id: NodeId) {
        super(id)
        modifiers_ = ArrayList()
        genericConstraint_ = ArrayList()
    }

    // MainDecl
    init(id: NodeId, declType: ?TypeNode) {
        this(id)
        declType_ = declType
    }

    // ClassDecl, InterfaceDecl
    init(id: NodeId, modifiers: ArrayList<Modifier>, keyword: Token, identifier: Token, genericParam: ?GenericParam,
        genericConstraint: ArrayList<GenericConstraint>) {
        super(id)
        identifier_ = identifier
        keyword_ = keyword
        modifiers_ = modifiers
        genericParam_ = genericParam
        genericConstraint_ = genericConstraint
    }

    // VarDecl
    init(id: NodeId, keyword: Token, identifier: Token, declType: ?TypeNode) {
        this(id)
        identifier_ = identifier
        keyword_ = keyword
        declType_ = declType
    }

    // FuncDecl
    init(id: NodeId, modifiers: ArrayList<Modifier>, keyword: Token, identifier: Token, declType: ?TypeNode,
        genericParam: ?GenericParam, genericConstraint: ArrayList<GenericConstraint>) {
        this(id, modifiers, keyword, identifier, genericParam, genericConstraint)
        declType_ = declType
    }

    // Constructor for FuncParam, they have no name
    init(id: NodeId, keyword: Token) {
        super(id)
        keyword_ = keyword
        modifiers_ = ArrayList()
        genericConstraint_ = ArrayList()
    }

    // Copy constructor
    init(decl: Decl) {
        this(decl.id)
        this.identifier_ = decl.identifier_
        this.keyword_ = decl.keyword_
    }

    public open override func traverse<R>(_: Visitor<R>): R {
        throw UnsupportedException("Traverse for Decl is not implemented")
    }

    public open mut prop identifier: Token {
        get() {
            identifier_
        }
        set(v) {
            identifier_ = v
        }
    }

    public open mut prop keyword: Token {
        get() {
            keyword_
        }
        set(v) {
            keyword_ = v
        }
    }

    public mut prop declType: ?TypeNode {
        get() {
            declType_
        }
        set(v) {
            declType_ = v
        }
    }

    public mut prop modifiers: ArrayList<Modifier> {
        get() {
            modifiers_
        }
        set(v) {
            modifiers_ = v
        }
    }

    public mut prop genericConstraint: ArrayList<GenericConstraint> {
        get() {
            genericConstraint_
        }
        set(v) {
            genericConstraint_ = v
        }
    }

    public mut prop genericParam: ?GenericParam {
        get() {
            genericParam_
        }
        set(v) {
            genericParam_ = v
        }
    }

    public prop isGenericDecl: Bool {
        get() {
            genericParam.isSome()
        }
    }

    public open override func prettyPrint(printer: PrettyPrinter) {
        for (modifier in modifiers) {
            modifier.prettyPrint(printer)
            printer.append(" ")
        }
        if (keyword.kind != TokenKind.ILLEGAL) {
            printer.append(keyword.value + " ")
        }
        if (identifier.kind != TokenKind.ILLEGAL) {
            printer.append(identifier.value)
        }
        if (let Some(genericParam) <- genericParam) {
            genericParam.prettyPrint(printer)
        }
    }

    protected open func printGenericConstraints(printer: PrettyPrinter): Unit {
        if (!genericConstraint.isEmpty()) {
            printer.append(" where ")
            genericConstraint[0].prettyPrint(printer)
            for (constraint in genericConstraint.iterator().skip(1)) {
                printer.append(", ")
                constraint.prettyPrint(printer)
            }
        }
    }

    public open override func yamlPrint(printer: YamlPrinter): Unit {
        if (keyword.kind != TokenKind.ILLEGAL) {
            printer.print("keyword", keyword)
        }
        if (keyword.kind != TokenKind.ILLEGAL) {
            printer.print("identifier", identifier)
        }
        printer.printOptionalObject("declType", declType)
        printer.printList("modifiers", modifiers)
        printer.printOptionalObject("genericParam", genericParam)
        printer.printList("genericConstraint", genericConstraint)
    }

    public override operator func ==(other: Decl) {
        id == other.id
    }

    public override operator func !=(other: Decl) {
        !(this == other)
    }
}

public open class VarDecl <: Decl {
    private var initializer_: ?Expr

    public init() {
        this(NodeId(), Token(), Token())
    }

    public init(id: NodeId, keyword: Token, identifier: Token) {
        this(id, keyword, identifier, None)
    }

    public init(id: NodeId, keyword: Token, identifier: Token, initializer: ?Expr) {
        this(id, keyword, identifier, initializer, None)
    }

    public init(id: NodeId, keyword: Token, identifier: Token, initializer: ?Expr, declType: ?TypeNode) {
        super(id, keyword, identifier, declType)
        initializer_ = initializer
    }

    public open override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public mut prop initializer: ?Expr {
        get() {
            initializer_
        }
        set(v) {
            initializer_ = v
        }
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        if (let Some(dtype) <- declType) {
            printer.append(": ")
            dtype.prettyPrint(printer)
        }
        printer.append("${if (initializer.isSome()) { " = " } else { "" }}")
        if (let Some(ini) <- initializer) {
            ini.prettyPrint(printer)
        }
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "VarDecl")
        super.yamlPrint(printer)
        printer.printOptionalObject("initializer", initializer)
    }
}

public open class MainDecl <: Decl {
    private var block_: Block
    private var param_: ?FuncParam

    public init() {
        this(NodeId(), Block(), None, None)
    }

    public MainDecl(id: NodeId, block: Block, param: ?FuncParam, declType: ?TypeNode) {
        super(id, declType)
        this.block_ = block
        this.param_ = param
        this.declType_ = declType
    }

    public open override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append("main(")
        if (let Some(a) <- param) {
            a.prettyPrint(printer)
        }
        printer.append(")")

        if (let Some(dtype) <- declType) {
            printer.append(": ")
            dtype.prettyPrint(printer)
        }
        printer.append(" ")
        block.prettyPrint(printer)
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "MainDecl")
        super.yamlPrint(printer)
        printer.printOptionalObject("param", param)
        printer.printObject("block", block)
    }

    public mut prop block: Block {
        get() {
            block_
        }
        set(v) {
            block_ = v
        }
    }

    public mut prop param: ?FuncParam {
        get() {
            param_
        }
        set(v) {
            param_ = v
        }
    }
}

public class FuncParam <: Decl {
    private var paramType_: TypeNode

    public init() {
        this(NodeId(), TypeNode())
    }

    public init(id: NodeId, paramType: TypeNode) {
        super(id)
        paramType_ = paramType
    }

    public init(id: NodeId, keyword: Token, paramType: TypeNode) {
        super(id, keyword)
        paramType_ = paramType
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append(paramType.typeParameterName.value + ": ")
        paramType.prettyPrint(printer)
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "FuncParam")
        super.yamlPrint(printer)
        printer.print("name", name)
        printer.printObject("paramType", paramType)
    }

    public mut prop paramType: TypeNode {
        get() {
            paramType_
        }
        set(v) {
            paramType_ = v
        }
    }

    public prop name: Token {
        get() {
            paramType.typeParameterName
        }
    }

    public override mut prop identifier: Token {
        get() {
            paramType.typeParameterName
        }
        set(v) {
            paramType.typeParameterName = v
        }
    }

    public func isMemberParam() {
        return keyword.kind != TokenKind.ILLEGAL
    }
}

public open class FuncDecl <: Decl {
    private var block_: ?Block
    private var params_: ArrayList<FuncParam>

    public init() {
        this(NodeId(), ArrayList(), Token(), Token(), Block(), ArrayList(), None, None, ArrayList())
    }

    public init(id: NodeId, modifiers: ArrayList<Modifier>, keyword: Token, identifier: Token, block: ?Block,
        params: ArrayList<FuncParam>, declType: ?TypeNode, genericParam: ?GenericParam,
        genericConstraint: ArrayList<GenericConstraint>) {
        super(id, modifiers, keyword, identifier, declType, genericParam, genericConstraint)
        this.block_ = block
        this.params_ = params
        this.declType_ = declType
    }

    // For init functions, which does not have generics
    public init(id: NodeId, keyword: Token, block: ?Block, params: ArrayList<FuncParam>) {
        this(id, ArrayList(), keyword, Token(), block, params, None, None, ArrayList())
    }

    public open override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append("(")
        if (!params.isEmpty()) {
            params[0].prettyPrint(printer)
            for (i in 1..params.size) {
                printer.append(", ")
                params[i].prettyPrint(printer)
            }
        }
        printer.append(")")
        if (let Some(dtype) <- declType) {
            printer.append(": ")
            dtype.prettyPrint(printer)
        }
        printGenericConstraints(printer)
        printer.append(" ")
        if (let Some(realBlock) <- block) {
            realBlock.prettyPrint(printer)
        }
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "FuncDecl")
        super.yamlPrint(printer)
        printer.printList("params", params)
        printer.printOptionalObject("block", block)
    }

    public mut prop block: ?Block {
        get() {
            block_
        }
        set(v) {
            block_ = v
        }
    }

    public mut prop params: ArrayList<FuncParam> {
        get() {
            params_
        }
        set(v) {
            params_ = v
        }
    }
}

public open class ClassDecl <: Decl {
    private let body_: Body
    private let superTypes_: ArrayList<TypeNode>

    public init(id: NodeId, modifiers: ArrayList<Modifier>, keyword: Token, identifier: Token, body: Body,
        superTypes: ArrayList<TypeNode>, genericParam: ?GenericParam, genericConstraint: ArrayList<GenericConstraint>) {
        super(id, modifiers, keyword, identifier, genericParam, genericConstraint)
        body_ = body
        superTypes_ = superTypes
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)

        if (!superTypes.isEmpty()) {
            printer.append(" <: ")
            printer.append(superTypes[0].typeName.value)
            for (i in 1..superTypes.size) {
                printer.append(" & ")
                superTypes[i].prettyPrint(printer)
            }
        }
        printGenericConstraints(printer)
        printer.append(" ")
        body.prettyPrint(printer)
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "ClassDecl")
        super.yamlPrint(printer)
        printer.printList("superTypes", superTypes)
        printer.printObject("body", body)
    }

    public open override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public prop body: Body {
        get() {
            body_
        }
    }

    public prop superTypes: ArrayList<TypeNode> {
        get() {
            superTypes_
        }
    }
}

public open class InterfaceDecl <: Decl {
    private let body_: Body
    private let superTypes_: ArrayList<TypeNode>

    public init(id: NodeId, modifiers: ArrayList<Modifier>, keyword: Token, identifier: Token, body: Body,
        superTypes: ArrayList<TypeNode>, genericParam: ?GenericParam, genericConstraint: ArrayList<GenericConstraint>) {
        super(id, modifiers, keyword, identifier, genericParam, genericConstraint)
        body_ = body
        superTypes_ = superTypes
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)

        if (!superTypes.isEmpty()) {
            printer.append(" <: ")
            printer.append(superTypes[0].typeName.value)
            for (i in 1..superTypes.size) {
                printer.append(" & ")
                superTypes[i].prettyPrint(printer)
            }
        }
        printGenericConstraints(printer)
        printer.append(" ")
        body.prettyPrint(printer)
    }

    public override func yamlPrint(printer: YamlPrinter): Unit {
        printer.print("type", "InterfaceDecl")
        super.yamlPrint(printer)
        printer.printList("superTypes", superTypes)
        printer.printObject("body", body)
    }

    public open override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public prop superTypes: ArrayList<TypeNode> {
        get() {
            superTypes_
        }
    }

    public prop body: Body {
        get() {
            body_
        }
    }
}
