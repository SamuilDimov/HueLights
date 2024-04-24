import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = HueBridgeViewModel()

    var body: some View {
        NavigationView {
            VStack {
                Text("Hue Lights Control")
                    .font(.title)
                    .padding()

                Button("Create User") {
                    viewModel.createUser()
                }

                if viewModel.isListening {
                    Text("Listening...")
                } else {
                    Button("Start Listening") {
                        viewModel.startVoiceControl()
                    }
                }

                TextField("Recognized Speech", text: $viewModel.recognizedText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                List(viewModel.lights) { light in
                    HStack {
                        Text("Light \(light.id)")
                        Spacer()
                        Text(light.state.on ? "On" : "Off")
                        Circle()
                            .fill(light.state.on ? Color.green : Color.gray)
                            .frame(width: 20, height: 20)
                    }
                }

                if let error = viewModel.authenticationError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                }
            }
            .navigationBarTitle("Home")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
