import XCTest
@testable import ZipPlugin

final class UnzipperTests: XCTestCase {
    private var temp: URL!

    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temp)
    }

    // The fixtures are shared with the Android tests, in test/fixtures at the repository root. A simulator reads the
    // host's file system, so the path of this source file finds them.
    private func fixture(_ name: String) throws -> URL {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("test/fixtures/\(name)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "missing fixture \(url.path)")
        return url
    }

    private func expectCode(_ code: String, _ block: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try block(), file: file, line: line) { error in
            XCTAssertEqual((error as? UnzipError)?.code, code, "\(error)", file: file, line: line)
        }
    }

    private func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func testExtractsFilesAndDirectories() throws {
        let out = temp.appendingPathComponent("out")
        var events: [[Int]] = []
        let count = try Unzipper.unzip(source: try fixture("basic.zip"), destination: out) { events.append([$0, $1]) }

        XCTAssertEqual(count, 5)
        XCTAssertEqual(try read(out.appendingPathComponent("hello.txt")), "Hello, zip!\n")
        XCTAssertEqual(try read(out.appendingPathComponent("www/index.html")), "<!doctype html><title>t</title>\n")
        XCTAssertEqual(try read(out.appendingPathComponent("www/js/app.js")),
                       String(repeating: "console.log(\"app\");\n", count: 50))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("empty").path,
                                                     isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(events, (1...5).map { [$0, 5] })
    }

    func testAcceptsAFileUrlAndAPath() throws {
        let out = temp.appendingPathComponent("url out")
        let source = try Unzipper.resolve(try fixture("basic.zip").absoluteString, name: "source")
        let destination = try Unzipper.resolve(out.absoluteString, name: "destination")
        XCTAssertEqual(destination.path, out.path)
        XCTAssertEqual(try Unzipper.resolve(out.path, name: "destination").path, out.path)
        try Unzipper.unzip(source: source, destination: destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("hello.txt").path))
    }

    func testRefusesRelativeAndForeignPaths() {
        expectCode("INVALID_ARGUMENT") { _ = try Unzipper.resolve("relative/a.zip", name: "source") }
        expectCode("INVALID_ARGUMENT") { _ = try Unzipper.resolve("https://example.com/a.zip", name: "source") }
        expectCode("INVALID_ARGUMENT") { _ = try Unzipper.resolve("", name: "source") }
        expectCode("INVALID_ARGUMENT") { _ = try Unzipper.resolve(nil, name: "source") }
    }

    func testRefusesZipSlipAndWritesNothing() throws {
        let parent = temp.appendingPathComponent("parent")
        let out = parent.appendingPathComponent("out")
        let slip = try fixture("slip.zip")
        expectCode("UNSAFE_ENTRY") { try Unzipper.unzip(source: slip, destination: out) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: parent.appendingPathComponent("evil.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.appendingPathComponent("safe.txt").path),
                       "the safe entry must not be written either")
    }

    func testRefusesAnAbsoluteEntry() throws {
        let absolute = try fixture("absolute.zip")
        expectCode("UNSAFE_ENTRY") { try Unzipper.unzip(source: absolute, destination: self.temp.appendingPathComponent("out")) }
    }

    func testFlagsUnsafeNames() {
        XCTAssertTrue(Unzipper.isUnsafeEntryName("../a"))
        XCTAssertTrue(Unzipper.isUnsafeEntryName("a/../../b"))
        XCTAssertTrue(Unzipper.isUnsafeEntryName("..\\a"))
        XCTAssertTrue(Unzipper.isUnsafeEntryName("/etc/passwd"))
        XCTAssertFalse(Unzipper.isUnsafeEntryName("a/b..c/d"))
        XCTAssertFalse(Unzipper.isUnsafeEntryName("..a"))
    }

    func testReportsAMissingSource() {
        expectCode("NOT_FOUND") {
            try Unzipper.unzip(source: self.temp.appendingPathComponent("nope.zip"),
                               destination: self.temp.appendingPathComponent("out"))
        }
    }

    func testReportsSomethingThatIsNotAZip() throws {
        let bad = try fixture("not-a-zip.zip")
        expectCode("BAD_ARCHIVE") { try Unzipper.unzip(source: bad, destination: self.temp.appendingPathComponent("out")) }
    }

    func testOverwritesByDefaultAndRefusesWhenAskedNotTo() throws {
        let out = temp.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let hello = out.appendingPathComponent("hello.txt")
        try "old".write(to: hello, atomically: true, encoding: .utf8)
        try Unzipper.unzip(source: try fixture("basic.zip"), destination: out)
        XCTAssertEqual(try read(hello), "Hello, zip!\n")

        try "old".write(to: hello, atomically: true, encoding: .utf8)
        let basic = try fixture("basic.zip")
        expectCode("EXISTS") { try Unzipper.unzip(source: basic, destination: out, overwrite: false) }
        XCTAssertEqual(try read(hello), "old")
    }
}
