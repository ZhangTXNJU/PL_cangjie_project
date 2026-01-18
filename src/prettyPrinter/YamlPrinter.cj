package cjcj.prettyPrinter

import cjcj.scanner.{Token, TokenKind}
import std.ast.Position

public interface YamlPrintable {
    func yamlPrint(printer: YamlPrinter): Unit
}

public class YamlPrinter {
    private var indentation: Int64 = 0
    private let printer: PrettyPrinter = PrettyPrinter(tabSize: 2)
    private var atObjectStart: Bool = true
    private var atListItemStart: Bool = false

    private func printlnIfNeeded(): Unit {
        if (atObjectStart) {
            atObjectStart = false
            if (atListItemStart) {
                atListItemStart = false
                printer.indent()
            }
        } else {
            printer.append("\n")
        }
    }

    public func printObject(key: String, obj: YamlPrintable): Unit {
        printlnIfNeeded()
        printer.append(key + ":")
        printer.indent()
        printer.append("\n")
        atObjectStart = true
        obj.yamlPrint(this)
        atObjectStart = false
        printer.unindent()
    }

    public func printOptionalObject<T>(key: String, obj: ?T): Unit where T <: YamlPrintable {
        if (let Some(o) <- obj) {
            printObject(key, o)
        } else {
            printlnIfNeeded()
            printer.append(key + ": null")
        }
    }

    public func printList<T>(key: String, objs: Iterable<T>): Unit where T <: YamlPrintable {
        printlnIfNeeded()
        if (objs.iterator().isEmpty()) {
            printer.append(key + ": []")
            return
        }
        printer.append(key + ":")
        objs.iterator().forEach(
            {
                o =>
                    printer.append("\n- ")
                    atObjectStart = true
                    atListItemStart = true
                    o.yamlPrint(this)
                    if (atListItemStart) {
                        printer.append("{}")
                        atListItemStart = false
                    } else {
                        printer.unindent()
                    }
                    atObjectStart = false
            }
        )
    }

    public func printList(key: String, tokens: Iterable<Token>): Unit {
        printlnIfNeeded()
        if (tokens.iterator().isEmpty()) {
            printer.append("${key}: []")
            return
        }
        printer.append(key + ":")
        printer.indent()
        tokens.iterator().forEach(
            {
                p =>
                    printer.append("\n- ")
                    printer.append(formatValue(p.value, false))
                    printPosition(p.pos)
            }
        )
        printer.unindent()
    }

    public func print(key: String, token: Token): Unit {
        print(key, token.value)
        printPosition(token.pos)
    }

    private static func formatValue(value: String, enforceQuoting: Bool): String {
        if (!enforceQuoting && value.runes().all({r => r.isAsciiNumberOrLetter()})) {
            value
        } else if (value.contains("\n") || value.contains("\t") || value.contains("'")) {
            '\"${value.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t").replace('"', '\\"')}\"'
        } else {
            "'${value}'"
        }
    }

    public func print(key: String, value: ToString, enforceQuoting!: Bool = false): Unit {
        printRaw(key, formatValue(value.toString(), enforceQuoting))
    }

    public func printLiteral(key: String, literal: Token): Unit {
        match (literal.kind) {
            case TokenKind.STRING_LITERAL => print(key, literal.value, enforceQuoting: true)
            case _ => print(key, literal.value)
        }
        printPosition(literal.pos)
    }

    private func printRaw(key: String, rawValue: String): Unit {
        printlnIfNeeded()
        printer.append("${key}: ${rawValue}")
    }

    private func printPosition(pos: Position): Unit {
        printer.append(" # Position: ${pos.line}:${pos.column}")
    }

    public func toString(): String {
        printer.toString()
    }
}
