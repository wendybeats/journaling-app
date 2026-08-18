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
    private var lastSpoken = ""
    private var graceUntil = Date.distantPast
    private var session = 0

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
        lastSpoken = ""
        graceUntil = .distantPast
        session += 1
        let mySession = session

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
        do { try engine.start() } catch { teardown(cancelTask: true); return }
        isRecording = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                // A callback from a superseded recording may never touch
                // the page — its base and transcript belong to an old take.
                guard self.session == mySession else { return }
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    // Live partials apply while recording. After a user
                    // stop, the recognizer's final consolidation may still
                    // land — short takes sometimes deliver ALL their words
                    // only there — but only inside the grace window and
                    // only carrying at least what the page already shows.
                    // Cancellation callbacks (commit path) pass neither
                    // test, so they can never erase the dictation.
                    let trailing = !self.isRecording
                        && Date() < self.graceUntil
                        && result.isFinal
                        && spoken.count >= self.lastSpoken.count
                    if self.isRecording || trailing, !spoken.isEmpty {
                        let joiner = { (b: String) -> String in
                            b.isEmpty || b.hasSuffix(" ") || b.hasSuffix("\n") ? "" : " "
                        }
                        // A pause makes on-device recognition start a fresh
                        // utterance: the transcription RESETS instead of
                        // extending. Detect the reset (shorter, not a
                        // revision of what we had) and fold the finished
                        // words into the base — a breath must never erase
                        // the sentence before it. (QA 2026-08-18.)
                        if spoken.count < self.lastSpoken.count,
                           !self.lastSpoken.hasPrefix(spoken) {
                            self.base += joiner(self.base) + self.lastSpoken
                        }
                        self.lastSpoken = spoken
                        self.onText?(self.base + joiner(self.base) + spoken)
                    }
                }
                if self.isRecording, error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    /// User-initiated stop (the REC pill): the take is over, but the final
    /// consolidated transcription is still welcome for a moment.
    func stop() {
        guard isRecording else { return }
        isRecording = false
        graceUntil = Date().addingTimeInterval(1.5)
        teardown(cancelTask: false)   // endAudio lets the task finish and file its final
    }

    /// Hard stop for the commit path: the draft is about to be committed
    /// and cleared, so nothing may write to it afterwards.
    func cancel() {
        graceUntil = .distantPast
        guard isRecording else { return }
        isRecording = false
        teardown(cancelTask: true)
    }

    private func teardown(cancelTask: Bool) {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        if cancelTask { task?.cancel() }
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}
