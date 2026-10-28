import Foundation
import Testing

@testable import LARP

/// The echo canceller on synthetic audio, without speakers: a reference signal, and a
/// microphone made of that reference delayed and attenuated plus a separate "user" signal.
@Suite("Echo canceller")
struct EchoCancellerTests {
    private static let rate = Int(AudioFormats.storageSampleRate)
    private static let frame = EchoCanceller.frameSamples

    /// A small deterministic generator (xorshift), so every run sees the same audio.
    private struct Noise {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        /// Uniform in [-1, 1).
        mutating func next() -> Float {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Float(Double(state >> 11) / Double(1 << 52)) - 1
        }
    }

    /// Speech-like audio: coloured noise whose level swells and fades a few times a second.
    private static func speechLike(seconds: Int, seed: UInt64, rms: Float) -> [Float] {
        var noise = Noise(seed: seed)
        var samples = [Float](repeating: 0, count: seconds * rate)
        var low: Float = 0
        for index in samples.indices {
            low = 0.6 * low + 0.4 * noise.next()
            let envelope = 0.55 + 0.45 * sin(2 * Float.pi * 3.1 * Float(index) / Float(rate))
            samples[index] = low * envelope
        }
        let level = (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
        return samples.map { $0 * rms / level }
    }

    private static func rms(_ samples: ArraySlice<Float>) -> Float {
        (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
    }

    private static func decibels(_ ratio: Float) -> Float { 20 * log10(ratio) }

    /// The seconds in which only the reference plays (the microphone holds its echo) and the
    /// seconds in which only the user speaks (the reference is silent): the echo alone, the
    /// user alone, then the echo alone again, so the echo canceller also has to cope with the
    /// reference coming back after a pause.
    private static let referenceOnly: [Range<Int>] = [0..<6, 8..<14]
    private static let userOnly: [Range<Int>] = [6..<8]

    @Test("after the first 2 seconds the echo is at least 20 dB lower, and the user's level is kept within 3 dB")
    func removesTheEchoAndKeepsTheUser() throws {
        let seconds = 14
        let delay = Self.rate * 80 / 1000
        let attenuation: Float = 0.4

        let isReferenceSecond = { (second: Int) in Self.referenceOnly.contains { $0.contains(second) } }
        let isUserSecond = { (second: Int) in Self.userOnly.contains { $0.contains(second) } }
        let speech = Self.speechLike(seconds: seconds, seed: 0x9E37_79B9_7F4A_7C15, rms: 0.2)
        let voice = Self.speechLike(seconds: seconds, seed: 0xD1B5_4A32_D192_ED03, rms: 0.1)
        let reference = (0..<speech.count).map { isReferenceSecond($0 / Self.rate) ? speech[$0] : 0 }
        let user = (0..<voice.count).map { isUserSecond($0 / Self.rate) ? voice[$0] : 0 }
        // The microphone: the reference as the speakers play it, delayed and attenuated, plus the user.
        let microphone = (0..<reference.count).map { index in
            (index >= delay ? attenuation * reference[index - delay] : 0) + user[index]
        }

        let canceller = try #require(EchoCanceller())
        var cleaned = [Float](repeating: 0, count: microphone.count)
        var frameStart = 0
        while frameStart + Self.frame <= microphone.count {
            reference.withUnsafeBufferPointer { canceller.processReference($0.baseAddress! + frameStart) }
            microphone.withUnsafeBufferPointer { input in
                cleaned.withUnsafeMutableBufferPointer { output in
                    #expect(
                        canceller.processMicrophone(input.baseAddress! + frameStart, into: output.baseAddress! + frameStart))
                }
            }
            frameStart += Self.frame
        }

        // Only the reference plays: the echo left, after the first 2 seconds.
        for part in Self.referenceOnly {
            let range = max(part.lowerBound, 2) * Self.rate..<part.upperBound * Self.rate
            let reduction = Self.decibels(Self.rms(microphone[range]) / Self.rms(cleaned[range]))
            #expect(reduction >= 20, "echo reduced by \(reduction) dB in seconds \(part)")
        }
        // Only the user speaks: the level of the user.
        for part in Self.userOnly {
            let range = part.lowerBound * Self.rate..<part.upperBound * Self.rate
            let change = Self.decibels(Self.rms(cleaned[range]) / Self.rms(microphone[range]))
            #expect(abs(change) <= 3, "user level changed by \(change) dB in seconds \(part)")
        }
    }
}
