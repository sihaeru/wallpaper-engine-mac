//
//  Status.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/8.
//

import Cocoa
import WebKit

extension AppDelegate {
    /// WKWebView を壁紙ウィンドウのビュー階層から取得するヘルパー
    private var wallpaperWebView: WKWebView? {
        wallpaperWindow.contentView?.subviews.first?.subviews.first as? WKWebView
    }

    @objc func mute() {
        switch self.wallpaperViewModel.currentWallpaper.project.type.lowercased() {
        case "video":
            self.wallpaperViewModel.playVolume = 0
        case "web":
            // Web壁紙: ページ内のaudio/video要素を全てミュート
            wallpaperWebView?.evaluateJavaScript(
                "document.querySelectorAll('audio, video').forEach(function(el){ el.muted = true; });",
                completionHandler: nil
            )
        default:
            return
        }
    }
    
    @objc func unmute() {
        switch self.wallpaperViewModel.currentWallpaper.project.type.lowercased() {
        case "video":
            self.wallpaperViewModel.playVolume = self.wallpaperViewModel.lastPlayVolume == 0 ? 1 : self.wallpaperViewModel.lastPlayVolume
        case "web":
            // Web壁紙: ページ内のaudio/video要素を全てミュート解除
            wallpaperWebView?.evaluateJavaScript(
                "document.querySelectorAll('audio, video').forEach(function(el){ el.muted = false; });",
                completionHandler: nil
            )
        default:
            return
        }
    }
    
    @objc func pause() {
        switch self.wallpaperViewModel.currentWallpaper.project.type.lowercased() {
        case "video":
            self.wallpaperViewModel.playRate = 0
        case "web":
            // Web壁紙: ページ内のaudio/video要素を全て一時停止
            wallpaperWebView?.evaluateJavaScript(
                "document.querySelectorAll('audio, video').forEach(function(el){ el.pause(); });",
                completionHandler: nil
            )
        default:
            return
        }
    }
    
    @objc func resume() {
        switch self.wallpaperViewModel.currentWallpaper.project.type.lowercased() {
        case "video":
            self.wallpaperViewModel.playRate = self.wallpaperViewModel.lastPlayRate == 0 ? 1 : self.wallpaperViewModel.lastPlayRate
        case "web":
            // Web壁紙: ページ内のaudio/video要素を全て再生再開
            wallpaperWebView?.evaluateJavaScript(
                "document.querySelectorAll('audio, video').forEach(function(el){ el.play().catch(function(){}); });",
                completionHandler: nil
            )
        default:
            return
        }
    }
    
    @objc func takeScreenshot() {
        try! Process.run(URL(filePath: "/usr/sbin/screencapture"), arguments: ["-Cmup", "~/Picturesscreenshot.png"])
    }
    
    @objc func browseWorkshop() {
        // Change tab selection to `Workshop`
        self.contentViewModel.topTabBarSelection = 2
        openMainWindow()
    }
    
    @objc func openSupportWebpage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/haren724/open-wallpaper-engine-mac/wiki")!)
    }
    
    func setStatusMenu() {
        // Recent Wallpapers Submenu
        let recentWallpapersMenuItem = NSMenuItem(title: String(localized: "Recent Wallpapers"), action: nil, keyEquivalent: "")
        let recentWallpapersMenu = NSMenu(title: String(localized: "Recent Wallpapers"))
        recentWallpapersMenu.items = [
            .init(title: "Comming soon", action: nil, keyEquivalent: "")
        ]
        recentWallpapersMenuItem.submenu = recentWallpapersMenu
        
        let menu = NSMenu()
        menu.items = [
            .init(title: String(localized: "Show Open Wallpaper Engine"),
                  systemImage: "photo",
                  action: #selector(openMainWindow),
                  keyEquivalent: "o"),
            
            recentWallpapersMenuItem,
            
//            .init(title: "Change Screensaver",
//                  systemImage: "moon.stars",
//                  action: nil,
//                  keyEquivalent: ""),
            
            .separator(),
            
            .init(title: String(localized: "Browse Workshop"),
                  systemImage: "globe",
                  action: #selector(browseWorkshop),
                  keyEquivalent: "w"),
            
//            .init(title: "Create Wallpaper",
//                  systemImage: "pencil.and.ruler.fill",
//                  action: nil,
//                  keyEquivalent: ""),
            
            .init(title: String(localized: "Settings"),
                  systemImage: "gearshape.fill",
                  action: #selector(openSettingsWindow),
                  keyEquivalent: ","),
            
            .separator(),
            
            .init(title: String(localized: "Support & FAQ"),
                  systemImage: "person.fill.questionmark",
                  action: #selector(openSupportWebpage),
                  keyEquivalent: "i"),
            
            .separator(),
            
//            .init(title: "Take Screenshot",
//                  systemImage: "camera.fill",
//                  action: #selector(takeScreenshot),
//                  keyEquivalent: ""),
            
            .init(title: String(localized: "Mute"),
                  systemImage: "speaker.slash.fill",
                  action: #selector(AppDelegate.shared.mute),
                  keyEquivalent: "m"),
            
            .init(title: String(localized: "Pause"),
                  systemImage: "pause.fill",
                  action: #selector(pause),
                  keyEquivalent: "p"),
            
            .init(title: String(localized: "Quit"),
                  systemImage: "power",
                  action: #selector(NSApplication.terminate(_:)),
                  keyEquivalent: "q")
        ]
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.menu = menu
        
        if let button = self.statusItem.button {
            if let image = NSImage(named: "we.logo") {
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "play.desktopcomputer", accessibilityDescription: nil)
            }
        }
    }
}
