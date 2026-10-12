import Foundation
import SwiftData

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: [URL: Double] = [:]
    var container: ModelContainer?
    private var titles: [URL: String] = [:]

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.background(withIdentifier: "com.mediagrab.dl")
        cfg.sessionSendsLaunchEvents = true
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    func start(_ m: DetectedMedia) {
        titles[m.url] = m.title
        session.downloadTask(with: m.url).resume()
    }

    func urlSession(_ s: URLSession, downloadTask t: URLSessionDownloadTask,
                    didWriteData _: Int64, totalBytesWritten w: Int64,
                    totalBytesExpectedToWrite e: Int64) {
        guard let u = t.originalRequest?.url, e > 0 else { return }
        DispatchQueue.main.async { self.progress[u] = Double(w) / Double(e) }
    }

    func urlSession(_ s: URLSession, downloadTask t: URLSessionDownloadTask,
                    didFinishDownloadingTo tmp: URL) {
        guard let u = t.originalRequest?.url else { return }
        let title = titles[u] ?? "media"
        let safe = title.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined(separator: "_").prefix(50)
        let ext = u.pathExtension.isEmpty ? "mp4" : u.pathExtension
        let fileName = "\(UUID().uuidString.prefix(4))_\(safe).\(ext)"

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName)
        try? FileManager.default.moveItem(at: tmp, to: dest)

        let container = self.container
        Task { @MainActor in
            guard let container else { return }
            container.mainContext.insert(
                LibraryItem(title: title, fileName: fileName, sourceURL: u.absoluteString))
            try? container.mainContext.save()
            self.progress[u] = nil
        }
    }
}
