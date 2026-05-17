struct IPCMessage: Codable {
    let title: String
    let message: String
    let sound: Bool
    let activate: String?
    let url: String?
}
