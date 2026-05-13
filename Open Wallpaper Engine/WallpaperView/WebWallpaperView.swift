//
//  WebWallpaperView.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/13.
//

import Cocoa
import SwiftUI
import WebKit

class WallpaperSchemeHandler: NSObject, WKURLSchemeHandler {
    let wallpaperDirectory: URL

    init(wallpaperDirectory: URL) {
        self.wallpaperDirectory = wallpaperDirectory
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let requestURL = urlSchemeTask.request.url!
        let relativePath = requestURL.path.hasPrefix("/")
            ? String(requestURL.path.dropFirst())
            : requestURL.path

        let decoded = relativePath.removingPercentEncoding ?? relativePath
        let fileURL = wallpaperDirectory.appendingPathComponent(decoded)

        let accessing = wallpaperDirectory.startAccessingSecurityScopedResource()
        defer { if accessing { wallpaperDirectory.stopAccessingSecurityScopedResource() } }

        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int else {

            let response = HTTPURLResponse(url: requestURL, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didFinish()
            return
        }

        let mime = mimeType(for: fileURL.pathExtension)

        let rangeHeader = urlSchemeTask.request.value(forHTTPHeaderField: "Range")
        let (startByte, endByte) = parseRange(rangeHeader, fileSize: fileSize)
        let length = endByte - startByte + 1

        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer { fileHandle.closeFile() }

            fileHandle.seek(toFileOffset: UInt64(startByte))
            let data = fileHandle.readData(ofLength: length)

            let statusCode = rangeHeader != nil ? 206 : 200
            let headers: [String: String] = [
                "Content-Type":   mime,
                "Content-Length": "\(data.count)",
                "Content-Range":  "bytes \(startByte)-\(endByte)/\(fileSize)",
                "Accept-Ranges":  "bytes",
            ]

            let response = HTTPURLResponse(
                url: requestURL,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            print("[WallpaperSchemeHandler] ❌ \(decoded): \(error.localizedDescription)")
            let response = HTTPURLResponse(url: requestURL, statusCode: 500, httpVersion: "HTTP/1.1", headerFields: nil)!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didFinish()
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private func parseRange(_ range: String?, fileSize: Int) -> (Int, Int) {
        guard let range = range,
              range.hasPrefix("bytes="),
              let eq = range.firstIndex(of: "=") else {
            return (0, fileSize - 1)
        }
        let spec = String(range[range.index(after: eq)...])
        let parts = spec.split(separator: "-", maxSplits: 1)
        let start = parts.count > 0 ? Int(parts[0]) ?? 0 : 0
        let end   = parts.count > 1 && !parts[1].isEmpty ? Int(parts[1]) ?? (fileSize - 1) : (fileSize - 1)
        return (min(start, fileSize - 1), min(end, fileSize - 1))
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html":          return "text/html; charset=utf-8"
        case "js":            return "application/javascript; charset=utf-8"
        case "css":           return "text/css; charset=utf-8"
        case "json":          return "application/json; charset=utf-8"
        case "srt", "vtt":   return "text/plain; charset=utf-8"
        case "png":           return "image/png"
        case "jpg", "jpeg":   return "image/jpeg"
        case "webp":          return "image/webp"
        case "gif":           return "image/gif"
        case "mp3":           return "audio/mpeg"
        case "flac":          return "audio/flac"
        case "mp4":           return "video/mp4"
        case "webm":          return "video/webm"
        case "woff2":         return "font/woff2"
        case "woff":          return "font/woff"
        default:              return "application/octet-stream"
        }
    }
}

struct WebWallpaperView: NSViewRepresentable {
    @ObservedObject var wallpaperViewModel: WallpaperViewModel
    @StateObject var viewModel: WebWallpaperViewModel

    init(wallpaperViewModel: WallpaperViewModel) {
        self.wallpaperViewModel = wallpaperViewModel
        self._viewModel = StateObject(wrappedValue: WebWallpaperViewModel(wallpaper: wallpaperViewModel.currentWallpaper))
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = makeWebView(for: viewModel.currentWallpaper)
        webView.navigationDelegate = viewModel
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let selected = wallpaperViewModel.currentWallpaper
        let current  = viewModel.currentWallpaper

        guard selected.wallpaperDirectory.appending(path: selected.project.file)
            != current.wallpaperDirectory.appending(path: current.project.file)
        else { return }

        viewModel.currentWallpaper = selected

        let newWebView = makeWebView(for: selected)
        newWebView.navigationDelegate = viewModel
        if let superview = nsView.superview {
            newWebView.frame = nsView.frame
            superview.replaceSubview(nsView, with: newWebView)
        }
    }

    private func makeWebView(for wallpaper: WEWallpaper) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        let handler = WallpaperSchemeHandler(wallpaperDirectory: wallpaper.wallpaperDirectory)
        configuration.setURLSchemeHandler(handler, forURLScheme: "wallpaper")

        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: configuration)

        let htmlFile = wallpaper.wallpaperDirectory
            .appendingPathComponent(wallpaper.project.file)

        let accessing = wallpaper.wallpaperDirectory.startAccessingSecurityScopedResource()
        defer { if accessing { wallpaper.wallpaperDirectory.stopAccessingSecurityScopedResource() } }

        if let htmlString = try? String(contentsOf: htmlFile, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: URL(string: "wallpaper://localhost/")!)
        }

        return webView
    }
}
