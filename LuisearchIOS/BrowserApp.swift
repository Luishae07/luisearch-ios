import SwiftUI
import WebKit
import Combine

let HOME_URL = URL(string: "https://luisearch.pages.dev/")!

final class BrowserTab: ObservableObject, Identifiable {
    let id = UUID()
    @Published var urlString: String = HOME_URL.absoluteString
    @Published var pageTitle: String = "Luisearch"
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var progress: Double = 0

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: HOME_URL))
    }

    func navigate(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let looksLikeURL = trimmed.contains(".") && !trimmed.contains(" ")
        let url: URL
        if looksLikeURL {
            let withScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
                ? trimmed : "https://\(trimmed)"
            url = URL(string: withScheme) ?? HOME_URL
        } else {
            var comps = URLComponents(url: HOME_URL, resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            url = comps.url ?? HOME_URL
        }
        load(url)
    }

    func load(_ url: URL) { webView.load(URLRequest(url: url)) }
    func goHome() { load(HOME_URL) }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
}

struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var session: AccountSession

    func makeUIView(context: Context) -> WKWebView {
        let c = context.coordinator
        tab.webView.publisher(for: \.title).receive(on: RunLoop.main)
            .sink { newTitle in
                let title = newTitle ?? "Luisearch"
                tab.pageTitle = title
                session.maybeLogVisit(url: tab.webView.url?.absoluteString ?? tab.urlString, title: title)
            }.store(in: &c.subs)
        tab.webView.publisher(for: \.url).receive(on: RunLoop.main)
            .sink { if let u = $0 { tab.urlString = u.absoluteString } }.store(in: &c.subs)
        tab.webView.publisher(for: \.isLoading).receive(on: RunLoop.main)
            .sink { tab.isLoading = $0 }.store(in: &c.subs)
        tab.webView.publisher(for: \.canGoBack).receive(on: RunLoop.main)
            .sink { tab.canGoBack = $0 }.store(in: &c.subs)
        tab.webView.publisher(for: \.canGoForward).receive(on: RunLoop.main)
            .sink { tab.canGoForward = $0 }.store(in: &c.subs)
        tab.webView.publisher(for: \.estimatedProgress).receive(on: RunLoop.main)
            .sink { tab.progress = $0 }.store(in: &c.subs)
        return tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var subs = Set<AnyCancellable>() }
}

struct BrowserView: View {
    @StateObject private var tab = BrowserTab()
    @StateObject private var session = AccountSession()
    @State private var addressText = HOME_URL.absoluteString
    @State private var showAccountSheet = false
    @State private var showBookmarks = false
    @State private var showHistory = false
    @AppStorage("luisearch_setup_done") private var setupDone = false
    @State private var showSetup = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: tab.isLoading ? "circle.dotted" : "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    TextField("Search Luisearch or enter address", text: $addressText)
                        .textFieldStyle(.plain)
                        .focused($addressFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            let looksLikeURL = addressText.contains(".") && !addressText.contains(" ")
                            if !looksLikeURL { session.logSearch(addressText) }
                            tab.navigate(to: addressText)
                            addressFocused = false
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .onChange(of: tab.urlString) { _, newValue in
                    if !addressFocused { addressText = newValue }
                }

                if tab.isLoading {
                    ProgressView(value: tab.progress).progressViewStyle(.linear).frame(height: 2)
                } else {
                    Color.clear.frame(height: 2)
                }

                WebViewRepresentable(tab: tab, session: session)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: tab.goBack) { Image(systemName: "chevron.left") }.disabled(!tab.canGoBack)
                    Button(action: tab.goForward) { Image(systemName: "chevron.right") }.disabled(!tab.canGoForward)
                    Spacer()
                    Button(action: tab.goHome) { Image(systemName: "house") }
                    Spacer()
                    accountButtons
                }
            }
        }
        .sheet(isPresented: $showAccountSheet) { AccountSheet(session: session, isPresented: $showAccountSheet) }
        .sheet(isPresented: $showBookmarks) { BookmarksList(session: session, activeTab: tab) }
        .sheet(isPresented: $showHistory) { HistoryList(session: session, activeTab: tab) }
        .sheet(isPresented: $showSetup) { SetupWizard(session: session, isPresented: $showSetup) }
        .onAppear {
            if !setupDone {
                showSetup = true
                setupDone = true
            }
        }
    }

    var isCurrentPageBookmarked: Bool {
        session.bookmarks.contains { $0.url == tab.urlString }
    }

    func bookmarkCurrentPage() {
        if let existing = session.bookmarks.first(where: { $0.url == tab.urlString }) {
            session.removeBookmark(existing)
        } else {
            session.addBookmark(url: tab.urlString, title: tab.pageTitle)
        }
    }

    @ViewBuilder
    var accountButtons: some View {
        if session.username != nil {
            Button(action: bookmarkCurrentPage) {
                Image(systemName: isCurrentPageBookmarked ? "star.fill" : "star")
            }
            Spacer()
            Button(action: { showBookmarks = true }) { Image(systemName: "list.star") }
            Spacer()
            Button(action: { showHistory = true }) { Image(systemName: "clock.arrow.circlepath") }
            Spacer()
        }
        if let username = session.username {
            Menu {
                Text("Signed in as \(username)")
                Divider()
                Button("Log Out", role: .destructive) { session.logOut() }
            } label: {
                Image(systemName: "person.crop.circle.fill")
            }
        } else {
            Button(action: { showAccountSheet = true }) {
                Image(systemName: "person.crop.circle")
            }
        }
    }
}

@main
struct LuisearchIOSApp: App {
    var body: some Scene {
        WindowGroup {
            BrowserView()
        }
    }
}
