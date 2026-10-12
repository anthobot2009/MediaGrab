import SwiftUI
import SwiftData

@Model
final class LibraryItem {
    var title: String
    var fileName: String
    var sourceURL: String
    var isFavorite: Bool = false
    var lastPlayed: Date?
    var added: Date = Date()

    init(title: String, fileName: String, sourceURL: String) {
        self.title = title
        self.fileName = fileName
        self.sourceURL = sourceURL
    }
}

@Model
final class Playlist {
    var name: String
    var items: [LibraryItem] = []
    init(name: String) { self.name = name }
}

enum Scope: String, CaseIterable { case myFiles = "My files", allMedia = "All media" }
enum LibSection: String, CaseIterable { case all = "All", playlists = "Playlists", favorites = "Favorites", recent = "Recent" }

struct LibraryView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \LibraryItem.added, order: .reverse) private var items: [LibraryItem]
    @Query private var playlists: [Playlist]
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var downloads: DownloadManager

    @State private var scope: Scope = .myFiles
    @State private var section: LibSection = .all
    @State private var newPlaylist = ""

    var shown: [LibraryItem] {
        switch section {
        case .favorites: return items.filter { $0.isFavorite }
        case .recent:
            return items.filter { $0.lastPlayed != nil }
                .sorted { $0.lastPlayed! > $1.lastPlayed! }
        default: return items
        }
    }

    func fileURL(_ i: LibraryItem) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("media/\(i.fileName)")
    }

    var body: some View {
        VStack {
            Picker("Scope", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented).padding(.horizontal)

            Picker("Section", selection: $section) {
                ForEach(LibSection.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented).padding(.horizontal)

            if !downloads.progress.isEmpty {
                ForEach(Array(downloads.progress.keys), id: \.self) { k in
                    ProgressView(value: downloads.progress[k] ?? 0) {
                        Text("Downloading…").font(.caption)
                    }.padding(.horizontal)
                }
            }

            List {
                if section == .playlists {
                    HStack {
                        TextField("New playlist", text: $newPlaylist)
                        Button("Add") {
                            guard !newPlaylist.isEmpty else { return }
                            ctx.insert(Playlist(name: newPlaylist))
                            newPlaylist = ""
                        }
                    }
                    ForEach(playlists) { p in
                        Text("\(p.name) (\(p.items.count))")
                    }
                } else {
                    ForEach(shown) { i in
                        HStack {
                            Button(i.title) {
                                player.play(fileURL(i), title: i.title)
                                i.lastPlayed = Date()
                            }
                            Spacer()
                            Button {
                                i.isFavorite.toggle()
                            } label: {
                                Image(systemName: i.isFavorite ? "heart.fill" : "heart")
                            }
                            .buttonStyle(.borderless)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                try? FileManager.default.removeItem(at: fileURL(i))
                                ctx.delete(i)
                            }
                        }
                    }
                }
            }
        }
    }
}
