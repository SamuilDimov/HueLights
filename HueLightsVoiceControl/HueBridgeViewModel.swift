import Foundation
import AVFoundation
import Speech

struct Bridge: Codable {
    let internalipaddress: String
}

struct CreateUserResponse: Codable {
    struct Success: Codable {
        let username: String
    }
    struct Error: Codable {
        let description: String
    }
    let success: Success?
    let error: Error?
}

struct LightModel: Identifiable {
    let id: String
    var state: LightState
}

struct LightState: Codable {
    var on: Bool
    var bri: Int?
    var hue: Int?
    var sat: Int?
}

class HueBridgeViewModel: ObservableObject {
    @Published var bridgeIP: String? = "192.168.2.17"
    @Published var username: String?
    @Published var lights = [LightModel(id: "1", state: LightState(on: false, bri: 254, hue: 10000, sat: 200))]
    @Published var authenticationError: String?
    @Published var isListening = false
    @Published var recognizedText = ""

    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            authenticationError = "Audio session setup failed: \(error.localizedDescription)"
        }
    }

    func createUser() {
        guard let ipAddress = bridgeIP, let url = URL(string: "http://\(ipAddress)/api"), let jsonData = try? JSONEncoder().encode(["devicetype": "my_hue_app#iphone"]) else {
            authenticationError = "Invalid URL or JSON encoding error"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { self.authenticationError = "User creation error: \(error.localizedDescription)" }
                return
            }
            guard let data = data, let response = try? JSONDecoder().decode([CreateUserResponse].self, from: data), let createUserResponse = response.first else {
                DispatchQueue.main.async { self.authenticationError = "Failed to decode user creation data." }
                return
            }
            DispatchQueue.main.async {
                if let success = createUserResponse.success {
                    self.username = success.username
                } else if let error = createUserResponse.error {
                    self.authenticationError = error.description
                }
            }
        }.resume()
    }

    func setLightState(lightId: String, state: LightState) {
        guard let ipAddress = bridgeIP, let username = username, let url = URL(string: "http://\(ipAddress)/api/\(username)/lights/\(lightId)/state") else {
            authenticationError = "Incomplete configuration for setting light state."
            return
        }
        guard let jsonData = try? JSONEncoder().encode(state) else {
            authenticationError = "JSON encoding error"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { self.authenticationError = "Error setting light state: \(error.localizedDescription)" }
            }
            DispatchQueue.main.async {
                self.stopVoiceControl()
                self.startVoiceControl()
            }
        }.resume()
    }

    func startVoiceControl() {
        isListening = true
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            authenticationError = "Unable to create the speech recognition request."
            return
        }
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            recognitionRequest.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] (result, error) in
            guard let self = self else { return }
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString.lowercased()
                self.processCommand(self.recognizedText)
            }
            if error != nil || result?.isFinal == true {
                self.stopVoiceControl()
            }
        })
        do {
            try audioEngine.start()
        } catch {
            authenticationError = "Audio engine could not start: \(error.localizedDescription)"
            isListening = false
        }
    }

    func stopVoiceControl() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }

    private func processCommand(_ command: String) {
        if command.contains("turn on") {
            let newState = LightState(on: true, bri: 254, hue: lights[0].state.hue, sat: lights[0].state.sat)
            setLightState(lightId: lights[0].id, state: newState)
        } else if command.contains("turn off") {
            let newState = LightState(on: false, bri: 254, hue: lights[0].state.hue, sat: lights[0].state.sat)
            setLightState(lightId: lights[0].id, state: newState)
        } else if command.contains("turn red") {
            let newState = LightState(on: true, bri: 254, hue: 65280, sat: 254)
            setLightState(lightId: lights[0].id, state: newState)
        } else if command.contains("turn blue") {
            let newState = LightState(on: true, bri: 254, hue: 46920, sat: 254)
            setLightState(lightId: lights[0].id, state: newState)
        } else if command.contains("turn green") {
            let newState = LightState(on: true, bri: 254, hue: 25500, sat: 254)
            setLightState(lightId: lights[0].id, state: newState)
        }
    }
}
