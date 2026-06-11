import Testing
@testable import copippe

@Suite("String singleLinePreview Tests")
struct StringPreviewTests {

    @Test("Newlines are flattened to spaces")
    func flattensNewlines() {
        #expect("a\nb".singleLinePreview(maxLength: 50) == "a b")
    }

    @Test("Short text is returned unchanged")
    func shortText() {
        #expect("hello".singleLinePreview(maxLength: 50) == "hello")
    }

    @Test("Long text is truncated with ellipsis")
    func truncatesLongText() {
        let text = String(repeating: "x", count: 60)
        let preview = text.singleLinePreview(maxLength: 50)
        #expect(preview == String(repeating: "x", count: 50) + "...")
    }

    @Test("Text exactly at max length is not truncated")
    func exactMaxLengthText() {
        let text = String(repeating: "x", count: 50)
        #expect(text.singleLinePreview(maxLength: 50) == text)
    }

    @Test("Text one character over max length is truncated")
    func oneCharacterOverMaxLengthText() {
        let text = String(repeating: "x", count: 51)
        #expect(text.singleLinePreview(maxLength: 50) == String(repeating: "x", count: 50) + "...")
    }
}
