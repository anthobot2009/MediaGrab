import SwiftUI
import WebKit

enum MediaKind { case audio, video, hls }

struct DetectedMedia: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let kind: MediaKind
}

enum StreamSniffer {
    static func classify(_ s: String) -> MediaKind? {
        let u = s.lowercased()
        if u.contains(".m3u8") { return .hls }
        if u.range(of: #"\.(mp3|m4a|aac|ogg)(\?|#|$)"#, options: .regularExpression) != nil { return .audio }
        if u.range(of: #"\.(mp4|webm|mov)(\?|#|$)"#, options: .regularExpression) != nil { return .video }
        return nil
    }

    static let js = """
    (function(){
      function report(u){
        if(u && typeof u === 'string' && u.indexOf('blob:') !== 0){
          window.webkit.messageHandlers.sniff.postMessage({url:u,title:document.title});
        }
      }
      var of = window.fetch;
      window.fetch = function(){
        try{ report(typeof arguments[0]==='string' ? arguments[0] : arguments[0].url) }catch(e){}
        return of.apply(this, arguments);
      };
      var oo = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(m,u){
        try{ report(u) }catch(e){}
        return oo.apply(this, arguments);
      };
      try{
        new PerformanceObserver(function(l){
          l.getEntries().forEach(function(e){ report(e.name) })
        }).observe({entryTypes:['resource']});
      }catch(e){}
      function scan(){
        document.querySelectorAll('video,audio').forEach(function(m){ report(m.currentSrc || m.src) })
      }
      new MutationObserver(scan).observe(document.documentElement,{childList:true,subtree:true});
      document.addEventListener('play', scan, true);
    })();
    """
}

struct SniffingWebView: UIViewRepresentable {
    let url: URL
    var onDetected: (DetectedMedia) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDetected) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let script = WKUserScript(source: StreamSniffer.js,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        cfg.userContentController.addUserScript(script)
        cfg.userContentController.add(context.coordinator, name: "sniff")
        let wv = WKWebView(frame: .zero, configuration: cfg)
        context.coordinator.loaded = url
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.loaded != url {
            context.coordinator.loaded = url
            wv.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onDetected: (DetectedMedia) -> Void
        var seen = Set<String>()
        var loaded: URL?

        init(_ cb: @escaping (DetectedMedia) -> Void) { onDetected = cb }

        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let d = m.body as? [String: Any],
                  let s = d["url"] as? String,
                  let kind = StreamSniffer.classify(s),
                  let url = URL(string: s),
                  seen.insert(s).inserted else { return }
            let title = (d["title"] as? String) ?? "Untitled"
            DispatchQueue.main.async {
                self.onDetected(DetectedMedia(url: url, title: title, kind: kind))
            }
        }
    }
}
