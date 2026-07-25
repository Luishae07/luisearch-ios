import SwiftUI

struct HistoryList: View {
    @ObservedObject var session: AccountSession
    let activeTab: BrowserTab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History").font(.headline)
                Spacer()
                if !session.history.isEmpty {
                    Button("Clear", action: session.clearHistory)
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            if session.history.isEmpty {
                Text("No history yet — pages you visit while signed in show up here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
            } else {
                List(session.history) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title?.isEmpty == false ? entry.title! : entry.url)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Text(entry.visited_at)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: entry.url) { activeTab.load(url) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 320, height: 320)
        .task { await session.refreshHistory() }
    }
}
