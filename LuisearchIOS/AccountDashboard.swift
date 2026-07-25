import SwiftUI
import UniformTypeIdentifiers

struct AccountDashboard: View {
    @ObservedObject var session: AccountSession
    @Binding var isPresented: Bool

    @State private var displayName = ""
    @State private var bio = ""
    @State private var avatarEmoji = "🗿"
    @State private var selectedTheme = "auto"
    @State private var showChangePassword = false
    @State private var showDeleteConfirm = false
    @State private var exportDoc: ExportDocument?

    let emojiOptions = ["🗿", "🚀", "🐧", "🌌", "⚡", "🔭", "🧭", "🪐", "🦉", "🔥"]
    let themeOptions = [("auto", "System"), ("light", "Light"), ("dark", "Dark")]

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 22))
                                .padding(6)
                                .background(avatarEmoji == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    avatarEmoji = emoji
                                    session.updateProfile(displayName: nil, bio: nil, avatarEmoji: emoji, theme: nil)
                                }
                        }
                    }
                    TextField("Display name", text: $displayName)
                        .onSubmit { session.updateProfile(displayName: displayName, bio: nil, avatarEmoji: nil, theme: nil) }
                    TextField("Bio", text: $bio)
                        .onSubmit { session.updateProfile(displayName: nil, bio: bio, avatarEmoji: nil, theme: nil) }
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themeOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .onChange(of: selectedTheme) { newValue in
                        session.updateProfile(displayName: nil, bio: nil, avatarEmoji: nil, theme: newValue)
                    }
                }

                Section("Stats") {
                    if let stats = session.stats {
                        LabeledContent("Bookmarks", value: "\(stats.bookmarks_count)")
                        LabeledContent("Pages Visited", value: "\(stats.history_count)")
                        LabeledContent("Searches", value: "\(stats.searches_count)")
                        if let topHost = stats.top_host {
                            LabeledContent("Most Visited", value: topHost)
                        }
                        if let joined = stats.joined_at {
                            LabeledContent("Member Since", value: joined)
                        }
                    } else {
                        ProgressView()
                    }
                }

                Section("Your Data") {
                    Button("Export All Data as JSON") { exportData() }
                        .disabled(exportDoc != nil)
                }
                .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }),
                              document: exportDoc, contentType: .json, defaultFilename: "luisearch-data-export") { _ in }

                Section("Account") {
                    Button("Change Password") { showChangePassword = true }
                    Button(role: .destructive, action: session.logOut) {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .onAppear(perform: loadProfile)
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(session: session, isPresented: $showChangePassword)
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task {
                    try? await session.deleteAccount()
                    isPresented = false
                }
            }
        } message: {
            Text("This permanently deletes your account, bookmarks, and history. This can't be undone.")
        }
    }

    func loadProfile() {
        Task { await session.refreshProfile(); await session.refreshStats() }
        if let p = session.profile {
            displayName = p.display_name ?? ""
            bio = p.bio ?? ""
            avatarEmoji = p.avatar_emoji ?? "🗿"
            selectedTheme = p.theme ?? "auto"
        }
    }

    func exportData() {
        guard let token = session.token else { return }
        Task {
            guard let data = await AccountAPI.fetchExportJSON(token: token) else { return }
            await MainActor.run { exportDoc = ExportDocument(data: data) }
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ChangePasswordSheet: View {
    @ObservedObject var session: AccountSession
    @Binding var isPresented: Bool

    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var success = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if success {
                    Text("Password updated.").foregroundStyle(.green)
                    Button("Done") { isPresented = false }
                        .buttonStyle(.borderedProminent)
                } else {
                    SecureField("Current password", text: $oldPassword)
                        .textFieldStyle(.roundedBorder)
                    SecureField("New password", text: $newPassword)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }

                    Button(action: submit) {
                        if isLoading { ProgressView() }
                        else { Text("Update Password").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(oldPassword.isEmpty || newPassword.isEmpty || isLoading)
                }
            }
            .padding(24)
            .navigationTitle("Change Password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await session.changePassword(old: oldPassword, new: newPassword)
                await MainActor.run { success = true; isLoading = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
            }
        }
    }
}
