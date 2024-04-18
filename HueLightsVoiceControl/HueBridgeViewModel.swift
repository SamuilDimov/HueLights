import Foundation

class HueBridgeViewModel: ObservableObject {
    @Published var bridgeIP: String?

    func discoverHueBridge() {
        let url = URL(string: "https://discovery.meethue.com/")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "No error description")")
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
                    print("JSON error: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
}
