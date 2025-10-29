import Foundation
import AVFoundation

final class AudioChunkRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private let chunkDuration: TimeInterval
    private let onChunkFinished: (URL, Bool) -> Void

    init(chunkDuration: TimeInterval = 60, onChunkFinished: @escaping (URL, Bool) -> Void) {
        self.chunkDuration = chunkDuration
        self.onChunkFinished = onChunkFinished
        super.init()
    }

    func startNewChunk() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tone_chunk_\(UUID().uuidString).caf")
        do {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            self.recorder = recorder
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record(forDuration: chunkDuration) else {
                // Failed to start timed recording
                onChunkFinished(url, false)
                return
            }
        } catch {
            // Failed to start recorder
            onChunkFinished(url, false)
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
    }

    // AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        self.recorder = nil
        onChunkFinished(url, flag)
    }
}
