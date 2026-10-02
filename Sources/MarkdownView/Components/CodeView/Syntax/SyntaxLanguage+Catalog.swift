import Foundation

extension SyntaxLanguage {
    /// Every language by the names a fence may give it.
    static let catalog: [String: SyntaxLanguage] = {
        var catalog: [String: SyntaxLanguage] = [:]
        func add(_ language: SyntaxLanguage, _ names: String) {
            for name in names.split(separator: " ") {
                catalog[String(name)] = language
            }
        }
        add(.swift, "swift")
        add(.cFamily, "c h cpp c++ cc cxx hpp hh hxx objc objective-c objectivec obj-c m mm cuda metal glsl hlsl arduino ino")
        add(.csharp, "cs csharp c# fsharp f#")
        add(.java, "java")
        add(.kotlin, "kotlin kt kts")
        add(.go, "go golang")
        add(.rust, "rust rs")
        add(.javascript, "javascript js jsx mjs cjs typescript ts tsx mts cts")
        add(.python, "python py py3 python3 gyp")
        add(.ruby, "ruby rb gemfile podfile rake")
        add(.shell, "shell sh bash zsh fish ksh console terminal shell-session sh-session bat cmd powershell ps1 ps")
        add(.sql, "sql mysql postgresql postgres psql plsql sqlite tsql")
        add(.lua, "lua")
        add(.haskell, "haskell hs elm purescript")
        add(.json, "json jsonc json5 geojson webmanifest")
        add(.yaml, "yaml yml")
        add(.toml, "toml ini cfg conf properties editorconfig gitconfig")
        add(.css, "css scss sass less styl stylus")
        add(.markup, "html htm xhtml xml svg plist xsl xslt vue svelte xaml storyboard xib")
        add(.diff, "diff patch")
        add(.dockerfile, "dockerfile docker containerfile")
        add(.makefile, "makefile make mk cmake")
        add(.php, "php")
        add(.generic, "dart scala groovy gradle zig solidity sol v nim perl pl r julia jl elixir ex exs erlang erl clojure clj ocaml ml")
        return catalog
    }()

    // MARK: - Families

    static let swift = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        quotes: [.doubleQuote],
        tripleQuotes: true,
        keywords: Set(words: """
        associatedtype class deinit enum extension fileprivate func import init inout internal let open operator \
        private precedencegroup protocol public rethrows static struct subscript typealias var break case catch \
        continue default defer do else fallthrough for guard if in repeat return throw switch where while as is \
        try await async throws some any actor nonisolated isolated mutating nonmutating override final lazy weak \
        unowned convenience required dynamic indirect get set willSet didSet macro consume borrowing consuming \
        sending package
        """),
        literals: Set(words: "true false nil self Self super"),
        declarations: Set(words: "func class struct enum protocol extension actor typealias associatedtype macro"),
        directives: true,
        annotations: true,
    )

    static let cFamily = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        singleQuoteIsCharacter: true,
        keywords: Set(words: """
        auto break case const continue default do else enum extern for goto if inline register restrict return \
        sizeof static struct switch typedef union volatile while alignas alignof asm catch class constexpr consteval \
        constinit co_await co_return co_yield decltype delete explicit export friend mutable namespace new noexcept \
        operator private protected public reinterpret_cast static_assert static_cast dynamic_cast const_cast template \
        thread_local throw try typeid typename using virtual override final concept requires __kernel __global__ \
        __device__ __host__ kernel device constant thread
        """),
        literals: Set(words: "true false NULL nullptr nil Nil YES NO self super this"),
        types: Set(words: """
        void char short int long float double signed unsigned bool size_t ssize_t ptrdiff_t int8_t int16_t int32_t \
        int64_t uint8_t uint16_t uint32_t uint64_t uintptr_t intptr_t wchar_t char8_t char16_t char32_t id \
        instancetype BOOL SEL IMP Class half float2 float3 float4 uint
        """),
        declarations: Set(words: "struct class enum union namespace"),
        directives: true,
        annotations: true,
    )

    static let csharp = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        singleQuoteIsCharacter: true,
        keywords: Set(words: """
        abstract as break case catch checked class const continue default delegate do else enum event explicit \
        extern finally fixed for foreach goto if implicit in interface internal is lock namespace new operator out \
        override params private protected public readonly ref return sealed sizeof stackalloc static struct switch \
        throw try typeof unchecked unsafe using virtual volatile while async await var dynamic get set init record \
        yield where when partial let match with type module open member
        """),
        literals: Set(words: "true false null this base"),
        types: Set(words: "bool byte char decimal double float int long object sbyte short string uint ulong ushort void nint nuint"),
        declarations: Set(words: "class struct interface enum record namespace"),
        directives: true,
    )

    static let java = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        tripleQuotes: true,
        singleQuoteIsCharacter: true,
        keywords: Set(words: """
        abstract assert break case catch class const continue default do else enum extends final finally for goto \
        if implements import instanceof interface native new package private protected public return static \
        strictfp switch synchronized throw throws transient try volatile while var record sealed permits yield
        """),
        literals: Set(words: "true false null this super"),
        types: Set(words: "boolean byte char double float int long short void"),
        declarations: Set(words: "class interface enum record"),
        annotations: true,
    )

    static let kotlin = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        tripleQuotes: true,
        singleQuoteIsCharacter: true,
        keywords: Set(words: """
        package import class interface fun val var object companion data sealed enum annotation open abstract final \
        override private protected public internal inline suspend operator infix tailrec lateinit const if else when \
        for while do return break continue throw try catch finally in is as by where init constructor typealias get \
        set reified crossinline noinline out vararg expect actual value
        """),
        literals: Set(words: "true false null this super it"),
        declarations: Set(words: "fun class interface object typealias"),
        annotations: true,
    )

    static let go = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        quotes: [.doubleQuote, .singleQuote, .backtick],
        multilineQuotes: [.backtick],
        singleQuoteIsCharacter: true,
        keywords: Set(words: """
        break case chan const continue default defer else fallthrough for func go goto if import interface map \
        package range return select struct switch type var
        """),
        literals: Set(words: "true false nil iota"),
        types: Set(words: """
        bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 \
        uint16 uint32 uint64 uintptr any
        """),
        declarations: Set(words: "func type"),
        capitalizedTypes: false,
    )

    static let rust = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        singleQuoteIsCharacter: true,
        keywords: Set(words: """
        as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move \
        mut pub ref return static struct trait type unsafe use where while macro_rules union
        """),
        literals: Set(words: "true false self Self super None Some Ok Err"),
        types: Set(words: "i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str"),
        declarations: Set(words: "fn struct enum trait type mod union macro_rules"),
        directives: true,
    )

    static let javascript = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        quotes: [.doubleQuote, .singleQuote, .backtick],
        multilineQuotes: [.backtick],
        keywords: Set(words: """
        break case catch class const continue debugger default delete do else export extends finally for function \
        if import in instanceof let new of return static switch throw try typeof var void while with yield async \
        await from as get set interface type enum implements namespace declare abstract private protected public \
        readonly keyof infer is satisfies module
        """),
        literals: Set(words: "true false null undefined this super NaN Infinity"),
        types: Set(words: "string number boolean any unknown never object symbol bigint"),
        declarations: Set(words: "function class interface type enum namespace"),
        annotations: true,
    )

    static let python = SyntaxLanguage(
        lineComments: ["#"],
        tripleQuotes: true,
        keywords: Set(words: """
        and as assert async await break class continue def del elif else except finally for from global if import \
        in is lambda nonlocal not or pass raise return try while with yield match case
        """),
        literals: Set(words: "True False None self cls"),
        types: Set(words: "int str float bool list dict set tuple bytes object complex frozenset"),
        declarations: Set(words: "def class"),
        annotations: true,
    )

    static let ruby = SyntaxLanguage(
        lineComments: ["#"],
        keywords: Set(words: """
        alias and begin break case class def defined do else elsif end ensure for if in module next not or redo \
        rescue retry return super then undef unless until when while yield require require_relative include extend \
        attr_accessor attr_reader attr_writer private public protected lambda proc
        """),
        literals: Set(words: "true false nil self"),
        declarations: Set(words: "def class module"),
    )

    static let shell = SyntaxLanguage(
        lineComments: ["#"],
        quotes: [.doubleQuote, .singleQuote, .backtick],
        multilineQuotes: [.doubleQuote, .singleQuote, .backtick],
        keywords: Set(words: """
        if then else elif fi case esac for while until do done in function select time return exit export local \
        readonly declare unset source alias break continue shift trap eval exec set
        """),
        literals: Set(words: "true false"),
        types: Set(words: """
        echo printf cd ls cat grep sed awk curl wget git sudo mkdir rm cp mv chmod chown touch find xargs tar ssh \
        brew apt yum npm npx yarn pnpm pip pip3 python python3 node swift xcodebuild make docker kubectl test read
        """),
        declarations: Set(words: "function"),
        capitalizedTypes: false,
        variables: true,
    )

    static let sql = SyntaxLanguage(
        lineComments: ["--"],
        blockComment: ("/*", "*/"),
        quotes: [.doubleQuote, .singleQuote, .backtick],
        keywords: Set(words: """
        select from where and or not insert into values update set delete create table drop alter add column index \
        view join inner left right outer full cross on as group by order having limit offset union all distinct \
        case when then else end is like in between exists primary key foreign references default unique check \
        constraint begin commit rollback transaction with returning if replace database schema grant revoke asc desc \
        cascade trigger procedure function returns declare explain analyze vacuum pragma using natural over \
        partition window
        """),
        literals: Set(words: "true false null"),
        types: Set(words: """
        int integer bigint smallint tinyint varchar char text boolean bool date time timestamp timestamptz float \
        double decimal numeric serial bigserial real blob json jsonb uuid
        """),
        foldsCase: true,
        capitalizedTypes: false,
    )

    static let lua = SyntaxLanguage(
        lineComments: ["--"],
        blockComment: ("--[[", "]]"),
        keywords: Set(words: """
        and break do else elseif end for function goto if in local not or repeat return then until while
        """),
        literals: Set(words: "true false nil self"),
        declarations: Set(words: "function"),
        capitalizedTypes: false,
    )

    static let haskell = SyntaxLanguage(
        lineComments: ["--"],
        blockComment: ("{-", "-}"),
        quotes: [.doubleQuote],
        keywords: Set(words: """
        case class data deriving do else if import in infix infixl infixr instance let module newtype of then type \
        where qualified hiding exposing port alias
        """),
        literals: Set(words: "True False"),
    )

    static let json = SyntaxLanguage(
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        quotes: [.doubleQuote],
        literals: Set(words: "true false null"),
        capitalizedTypes: false,
        keySeparator: .colon,
    )

    static let yaml = SyntaxLanguage(
        lineComments: ["#"],
        literals: Set(words: "true false null yes no on off True False Null Yes No"),
        capitalizedTypes: false,
        keySeparator: .colon,
        hyphenatedWords: true,
    )

    static let toml = SyntaxLanguage(
        lineComments: ["#", ";"],
        tripleQuotes: true,
        literals: Set(words: "true false"),
        capitalizedTypes: false,
        keySeparator: .equals,
        hyphenatedWords: true,
    )

    /// No `//` comments: SCSS has them, but plain CSS has unquoted URLs.
    static let css = SyntaxLanguage(
        blockComment: ("/*", "*/"),
        literals: Set(words: "important inherit initial unset auto none transparent currentColor"),
        capitalizedTypes: false,
        annotations: true,
        keySeparator: .colon,
        hyphenatedWords: true,
    )

    static let markup = SyntaxLanguage(mode: .markup)

    static let diff = SyntaxLanguage(mode: .diff)

    static let dockerfile = SyntaxLanguage(
        lineComments: ["#"],
        multilineQuotes: [],
        keywords: Set(words: """
        from run cmd label expose env add copy entrypoint volume user workdir arg onbuild stopsignal healthcheck \
        shell as maintainer
        """),
        foldsCase: true,
        capitalizedTypes: false,
        variables: true,
    )

    static let makefile = SyntaxLanguage(
        lineComments: ["#"],
        keywords: Set(words: """
        ifeq ifneq ifdef ifndef else endif include define endef export override unexport vpath \
        add_executable add_library project \
        set if elseif endif foreach endforeach function endfunction option message find_package
        """),
        capitalizedTypes: false,
        variables: true,
    )

    static let php = SyntaxLanguage(
        lineComments: ["//", "#"],
        blockComment: ("/*", "*/"),
        keywords: Set(words: """
        abstract and as break case catch class clone const continue declare default do echo else elseif empty \
        enddeclare endfor endforeach endif endswitch endwhile extends final finally fn for foreach function global \
        goto if implements include include_once instanceof insteadof interface isset list match namespace new or \
        print private protected public readonly require require_once return static switch throw trait try unset use \
        var while xor yield
        """),
        literals: Set(words: "true false null TRUE FALSE NULL this self parent"),
        declarations: Set(words: "function class interface trait enum fn"),
        variables: true,
    )

    /// For a named language this catalog does not know: the comments, strings
    /// and keywords most languages share.
    static let generic = SyntaxLanguage(
        lineComments: ["//", "#"],
        blockComment: ("/*", "*/"),
        quotes: [.doubleQuote, .singleQuote, .backtick],
        keywords: Set(words: """
        if else elif elsif for foreach while do return function func def fn fun defn class struct enum interface \
        trait impl import export from let var val const public private protected static new try catch finally throw \
        switch case default break continue in is as package module use using namespace type async await yield end \
        then match when with extends implements and or not
        """),
        literals: Set(words: "true false null nil none undefined self this True False None"),
        declarations: Set(words: "function func def fn fun defn class struct enum interface trait"),
    )
}
