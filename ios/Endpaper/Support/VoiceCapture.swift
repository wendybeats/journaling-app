// Voice capture — speech-to-text that arrives as its own section.
// Apple's Speech framework, on-device whenever the device supports it
// (requiresOnDeviceRecognition), so the privacy story holds: nothing
// leaves the phone. No audio is stored — only the words.
//
// 1.0.2 redesign: the capture owns its whole transcript. It never touches
// the typed draft — the two surfaces share nothing, so neither can
// overwrite the other (the root of every voice bug before this).
// The card renders `transcript` live and `level` drives the waveform.
//
// Permission asks (mic + speech) are deferred until the first tap on REC.

import Foundation
import AVFoundation
import Speech

final class VoiceCapture: ObservableObject {
    @Published private(set) var isRecording = false
    /// The full take so far: folded finished utterances + the live one.
    @Published private(set) var transcript = ""
    /// Mic RMS, 0…1-ish — the waveform's pulse. Updated per audio buffer.
    @Published private(set) var level: Float = 0
    /// When the take began — the card's timer counts from here.
    @Published private(set) var startedAt: Date?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var folded = ""       // finished utterances, already joined
    private var lastSpoken = ""   // the live utterance's latest partial
    private var graceUntil = Date.distantPast
    private var session = 0

    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted { self.begin() }
                    }
                }
            }
        }
    }

    /// The recognizer honoring the Settings language choice: "" follows
    /// the device; an explicit locale (e.g. ru-RU) overrides it. If the
    /// chosen language can't run on-device on this hardware, fall back to
    /// the device recognizer so REC still works rather than going dead.
    private static func makeRecognizer() -> SFSpeechRecognizer? {
        let chosen = UserDefaults.standard.string(forKey: AppKeys.voiceLocale) ?? ""
        if !chosen.isEmpty,
           let r = SFSpeechRecognizer(locale: Locale(identifier: chosen)),
           r.isAvailable, r.supportsOnDeviceRecognition {
            return r
        }
        return SFSpeechRecognizer()
    }

    private func begin() {
        // On-device is a requirement, not a preference — the permission
        // copy promises "nothing leaves your phone," so a locale without
        // on-device support gets no recording rather than a server fallback.
        guard !isRecording,
              let recognizer = Self.makeRecognizer(), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else { return }
        folded = ""
        lastSpoken = ""
        transcript = ""
        graceUntil = .distantPast
        session += 1
        let mySession = session

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        // Spoken pages arrived as one long run-on; let the recogniser
        // punctuate them.
        req.addsPunctuation = true
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request?.append(buffer)
            if let rms = Self.rms(of: buffer) {
                // .measurement mode delivers the raw mic — no system gain —
                // so linear RMS of normal speech is tiny (~0.02) and reads
                // as silence. Map in dB space instead: -50 dB floor (room
                // tone) to -10 dB ceiling (loud speech) → 0…1. (QA 8-18:
                // the card's waveform rendered flat on device.)
                let db = 20 * log10(max(rms, 0.00001))
                let norm = min(1, max(0, (db + 50) / 40))
                DispatchQueue.main.async { self.level = norm }
            }
        }
        engine.prepare()
        do { try engine.start() } catch { teardown(cancelTask: true); return }
        isRecording = true
        startedAt = Date()

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                // A callback from a superseded take may never land — its
                // transcript belongs to an old recording.
                guard self.session == mySession else { return }
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    // Live partials apply while recording. After a user
                    // stop, the recognizer's final consolidation may still
                    // land — short takes sometimes deliver ALL their words
                    // only there — but only inside the grace window and
                    // only carrying at least what the take already holds.
                    let trailing = !self.isRecording
                        && Date() < self.graceUntil
                        && result.isFinal
                        && spoken.count >= self.lastSpoken.count
                    if self.isRecording || trailing, !spoken.isEmpty {
                        // A pause makes on-device recognition start a fresh
                        // utterance: the transcription RESETS instead of
                        // extending. Detect the reset (shorter, not a
                        // revision of what we had) and fold the finished
                        // words in — a breath never erases the sentence
                        // before it. (QA 2026-08-18.)
                        if spoken.count < self.lastSpoken.count,
                           !self.lastSpoken.hasPrefix(spoken) {
                            self.folded = Self.appendDeduped(self.folded, self.lastSpoken)
                        }
                        self.lastSpoken = spoken
                        self.transcript = Self.appendDeduped(self.folded, spoken)
                    }
                }
                if self.isRecording, error != nil || result?.isFinal == true {
                    self.stopListening()
                }
            }
        }
    }

    /// User-initiated stop: end the take, hold briefly for the recognizer's
    /// final consolidated transcription, then deliver the finished text.
    func finish(_ done: @escaping (String) -> Void) {
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.graceUntil = .distantPast
            done(self.transcript.trimmingCharacters(in: .whitespacesAndNewlines))
            self.transcript = ""
            self.startedAt = nil
        }
    }

    /// Hard stop (backgrounding, navigation): no grace window, no delivery
    /// beyond what the take already holds.
    func cancel() {
        graceUntil = .distantPast
        guard isRecording else { return }
        isRecording = false
        teardown(cancelTask: true)
    }

    private func stopListening() {
        guard isRecording else { return }
        isRecording = false
        graceUntil = Date().addingTimeInterval(1.5)
        level = 0
        teardown(cancelTask: false)   // endAudio lets the task file its final
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

    /// Append `addition` to `base`, dropping words the recognizer has
    /// handed back twice. On-device recognition revises ACROSS utterance
    /// boundaries: after a pause it can re-deliver words already folded
    /// in, and a blind concatenation writes the same clause onto the page
    /// again and again (QA 2026-08-22 — a long take repeated whole
    /// sentences). Matching is word-level and ignores case and
    /// punctuation, since the recognizer re-punctuates as it revises.
    ///
    /// A one-word overlap is left alone unless the whole addition is
    /// already present — real speech repeats single words ("and", "the")
    /// often enough that trimming them would eat the user's own words.
    private static func appendDeduped(_ base: String, _ addition: String) -> String {
        let baseWords = base.split(whereSeparator: \.isWhitespace).map(String.init)
        let addWords = addition.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !addWords.isEmpty else { return base }
        guard !baseWords.isEmpty else { return addWords.joined(separator: " ") }

        let norm = { (w: String) in
            w.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        }
        let baseNorm = baseWords.map(norm), addNorm = addWords.map(norm)

        var overlap = min(baseWords.count, addWords.count)
        while overlap > 0 {
            if Array(baseNorm.suffix(overlap)) == Array(addNorm.prefix(overlap)) { break }
            overlap -= 1
        }
        if overlap == 1 && addWords.count > 1 { overlap = 0 }

        let rest = addWords.dropFirst(overlap)
        guard !rest.isEmpty else { return base }
        return (baseWords + rest).joined(separator: " ")
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return nil }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        return sqrt(sum / Float(n))
    }
}
