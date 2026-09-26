import AppKit

enum AppIcon {
    static var image: NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        return NSApp.applicationIconImage
    }
}
