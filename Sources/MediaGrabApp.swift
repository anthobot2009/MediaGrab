import SwiftUI
import SwiftData
import AVKit

@main
struct MediaGrabApp: App {
    let container: ModelContainer
    @StateObject private var player = PlayerManager()
    @StateObject private var downloads = DownloadManager()

    init() {
        container = try! ModelContainer(for: LibraryItem.self, Playlist.self)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(player)
                .environmentObject(downloads)
                .onAppear { downloads.container = container }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "music.note.list") }
            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.isActive {
                VStack(spacing: 4) {
                    VideoPlayer(player: player.player).frame(height: 180)
                    HStack {
                        Text(player.title).lineLimit(1).font(.subheadline)
                        Spacer()
                        Button { player.togglePause() } label: { Image(systemName: "playpause.fill") }
                        Button { player.stop() } label: { Image(systemName: "xmark") }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                .background(.ultraThinMaterial)
            }
        }
    }
}
