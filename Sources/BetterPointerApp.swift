import SwiftUI

@main
struct BetterPointerApp: App {
    @StateObject private var store = PointerStore()

    var body: some Scene {
        MenuBarExtra("BetterPointer", systemImage: "cursorarrow.rays") {
            MenuView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
