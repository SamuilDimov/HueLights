import SwiftUI

struct ContentView: View {
    // Instantiate the view model
    @ObservedObject var viewModel = HueBridgeViewModel()

    var body: some View {
        VStack {
            Text("Hue Lights Control")
            Button("Discover Bridge", action: {
                // This will trigger bridge discovery when the button is tapped
                viewModel.discoverHueBridge()
            })
            if let bridgeIP = viewModel.bridgeIP {
                Text("Bridge IP: \(bridgeIP)")
            }
        }
    }
}
