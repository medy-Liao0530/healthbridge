# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-10-22

### Added
- iOS app: reads steps, active energy, exercise minutes, heart rate, resting heart rate and workouts from Apple Health; background delivery on new workouts; full-history backfill in 30-day chunks
- AES-256-GCM sealed payloads; fallback to the Mac's LAN IP only on transport errors
- Mac CLI `mac/healthbridge.py`: `doctor`, `init`, `serve`, `archive`
- Receiver: 10-minute freshness window, per-day monotonic `sent_at`, date validation, 4 MB body cap
- Markdown archive with yearly/monthly summaries and a workout list, English or Chinese
