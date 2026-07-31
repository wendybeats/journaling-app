// Voice capture — simple speech-to-text that appears on the page.
// Apple's Speech framework, on-device whenever the device supports it
// (requiresOnDeviceRecognition), so the privacy story holds: nothing
// leaves the phone. No audio is stored — the words land in the draft and
// follow the normal commit rules like anything typed.
//
// Permission asks (mic + speech) are deferred until the first tap on REC.

import Foundation
import AVFoundation
import Speech

final class VoiceCapture: ObservableObject {
    @Published private(set) var isRecording = false

    /// Receives the full replacement draft text on every partial result.
    var onText: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var base = ""

    /// `base` is a provider, not a value — it's read the moment recording
    /// actually begins, after any permission flow. Capturing the text at
    /// tap time went stale when the permission alert's scene-phase dance
    /// changed the draft underneath it.
    func start(base: @escaping () -> String) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted { self.begin(base: base()) }
                    }
                }
            }
        }
    }

    private func begin(base: String) {
        // On-device is a requirement, not a preference — the permission
        // copy promises "nothing leaves your phone," so a locale without
        // on-device support gets no recording rather than a server fallback.
        guard !isRecording,
              let recognizer = SFSpeechRecognizer(), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else { return }
        self.base = base

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { teardown(); return }
        isRecording = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                // Once stopped, no late callback may touch the page —
                // cancellation fires a final callback whose transcription
                // can reset to (near) empty and would erase the dictation.
                guard self.isRecording else { return }
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    if !spoken.isEmpty {
                        let joiner = self.base.isEmpty
                            || self.base.hasSuffix(" ") || self.base.hasSuffix("\n") ? "" : " "
                        self.onText?(self.base + joiner + spoken)
                    }
                }
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        teardown()
    }

    private func teardown() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}
