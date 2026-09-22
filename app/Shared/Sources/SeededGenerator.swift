import Foundation

/// §10: "Entirely deterministic and seeded, so the same inputs always
/// produce the same plan and any generated week can be reproduced exactly
/// from a bug report." Not cryptographic — just a small, well-known,
/// reproducible PRNG (FNV-1a to turn the seed string into a 64-bit state,
/// then SplitMix64 to stream from it) so the generator's few tie-breaking
/// choices are deterministic per seed rather than depending on
/// `SystemRandomNumberGenerator`, which is intentionally non-reproducible.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        // A zero state would stay zero forever under SplitMix64's update
        // rule below, so an empty/degenerate seed still needs a real value.
        state = hash == 0 ? 0x9E37_79B9_7F4A_7C15 : hash
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
