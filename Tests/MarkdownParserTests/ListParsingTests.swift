import MarkdownParser
import Testing

struct ListParsingTests {
    @Test("Lists mixing task and plain items stay homogeneous")
    func listsMixingTaskAndPlainItemsStayHomogeneous() throws {
        let result = MarkdownParser().parse("""
        - [ ] task
        - plain
        - [x] done
        """)

        #expect(result.document.count == 3)
        guard result.document.count == 3 else { return }

        guard case let .taskList(_, firstItems) = result.document[0] else {
            Issue.record("Expected first segment to be a task list")
            return
        }
        guard case let .bulletedList(_, plainItems) = result.document[1] else {
            Issue.record("Expected middle segment to be a plain bulleted list")
            return
        }
        guard case let .taskList(_, lastItems) = result.document[2] else {
            Issue.record("Expected last segment to be a task list")
            return
        }

        #expect(firstItems.count == 1)
        #expect(firstItems.first?.isCompleted == false)
        #expect(plainItems.count == 1)
        #expect(lastItems.count == 1)
        #expect(lastItems.first?.isCompleted == true)
    }
}
