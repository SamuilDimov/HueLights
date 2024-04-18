import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = HueBridgeViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Hue Lights Control")
                .font(.largeTitle)

            if let bridgeIP = viewModel.bridgeIP {
                Text("Bridge IP: \(bridgeIP)")
                Button("Register User") {
                    viewModel.createUser(ipAddress: bridgeIP)
                }
                .disabled(viewModel.bridgeIP == nil)
            } else {
                Button("Discover Bridge", action: viewModel.discoverHueBridge)
            }

            if let username = viewModel.username {
                Text("Registered Username: \(username)")
            }

            if let error = viewModel.authenticationError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}
