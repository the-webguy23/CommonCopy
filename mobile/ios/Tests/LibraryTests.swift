import XCTest
@testable import CommonCopyMobileCore
final class LibraryTests: XCTestCase {
    func fixture() throws -> LibraryDocument {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures/desktop-library.json")
        return try LibraryDocument(data: Data(contentsOf: url))
    }
    func testDesktopRoundTrip() throws {
        let copy = try LibraryDocument(data: fixture().data())
        XCTAssertEqual(copy.phrases.first?.text, "Hello,\n世界 👋")
        XCTAssertEqual((copy.raw["Settings"] as? [String: Any])?["FutureSetting"] as? String, "preserve-me")
    }
    func testDisabledPhrasesAndCategoriesAreHidden() throws { XCTAssertEqual(try fixture().visible(filter: "all").count, 1) }
    func testNestedCategoriesAndSearch() throws { let lib = try fixture(); XCTAssertEqual(lib.categoryPath("22222222-2222-4222-8222-222222222222"), "Prompts / GPT"); XCTAssertEqual(lib.visible(filter: "all", query: "世界").count, 1) }
    func testEditingPreservesUsageAndCreation() throws {
        var lib = try fixture(); let id = lib.phrases[0].id; lib.used(id: id)
        try lib.save(id: id, title: "Edited", text: "New", categoryID: lib.categories[0].id, favorite: false)
        XCTAssertEqual(lib.phrases[0].useCount, 3)
        XCTAssertEqual((lib.raw["Phrases"] as? [[String: Any]])?[0]["CreatedAt"] as? String, "2026-10-01T12:00:00+00:00")
    }
    func testInvalidSchemaMissingParentsAndCyclesRejected() throws {
        var raw = try fixture().raw; raw["SchemaVersion"] = 2
        XCTAssertThrowsError(try LibraryDocument(data: JSONSerialization.data(withJSONObject: raw)))
        raw = try fixture().raw; var cats = raw["Categories"] as! [[String: Any]]; cats[0]["ParentId"] = cats[1]["Id"]; raw["Categories"] = cats
        XCTAssertThrowsError(try LibraryDocument(data: JSONSerialization.data(withJSONObject: raw)))
        cats[0]["ParentId"] = UUID().uuidString; raw["Categories"] = cats
        XCTAssertThrowsError(try LibraryDocument(data: JSONSerialization.data(withJSONObject: raw)))
    }
    func testNewLibraryAndSaveDelete() throws {
        var lib = LibraryDocument(); try lib.save(id: nil, title: "Test", text: "Text", categoryID: lib.categories[0].id, favorite: true)
        XCTAssertEqual(lib.visible(filter: "favourites").count, 1); lib.remove(id: lib.phrases[0].id); XCTAssertTrue(lib.phrases.isEmpty)
    }
}
