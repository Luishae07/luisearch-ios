import SwiftUI

/// Full onboarding walkthrough -- covers every major feature of the app
/// before landing on account creation, so a new user actually understands
/// what they have before they start using it.
struct SetupWizard: View {
    @ObservedObject var session: AccountSession
    @Binding var isPresented: Bool

    @State private var step = 0
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    let totalSteps = 7

    var body: some View {
        VStack(spacing: 22) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .frame(width: 280)

            Group {
                switch step {
                case 0: welcomeStep
                case 1: tabsStep
                case 2: searchStep
                case 3: bookmarksStep
                case 4: historyStep
                case 5: accountStep
                default: doneStep
                }
            }
            .transition(.opacity)

            HStack {
                if step > 0 && step < totalSteps - 1 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if step < totalSteps - 2 {
                    Button("Skip Tour") { step = totalSteps - 2 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 320)
        }
        .padding(32)
        .frame(width: 420, height: 460)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    func featureStep(icon: String, title: String, body: String, next: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text(title).font(.title2.bold())
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 320)
            Spacer()
            Button(next) { step += 1 }
                .buttonStyle(.borderedProminent)
                .frame(width: 200)
        }
    }

    var welcomeStep: some View {
        featureStep(
            icon: "sparkle.magnifyingglass",
            title: "Welcome to Luisearch",
            body: "A real browser built around Luisearch's own crawled index — fast search, a genuine knowledge panel for people/companies/places, and a browsing experience with no tracking games. This quick tour covers everything before you start.",
            next: "Show me around"
        )
    }

    var tabsStep: some View {
        featureStep(
            icon: "square.on.square",
            title: "Tabs & navigation",
            body: "Open new tabs with the + button in the tab strip, close them with the x. Back, forward, reload, and home live in the toolbar — a real loading bar tracks page progress under the tabs, and the address bar lock icon shows connection status.",
            next: "Next"
        )
    }

    var searchStep: some View {
        featureStep(
            icon: "magnifyingglass",
            title: "Search that means it",
            body: "Type anything that isn't a URL into the address bar and it searches Luisearch's real crawled index — not a redirect to someone else's engine. Search a notable person, company, or place and you'll get a knowledge panel with a real summary and image alongside the results.",
            next: "Next"
        )
    }

    var bookmarksStep: some View {
        featureStep(
            icon: "star",
            title: "Bookmarks, synced to your account",
            body: "Tap the star in the toolbar to save the current page. Your bookmarks live in their own database on the server, tied to your Luisearch app account — not just a local list that disappears if you reinstall.",
            next: "Next"
        )
    }

    var historyStep: some View {
        featureStep(
            icon: "clock.arrow.circlepath",
            title: "History that follows your account",
            body: "Every page you visit while signed in — and every search you run — gets logged to your account automatically, viewable from the clock icon in the toolbar. Clear it anytime with one tap. Signed out, nothing is tracked.",
            next: "Almost done"
        )
    }

    var accountStep: some View {
        VStack(spacing: 12) {
            Text("Create your account").font(.title3.bold())
            Text("This is what powers bookmarks and history — optional, but you'll want it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 280)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            Button(action: createAccount) {
                if isLoading { ProgressView().controlSize(.small) }
                else { Text("Create Account").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || isLoading)

            Spacer()
            Button("Skip for now") { step = totalSteps - 1 }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .frame(width: 260)
    }

    var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("You're all set").font(.title2.bold())
            Text(session.username != nil
                 ? "Signed in as \(session.username!). Bookmarks and history are tracking now."
                 : "You can create an account anytime from the toolbar to unlock bookmarks and history.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 300)
            Spacer()
            Button("Start Browsing") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .frame(width: 200)
        }
    }

    func createAccount() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let token = try await AccountAPI.signup(username: username, password: password)
                await MainActor.run {
                    session.setSession(username: username, token: token)
                    isLoading = false
                    step = totalSteps - 1
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
