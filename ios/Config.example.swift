// Copy to HealthBridge/Config.swift, or let `python3 mac/healthbridge.py init` write it for you.
// Config.swift is git-ignored: it holds your shared secret.
enum Config {
    /// Shared secret; the AES-256-GCM key is SHA-256 of this string. Must match the Mac.
    static let secret = "REPLACE_WITH_OUTPUT_OF_init"
    /// Receiver URL on your Mac (Bonjour name works on most home networks).
    static let endpoint = "http://YOUR-MAC.local:8765/health"
    /// Optional LAN IP used only when the name above cannot be reached at all.
    static let fallbackHost: String? = nil
    static let port = 8765
}
