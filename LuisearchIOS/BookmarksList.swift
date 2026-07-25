import SwiftUI

struct BookmarksList: View {
    @ObservedObject var session: AccountSession
    let activeTab: BrowserTab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Bookmarks")
                .font(.headline)
                .padding(12)

            if session.bookmarks.isEmpty {
                Text("No bookmarks yet — tap the star to save a page.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
            } else {
                List(session.bookmarks) { bookmark in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookmark.title?.isEmpty == false ? bookmark.title! : bookmark.url)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Text(bookmark.url)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: { session.removeBookmark(bookmark) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: bookmark.url) { activeTab.load(url) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 320, height: 320)
    }
}
