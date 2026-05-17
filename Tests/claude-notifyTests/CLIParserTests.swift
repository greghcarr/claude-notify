import XCTest
@testable import claude_notify

final class CLIParserTests: XCTestCase {
    func testEmptyArgsDefaultsToDaemonMode() {
        let parsed = run([])
        XCTAssertTrue(parsed.daemonMode)
        XCTAssertEqual(parsed.args.message, "")
    }

    func testDaemonFlagSetsDaemonMode() {
        let parsed = run(["--daemon"])
        XCTAssertTrue(parsed.daemonMode)
    }

    func testShortDaemonFlagSetsDaemonMode() {
        let parsed = run(["-d"])
        XCTAssertTrue(parsed.daemonMode)
    }

    func testMessageFlag() {
        let parsed = run(["-m", "hello"])
        XCTAssertFalse(parsed.daemonMode)
        XCTAssertEqual(parsed.args.message, "hello")
    }

    func testLongMessageFlag() {
        let parsed = run(["--message", "hello"])
        XCTAssertEqual(parsed.args.message, "hello")
    }

    func testTitleFlag() {
        let parsed = run(["-m", "x", "-t", "Custom"])
        XCTAssertEqual(parsed.args.title, "Custom")
    }

    func testTitleDefaultsToConstantsValue() {
        let parsed = run(["-m", "x"])
        XCTAssertEqual(parsed.args.title, Constants.Defaults.title)
    }

    func testActivateFlag() {
        let parsed = run(["-m", "x", "-a", "com.apple.Terminal"])
        XCTAssertEqual(parsed.args.activate, "com.apple.Terminal")
    }

    func testUrlFlag() {
        let parsed = run(["-m", "x", "-u", "https://example.com"])
        XCTAssertEqual(parsed.args.url, "https://example.com")
    }

    func testUrlAndActivateCoexist() {
        let parsed = run(["-m", "x", "-a", "com.apple.Terminal", "-u", "vscode://file//x"])
        XCTAssertEqual(parsed.args.activate, "com.apple.Terminal")
        XCTAssertEqual(parsed.args.url, "vscode://file//x")
    }

    func testNoSoundFlag() {
        let parsed = run(["-m", "x", "--no-sound"])
        XCTAssertFalse(parsed.args.sound)
    }

    func testSoundDefaultsTrue() {
        let parsed = run(["-m", "x"])
        XCTAssertTrue(parsed.args.sound)
    }

    func testPositionalBecomesMessageWhenMessageEmpty() {
        let parsed = run(["hello"])
        XCTAssertEqual(parsed.args.message, "hello")
    }

    func testPositionalIgnoredAfterMessageSet() {
        let parsed = run(["-m", "first", "ignored"])
        XCTAssertEqual(parsed.args.message, "first")
    }

    func testVersionReturnsPrintAndExit() {
        let result = CLIParser.parse(["--version"])
        guard case .printAndExit(let output) = result else {
            XCTFail("expected .printAndExit, got \(result)")
            return
        }
        XCTAssertTrue(output.contains("claude-notify"))
        XCTAssertTrue(output.contains(AppVersion.current))
    }

    func testHelpReturnsPrintAndExit() {
        let result = CLIParser.parse(["--help"])
        guard case .printAndExit(let output) = result else {
            XCTFail("expected .printAndExit, got \(result)")
            return
        }
        XCTAssertTrue(output.contains("Usage:"))
        XCTAssertTrue(output.contains("--url"))
        XCTAssertTrue(output.contains("--version"))
    }

    func testShortHelpReturnsPrintAndExit() {
        let result = CLIParser.parse(["-h"])
        guard case .printAndExit = result else {
            XCTFail("expected .printAndExit, got \(result)")
            return
        }
    }

    func testHelpTextInterpolatesDefaultTitle() {
        let result = CLIParser.parse(["--help"])
        guard case .printAndExit(let output) = result else {
            XCTFail("expected .printAndExit")
            return
        }
        XCTAssertTrue(output.contains(Constants.Defaults.title))
    }

    func testCombinedDaemonAndMessageStillRuns() {
        let parsed = run(["--daemon", "-m", "boot"])
        XCTAssertTrue(parsed.daemonMode)
        XCTAssertEqual(parsed.args.message, "boot")
    }

    private struct Parsed {
        let args: NotificationArgs
        let daemonMode: Bool
    }

    private func run(_ args: [String], file: StaticString = #file, line: UInt = #line) -> Parsed {
        let result = CLIParser.parse(args)
        guard case .run(let parsedArgs, let daemon) = result else {
            XCTFail("expected .run, got \(result)", file: file, line: line)
            return Parsed(args: NotificationArgs(), daemonMode: false)
        }
        return Parsed(args: parsedArgs, daemonMode: daemon)
    }
}
