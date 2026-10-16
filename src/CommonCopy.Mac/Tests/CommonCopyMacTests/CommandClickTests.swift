import XCTest
import AppKit
@testable import CommonCopyMac

final class CommandClickTests: XCTestCase {
    @MainActor func testPopupOffersCaptureAndNestedPhrasesButExcludesDisabledPhrases() throws {
        let fixture = """
        {"document":{"phrases":[
          {"id":"one","categoryId":"gpt","title":"Review code","text":"Review this code","isFavorite":true,"isEnabled":true,"useCount":2,"sortOrder":0},
          {"id":"off","categoryId":"gpt","title":"Disabled","text":"hidden","isFavorite":true,"isEnabled":false,"useCount":0,"sortOrder":1}],
          "categories":[{"id":"prompts","name":"Prompts","parentId":null},{"id":"gpt","name":"GPT","parentId":"prompts"}],
          "settings":{"appearance":"Dark","restoreTextClipboardAfterPaste":true,"clipboardRestoreDelayMilliseconds":350,"pasteDelayMilliseconds":120}},
          "categoryList":[{"id":"prompts","displayName":"Prompts"},{"id":"gpt","displayName":"GPT"}],
          "favourites":["one","off"],"commonlyUsed":["one"],"categoryPhrases":{"prompts":["one","off"],"gpt":["one","off"]}}
        """
        let state = try JSONDecoder().decode(CoreState.self, from: Data(fixture.utf8))
        let delegate = AppDelegate()
        delegate.store.state = state
        let menu = delegate.makePhraseMenu(state: state)
        XCTAssertEqual(menu.items.first?.title, "Save highlighted text…")
        XCTAssertNotNil(menu.items.first?.action)
        let favourites = try XCTUnwrap(menu.item(withTitle: "Favourites")?.submenu)
        XCTAssertEqual(favourites.items.map(\.title), ["Review code"])
        let prompts = try XCTUnwrap(menu.item(withTitle: "Prompts")?.submenu)
        let gpt = try XCTUnwrap(prompts.item(withTitle: "GPT")?.submenu)
        XCTAssertEqual(gpt.items.map(\.title), ["Review code"])
        XCTAssertEqual(menu.appearance?.name, .darkAqua)
    }

    func testOrdinaryRightClickPassesThrough() {
        var matcher = CommandClickMatcher()
        XCTAssertEqual(matcher.handle(.down, commandHeld: false), CommandClickDecision(suppress: false, activate: false))
        XCTAssertEqual(matcher.handle(.up, commandHeld: false), CommandClickDecision(suppress: false, activate: false))
    }

    func testCommandRightClickSuppressesBothEdgesAndActivatesOnce() {
        var matcher = CommandClickMatcher()
        XCTAssertEqual(matcher.handle(.down, commandHeld: true), CommandClickDecision(suppress: true, activate: false))
        XCTAssertEqual(matcher.handle(.up, commandHeld: true), CommandClickDecision(suppress: true, activate: true))
        XCTAssertFalse(matcher.handle(.up, commandHeld: true).activate)
    }

    func testReleasingCommandBeforeMouseUpStillConsumesMatchingRelease() {
        var matcher = CommandClickMatcher()
        _ = matcher.handle(.down, commandHeld: true)
        XCTAssertEqual(matcher.handle(.up, commandHeld: false), CommandClickDecision(suppress: true, activate: true))
    }

    func testPressingCommandAfterNormalMouseDownDoesNotStealRelease() {
        var matcher = CommandClickMatcher()
        _ = matcher.handle(.down, commandHeld: false)
        XCTAssertEqual(matcher.handle(.up, commandHeld: true), CommandClickDecision(suppress: false, activate: false))
    }

    func testTapResetDoesNotLeaveGestureArmed() {
        var matcher = CommandClickMatcher()
        _ = matcher.handle(.down, commandHeld: true)
        matcher.reset()
        XCTAssertFalse(matcher.handle(.up, commandHeld: true).suppress)
        XCTAssertFalse(matcher.handle(.down, commandHeld: false).suppress)
    }
}
