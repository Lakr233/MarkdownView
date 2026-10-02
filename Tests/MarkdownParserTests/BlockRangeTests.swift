import MarkdownParser
import Testing

struct BlockRangeTests {
    @Test
    func `Block ranges cover full ASCII blocks`() throws {
        let markdown = "# Hi\n\nHello world"
        let ranges = MarkdownParser().parseBlockRange(markdown)

        #expect(ranges.count == 2)
        let heading = try #require(ranges.first)
        let paragraph = try #require(ranges.last)
        #expect(String(markdown[heading.startIndex ..< heading.endIndex]) == "# Hi")
        #expect(String(markdown[paragraph.startIndex ..< paragraph.endIndex]) == "Hello world")
    }

    @Test
    func `Block ranges use UTF-8 byte columns for non-ASCII text`() throws {
        let markdown = "# 你好🌍\n\n段落 emoji 🎉 end"
        let ranges = MarkdownParser().parseBlockRange(markdown)

        #expect(ranges.count == 2)
        let heading = try #require(ranges.first)
        let paragraph = try #require(ranges.last)
        #expect(String(markdown[heading.startIndex ..< heading.endIndex]) == "# 你好🌍")
        #expect(String(markdown[paragraph.startIndex ..< paragraph.endIndex]) == "段落 emoji 🎉 end")
    }
}
