import Foundation

public enum LibraryError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let reason) = self { return reason }; return nil }
}
public struct Category: Identifiable { public let id: String; public let name: String; public let parentID: String?; public let enabled: Bool }
public struct Phrase: Identifiable { public let id: String; public let categoryID: String; public let title: String; public let text: String; public let favorite: Bool; public let enabled: Bool; public let useCount: Int; public let lastUsed: String; public let order: Int }

/// Preserves desktop schema-1 fields, settings, timestamps and unknown properties.
public struct LibraryDocument {
    public private(set) var raw: [String: Any]
    public init(data: Data) throws {
        guard data.count <= 5 * 1024 * 1024, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LibraryError.invalid("Choose a CommonCopy JSON library smaller than 5 MB.") }
        raw = object; try validate()
    }
    public init() {
        raw = ["SchemaVersion": 1, "Categories": [[String: Any]](), "Phrases": [[String: Any]](), "Settings": [String: Any]()]
        for name in ["Prompts", "Code", "Day-to-Day"] { _ = try? addCategory(name: name, parentID: nil) }
    }
    private var categoryRows: [[String: Any]] { raw["Categories"] as? [[String: Any]] ?? [] }
    private var phraseRows: [[String: Any]] { raw["Phrases"] as? [[String: Any]] ?? [] }
    public var categories: [Category] { categoryRows.map { Category(id: ($0["Id"] as? String ?? "").lowercased(), name: $0["Name"] as? String ?? "", parentID: ($0["ParentId"] as? String)?.lowercased(), enabled: $0["IsEnabled"] as? Bool ?? true) } }
    public var phrases: [Phrase] { phraseRows.map { Phrase(id: ($0["Id"] as? String ?? "").lowercased(), categoryID: ($0["CategoryId"] as? String ?? "").lowercased(), title: $0["Title"] as? String ?? "", text: $0["Text"] as? String ?? "", favorite: $0["IsFavorite"] as? Bool ?? false, enabled: $0["IsEnabled"] as? Bool ?? true, useCount: $0["UseCount"] as? Int ?? 0, lastUsed: $0["LastUsedAt"] as? String ?? "", order: $0["SortOrder"] as? Int ?? 0) } }
    public func validate() throws {
        guard raw["SchemaVersion"] as? Int == 1, raw["Categories"] is [[String: Any]], raw["Phrases"] is [[String: Any]] else { throw LibraryError.invalid("This library format is not supported.") }
        let cats = categories; let ids = cats.map(\.id)
        guard Set(ids).count == ids.count else { throw LibraryError.invalid("Duplicate category identifiers.") }
        for c in cats {
            try validID(c.id)
            guard !c.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LibraryError.invalid("A category needs a name.") }
            var seen = Set<String>(); var current: Category? = c
            while let item = current {
                guard seen.insert(item.id).inserted else { throw LibraryError.invalid("Categories cannot contain cycles.") }
                guard let parent = item.parentID else { break }
                guard let match = cats.first(where: { $0.id == parent }) else { throw LibraryError.invalid("Missing parent category.") }
                current = match
            }
        }
        var seen = Set<String>()
        for p in phrases {
            try validID(p.id)
            guard seen.insert(p.id).inserted, ids.contains(p.categoryID), !p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !p.text.isEmpty else { throw LibraryError.invalid("A phrase is incomplete or references a missing category.") }
        }
    }
    private func validID(_ id: String) throws {
        guard let uuid = UUID(uuidString: id), uuid.uuidString.lowercased() == id, id != "00000000-0000-0000-0000-000000000000" else { throw LibraryError.invalid("Invalid library identifier.") }
    }
    public func data() throws -> Data { try validate(); return try JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys]) }
    public func categoryPath(_ id: String) -> String {
        guard let c = categories.first(where: { $0.id == id.lowercased() }) else { return "" }
        return c.parentID.map { categoryPath($0) + " / " + c.name } ?? c.name
    }
    public func categoryEnabled(_ id: String) -> Bool {
        guard let c = categories.first(where: { $0.id == id.lowercased() }) else { return false }
        return c.enabled && (c.parentID.map { categoryEnabled($0) } ?? true)
    }
    public func visible(filter: String, query: String = "") -> [Phrase] {
        phrases.filter { p in
            p.enabled && categoryEnabled(p.categoryID) && (filter == "all" || filter == "common" || (filter == "favourites" ? p.favorite : p.categoryID == filter)) && (query.isEmpty || (p.title + "\n" + p.text).localizedCaseInsensitiveContains(query))
        }.sorted { a,b in filter == "common" ? (a.useCount == b.useCount ? a.lastUsed > b.lastUsed : a.useCount > b.useCount) : a.order < b.order }
    }
    private static func now() -> String { ISO8601DateFormatter().string(from: Date()) }
    @discardableResult public mutating func addCategory(name: String, parentID: String?) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, parentID == nil || categories.contains(where: { $0.id == parentID }) else { throw LibraryError.invalid("Enter a name and valid parent category.") }
        let id = UUID().uuidString.lowercased(); var rows = categoryRows
        rows.append(["Id": id, "Name": trimmed, "ParentId": parentID.map { $0 as Any } ?? NSNull(), "IsEnabled": true, "SortOrder": rows.count, "CreatedAt": Self.now(), "UpdatedAt": Self.now()]); raw["Categories"] = rows
        return id
    }
    public mutating func save(id: String?, title: String, text: String, categoryID: String, favorite: Bool) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !text.isEmpty, categories.contains(where: { $0.id == categoryID }) else { throw LibraryError.invalid("Add a title, text and category.") }
        var rows = phraseRows; let index = id.flatMap { target in rows.firstIndex { ($0["Id"] as? String)?.lowercased() == target } }
        if id != nil && index == nil { throw LibraryError.invalid("This phrase no longer exists.") }
        var row = index.map { rows[$0] } ?? ["Id": UUID().uuidString.lowercased(), "CreatedAt": Self.now(), "IsEnabled": true, "UseCount": 0, "SortOrder": rows.count]
        row["Title"] = title.trimmingCharacters(in: .whitespacesAndNewlines); row["Text"] = text; row["CategoryId"] = categoryID; row["IsFavorite"] = favorite; row["UpdatedAt"] = Self.now()
        if let i = index { rows[i] = row } else { rows.append(row) }; raw["Phrases"] = rows
    }
    public mutating func remove(id: String) { raw["Phrases"] = phraseRows.filter { ($0["Id"] as? String)?.lowercased() != id } }
    public mutating func used(id: String) {
        var rows = phraseRows; guard let i = rows.firstIndex(where: { ($0["Id"] as? String)?.lowercased() == id }) else { return }
        rows[i]["UseCount"] = max(0, rows[i]["UseCount"] as? Int ?? 0) + 1; rows[i]["LastUsedAt"] = Self.now(); raw["Phrases"] = rows
    }
}
