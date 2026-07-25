import Foundation

// Calls the app-account API -- a separate database on the external drive,
// independent of the website's login system.
let ACCOUNT_API_BASE = "https://signal-forwarding-vacation-older.trycloudflare.com"

struct AccountAPIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Bookmark: Identifiable, Decodable {
    let id: Int
    let url: String
    let title: String?
    let note: String?
    let tag: String?
    let created_at: String
}

struct HistoryEntry: Identifiable, Decodable {
    let id: Int
    let url: String
    let title: String?
    let visited_at: String
}

struct SearchHistoryEntry: Identifiable, Decodable {
    let id: Int
    let query: String
    let searched_at: String
}

struct Profile: Decodable {
    let username: String
    var display_name: String?
    var bio: String?
    var avatar_emoji: String?
    var theme: String?
    var homepage: String?
}

struct AccountStats: Decodable {
    let bookmarks_count: Int
    let history_count: Int
    let searches_count: Int
    let joined_at: String?
    let top_host: String?
}

enum AccountAPI {
    static func signup(username: String, password: String) async throws -> String {
        try await authCall(path: "/api/app-account/signup", username: username, password: password)
    }

    static func login(username: String, password: String) async throws -> String {
        try await authCall(path: "/api/app-account/login", username: username, password: password)
    }

    private static func authCall(path: String, username: String, password: String) async throws -> String {
        guard let url = URL(string: ACCOUNT_API_BASE + path) else {
            throw AccountAPIError(message: "Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["username": username, "password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = (json["error"] as? String) ?? "Request failed"
            throw AccountAPIError(message: msg)
        }
        guard let token = json["token"] as? String else {
            throw AccountAPIError(message: "No token in response")
        }
        return token
    }

    @discardableResult
    private static func post(path: String, token: String, body: [String: Any]) async throws -> Data {
        guard let endpoint = URL(string: ACCOUNT_API_BASE + path) else {
            throw AccountAPIError(message: "Bad URL")
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            throw AccountAPIError(message: (json["error"] as? String) ?? "Request failed")
        }
        return data
    }

    private static func get<T: Decodable>(path: String, token: String, as type: T.Type) async -> T? {
        guard let endpoint = URL(string: ACCOUNT_API_BASE + path) else { return nil }
        var req = URLRequest(url: endpoint)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // Bookmarks
    static func addBookmark(token: String, url: String, title: String) async throws {
        try await post(path: "/api/app-account/bookmarks", token: token, body: ["url": url, "title": title])
    }
    static func fetchBookmarks(token: String) async throws -> [Bookmark] {
        struct Resp: Decodable { let bookmarks: [Bookmark] }
        return (await get(path: "/api/app-account/bookmarks", token: token, as: Resp.self))?.bookmarks ?? []
    }
    static func deleteBookmark(token: String, id: Int) async throws {
        try await post(path: "/api/app-account/bookmarks/delete", token: token, body: ["id": id])
    }
    static func updateBookmark(token: String, id: Int, note: String?, tag: String?) async throws {
        var body: [String: Any] = ["id": id]
        if let note { body["note"] = note }
        if let tag { body["tag"] = tag }
        try await post(path: "/api/app-account/bookmarks/update", token: token, body: body)
    }

    // Browsing history
    static func logVisit(token: String, url: String, title: String) async throws {
        try await post(path: "/api/app-account/history", token: token, body: ["url": url, "title": title])
    }
    static func fetchHistory(token: String) async throws -> [HistoryEntry] {
        struct Resp: Decodable { let history: [HistoryEntry] }
        return (await get(path: "/api/app-account/history", token: token, as: Resp.self))?.history ?? []
    }
    static func clearHistory(token: String) async throws {
        try await post(path: "/api/app-account/history/clear", token: token, body: [:])
    }

    // Search history
    static func logSearch(token: String, query: String) async throws {
        try await post(path: "/api/app-account/search-history", token: token, body: ["query": query])
    }
    static func fetchSearchHistory(token: String) async throws -> [SearchHistoryEntry] {
        struct Resp: Decodable { let searches: [SearchHistoryEntry] }
        return (await get(path: "/api/app-account/search-history", token: token, as: Resp.self))?.searches ?? []
    }

    // Profile
    static func fetchProfile(token: String) async -> Profile? {
        await get(path: "/api/app-account/profile", token: token, as: Profile.self)
    }
    static func updateProfile(token: String, fields: [String: Any]) async throws {
        try await post(path: "/api/app-account/profile", token: token, body: fields)
    }

    // Stats
    static func fetchStats(token: String) async -> AccountStats? {
        await get(path: "/api/app-account/stats", token: token, as: AccountStats.self)
    }

    // Export
    static func exportData(token: String) async throws -> Data {
        try await post(path: "/api/app-account/export", token: token, body: [:])
    }
    static func fetchExportJSON(token: String) async -> Data? {
        guard let endpoint = URL(string: ACCOUNT_API_BASE + "/api/app-account/export") else { return nil }
        var req = URLRequest(url: endpoint)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try? await URLSession.shared.data(for: req).0
    }

    // Account management
    static func changePassword(token: String, oldPassword: String, newPassword: String) async throws {
        try await post(path: "/api/app-account/change-password", token: token,
                        body: ["old_password": oldPassword, "new_password": newPassword])
    }
    static func deleteAccount(token: String) async throws {
        try await post(path: "/api/app-account/delete-account", token: token, body: [:])
    }
}

// MARK: - Persisted session

final class AccountSession: ObservableObject {
    @Published var username: String? {
        didSet { UserDefaults.standard.set(username, forKey: "luisearch_app_username") }
    }
    @Published var token: String? {
        didSet { UserDefaults.standard.set(token, forKey: "luisearch_app_token") }
    }
    @Published var bookmarks: [Bookmark] = []
    @Published var history: [HistoryEntry] = []
    @Published var searchHistory: [SearchHistoryEntry] = []
    @Published var profile: Profile?
    @Published var stats: AccountStats?

    private var lastLoggedURL: String?

    init() {
        username = UserDefaults.standard.string(forKey: "luisearch_app_username")
        token = UserDefaults.standard.string(forKey: "luisearch_app_token")
        if token != nil {
            Task { await refreshBookmarks() }
            Task { await refreshHistory() }
            Task { await refreshProfile() }
            Task { await refreshStats() }
        }
    }

    func setSession(username: String, token: String) {
        self.username = username
        self.token = token
        Task { await refreshBookmarks() }
        Task { await refreshHistory() }
        Task { await refreshProfile() }
        Task { await refreshStats() }
    }

    func logOut() {
        username = nil
        token = nil
        bookmarks = []
        history = []
        searchHistory = []
        profile = nil
        stats = nil
    }

    @MainActor func refreshBookmarks() async {
        guard let token else { return }
        bookmarks = (try? await AccountAPI.fetchBookmarks(token: token)) ?? []
    }

    @MainActor func refreshHistory() async {
        guard let token else { return }
        history = (try? await AccountAPI.fetchHistory(token: token)) ?? []
    }

    @MainActor func refreshSearchHistory() async {
        guard let token else { return }
        searchHistory = (try? await AccountAPI.fetchSearchHistory(token: token)) ?? []
    }

    @MainActor func refreshProfile() async {
        guard let token else { return }
        profile = await AccountAPI.fetchProfile(token: token)
    }

    @MainActor func refreshStats() async {
        guard let token else { return }
        stats = await AccountAPI.fetchStats(token: token)
    }

    func addBookmark(url: String, title: String) {
        guard let token else { return }
        Task {
            try? await AccountAPI.addBookmark(token: token, url: url, title: title)
            await refreshBookmarks()
            await refreshStats()
        }
    }

    func removeBookmark(_ bookmark: Bookmark) {
        guard let token else { return }
        Task {
            try? await AccountAPI.deleteBookmark(token: token, id: bookmark.id)
            await refreshBookmarks()
            await refreshStats()
        }
    }

    func updateBookmark(_ bookmark: Bookmark, note: String?, tag: String?) {
        guard let token else { return }
        Task {
            try? await AccountAPI.updateBookmark(token: token, id: bookmark.id, note: note, tag: tag)
            await refreshBookmarks()
        }
    }

    /// Called on every page-title update; de-duped per-URL so a page that
    /// only changes its title mid-load doesn't spam duplicate history rows.
    func maybeLogVisit(url: String, title: String) {
        guard let token, url != lastLoggedURL, !url.isEmpty else { return }
        lastLoggedURL = url
        Task {
            try? await AccountAPI.logVisit(token: token, url: url, title: title)
            await refreshHistory()
            await refreshStats()
        }
    }

    func logSearch(_ query: String) {
        guard let token, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            try? await AccountAPI.logSearch(token: token, query: query)
            await refreshStats()
        }
    }

    func clearHistory() {
        guard let token else { return }
        Task {
            try? await AccountAPI.clearHistory(token: token)
            await refreshHistory()
            await refreshStats()
        }
    }

    func updateProfile(displayName: String?, bio: String?, avatarEmoji: String?, theme: String?) {
        guard let token else { return }
        func buildFields() -> [String: Any] {
            var fields: [String: Any] = [:]
            if let displayName { fields["display_name"] = displayName }
            if let bio { fields["bio"] = bio }
            if let avatarEmoji { fields["avatar_emoji"] = avatarEmoji }
            if let theme { fields["theme"] = theme }
            return fields
        }
        let fields = buildFields()
        Task {
            try? await AccountAPI.updateProfile(token: token, fields: fields)
            await refreshProfile()
        }
    }

    func changePassword(old: String, new: String) async throws {
        guard let token else { return }
        try await AccountAPI.changePassword(token: token, oldPassword: old, newPassword: new)
    }

    func deleteAccount() async throws {
        guard let token else { return }
        try await AccountAPI.deleteAccount(token: token)
        await MainActor.run { logOut() }
    }
}
