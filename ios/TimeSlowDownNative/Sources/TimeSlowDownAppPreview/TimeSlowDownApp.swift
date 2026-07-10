#if canImport(SwiftUI)
import SwiftUI
import TimeSlowDownKit

@available(iOS 17.0, macOS 14.0, *)
@main
struct TimeSlowDownAppPreview: App {
    var body: some Scene {
        WindowGroup {
            TSDNativeShellView(store: .seeded(), persistenceURL: nil)
        }
    }
}
#else
@main
struct TimeSlowDownAppPreview {
    static func main() {
        print("TimeSlowDownAppPreview requires SwiftUI.")
    }
}
#endif
