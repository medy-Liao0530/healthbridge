# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-10-22

### Added
- HRV (SDNN), walking heart rate, sleep (total/deep/REM, overlapping sources merged), blood oxygen, respiratory rate, VO₂ max, blood pressure, weight
- Archive: HRV and sleep columns in yearly/monthly summaries
- `post_sync_cmd` config hook: run your own script after each archive rebuild

### Note
- Existing installs: tap **Allow Health access** again to grant the new types, then **Backfill all history** to fill them in

## [0.1.0] - 2026-10-22

### Added
- iOS app: reads steps, active energy, exercise minutes, heart rate, resting heart rate and workouts from Apple Health; background delivery on new workouts; full-history backfill in 30-day chunks
- AES-256-GCM sealed payloads; fallback to the Mac's LAN IP only on transport errors
- Mac CLI `mac/healthbridge.py`: `doctor`, `init`, `serve`, `archive`
- Receiver: 10-minute freshness window, per-day monotonic `sent_at`, date validation, 4 MB body cap
- Markdown archive with yearly/monthly summaries and a workout list, English or Chinese
