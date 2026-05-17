import XCTest
@testable import claude_notify

final class IPCMessageTests: XCTestCase {
    func testRoundTripWithAllFields() throws {
        let original = IPCMessage(
            title: "Title",
            message: "Body",
            sound: true,
            activate: "com.apple.Terminal",
            url: "vscode://file//Users/me/project"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IPCMessage.self, from: data)

        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertEqual(decoded.sound, original.sound)
        XCTAssertEqual(decoded.activate, original.activate)
        XCTAssertEqual(decoded.url, original.url)
    }

    func testRoundTripWithNilOptionals() throws {
        let original = IPCMessage(
            title: "T",
            message: "M",
            sound: false,
            activate: nil,
            url: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IPCMessage.self, from: data)

        XCTAssertNil(decoded.activate)
        XCTAssertNil(decoded.url)
        XCTAssertEqual(decoded.sound, false)
    }

    func testRoundTripPreservesUnicode() throws {
        let original = IPCMessage(
            title: "Café \u{1F389}",
            message: "Done: 100% ✓ — but no em-dash anywhere else",
            sound: true,
            activate: nil,
            url: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IPCMessage.self, from: data)

        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.message, original.message)
    }

    func testDecodeFailsOnMissingRequiredField() {
        let payload = #"{"title":"T","sound":true}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(IPCMessage.self, from: payload))
    }
}
