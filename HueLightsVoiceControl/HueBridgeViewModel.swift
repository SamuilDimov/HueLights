import Foundation
import Speech

class HueBridgeViewModel: ObservableObject {
    @Published var bridgeIP: String?
    @Published var username: String?
    @Published var lights: [Light] = []
    @Published var authenticationError: String?

    func discoverHueBridge() {
        let url = URL(string: "https://discovery.meethue.com/")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let bridges = try JSONDecoder().decode([Bridge].self, from: data)
                    DispatchQueue.main.async {
                        self.bridgeIP = bridges.first?.internalipaddress
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.authenticationError = "JSON decoding error: \(error)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.authenticationError = error?.localizedDescription ?? "Unknown error"
                }
            }
        }.resume()
    }

    func createUser(ipAddress: String) {
        let url = URL(string: "http://\(ipAddress)/api")!
        let body = ["devicetype": "my_hue_app#ios"]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let result = try JSONDecoder().decode([CreateUserResponse].self, from: data)
                    DispatchQueue.main.async {
                        self.username = result.first?.success?.username
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.authenticationError = "JSON decoding error: \(error)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.authenticationError = error?.localizedDescription ?? "Unknown error"
                }
            }
        }.resume()
    }

    func fetchLights() {
        guard let ipAddress = bridgeIP, let username = username else {
            DispatchQueue.main.async {
                self.authenticationError = "No bridge IP or username"
            }
            return
        }
        let url = URL(string: "http://\(ipAddress)/api/\(username)/lights")!
        let request = URLRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let lightsDictionary = try JSONDecoder().decode([String: LightData].self, from: data)
                    DispatchQueue.main.async {
                        self.lights = lightsDictionary.map { id, lightData in
                            Light(id: id, state: lightData.state)
                        }.sorted(by: { $0.id < $1.id })
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.authenticationError = "JSON decoding error: \(error.localizedDescription)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.authenticationError = error?.localizedDescription ?? "Unknown error fetching lights."
                }
            }
        }.resume()
    }

    func setLightState(lightId: String, isOn: Bool, hue: Int? = nil, saturation: Int? = nil, brightness: Int? = nil) {
        guard let ipAddress = bridgeIP, let username = username else {
            DispatchQueue.main.async {
                self.authenticationError = "No bridge IP or username"
            }
            return
        }
        let url = URL(string: "http://\(ipAddress)/api/\(username)/lights/\(lightId)/state")!
        var state: [String: Any] = ["on": isOn]
        if let hue = hue { state["hue"] = hue }
        if let saturation = saturation { state["sat"] = saturation }
        if let brightness = brightness { state["bri"] = brightness }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = try? JSONSerialization.data(withJSONObject: state)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.authenticationError = "Error setting light state: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct Bridge: Decodable {
    let internalipaddress: String
}

struct CreateUserResponse: Decodable {
    struct Success: Decodable {
        let username: String
    }
    let success: Success?
}

struct Light: Identifiable {
    var id: String
    var state: LightState
}

struct LightData: Decodable {
    var state: LightState
}

struct LightState: Decodable {
    var on: Bool
    var bri: Int
    var hue: Int?
    var sat: Int?
}
