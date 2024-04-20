import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var viewModel = HueBridgeViewModel()
    @State private var allLightsOn: Bool = false
    @State private var brightness: Double = 254 // Assuming full brightness
    @State private var selectedColor: Color = .white

    var body: some View {
        VStack {
            Text("Hue Lights Control")
                .font(.headline)
            
            if let bridgeIP = viewModel.bridgeIP {
                Text("Bridge IP: \(bridgeIP)")
                if viewModel.username != nil {
                    Button("Fetch Lights") {
                        viewModel.fetchLights()
                    }
                } else {
                    Button("Register User") {
                        viewModel.createUser(ipAddress: bridgeIP)
                    }
                }
            } else {
                Button("Discover Bridge", action: viewModel.discoverHueBridge)
            }

            Toggle(isOn: $allLightsOn) {
                Text(allLightsOn ? "Turn All Lights Off" : "Turn All Lights On")
            }
            .onReceive([self.allLightsOn].publisher.first()) { newValue in
                viewModel.lights.forEach { light in
                    viewModel.setLightState(lightId: light.id, isOn: newValue)
                }
            }

            Slider(value: $brightness, in: 0...254, step: 1)
                .onReceive([self.brightness].publisher.first()) { newValue in
                    let newBrightness = Int(newValue)
                    viewModel.lights.forEach { light in
                        viewModel.setLightState(lightId: light.id, isOn: light.state.on, brightness: newBrightness)
                    }
                }

            ColorPicker("Pick a color", selection: $selectedColor, supportsOpacity: false)
                .onReceive([self.selectedColor].publisher.first()) { newColor in
                    let hsba = newColor.hsba
                    let hue = Int(hsba.hue * 65535) % 65536
                    let sat = Int(hsba.saturation * 254)
                    let bri = Int(hsba.brightness * 254)
                    viewModel.lights.forEach { light in
                        viewModel.setLightState(lightId: light.id, isOn: light.state.on, hue: hue, saturation: sat, brightness: bri)
                    }
                }

            if let error = viewModel.authenticationError {
                Text("Error: \(error)").foregroundColor(.red)
            }
        }
        .padding()
    }
}

extension Color {
    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness, alpha)
    }
}
