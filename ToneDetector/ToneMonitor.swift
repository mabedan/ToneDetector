import Foundation
import AVFoundation
import Speech
import UserNotifications
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ToneMonitor: NSObject, ObservableObject {
    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[ToneMonitor][\(ts)] \(message)")
    }

    @Published var enabled = false
    @Published var liveText = ""
    @Published var isAgreeable: Bool? = nil
    @Published var disagreeableReason: String? = nil
    @Published var statusMessage: String? = nil
    @Published var lastNotifiedAt: Date? = nil

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private var task: SFSpeechRecognitionTask?
    private var audioChunkRecorder: AudioChunkRecorder?

    func toggle() {
        log("Toggle requested. Currently enabled=\(enabled)")
        enabled ? stop() : start()
    }

    private func start() {
        Task {
            self.log("Starting ToneMonitor… requesting permissions")
            guard await requestPermissions() else {
                self.log("Permissions denied. Aborting start.")
                return
            }
            self.log("Permissions granted. Skipping AVAudioSession configuration on this platform.")
            let _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            self.log("Notification authorization requested")

            liveText = ""
            self.isAgreeable = nil
            self.disagreeableReason = nil
            self.statusMessage = nil
            self.log("State reset. Clearing indicators")
            startNewChunk()
            await MainActor.run {
                self.enabled = true
            }
        }
    }

    private func stop() {
        log("Stopping ToneMonitor…")
        task?.cancel(); task = nil
        audioChunkRecorder?.stop(); audioChunkRecorder = nil

        // Best-effort cleanup of any lingering temp recordings from this session
        let tempDir = FileManager.default.temporaryDirectory
        if let items = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for item in items where item.lastPathComponent.hasPrefix("tone_chunk_") {
                try? FileManager.default.removeItem(at: item)
            }
        }

        log("Recorder stopped")
        Task { @MainActor in
            self.enabled = false
            self.log("ToneMonitor disabled")
        }
    }

    private func requestPermissions() async -> Bool {
        log("Requesting speech and microphone permissions…")
        let speechAuth = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                c.resume(returning: status)
            }
        }

        let micGranted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                c.resume(returning: granted)
            }
        }

        let granted = (speechAuth == .authorized) && micGranted
        log("Permissions result — speech=\(speechAuth.rawValue), mic=\(micGranted), granted=\(granted)")
        return granted
    }

    private func startNewChunk() {
        if audioChunkRecorder == nil {
            audioChunkRecorder = AudioChunkRecorder(chunkDuration: 60) { [weak self] url, success in
                guard let self else { return }
                self.log("Recorder did finish. success=\(success)")
                if success {
                    // Recognize, then ensure cleanup regardless of result
                    self.recognizeChunk(at: url)
                } else {
                    // Clean up file and optionally start next chunk
                    if FileManager.default.fileExists(atPath: url.path) {
                        try? FileManager.default.removeItem(at: url)
                        self.log("Removed failed chunk file: \(url.lastPathComponent)")
                    }
                    if self.enabled { self.startNewChunk() }
                }
            }
        }
        audioChunkRecorder?.startNewChunk()
        self.log("Recording started (timed)")
    }

    private func recognizeChunk(at url: URL) {
        log("Starting recognition for chunk: \(url.lastPathComponent)")
        let req = SFSpeechURLRecognitionRequest(url: url)
        req.requiresOnDeviceRecognition = false
        req.shouldReportPartialResults = false
        task?.cancel(); task = nil
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let error = error as NSError? {
                self.log("Chunk recognition error: \(error.localizedDescription) domain=\(error.domain) code=\(error.code)")
            }
            var text = ""
            if let result {
                text = result.bestTranscription.formattedString
                self.log("Chunk recognition result: \(text.count) chars")
                Task { @MainActor in
                    self.liveText = text
                }
            } else {
                self.log("No recognition result for chunk")
            }
            self.evaluateToneAndNotifyIfNeeded(text: text)
            // Ensure cleanup: remove the chunk file if it still exists
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                    self.log("Removed chunk file: \(url.lastPathComponent)")
                } catch {
                    self.log("Failed to remove chunk file: \(error.localizedDescription)")
                }
            }
            if self.enabled {
                self.startNewChunk()
            }
        }
    }

    private func evaluateToneAndNotifyIfNeeded(text: String) {
        log("Evaluating tone…")
        guard !text.isEmpty else {
            Task { @MainActor in
                self.isAgreeable = nil
                self.disagreeableReason = nil
                self.log("No text to evaluate. Indicators cleared")
            }
            return
        }

        Task {
            do {
                let startTime = Date()
                let result = try await ToneClassifier.classify(
                    text: text,
                    question: "Is the following text agreeable in tone? Consider politeness, empathy, non-aggressiveness and non-confrontational tone."
                )
                let classificationDuration = Date().timeIntervalSince(startTime)
                await MainActor.run {
                    self.isAgreeable = result.yes
                    self.disagreeableReason = result.reason
                }
                self.log("Agreeableness -> \(result.yes ? "agreeable" : "not agreeable"). Reason=\(result.reason ?? "<none>") for \(text.count) chars. Classification took \(String(format: "%.3f", classificationDuration))s")

                if result.yes == false {
                    self.log("Disagreeable tone detected. Considering notification… lastNotifiedAt=\(String(describing: self.lastNotifiedAt))")
                    let now = Date()
                    if self.lastNotifiedAt == nil || now.timeIntervalSince(self.lastNotifiedAt!) > 60 {
                        self.log("Sending notification (cooldown satisfied)")
                        await MainActor.run { self.lastNotifiedAt = now }
                        self.notifyDisagreeable(reason: result.reason, sample: text.prefix(120))
                    } else {
                        let remaining = 60 - now.timeIntervalSince(self.lastNotifiedAt!)
                        self.log("Notification suppressed due to cooldown. Remaining=\(String(format: "%.1f", remaining))s")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAgreeable = nil
                    self.disagreeableReason = nil
                    self.enabled = false
                    self.statusMessage = error.localizedDescription.isEmpty ? "On-device language model is unavailable." : error.localizedDescription
                }
                self.stop()
                self.log("Classification unavailable: \(error.localizedDescription). App disabled.")
            }
        }
    }

    private func notifyDisagreeable(reason: String?, sample: Substring) {
        log("Posting local notification. reasonLen=\(reason?.count ?? 0), sampleLen=\(sample.count)")
        let content = UNMutableNotificationContent()
        content.title = "Disagreeable tone detected"
        if let reason, !reason.isEmpty {
            content.body = "\(reason) — \"\(String(sample))\""
        } else {
            content.body = "\"\(String(sample))\""
        }
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if let error { self.log("Notification scheduling failed: \(error.localizedDescription)") }
            else { self.log("Notification scheduled successfully") }
        }
    }
}

