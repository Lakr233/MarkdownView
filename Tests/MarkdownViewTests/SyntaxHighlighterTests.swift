import Foundation
@testable import MarkdownView
import Testing

/// The highlighter is approximate by design; these pin what it must get right
/// for code to read well, and that every language it knows colours something.
struct SyntaxHighlighterTests {
    /// The highlighted pieces of `code`, in order, as text and kind.
    private func tokens(_ code: String, _ language: String?) -> [(text: String, token: SyntaxToken)] {
        let map = SyntaxHighlighter.highlight(code, language: language)
        let text = code as NSString
        let kinds: [SyntaxToken] = [.comment, .keyword, .string, .number, .type, .attribute, .meta, .variable]
        return map.keys.sorted { $0.location < $1.location }.compactMap { range in
            guard let color = map[range], let kind = kinds.first(where: { $0.color == color }) else { return nil }
            return (text.substring(with: range), kind)
        }
    }

    private func kind(of piece: String, in code: String, _ language: String?) -> SyntaxToken? {
        tokens(code, language).first { $0.text == piece }?.token
    }

    @Test("Swift reads as Xcode colours it")
    func swiftTokens() {
        let code = """
        @MainActor
        func load(_ query: String) -> Int {
            return 42 // done
        }
        let name = "a \\"quoted\\" word"
        """
        #expect(kind(of: "@MainActor", in: code, "swift") == .meta)
        #expect(kind(of: "func", in: code, "swift") == .keyword)
        #expect(kind(of: "load", in: code, "swift") == .number)
        #expect(kind(of: "String", in: code, "swift") == .type)
        #expect(kind(of: "return", in: code, "swift") == .keyword)
        #expect(kind(of: "42", in: code, "swift") == .number)
        #expect(kind(of: "// done", in: code, "swift") == .comment)
        #expect(kind(of: "\"a \\\"quoted\\\" word\"", in: code, "swift") == .string)
        #expect(kind(of: "query", in: code, "swift") == nil)
    }

    @Test(
        "Every language in the catalog colours its sample",
        arguments: [
            ("swift", "let x = 1"),
            ("c", "#include <stdio.h>\nint main(void) { return 0; }"),
            ("cpp", "template <typename T> class Box {};"),
            ("objc", "@interface Foo : NSObject\n@end"),
            ("csharp", "public class Foo { int x = 1; }"),
            ("java", "public static void main(String[] args) {}"),
            ("kotlin", "fun main() { val x = 1 }"),
            ("go", "func main() { fmt.Println(\"hi\") }"),
            ("rust", "fn main() { let x: i32 = 1; }"),
            ("javascript", "const x = `hi ${name}`;"),
            ("typescript", "interface Foo { bar: string }"),
            ("python", "def main():\n    return None"),
            ("ruby", "def main\n  puts 'hi'\nend"),
            ("bash", "if [ -f \"$FILE\" ]; then echo ok; fi"),
            ("sql", "SELECT id FROM users WHERE id = 1;"),
            ("lua", "local x = nil -- none"),
            ("haskell", "main = putStrLn \"hi\" -- greet"),
            ("json", "{\"id\": 1, \"ok\": true}"),
            ("yaml", "name: app\nreplicas: 3"),
            ("toml", "[package]\nname = \"app\""),
            ("css", ".a { color: #fff; margin: 0 auto; }"),
            ("html", "<div class=\"a\">text</div>"),
            ("diff", "-old\n+new"),
            ("dockerfile", "FROM swift:6.2\nRUN swift build"),
            ("makefile", "all:\n\techo $(CC) # build"),
            ("php", "<?php echo $name; ?>"),
            ("dart", "void main() { print('hi'); }"),
            ("unknown-language", "if (x) { return 1; }"),
        ]
    )
    func everyLanguageColours(language: String, code: String) {
        #expect(!SyntaxHighlighter.highlight(code, language: language).isEmpty)
    }

    @Test("A block that names no language is still highlighted")
    func unlabelledBlockIsHighlighted() {
        #expect(!SyntaxHighlighter.highlight("let x = \"a\" // b", language: nil).isEmpty)
        #expect(!SyntaxHighlighter.highlight("let x = \"a\" // b", language: "").isEmpty)
    }

    @Test("Plain text stays uncoloured")
    func plainTextIsUncoloured() {
        for language in ["text", "plaintext", "txt", "output", "markdown"] {
            #expect(SyntaxHighlighter.highlight("let x = \"a\" // b", language: language).isEmpty)
        }
    }

    @Test("Language names are read from the first word, in any case")
    func languageNameIsNormalised() {
        #expect(kind(of: "func", in: "func a()", "Swift title=\"A\"") == .keyword)
    }

    @Test("A Rust lifetime is not a string, a character literal is")
    func rustLifetimes() {
        let code = "fn f<'a>(x: &'a str) -> char { 'x' }"
        let strings = tokens(code, "rust").filter { $0.token == .string }.map(\.text)
        #expect(strings == ["'x'"])
    }

    @Test("A stray apostrophe does not swallow the rest of the line")
    func strayApostrophe() {
        let code = "x = it's + 1"
        #expect(kind(of: "1", in: code, "swift") == .number)
    }

    @Test("JSON keys and values take different colours")
    func jsonKeys() {
        let code = "{\"name\": \"value\", \"n\": 1, \"ok\": null}"
        #expect(kind(of: "\"name\"", in: code, "json") == .attribute)
        #expect(kind(of: "\"value\"", in: code, "json") == .string)
        #expect(kind(of: "1", in: code, "json") == .number)
        #expect(kind(of: "null", in: code, "json") == .keyword)
    }

    @Test("YAML keys, including hyphenated ones")
    func yamlKeys() {
        let code = "app-name: demo # the name\nreplicas: 3"
        #expect(kind(of: "app-name", in: code, "yaml") == .attribute)
        #expect(kind(of: "# the name", in: code, "yaml") == .comment)
        #expect(kind(of: "3", in: code, "yaml") == .number)
    }

    @Test("An unterminated comment or docstring runs to the end while streaming")
    func unterminatedRunsToEnd() {
        #expect(kind(of: "/* still typing", in: "a /* still typing", "swift") == .comment)
        #expect(kind(of: "\"\"\"doc\nmore", in: "x = \"\"\"doc\nmore", "python") == .string)
    }

    @Test("Ranges are UTF-16 offsets")
    func utf16Ranges() {
        let code = "let 名字 = \"中文😀\" // 注释"
        #expect(kind(of: "\"中文😀\"", in: code, "swift") == .string)
        #expect(kind(of: "// 注释", in: code, "swift") == .comment)
        #expect(kind(of: "名字", in: code, "swift") == nil)
    }

    @Test("Numbers, and ranges between them")
    func numbers() {
        let pieces = tokens("a = 0x1F + 2.5e-3 + 1_000; for i in 1..5 {}", "swift")
            .filter { $0.token == .number }
            .map(\.text)
        #expect(pieces == ["0x1F", "2.5e-3", "1_000", "1", "5"])
    }

    @Test("SQL keywords match in any case")
    func sqlFoldsCase() {
        #expect(kind(of: "SELECT", in: "SELECT 1", "sql") == .keyword)
        #expect(kind(of: "select", in: "select 1", "sql") == .keyword)
        #expect(kind(of: "-- note", in: "select 1 -- note", "sql") == .comment)
    }

    @Test("Shell variables, and a hash inside one, which is not a comment")
    func shellVariables() {
        let code = "echo $HOME ${name} $# # done"
        #expect(kind(of: "$HOME", in: code, "bash") == .variable)
        #expect(kind(of: "${name}", in: code, "bash") == .variable)
        #expect(kind(of: "$#", in: code, "bash") == .variable)
        #expect(kind(of: "# done", in: code, "bash") == .comment)
    }

    @Test("Markup colours tags and attributes, not the text between them")
    func markup() {
        let code = "<!-- note --><div class=\"a\">it's text</div>"
        #expect(kind(of: "<!-- note -->", in: code, "html") == .comment)
        #expect(kind(of: "div", in: code, "html") == .keyword)
        #expect(kind(of: "class", in: code, "html") == .attribute)
        #expect(kind(of: "\"a\"", in: code, "html") == .string)
        #expect(tokens(code, "html").allSatisfy { !$0.text.contains("text") })
    }

    @Test("C directives and Rust attributes are meta")
    func directives() {
        #expect(kind(of: "#include", in: "#include <stdio.h>", "c") == .meta)
        #expect(kind(of: "#  define", in: "#  define X 1", "c") == .meta)
        #expect(kind(of: "#[derive(Debug)]", in: "#[derive(Debug)]\nstruct A;", "rust") == .meta)
    }

    @Test("Diff lines take the colour of what they do")
    func diff() {
        let code = "@@ -1 +1 @@\n-old\n+new\n same"
        #expect(kind(of: "@@ -1 +1 @@", in: code, "diff") == .meta)
        #expect(kind(of: "-old", in: code, "diff") == .string)
        #expect(kind(of: "+new", in: code, "diff") == .comment)
        #expect(kind(of: " same", in: code, "diff") == nil)
    }
}
