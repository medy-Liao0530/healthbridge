# Independent review — v0.1.0

Reviewer: a fresh-context AI reviewer with a read-only mandate ("evaluate from scratch"). The planned Codex pass could not run (model not available on the account at review time); this pass replaces it.

## 🔴 Blockers (all fixed)
- mac/healthbridge.py — negative/missing `Content-Length` bypassed the 4 MB cap → now 411/400 before reading.
- mac/healthbridge.py — single-threaded server with no timeout could be stalled by one idle client → `ThreadingHTTPServer` + 15 s socket timeout.

## 🟡 Warnings
Fixed:
- `init` no longer changes an existing bundle ID (a new ID would install a second app without Health access).
- `ios/Local.example.xcconfig` added; xcodegen needs `Local.xcconfig`.
- Data dir 700, day files / archive / config / Config.swift 600, written atomically.
- Unreadable day files are overwritten instead of failing every later sync.
- Archive rebuilds are debounced (one rebuild per burst) and written atomically.
- All dates are validated before any write (no half-applied payloads).
- Error responses no longer echo exception text.
- Gregorian calendar + POSIX locale for date keys (non-Gregorian device calendars).
- Workouts use `.strictStartDate` (no double counting across midnight).
- HealthKit observers start once.
- Background task sets an expiration handler.
- Backfill reads success from its own request (no shared flag) and uses one anchor date.
- install.md clones before `doctor`; LaunchAgent example in `docs/healthbridge.receiver.plist`.
- `doctor` probes the configured bind address and expands `~` in paths.

Verified after fixes (local): valid payload accepted while another client stalls (0.1 s); `Content-Length: -1` → 400; missing length → 411; payload with one bad date → 400 and nothing written; files created 600 / dir 700; iOS app builds with Xcode 26.5.

## 🟢 OK
- Crypto: CryptoKit `.combined` (nonce‖ct‖tag) matches the receiver; random nonces; key = SHA-256 of a 256-bit secret.
- Replay: 10-minute freshness + per-day monotonic `sent_at`.
- No path traversal (`DATE_RE.fullmatch` gates file names); subprocess calls use fixed argv, no shell.
- BG task identifier in Info.plist matches the runtime id.
- No personal data in tracked files.

---

# Independent review — v0.2.0

Same fresh-context, read-only reviewer setup; scope: the v0.2.0 diff.

## 🔴 Blockers (fixed)
- `post_sync_cmd` failures (missing executable, string instead of list) killed the archiver thread silently → validated as a list of strings at startup; every archive/hook run is wrapped and logged.
- A hanging hook blocked archiving forever → archive timeout 600 s, hook timeout 300 s.

## 🟡 Warnings (fixed)
- Hook refused when the config is readable/writable by other users.
- Hook runs only after a successful archive rebuild.
- Docs: restart `serve` after editing the config; sleep window 18:00 → 12:00 (naps excluded).
- Health permission text lists every new data type.
- VO₂ max unit built explicitly (no string parsing).
- Sleep window uses wall-clock 18:00/12:00 (correct on DST days); `deep_min`/`rem_min` omitted when a source has no stages.

Verified after fixes (local): string hook → refused at start; group-readable config → refused; failing hook logged twice while syncs kept returning 200 and the archive kept rebuilding.

## 🟢 OK
- Units/scaling for SDNN, walking HR, SpO₂, respiratory rate, mmHg, kg; `.discreteAverage` valid for all types.
- Sleep interval merge: clipped to the window, overlaps merged once, no off-by-one.
- Archive header/row column counts match; missing fields render as "—".
- No private information in the diff.
