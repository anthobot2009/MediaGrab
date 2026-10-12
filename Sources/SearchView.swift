import SwiftUI

@MainActor
final class SearchVM: ObservableObject {
    @Published var query = ""
    @Published var pageURL: URL?
    @Published var detected: DetectedMedia?

    func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty,
              let enc = (q + " mp3").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return }
        pageURL = URL(string: "https://duckduckgo.com/?q=\(enc)")
    }

    func onDetected(_ m: DetectedMedia) {
        if detected == nil { detected = m }
    }
}

struct SearchView: View {
    @StateObject private var vm = SearchVM()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search song or video", text: $vm.query)
                    .submitLabel(.search)
                    .onSubmit { vm.search() }
                    .textInputAutocapitalization(.never)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()

            if let url = vm.pageURL {
                SniffingWebView(url: url, onDetected: vm.onDetected)
            } else {
                Spacer()
                Text("Type something to search").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .sheet(item: $vm.detected) { m in
            DetectedMediaSheet(media: m) { vm.detected = nil }
        }
    }
}

struct DetectedMediaSheet: View {
    let media: DetectedMedia
    let close: () -> Void
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var downloads: DownloadManager

    var body: some View {
        VStack(spacing: 14) {
            Text(media.title).font(.headline).lineLimit(2)
            Text(media.url.host ?? "").font(.caption).foregroundStyle(.secondary)

            Button {
                player.play(media.url, title: media.title)
                close()
            } label: {
                Label("Direct Play", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                downloads.start(media)
                close()
            } label: {
                Label("Download", systemImage: "arrow.down.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(media.kind == .hls)

            if media.kind == .hls {
                Text("Download not supported for HLS streams yet").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .presentationDetents([.height(260)])
    }
}
