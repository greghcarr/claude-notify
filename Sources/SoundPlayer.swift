import Foundation

protocol SoundPlayer {
    func play()
}

// Plays the sound via `afplay` rather than UNNotificationSound.default; the
// system path is unreliable. See CLAUDE.md invariant 3.
struct AfplaySoundPlayer: SoundPlayer {
    let binaryPath: String
    let soundFile: String

    func play() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binaryPath)
        task.arguments = [soundFile]
        try? task.run()
    }
}
