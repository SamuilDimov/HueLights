import Foundation

class HueBridgeViewModel: ObservableObject {
    @Published var bridgeIP: String?
    @Published var username: String?
    @Published var authenticationError: String?

    // Discover the Hue Bridge on the local network
    func discoverHueBridge() {
        let url = URL(string: "https://discovery.meethue.com/")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.authenticationError = "Discovery error: \(error?.localizedDescription ?? "Unknown error")"
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                       let firstBridge = jsonArray.first,
                       let internalIPAddress = firstBridge["internalipaddress"] as? String {
                        self.bridgeIP = internalIPAddress
                        print("Found bridge IP: \(internalIPAddress)")
                    }
                } catch {
                    self.authenticationError = "JSON parsing error during discovery: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }

    // Attempt to register a new user with the Hue Bridge
    func createUser(ipAddress: String) {
        guard let url = URL(string: "http://\(ipAddress)/api") else {
            DispatchQueue.main.async {
                self.authenticationError = "Invalid URL for bridge."
            }
            return
        }
        
        let requestBody = ["devicetype": "my_hue_app#swift_app"]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    self.authenticationError = "Network error during authentication: \(error?.localizedDescription ?? "Unknown error")"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                       let firstElement = json.first {
                        
                        if let success = firstElement["success"] as? [String: Any],
                           let username = success["username"] as? String {
                            self.username = username
                        } else if let error = firstElement["error"] as? [String: Any],
                                  let description = error["description"] as? String {
                            self.authenticationError = description
                        }
                    }
                } catch {
                    self.authenticationError = "JSON parsing error during authentication: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }
}
