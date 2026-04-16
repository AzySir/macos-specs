import Foundation

enum SMCError: Error {
    case unavailable
}

final class SMC {
    func readFan() throws -> Double {
        // Intel: AppleSMC + key "F0Ac" (FPE2 format).
        // Apple Silicon: needs different private endpoints; not implemented yet.
        throw SMCError.unavailable
    }
}
