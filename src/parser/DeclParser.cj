package cjcj.parser

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper
import std.collection.{ArrayList, HashSet}
import std.ast.Position

private type TK = TokenKind

private type TKH = TokenKindHelper

internal open class DeclParser {
    private static const MAX_PARAM_NUMBER = 255

    public DeclParser(private let helper: ParserHelper, private let reporter: Reporter) {
    }

    func topLevelObject(): ?Decl {
        if (let Some(funcDef) <- functionDefinition()) {
            return funcDef
        }
        if (let Some(varDecl) <- variableDeclaration()) {
            return varDecl
        }
        if (let Some(classDecl) <- classDefinition()) {
            return classDecl
        }
        if (let Some(interfaceDecl) <- interfaceDefinition()) {
            return interfaceDecl
        }
        None
    }

    private func declaration(): ?Decl {
        helper.skipNL()
        try {
            if (let Some(varDecl) <- variableDeclaration()) {
                return varDecl
            }
            if (let Some(funcDef) <- functionDefinition()) {
                return funcDef
            }
        } catch (error: ParseError | ConsumeError) {
            helper.synchronize()
        }
        None
    }

    private func unnamedParameterList(): ArrayList<FuncParam> {
        let parameters: ArrayList<FuncParam> = ArrayList()
        let start: (Token, Int64) = helper.previousNonNLTokenWithIndex()
        if (helper.check(TK.IDENTIFIER)) {
            do {
                if (helper.check(TK.IDENTIFIER)) {
                    helper.skipNL()
                    if (parameters.size >= MAX_PARAM_NUMBER) {
                        throw helper.error(helper.previous(),
                            "Can't have more than " + MAX_PARAM_NUMBER.toString() + " parameters.", helper.current)
                    }
                    try {
                        parameters.add(unnamedParameter())
                    } catch (e: FinalError) {
                        helper.synchronizeBlockParenthesis(start[0], start[1])
                    }
                } else {
                    helper.error(helper.previous(), "Expected parameter name after comma", helper.current - 1)
                }
                helper.skipNL()
            } while (helper.matches(TK.COMMA))
        }
        return parameters
    }

    private func genericParam(): ?GenericParam {
        if (!helper.matches(TKH.LANGLE)) {
            return None
        }
        let tokens = ArrayList<Token>()
        do {
            helper.skipNL()
            if (helper.check(TKH.RANGLE)) {
                if (tokens.isEmpty()) {
                    // Triggers consume error
                    helper.consume(TK.IDENTIFIER, "Expect generic parameter name.", helper.current)
                }
                break;
            }
            tokens.add(helper.consume(TK.IDENTIFIER, "Expect generic parameter name.", helper.current))
            helper.skipNL()
        } while (helper.matches(TK.COMMA))
        helper.consume(TKH.RANGLE, "Expect '>' after generic parameters.", helper.current)
        GenericParam(NodeIdManager.nextId(), tokens)
    }

    private func genericConstraints(): ArrayList<GenericConstraint> {
        if (!helper.matches(TK.WHERE)) {
            return ArrayList()
        }
        let constraints: ArrayList<GenericConstraint> = ArrayList()
        do {
            helper.skipNL()
            let lowerBound = nodeType(NodeIdManager.nextId(), None)
            let upperBounds = ArrayList<TypeNode>()
            do {
                helper.skipNL()
                upperBounds.add(nodeType(NodeIdManager.nextId(), None))
                helper.skipNL()
            } while (helper.matches(TK.BITAND))
            constraints.add(GenericConstraint(NodeIdManager.nextId(), lowerBound, upperBounds))
        } while (helper.matches(TK.COMMA))
        constraints
    }

    private func modifiers(modifierTypes: Array<TK>, keyword!: TK): ?ArrayList<Modifier> {
        helper.tryParse {
            let modifierKinds = HashSet<String>()
            let modifiers = ArrayList<Modifier>()
            while (helper.matches(modifierTypes)) {
                if (modifierKinds.add(helper.previous().kind.toString())) {
                    modifiers.add(Modifier(NodeIdManager.nextId(), helper.previous()))
                } else {
                    // No need to throw here, just ignore the modifier
                    helper.error(helper.previous(),
                        "Duplicate modifier '\u{001b}[31m${helper.previous().value}\u{001b}[0m'", helper.current - 1)
                }
                helper.skipNL()
            }
            if (!helper.matches(keyword)) {
                return None
            }
            modifiers
        }
    }

    private func functionDefinition(): ?FuncDecl {
        let optModifiers = modifiers(TK.OPEN, TK.OVERRIDE, keyword: TK.FUNC)
        if (optModifiers.isNone()) {
            return None
        }
        let modifiers = optModifiers.getOrThrow()
        let keyword: Token = helper.previous()
        helper.skipNL()
        let name: Token = helper.consume(TK.IDENTIFIER, "Expect function name.", helper.current)
        helper.skipNL()
        let generics = genericParam()
        helper.skipNL()
        var parameters: ArrayList<FuncParam> = ArrayList()
        helper.skipNL()
        parameters = functionParameters()

        var declType: ?TypeNode = None
        helper.skipNL()
        let constraints = genericConstraints()
        helper.skipNL()
        if (helper.matches(TK.COLON)) {
            helper.skipNL()
            declType = nodeType(NodeIdManager.nextId(), name)
        }
        helper.skipNL()

        // Sometimes functions might not have a block, e.g. in an interface, or an abstract class 
        var block_: ?Block = None
        try {
            block_ = block()
        } catch (e: ConsumeError) {
            if (e.message != "No Block") {
                throw e
            } else {
                reporter.pop()
                helper.retreat()
            }
        }

        if (let Some(dtype) <- declType && dtype.typeName.value == "Unit" && let Some(realBlock) <- block_) {
            realBlock
                .nodes
                .add(
                    ReturnExpr(NodeIdManager.nextId(),
                        LitConstExpr(NodeIdManager.nextId(), Token(TK.UNIT_LITERAL, "()", Position())),
                        Token(TK.RETURN, "return", Position())))
        }

        FuncDecl(NodeIdManager.nextId(), modifiers, keyword, name, block_, parameters, declType, generics, constraints)
    }

    private func functionParameters(): ArrayList<FuncParam> {
        helper.consume(TK.LPAREN, "Expect '(' before function parameters", helper.current)
        let start: (Token, Int64) = helper.previousNonNLTokenWithIndex()
        helper.skipNL()
        let parameters: ArrayList<FuncParam> = ArrayList()
        try {
            parameters.add(all: unnamedParameterList())
            helper.skipNL()
            try {
                helper.consume(TK.RPAREN, "Expect ')' after function parameters", helper.current)
                helper.skipNL()
            } catch (e: ConsumeError) {
                if (helper.check(TK.LCURL)) {
                    helper.unclosedDelimiterError(helper.peek(), start[0], start[1], helper.current)
                } else {
                    helper.synchronizeBlockParenthesis(start[0], start[1])
                }
            }
        } catch (e: ParseError) {
            helper.synchronizeBlockParenthesis(start[0], start[1])
        }
        parameters
    }

    private func classDefinition(): ?ClassDecl {
        let optModifiers = modifiers(TK.ABSTRACT, TK.OPEN, keyword: TK.CLASS)
        if (optModifiers.isNone()) {
            return None
        }
        let modifiers = optModifiers.getOrThrow()
        let keyword: Token = helper.previous()
        helper.skipNL()
        let identifier: Token = className()
        helper.skipNL()
        let generics = genericParam()
        helper.skipNL()
        let supertypes: ArrayList<TypeNode> = if (helper.matches(TK.UPPERBOUND)) {
            helper.skipNL()
            superClassOrInterfaces()
        } else {
            ArrayList()
        }
        helper.skipNL()
        let constraints = genericConstraints()
        helper.skipNL()
        try {
            let body: Body = classBody()
            return ClassDecl(NodeIdManager.nextId(), modifiers, keyword, identifier, body, supertypes, generics,
                constraints)
        } catch (e: ConsumeError) {
            helper.pop()
            helper.error(helper.peek(), "body of class '\u{001b}[31m${identifier}\u{001b}[0m' is missing",
                helper.current)
            return None
        }
    }

    private func className(): Token {
        return helper.consume(TK.IDENTIFIER, "Expect class name.", helper.current)
    }

    private func classBody(): Body {
        let start: (Token, Int64) = (helper.peek(), helper.current)
        helper.consume(TK.LCURL, "Expect '{' before body.", helper.current)
        helper.endStar()
        let decls: ArrayList<Decl> = ArrayList()
        if (let Some(cmd) <- classMemberDeclaration()) {
            decls.add(cmd)

            while (let Some(cmd) <- helper.tryParse(
                    {
                        =>
                            helper.endPlus("", helper.peek(), helper.current);
                            classMemberDeclaration()
                    }
                )) {
                decls.add(cmd)
            }
        }
        helper.endStar()
        try {
            helper.consume(TK.RCURL, "Expect '}' after block.", helper.current)
        } catch (e: ConsumeError) {
            helper.trySynchronizeBlockRightCurlOrError(helper.peek(), start[0], start[1], helper.current)
        }
        Body(NodeIdManager.nextId(), decls)
    }

    public func classMemberDeclaration(): ?Decl {
        var decl: ?Decl = None
        try {
            if (let Some(classInit) <- classInit()) {
                decl = classInit
            }
            if (let Some(variableDeclaration) <- variableDeclaration()) {
                decl = variableDeclaration
            }
            if (let Some(functionDefinition) <- functionDefinition()) {
                decl = functionDefinition
            }
        } catch (e: ParseError | ConsumeError) {
            helper.synchronize()
        }
        decl
    }

    public func classInit(): ?FuncDecl {
        //TODO: look and understand what the const modifier does.
        if (!helper.matches(TK.INIT)) {
            return None
        }
        let keyword: Token = helper.previous()
        let params: ArrayList<FuncParam> = functionParameters()
        helper.skipNL()
        let block: Block = block()
        FuncDecl(NodeIdManager.nextId(), keyword, block, params)
    }

    private func superClassOrInterfaces(): ArrayList<TypeNode> {
        let superClassOrInterfaces: ArrayList<TypeNode> = ArrayList()
        // We assume that the first element of the super classes or interfaces is a class, we will
        // check it in the following process.
        superClassOrInterfaces.add(superClass())
        while (let Some(superClassOrInterface) <- helper.tryParse(
                {
                    =>
                        helper.skipNL()
                        if (helper.matches(TK.BITAND)) {
                            helper.skipNL()
                            return superClass()
                        }
                        None
                }
            )) {
            superClassOrInterfaces.add(superClassOrInterface)
        }
        superClassOrInterfaces
    }

    private func interfaceName(): Token {
        return helper.consume(TK.IDENTIFIER, "Expect interface name.", helper.current)
    }

    private func interfaceDefinition(): ?InterfaceDecl {
        if (!helper.matches(TK.INTERFACE)) {
            return None
        }
        let keyword: Token = helper.previous()
        helper.skipNL()
        let identifier: Token = interfaceName()
        helper.skipNL()
        let generics = genericParam()
        helper.skipNL()
        let supertypes: ArrayList<TypeNode> = if (helper.matches(TK.UPPERBOUND)) {
            helper.skipNL()
            superClassOrInterfaces()
        } else {
            ArrayList()
        }
        helper.skipNL()
        let constraints = genericConstraints()
        helper.skipNL()

        try {
            let body: Body = interfaceBody()
            return InterfaceDecl(NodeIdManager.nextId(), ArrayList(), keyword, identifier, body, supertypes, generics,
                constraints)
        } catch (e: ConsumeError) {
            helper.pop()
            helper.error(helper.peek(), "body of interface '\u{001b}[31m${identifier}\u{001b}[0m' is missing",
                helper.current)
            return None
        }
    }

    private func interfaceBody(): Body {
        let start: (Token, Int64) = (helper.peek(), helper.current)
        helper.consume(TK.LCURL, "Expect '{' before body.", helper.current)
        helper.endStar()
        let decls: ArrayList<Decl> = ArrayList()
        if (let Some(cmd) <- interfaceMemberDeclaration()) {
            decls.add(cmd)

            while (let Some(cmd) <- helper.tryParse(
                    {
                        =>
                            helper.endPlus("", helper.peek(), helper.current);
                            interfaceMemberDeclaration()
                    }
                )) {
                decls.add(cmd)
            }
        }
        helper.endStar()

        try {
            helper.consume(TK.RCURL, "Expect '}' after block.", helper.current)
        } catch (e: ConsumeError) {
            helper.trySynchronizeBlockRightCurlOrError(helper.peek(), start[0], start[1], helper.current)
        }

        Body(NodeIdManager.nextId(), decls)
    }

    private func interfaceMemberDeclaration(): ?Decl {
        try {
            if (let Some(functionDefinition) <- functionDefinition()) {
                return functionDefinition
            }
        } catch (e: ParseError | ConsumeError) {
            helper.synchronize()
        }
        None
    }

    private func superClass(): TypeNode {
        classType()
    }

    private func classType(): TypeNode {
        // In the future we'll have also (identifier NL* DOT  NL*)*
        refType(NodeIdManager.nextId(), Token(), className())
    }

    private func refType(id: NodeId, typeParamName: Token, typeName: Token): RefType {
        // if (typeName.kind != TK.IDENTIFIER) {
        //     throw helper.consumeError(typeName, helper.current - 1, TK.IDENTIFIER, typeName.value)
        // }
        let typeArguments = ArrayList<TypeNode>()
        if (helper.skipNLCompare(TKH.LANGLE)) {
            do {
                helper.skipNL()
                if (helper.check(TKH.RANGLE)) {
                    if (typeArguments.isEmpty()) {
                        // Trigger consume error
                        helper.consume(TK.IDENTIFIER, "Expect generic parameter name.", helper.current)
                    }
                    break;
                }
                typeArguments.add(nodeType(NodeIdManager.nextId(), None))
                helper.skipNL()
            } while (helper.matches(TK.COMMA))
            helper.consume(TKH.RANGLE, "Expect '>' after generic parameters.", helper.current)
        }
        return RefType(id, typeParamName, typeName, typeArguments)
    }

    private static let OPTION_TYPE_NAME = Token(TK.IDENTIFIER, "Option", Position())

    private func nodeType(id: NodeId, typeParameterName: ?Token): TypeNode {
        if (helper.matches(TK.LPAREN)) {
            // Tuple type or function type
            let typeList = ArrayList<TypeNode>()
            if (!helper.matches(TK.RPAREN)) {
                while (true) {
                    helper.skipNL()
                    typeList.add(nodeType(NodeIdManager.nextId(), None))
                    helper.skipNL()
                    if (helper.matches(TK.RPAREN)) {
                        break
                    } else if (!helper.matches(TK.COMMA)) {
                        helper.error(helper.peek(),
                            "Expected new line, ',' or ')' in function type, found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'",
                            helper.current)
                    }
                }
            }
            if (helper.skipNLCompare(TK.ARROW)) {
                // Function type
                helper.skipNL()
                let returnType = nodeType(NodeIdManager.nextId(), None)
                FuncType(id, typeParameterName, typeList, returnType)
            } else if (typeList.size == 1) {
                // Parenthesized type
                typeList[0]
            } else if (typeList.size == 0) {
                throw helper.error(helper.previous(), "Malformed type: empty parentheses '()' is not a type",
                    helper.current - 1)
            } else {
                // Tuple type
                TupleType(id, typeParameterName, typeList)
            } // typeList.size != 0 as () is UNIT_LITERAL instead
        } else if (helper.matches(TK.QUEST)) {
            let valueType = nodeType(NodeIdManager.nextId(), None)
            RefType(id, typeParameterName.getOrDefault {OPTION_TYPE_NAME}, OPTION_TYPE_NAME, ArrayList([valueType]))
        } else {
            let typeName = helper.advance()
            let typeParamName = typeParameterName.getOrDefault {typeName}
            try {
                return PrimitiveType(id, typeParamName, typeName)
            } catch (_: IllegalArgumentException) {
                return refType(id, typeParamName, typeName)
            }
        }
    }

    private func unnamedParameter(): FuncParam {
        if (helper.matches(TK.IDENTIFIER, TK.WILDCARD)) {
            let parameterName = helper.previous()
            helper.consume(TK.COLON, "Expect ':' after parameter name", helper.current)
            FuncParam(NodeIdManager.nextId(), nodeType(NodeIdManager.nextId(), parameterName))
        } else {
            throw helper.error(helper.peek(),
                "Expected unnamed parameter, found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'", helper.current)
        }
    }

    func mainDefinition(): ?MainDecl {
        if (!helper.matches(TK.MAIN)) {
            return None
        }
        let start: (Token, Int64) = (helper.previous(), helper.current - 1)
        var parameter: ?FuncParam = None
        var parameters: Int64 = 0
        helper.consume(TK.LPAREN, "Expect '(' after main.", helper.current)
        try {
            if (!helper.check(TK.RPAREN)) {
                do {
                    if (parameters >= 1) {
                        throw helper.error(helper.peek(), "Can't have more than 1 parameter in main function.",
                            helper.current)
                    }
                    parameters++
                    parameter = unnamedParameter()

                // TODO: For now, discards all other parameters other than the first one.
                // TEMPORARY FIX, REMEMBER TO MAKE A REAL SOLUTION

                } while (helper.matches(TK.COMMA))
            }
        } catch (error: ParseError) {
            helper.synchronize()
        }
        helper.consume(TK.RPAREN, "Expect ') after parameters.", helper.current)

        var declType: ?TypeNode = None
        if (helper.matches(TK.COLON)) {
            declType = nodeType(NodeIdManager.nextId(), None)
        }

        try {
            let block: Block = block()
            return MainDecl(NodeIdManager.nextId(), block, parameter, declType)
        } catch (e: ConsumeError) {
            helper.pop()
            helper.error(start[0], "body of main function is missing", start[1])
            return MainDecl(NodeIdManager.nextId(), Block(), parameter, declType)
        }
    }

    private func variableDeclaration(): ?VarDecl {
        if (!helper.matches(TK.LET, TK.VAR)) {
            return None
        }
        let keyword: Token = helper.previous()

        helper.skipNL()
        let name: Token = helper.consume(TK.IDENTIFIER, "Expect variable name.", helper.current)

        var declType: ?TypeNode = None
        if (helper.matches(TK.COLON)) {
            declType = nodeType(NodeIdManager.nextId(), name)
        }

        var initializer: ?Expr = None
        if (helper.matches(TK.ASSIGN)) {
            initializer = expression()
        }

        VarDecl(NodeIdManager.nextId(), keyword, name, initializer, declType)
    }

    private func block(): Block {
        if (!helper.check(TK.LCURL)) {
            helper.consumeError(helper.peek(), helper.current, TK.LCURL, helper.peek().value)
            throw ConsumeError("No Block")
        }

        var nodes: ArrayList<Node> = ArrayList()
        helper.consume(TK.LCURL, "Expect '{' before block.", helper.current)
        let start: (Token, Int64) = (helper.previous(), helper.current - 1)
        try {
            nodes = expressionOrDeclarations()
            helper.endStar()
            helper.consume(TK.RCURL, "Expect '}' after block.", helper.current)
        } catch (e: ParseError | ConsumeError) {
            // ParserError comes from expressionOrDeclaration(),
            // and ConsumeError comes from helper.consume(...),
            // both indicating something invalid appears in the block,
            // which means the block is either missing a '}',
            // or containing TLDs.
            helper.trySynchronizeBlockRightCurlOrError(helper.peek(), start[0], start[1], helper.current)
        }
        Block(NodeIdManager.nextId(), nodes)
    }

    private func expressionOrDeclarations(): ArrayList<Node> {
        let expressionOrDeclarations: ArrayList<Node> = ArrayList()
        helper.endStar()
        if (let Some(exprOrDecl) <- expressionOrDeclaration()) {
            expressionOrDeclarations.add(exprOrDecl)
            while (let Some(exprOrDecl) <- helper.tryParse<Node>(
                    {
                        =>
                            try {
                                helper.endPlus("", helper.peek(), helper.current)
                            } catch (_) {
                                helper.pop();
                                return None
                            }
                            expressionOrDeclaration()
                    }
                )) {
                expressionOrDeclarations.add(exprOrDecl)
            }
        }
        expressionOrDeclarations
    }

    private func expressionOrDeclaration(): ?Node {
        if (let Some(decl) <- declaration()) {
            return decl
        }
        if (let Some(expr) <- expression()) {
            return expr
        }
        if (helper.matches(TKH.END) || helper.check(TK.RCURL)) {
            return None
        }
        throw helper.error(helper.peek(),
            "Expected expression or declaration inside block, found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'",
            helper.current)
    }

    private func whileExpr(): ?Expr {
        if (!helper.matches(TK.WHILE)) {
            return None
        }

        helper.skipNL()
        helper.consume(TK.LPAREN, "Expect '(' before condition.", helper.current)
        let start: (Token, Int64) = (helper.previous(), helper.current - 1)
        helper.skipNL()
        var condition: Expr
        try {
            condition = expectExpression(expression, "Expected condition after while.")
            helper.skipNL()
            helper.consume(TK.RPAREN, "Expect ')' after condition.", helper.current)
        } catch (e: ParseError) {
            helper.synchronizeBlockParenthesis(start[0], start[1])
            condition = Expr(NodeIdManager.nextId())
        }
        helper.skipNL()
        let block: Block = block()

        WhileExpr(NodeIdManager.nextId(), condition, block)
    }

    private func loopExpression(): ?Expr {
        if (let Some(whileExpr) <- whileExpr()) {
            return whileExpr
        }
        None
    }

    private func ifExpression(): ?Expr {
        if (!helper.matches(TK.IF)) {
            return None
        }
        helper.skipNL()
        helper.consume(TK.LPAREN, "Expect '(' before condition.", helper.current)
        let start: (Token, Int64) = (helper.previous(), helper.current - 1)
        helper.skipNL()
        var condition: Expr
        try {
            condition = expectExpression(expression, "Expected condition after while.")
            helper.skipNL()
            helper.consume(TK.RPAREN, "Expect ')' after condition.", helper.current)
        } catch (e: ParseError) {
            helper.synchronizeBlockParenthesis(start[0], start[1])
            condition = Expr(NodeIdManager.nextId())
        }
        helper.skipNL()

        let ifBlock: Block = block()
        let elseBranch: Expr = if (let Some(elseBranch) <- helper.tryParse<Expr>(
            {
                =>
                    helper.skipNL()
                    if (helper.matches(TK.ELSE)) {
                        helper.skipNL()
                        if (let Some(ifExpr) <- ifExpression()) {
                            return ifExpr
                        } else {
                            return block()
                        }
                    }
                    return None
            }
        )) {
            elseBranch
        } else {
            /*
             * Desugar if () { expr } to if () { expr; () } else { () }
             */
            ifBlock.nodes.add(LitConstExpr(NodeIdManager.nextId(), Token(TK.UNIT_LITERAL, "()", Position())))
            Block(NodeIdManager.nextId(),
                ArrayList<Node>([LitConstExpr(NodeIdManager.nextId(), Token(TK.UNIT_LITERAL, "()", Position()))]))
        }
        return IfExpr(NodeIdManager.nextId(), condition, ifBlock, elseBranch)
    }

    public func expression(): ?Expr {
        try {
            return assignmentExpression()
        } catch (e: Exception) {
            helper.synchronize()
            return None
        }
    }

    private func leftValueExpression(): ?Expr {
        return leftValueExpressionWithoutWildCard()
    }

    private func leftValueExpressionWithoutWildCard(): ?Expr {
        if (let Some(leftWithAssignable) <- helper.tryParse(
            {
                =>
                    if (let Some(lae) <- leftAuxExpression()) {
                        helper.skipNL()
                        var base: Expr = lae
                        var assignable: Bool = true
                        while (true) {
                            if (let Some(fieldAccess) <- fieldAccess(base)) {
                                base = fieldAccess
                                assignable = true
                                continue
                            }
                            if (let Some(callSuffix) <- callSuffix(base)) {
                                base = callSuffix
                                assignable = false
                                continue
                            }
                            break
                        }
                        if (assignable) {
                            return base
                        }
                        throw helper.error(helper.previous(), "The left part needs to be assignable!", helper.current - 1)
                    }
                    None
            }
        )) {
            return leftWithAssignable
        }
        return identifier()
    }

    private func leftAuxExpression(): ?Expr {
        if (let Some(identifier) <- identifierWithTypeArguments()) {
            return identifier
        }
        if (let Some(thisSuperExpression) <- thisSuperExpression()) {
            return thisSuperExpression
        }
        primitiveTypeExpr()
    }

    private func primitiveTypeExpr(): ?Expr {
        if (helper.matches(TKH.CHAR_LANG_TYPES)) {
            return PrimitiveTypeExpr(NodeIdManager.nextId(), helper.previous())
        }
        None
    }

    private func fieldAccess(baseExpr: Expr): ?Expr {
        return helper.tryParse(
            {
                =>
                    helper.skipNL()
                    if (helper.matches(TK.DOT)) {
                        helper.skipNL()
                        return MemberAccess(NodeIdManager.nextId(), baseExpr,
                            helper.consume(TK.IDENTIFIER, "Expected identifier after '.'", helper.current),
                            optionalTypeArguments())
                    }
                    None
            }
        )
    }

    private func indexAccess(baseExpr: Expr): ?Expr {
        helper.tryParse {
            helper.skipNL()
            if (!helper.matches(TK.LSQUARE)) {
                return None
            }
            helper.skipNL()
            // TODO: support other expressions (with normal calls)
            if (!helper.matches(TK.INTEGER_LITERAL)) {
                return None
            }
            let lit = LitConstExpr(NodeIdManager.nextId(), helper.previous())
            if (!helper.matches(TK.RSQUARE)) {
                return None
            }
            IndexAccess(NodeIdManager.nextId(), baseExpr, lit)
        }
    }

    private func callSuffix(callee: Expr): ?Expr {
        let arguments: ArrayList<Argument> = ArrayList()
        if (!helper.matches(TK.LPAREN)) {
            return None
        }
        let start: (Token, Int64) = (helper.previous(), helper.current - 1)
        try {
            helper.skipNL()
            if (!helper.check(TK.RPAREN)) {
                do {
                    helper.skipNL()
                    arguments.add(
                        Argument(
                            NodeIdManager.nextId(),
                            expectExpression(
                                expression,
                                "Expected expression inside call suffix."
                            )
                        )
                    )
                    helper.skipNL()
                } while (helper.matches(TK.COMMA))
            }
            try {
                helper.consume(TK.RPAREN, "Expect ')' after arguments.", helper.current)
            } catch (e: ConsumeError) {
                helper.unclosedDelimiterError(helper.peek(), start[0], start[1], helper.current)
            }
        } catch (e: ParseError) {
            helper.synchronizeCallParenthesis(start[0], start[1])
        }
        CallExpr(NodeIdManager.nextId(), callee, arguments)
    }

    /*
     * Tries to parse an expression and throws an error with the given message if
     * no expression was found.
     */
    private func expectExpression<T>(function: () -> ?T, message: String): Expr where T <: Expr {
        return function().getOrThrow({
            => helper.error(helper.peek(), message, helper.current)
        })
    }

    private func assignmentExpression(): ?Expr {
        if (let Some(value) <- helper.tryParse(
            {
                =>
                    /*
                     * If I don't find the Assignment Operator I need to go back to
                     * include my left value expression to the expression I will
                     * eventually parse.
                     */
                    try {
                        if (let Some(value) <- leftValueExpression() && helper.matches(TKH.ASSIGNMENT_OPERATOR) && let Some(right) <- logicDisjunctionExpression()) {
                            return AssignExpr(NodeIdManager.nextId(), value, right)
                        }
                    } catch (e: Exception) {
                        if (helper.check(TKH.ASSIGNMENT_OPERATOR)) {
                            throw e
                        }
                        helper.pop()
                    }
                    None
            }
        )) {
            return value
        }
        logicDisjunctionExpression()
    }

    private func identifier(): ?Expr {
        if (helper.matches(TK.IDENTIFIER)) {
            return RefExpr(NodeIdManager.nextId(), helper.previous(), ArrayList())
        }
        None
    }

    private func optionalTypeArguments(): ArrayList<TypeNode> {
        helper.tryParse {
            let typeArguments = ArrayList<TypeNode>()
            if (helper.matches(TKH.LANGLE)) {
                do {
                    helper.skipNL()
                    if (helper.check(TKH.RANGLE)) {
                        break;
                    }
                    typeArguments.add(nodeType(NodeIdManager.nextId(), None))
                    helper.skipNL()
                } while (helper.matches(TK.COMMA))
                if (!helper.matches(TKH.RANGLE)) {
                    typeArguments.clear()
                    return None
                }
            }
            typeArguments
        }.getOrDefault {ArrayList<TypeNode>()}
    }

    private func identifierWithTypeArguments(): ?Expr {
        if (helper.matches(TK.IDENTIFIER)) {
            let ident: Token = helper.previous()
            let typeArguments = optionalTypeArguments()
            return RefExpr(NodeIdManager.nextId(), ident, typeArguments)
        }
        None
    }

    private func logicDisjunctionExpression(): ?Expr {
        if (let Some(e) <- logicConjunctionExpression()) {
            var expr: Expr = e
            while (helper.matches(TK.OR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(logicConjunctionExpression,
                    "Expected logicConjunctionExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func logicConjunctionExpression(): ?Expr {
        if (let Some(e) <- bitwiseDisjunctionExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TK.AND)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(bitwiseDisjunctionExpression,
                    "Expect bitwiseDisjunctionExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func bitwiseDisjunctionExpression(): ?Expr {
        if (let Some(e) <- bitwiseConjunctionExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TK.BITOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(bitwiseConjunctionExpression,
                    "Expect bitwiseConjuctionExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func bitwiseConjunctionExpression(): ?Expr {
        if (let Some(e) <- equalityComparisonExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TK.BITAND)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(equalityComparisonExpression,
                    "Expect equalityComparisonExpression after ${oper.value}")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func equalityComparisonExpression(): ?Expr {
        if (let Some(e) <- comparisonOrTypeExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.EQUALITY_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(comparisonOrTypeExpression,
                    "Expect comparisonOrTypeExpression after ${oper.value}")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func comparisonOrTypeExpression(): ?Expr {
        if (let Some(e) <- shiftingExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.COMPARISON_OPERATOR) || helper.skipNLCompare(TK.IS, TK.AS)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                if (oper.kind == TK.IS) {
                    let typeNode = nodeType(NodeIdManager.nextId(), None)
                    expr = IsExpr(NodeIdManager.nextId(), expr, typeNode)
                } else if (oper.kind == TK.AS) {
                    let typeNode = nodeType(NodeIdManager.nextId(), None)
                    expr = AsExpr(NodeIdManager.nextId(), expr, typeNode)
                } else {
                    let right: Expr = expectExpression(shiftingExpression,
                        "Expect additiveExpression after '${oper.value}'")
                    expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
                }
            }
            return expr
        }
        None
    }

    private func shiftingExpression(): ?Expr {
        if (let Some(e) <- additiveExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TK.LSHIFT) || helper.skipNLTry {
                    helper.matches(TK.GT) && helper.matches(TK.RSHIFT_CONTINUE)
                }) {
                let oper: Token = if (helper.previous().kind == TK.RSHIFT_CONTINUE) {
                    Token(TK.RSHIFT, ">>", helper.seek(-2).pos)
                } else {
                    helper.previous()
                }
                helper.skipNL()
                let right: Expr = expectExpression(additiveExpression, "Expect additiveExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func additiveExpression(): ?Expr {
        if (let Some(e) <- multiplicativeExpression()) {
            var expr: Expr = e
            while (helper.matches(TK.SUB) || helper.skipNLCompare(TK.ADD)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(multiplicativeExpression,
                    "Expect multiplicativeExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func multiplicativeExpression(): ?Expr {
        if (let Some(e) <- exponentExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.MULTIPLICATIVE_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(exponentExpression,
                    "Expect exponent expression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func exponentExpression(): ?Expr {
        if (let Some(e) <- prefixUnaryExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.EXPONENT_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(prefixUnaryExpression,
                    "Expected a prefixUnaryExpression after '**', found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func prefixUnaryExpression(): ?Expr {
        // TODO: now an expression like --5 is ok but in the future
        // we will add the inc and dec operators that will be after this so that
        // the problem will be solved.
        if (helper.matches(TKH.PREFIX_UNARY_OPERATOR)) {
            let oper: Token = helper.previous()
            if (oper.kind == TK.SUB && helper.matches(TK.INTEGER_LITERAL, TK.FLOAT_LITERAL)) {
                let literal: Token = helper.previous()
                return LitConstExpr(NodeIdManager.nextId(), Token(literal.kind, "-" + literal.value, oper.pos))
            }
            let right: Expr = expectExpression(prefixUnaryExpression,
                "Expected a postfixExpression after ${oper.value}, found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'")
            return UnaryExpr(NodeIdManager.nextId(), oper, right)
        }
        postfixExpression()
    }

    private func postfixExpression(): ?Expr {
        let base: Expr
        if (let Some(e) <- atomicExpression()) {
            base = e
        } else if (let Some(e) <- helper.tryParse(
            {
                =>
                    if (let Some(primitiveTypeExpr) <- primitiveTypeExpr()) {
                        var base: Expr = primitiveTypeExpr
                        while (true) {
                            if (let Some(fieldAccess) <- fieldAccess(base)) {
                                base = fieldAccess
                                continue
                            }
                            if (let Some(callSuffix) <- callSuffix(base)) {
                                base = callSuffix
                                continue
                            }
                            break
                        }
                        return base
                    }
                    None
            }
        )) {
            base = e
        } else {
            return None
        }
        var expr: Expr = base
        while (true) {
            if (let Some(callSuffix) <- callSuffix(expr)) {
                expr = callSuffix
                continue
            }
            if (let Some(fieldAccess) <- fieldAccess(expr)) {
                expr = fieldAccess
                continue
            }
            if (let Some(indexAccess) <- indexAccess(expr)) {
                expr = indexAccess
                continue
            }
            break
        }
        return expr
    }

    private func atomicExpression(): ?Expr {
        if (helper.matches(TKH.LITERAL_CONSTANT)) {
            return LitConstExpr(NodeIdManager.nextId(), helper.previous())
        }
        if (let Some(ifExpr) <- ifExpression()) {
            return ifExpr
        }
        if (let Some(loop) <- loopExpression()) {
            return loop
        }
        if (let Some(jump) <- jumpExpression()) {
            return jump
        }
        if (let Some(i) <- identifierWithTypeArguments()) {
            return i
        }
        if (let Some(thisSuperExpression) <- thisSuperExpression()) {
            return thisSuperExpression
        }
        if (helper.matches(TK.LPAREN)) {
            helper.skipNL()
            if (helper.matches(TK.RPAREN)) {
                return LitConstExpr(NodeIdManager.nextId(), Token(TK.UNIT_LITERAL, "()", helper.seek(-2).pos))
            }
            let expr: Expr = expectExpression(expression, "Expect expression after '('")
            helper.skipNL()
            if (helper.matches(TK.COMMA)) {
                helper.skipNL()
                return tupleLiteral(expr)
            } else {
                helper.consume(TK.RPAREN, "Expected ')' after expression.", helper.current)
                return ParenExpr(NodeIdManager.nextId(), expr)
            }
        }
        None
    }

    private func tupleLiteral(firstExpr: Expr): ?Expr {
        let elements: ArrayList<Expr> = ArrayList()
        elements.add(firstExpr)
        do {
            helper.skipNL()
            let expr: Expr = expectExpression(expression, "Expect expression in tuple expression.")
            elements.add(expr)
            helper.skipNL()
        } while (helper.matches(TK.COMMA))
        helper.consume(TK.RPAREN, "Expect ')' after tuple expression.", helper.current)
        TupleExpr(NodeIdManager.nextId(), elements)
    }

    private func thisSuperExpression(): ?Expr {
        if (helper.matches(TKH.THIS_SUPER)) {
            return ThisSuperExpr(NodeIdManager.nextId(), helper.previous())
        }
        None
    }

    private func returnExpr(): ?Expr {
        if (!helper.matches(TK.RETURN)) {
            return None
        }
        let keyword: Token = helper.previous()
        helper.skipNL()
        // TODO: Change return Expr to always have an expression, if expression is None then put ().
        ReturnExpr(NodeIdManager.nextId(), expression(), keyword)
    }

    private func jumpExpression(): ?Expr {
        if (let Some(retExpr) <- returnExpr()) {
            return retExpr
        }
        if (helper.matches(TK.CONTINUE, TK.BREAK)) {
            return JumpExpr(NodeIdManager.nextId(), helper.previous())
        }
        None
    }
}
