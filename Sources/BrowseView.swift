import SwiftUI

struct BrowseView: View {
    @State private var sources: [String] = ["https://archive.org", "https://freemusicarchive.org"]
    @State private var newSource = ""
    @State private var open: URL?
    @State private var detected: DetectedMedia?

    var body: some View {
        NavigationStack {
            List {
                HStack {
                    TextField("https://…", text: $newSource)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("Add") {
                        guard URL(string: newSource) != nil else { return }
                        sources.append(newSource); newSource = ""
                    }
                }
                ForEach(sources, id: \.self) { s in
                    Button(s) { open = URL(string: s) }
                }
                .onDelete { sources.remove(atOffsets: $0) }
            }
            .navigationTitle("Browse")
            .fullScreenCover(item: Binding(
                get: { open.map { IdentURL(url: $0) } },
                set: { open = $0?.url })) { w in
                VStack(spacing: 0) {
                    HStack {
                        Button("Close") { open = nil }.padding()
                        Spacer()
                    }
                    SniffingWebView(url: w.url) { m in
                        if detected == nil { detected = m }
                    }
                }
                .sheet(item: $detected) { m in
                    DetectedMediaSheet(media: m) { detected = nil }
                }
            }
        }
    }
}

struct IdentURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
