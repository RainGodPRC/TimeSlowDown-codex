#if canImport(SwiftUI)
import SwiftUI
import TimeSlowDownKit

@available(iOS 17.0, *)
@main
struct TimeSlowDownApp: App {
    var body: some Scene {
        WindowGroup {
            TSDNativeShellView()
        }
    }
}
#endif
