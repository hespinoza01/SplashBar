import Foundation

/// Computes sensible max-memory / max-context defaults from the machine's actual RAM instead
/// of a hardcoded number, so the same app gives reasonable values on a 36GB minimum-spec Mac
/// or a 64GB/128GB one.
enum RecommendedDefaults {
    struct Recommendation {
        let memoryValue: String
        let memoryUnit: SizeUnit
        let contextValue: String
        let contextUnit: SizeUnit
        let totalRAMGB: Int
    }

    static func compute(totalRAMBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) -> Recommendation {
        let totalGB = Double(totalRAMBytes) / 1_073_741_824.0

        // Reserve enough for macOS + a normal dev workload (IDEs, browser, opencode) running
        // alongside Splash: at least 16GB, or 30% of total RAM on bigger machines, whichever is
        // larger. What's left is what Splash is allowed to claim.
        let reservedGB = max(16.0, totalGB * 0.30)
        let memoryGB = max(8.0, (totalGB - reservedGB))
        // Round down to a clean multiple of 4 so the number reads naturally (28G, 32G, 44G...).
        let roundedMemoryGB = max(8, Int(memoryGB / 4) * 4)

        // Context scales in coarse tiers with total RAM: more memory affords a bigger KV cache
        // budget within the --max-memory ceiling above, without assuming a specific model.
        let contextK: Int
        switch totalGB {
        case ..<40: contextK = 32
        case 40..<56: contextK = 64
        case 56..<80: contextK = 128
        default: contextK = 256
        }

        return Recommendation(
            memoryValue: String(roundedMemoryGB),
            memoryUnit: .g,
            contextValue: String(contextK),
            contextUnit: .k,
            totalRAMGB: Int(totalGB.rounded())
        )
    }
}
