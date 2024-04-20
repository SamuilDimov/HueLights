import Foundation

class HueBridgeViewModel: ObservableObject {
    @Published var bridgeIP: String?
    @Published var username: String?
    @Published var lights: [Light] = []
    @Published var authenticationError: String?

    func discoverHueBridge() {
        let url = URL(string: "https://discovery.meethue.com/")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.authenticationError = error?.localizedDescription ?? "Unknown error"
                }
                return
            }
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
        }
        task.resume()
    }

    func createUser(ipAddress: String) {
        let url = URL(string: "http://\(ipAddress)/api")!
        let body = ["devicetype": "my_hue_app#ios"]
        guard let requestBody = try? JSONEncoder().encode(body) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.authenticationError = error?.localizedDescription ?? "Unknown error"
                }
                return
            }
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
        }
        task.resume()
    }

    func fetchLights() {
        guard let ipAddress = bridgeIP, let username = username else {
            self.authenticationError = "No bridge IP or username"
            return
        }
        let url = URL(string: "http://\(ipAddress)/api/\(username)/lights")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.authenticationError = error?.localizedDescription ?? "Unknown error"
                }
                return
            }
            do {
                let lightsDictionary = try JSONDecoder().decode([String: Light].self, from: data)
                DispatchQueue.main.async {
                    self.lights = lightsDictionary.map { id, light in
                        var lightCopy = light
                        lightCopy.id = id
                        return lightCopy
                    }.sorted(by: { $0.id < $1.id })
                }
            } catch {
                DispatchQueue.main.async {
                    self.authenticationError = "JSON decoding error: \(error)"
                }
            }
        }
        task.resume()
    }

    func setLightState(lightId: String, isOn: Bool, hue: Int? = nil, saturation: Int? = nil, brightness: Int? = nil) {
        guard let ipAddress = bridgeIP, let username = username else {
            self.authenticationError = "No bridge IP or username"
            return
        }
        let url = URL(string: "http://\(ipAddress)/api/\(username)/lights/\(lightId)/state")!
        var state: [String: Any] = ["on": isOn]
        if let hue = hue {
            state["hue"] = hue
        }
        if let saturation = saturation {
            state["sat"] = saturation
        }
        if let brightness = brightness {
            state["bri"] = brightness
        }
        
        guard let requestBody = try? JSONSerialization.data(withJSONObject: state) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = requestBody
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.authenticationError = "Error setting light state: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }
}

struct Bridge: Codable {
    let id: String
    let internalipaddress: String
}

struct CreateUserResponse: Codable {
    struct Success: Codable {
        let username: String
    }
    let success: Success?
}

struct Light: Identifiable, Codable {
    var id: String
    var name: String
    var state: LightState
}

struct LightState: Codable {
    var on: Bool
    var bri: Int
    var hue: Int?
    var sat: Int?
}
