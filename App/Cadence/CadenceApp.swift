import SwiftUI
import CadenceUI

/// The app target is deliberately tiny: all views live in the `CadenceUI`
/// package and all logic in `CadenceCore`, so both can be built and tested
/// without a simulator.
@main
struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            CadenceRootView()
        }
    }
}
