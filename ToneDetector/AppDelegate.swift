import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Ensure the app quits when the last window is closed
        true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up any lingering temporary recording files
        let tempDir = FileManager.default.temporaryDirectory
        if let items = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for item in items where item.lastPathComponent.hasPrefix("tone_chunk_") {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }
}
