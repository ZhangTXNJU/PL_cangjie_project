package cjcj.executor

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import std.collection.{HashMap, HashSet, ArrayList}

/**
 * Type checker for the OOP language
 */
public class TypeChecker <: Visitor<Unit> {
    private let symbolTable_: HashMap<String, Decl>
    private var currentClass_: ?ClassDecl
    private let errors_: ArrayList<String>

    public init() {
        symbolTable_ = HashMap<String, Decl>()
        currentClass_ = None
        errors_ = ArrayList<String>()
    }

    public func typeCheck(program: Program): ArrayList<String> {
        // First pass: collect all declarations
        for (decl in program.decls) {
            collectDeclaration(decl)
        }

        // Second pass: check types
        for (decl in program.decls) {
            decl.traverse(this)
        }

        return errors_
    }

    private func collectDeclaration(decl: Decl): Unit {
        if (decl is ClassDecl) {
            let classDecl = (decl as ClassDecl).getOrThrow()
                let name = classDecl.identifier.value
                match (symbolTable_.get(name)) {
                    case Some(_) => errors_.add("Duplicate class definition: ${name}")
                    case None => symbolTable_[name] = classDecl
                }
        } else if (decl is InterfaceDecl) {
            let interfaceDecl = (decl as InterfaceDecl).getOrThrow()
                let name = interfaceDecl.identifier.value
                match (symbolTable_.get(name)) {
                    case Some(_) => errors_.add("Duplicate interface definition: ${name}")
                    case None => symbolTable_[name] = interfaceDecl
                }
        } else if (decl is FuncDecl) {
            let funcDecl = (decl as FuncDecl).getOrThrow()
            let name = funcDecl.identifier.value
            // Functions can be overloaded, so we don't check duplicates here
            symbolTable_[name] = funcDecl
        } else if (decl is VarDecl) {
            let varDecl = (decl as VarDecl).getOrThrow()
                let name = varDecl.identifier.value
                match (symbolTable_.get(name)) {
                    case Some(_) => errors_.add("Duplicate variable definition: ${name}")
                    case None => symbolTable_[name] = varDecl
                }
        }
    }

    // Visitor methods implementation
    public open override func visit(program: Program): Unit {
        for (decl in program.decls) {
            decl.traverse(this)
        }
    }

    public open override func visit(classDecl: ClassDecl): Unit {
        let savedClass = currentClass_
        currentClass_ = Some(classDecl)

        // Check super types
        for (superType in classDecl.superTypes) {
            checkSuperType(superType, classDecl)
        }

        // Check class body
        classDecl.body.traverse(this)

        currentClass_ = savedClass
    }

    public open override func visit(interfaceDecl: InterfaceDecl): Unit {
        // Check super types
        for (superType in interfaceDecl.superTypes) {
            checkSuperType(superType, interfaceDecl)
        }

        // Check interface body
        interfaceDecl.body.traverse(this)
    }

    private func checkSuperType(superType: TypeNode, currentDecl: Decl): Unit {
        if (superType is RefType) {
            let refType = (superType as RefType).getOrThrow()
            let typeName = refType.typeName.value
            match (symbolTable_.get(typeName)) {
                case Some(_) =>
                    let superDecl = symbolTable_[typeName]
                    if (superDecl is ClassDecl && currentDecl is ClassDecl) {
                        let superClass = (superDecl as ClassDecl).getOrThrow()
                        if (!isClassExtensible(superClass)) {
                            errors_.add("Class ${typeName} is not extensible")
                        }
                    }
                    // Interfaces are always extensible, no check needed
                case None => errors_.add("Undefined super type: ${typeName}")
            }
        }
    }

    private func isClassExtensible(classDecl: ClassDecl): Bool {
        // Check if class has 'open' modifier
        for (modifier in classDecl.modifiers) {
            if (modifier.keyword.kind == TokenKind.OPEN) {
                return true
            }
        }
        return false
    }

    public open override func visit(funcDecl: FuncDecl): Unit {
        // Check function body if present
        if (let Some(body) <- funcDecl.block) {
            body.traverse(this)
        }
    }

    public open override func visit(varDecl: VarDecl): Unit {
        // Check initializer type matches declared type
        match (varDecl.initializer) {
            case Some(initExpr) => initExpr.traverse(this)
            case None => ()
        }
    }

    public open override func visit(body: Body): Unit {
        for (decl in body.decls) {
            decl.traverse(this)
        }
    }

    // Basic expression checking - simplified for now
    public open override func visit(_: BinaryExpr): Unit {}
    public open override func visit(_: UnaryExpr): Unit {}
    public open override func visit(_: LitConstExpr): Unit {}
    public open override func visit(_: RefExpr): Unit {}
    public open override func visit(_: AssignExpr): Unit {}
    public open override func visit(_: Block): Unit {}
    public open override func visit(_: IfExpr): Unit {}
    public open override func visit(_: WhileExpr): Unit {}
    public open override func visit(_: CallExpr): Unit {}
    public open override func visit(_: ReturnExpr): Unit {}
    public open override func visit(_: JumpExpr): Unit {}

    // Other visitor methods - to be implemented
    public open override func visit(_: ParenExpr): Unit {}
    public open override func visit(_: MainDecl): Unit {}
    public open override func visit(_: Argument): Unit {}
    public open override func visit(_: TypeNode): Unit {}
    public open override func visit(_: PrimitiveType): Unit {}
    public open override func visit(_: RefType): Unit {}
    public open override func visit(_: FuncType): Unit {}
    public open override func visit(_: TupleType): Unit {}
    public open override func visit(_: VariableReference): Unit {}
    public open override func visit(_: FuncReference): Unit {}
    public open override func visit(_: ClassReference): Unit {}
    public open override func visit(_: VarDeclWithRef): Unit {}
    public open override func visit(_: FuncDeclWithRef): Unit {}
    public open override func visit(_: MainDeclWithRef): Unit {}
    public open override func visit(_: ClassDeclWithRef): Unit {}
    public open override func visit(_: MemberAccess): Unit {}
    public open override func visit(_: IndexAccess): Unit {}
    public open override func visit(_: PrimitiveTypeExpr): Unit {}
    public open override func visit(_: RefExprWithRef): Unit {}
    public open override func visit(_: ThisSuperExpr): Unit {}
    public open override func visit(_: ThisSuperReference): Unit {}
    public open override func visit(_: CallExprWithRef): Unit {}
    public open override func visit(_: MemberAccessWithRef): Unit {}
    public open override func visit(_: FuncParam): Unit {}
    public open override func visit(_: InterfaceDeclWithRef): Unit {}
    public open override func visit(_: InterfaceReference): Unit {}
}