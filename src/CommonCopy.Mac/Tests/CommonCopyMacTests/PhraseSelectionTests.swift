import XCTest
@testable import CommonCopyMac

final class PhraseSelectionTests: XCTestCase {
    private func phrase(_ id: String, category: String = "email", text: String = "A complete phrase\nSecond line 🧠") -> Phrase {
        Phrase(id: id, categoryId: category, title: id, text: text,
            isFavorite: id == "Beta", isEnabled: true, useCount: 3, sortOrder: 0)
    }
    private func snapshot(_ phrases: [Phrase]) -> CoreState {
        CoreState(document: Library(phrases: phrases,
            categories: [Category(id: "email", name: "Email", parentId: nil), Category(id: "code", name: "Code", parentId: nil)],
            settings: Settings(appearance: "Light", restoreTextClipboardAfterPaste: true,
                clipboardRestoreDelayMilliseconds: 350, pasteDelayMilliseconds: 100)),
            categoryList: [CategoryOption(id: "email", displayName: "Email"), CategoryOption(id: "code", displayName: "Code")],
            favourites: phrases.filter(\.isFavorite).map(\.id), commonlyUsed: phrases.map(\.id),
            categoryPhrases: ["email": phrases.filter { $0.categoryId == "email" }.map(\.id), "code": phrases.filter { $0.categoryId == "code" }.map(\.id)], captureTitle: nil)
    }
    @MainActor func testSelectionFollowsVisibleRowsAndClearsForEmptySearch() {
        let store = Store()
        store.state = snapshot([phrase("Alpha"), phrase("Beta", category: "code")])
        XCTAssertEqual(store.selectedPhrase?.id, "Alpha")
        store.selectedPhraseId = "Beta"
        store.search = "Beta"
        XCTAssertEqual(store.selectedPhrase?.id, "Beta")
        store.search = "No match"
        XCTAssertNil(store.selectedPhrase)
        XCTAssertNil(store.selectedPhraseId)
        store.search = ""
        store.selectedCategory = "code"
        XCTAssertEqual(store.selectedPhrase?.id, "Beta")
        store.selectedCategory = "email"
        XCTAssertEqual(store.selectedPhrase?.id, "Alpha")
    }
    @MainActor func testReloadEditDeleteAndImportNeverLeaveAStalePreview() {
        let store = Store()
        store.state = snapshot([phrase("Alpha"), phrase("Beta")])
        store.selectedPhraseId = "Beta"
        store.state = snapshot([phrase("Alpha"), phrase("Beta", text: "Updated full text\nUnicode 🧠")])
        XCTAssertEqual(store.selectedPhrase?.text, "Updated full text\nUnicode 🧠")
        store.state = snapshot([phrase("Alpha")])
        XCTAssertEqual(store.selectedPhrase?.id, "Alpha")
        store.state = snapshot([])
        XCTAssertNil(store.selectedPhrase)
        store.state = snapshot([phrase("Imported")])
        XCTAssertEqual(store.selectedPhrase?.id, "Imported")
    }
}
