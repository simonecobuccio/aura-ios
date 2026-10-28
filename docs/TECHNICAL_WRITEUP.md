# Aura: Technical Writeup

This document explains how Aura is put together: the problem it addresses, the architecture, the design of the Aura Score, and the trade-offs made while building it as a prototype. It is intended as an engineering companion to the [README](../README.md).
## 1. Motivation

Consumer well-being apps tend to surface raw metrics (steps, hours slept, a UV number) and leave interpretation to the user. Two problems follow: First, the numbers are not comparable: is 6,000 steps "worth" more than one hour less sleep? Second, their relevance changes over the day: activity is actionable in the morning, sleep is only actionable at night.

Aura's thesis is that a single, well-designed composite score is more useful than a dashboard of disconnected numbers, provided the composition is honest about how well-being works. The Aura Score is that composite.

## 2. Architecture

The app is a single SwiftUI target organized with an MVVM separation.

```
View  ──observes──▶  ViewModel  ──uses──▶  Service / Model
(SwiftUI)            (ObservableObject)     (persistence, system APIs, domain)
```

- **Views** are declarative and stateless beyond local `@State`. They render what a view model publishes and forward user intent back to it.
- **ViewModels** are `ObservableObject`s that own state and side effects: `AuthViewModel`, `WeatherViewModel`, `HealthViewModel`, `AuraChatAIViewModel`.
- **Services** encapsulate infrastructure: `AuraDataStore` (the shared, single-load persistence layer), `AuraNotificationManager`, `AccountStore`, and `HistoricalDataGenerator`.
- **Models** are value types, most of them `Codable`: `Mood`, `MoodEntry`, `DailySnapshot`, the weather DTOs, `ChatMessage`, and `AuraScore` itself.
- **Components / Theme / Utilities** hold reusable UI, design tokens, and small helpers (cached formatters, pre-built haptics).

### State and persistence

`AuraDataStore` is the single source of truth for mood entries and daily snapshots. It loads once and is shared across tabs, decoding from `UserDefaults` on launch and re-encoding on change. Keeping one store avoids repeated decode work in hot paths (for example, the calendar's day cells look up data in O(1) rather than rescanning arrays). Formatters and haptic generators are cached in `AuraFormatters` and `AuraHaptics` for the same reason, allocation in a gesture or a scroll is a visible cost on device.

## 3. The Aura Score

`AuraScore` (see `Models/AuraScore.swift`) turns four normalized pillars (sleep, activity, daylight/UV, and mood) plus sunlight hours and resting heart rate into a single value in `[0, 1]`. The composition is deliberately more than a weighted average.

### 3.1 Circadian weights

The four pillars are weighted by time of day, because relevance shifts:

| Window      | Sleep | Activity | Sunlight | Mood |
| ----------- | :---: | :------: | :------: | :--: |
| 05:00–10:00 | 0.35  |   0.28   |   0.17   | 0.20 |
| 10:00–14:00 | 0.22  |   0.28   |   0.28   | 0.22 |
| 14:00–18:00 | 0.22  |   0.22   |   0.22   | 0.34 |
| 18:00–22:00 | 0.34  |   0.18   |   0.14   | 0.34 |
| 22:00–05:00 | 0.42  |   0.12   |   0.10   | 0.36 |

Mornings favour activity and light (things the user can still act on); nights favour sleep and mood (the day's outcome).

### 3.2 Diminishing returns

Each pillar is passed through a `pow(x, 0.6)` curve before weighting. This is softer than a square root and encodes the intuition that the first improvement matters most: going from a poor to a fair night of sleep moves the score more than going from good to perfect.

### 3.3 Coupling, trend, and physiological signals

On top of the weighted base, several adjustments model interactions that a linear blend would miss:

- **Sleep–mood coupling.** When both sleep and mood fall below 0.4, a penalty
  proportional to their joint severity is applied.
- **Mood trend bonus.** A weighted slope over the last five mood entries adds a small bonus for an improving trajectory and a smaller penalty for a declining one (asymmetric: rewarding recovery more than punishing dips).
- **Sunlight curve.** Daily sunlight hours contribute through a logarithmic term that plateaus around two hours, reflecting saturating benefit.
- **Heart-rate stress signal.** A resting heart rate above ~85 bpm applies a small penalty scaled to the excess, as a rough stress proxy.
- **Synergy and imbalance.** Having three or more strong pillars earns a synergy bonus; a single pillar dragging far below the average incurs an imbalance
  penalty. Balance is rewarded, lopsidedness is not.

The result is clamped to `[0, 1]`.

### 3.4 Explainability

A composite score is only useful if the user can see why it is what it is. The`breakdown` property exposes each pillar's raw value, its current weight, and its weighted contribution, which drives the on-screen ring and pillar cards. The `insight` property names the weakest pillar in plain language ("Sleep is your bottleneck today", "A short walk could lift your score"), and the `label`
maps the score to a human band (Radiant, Thriving, Balanced, Drained, Low Energy) with matching colors. The intent is that the number never appears without a reason attached to it.

## 4. Data sources

- **Health**: `HealthViewModel` reads sleep, steps and heart rate via
  HealthKit, with permission requested at runtime (usage descriptions are set in the target's generated Info.plist).
- **Weather and location**: `WeatherViewModel` resolves the device location via CoreLocation and queries a weather API for temperature, condition, UV index, wind, precipitation and astronomy (sunrise/sunset), from which sunlight hours are derived and rendered by the sun-arc component.
- **Mood**: captured through the check-in sheet, capped at two entries per day, and persisted as `MoodEntry` values.
- **History**: `HistoricalDataGenerator` synthesizes plausible historical snapshots for the demo account (`demo@aura.app`) so the trend charts and calendar are populated; regular accounts start empty, and in a production build this would be replaced by real historical HealthKit queries.

## 5. Authentication and privacy

Two paths exist: Sign in with Apple (via `AuthenticationServices`) and a loca email/password account. The local path never stores plaintext passwords `AccountStore` keeps only a SHA-256 hash (CryptoKit) in `UserDefaults`. This is adequate for a local-only prototype but is explicitly not a substitute for a real identity backend; there is no server, no salting/stretching (e.g. bcrypt or Argon2), and no cross-device sync.

All mood and health data stays on device. The only outbound network calls are the weather query and, when enabled, the AI assistant request.

## 6. The AI assistant

`AuraChatAIViewModel` talks to an OpenAI-compatible chat endpoint (Groq's Llama 3.3 by default). It sends a system prompt that frames the assistant as a warm, non-diagnostic wellness companion, includes a short window of recent messages for context, and appends the complete reply to the chat view once it arrives (no token streaming). The assistant is gated behind the mock paywall. When no key is configured, the feature is simply inert.

## 7. Known limitations and next steps

- **Synthetic history.** Trends rely on generated historical data; wiring real HealthKit history is the obvious next step.
- **Local-only accounts.** Authentication and persistence are on-device only; a real backend would be needed for sync and secure identity.
- **Mock monetization.** The paywall gates features but performs no StoreKit transactions.
- **Score calibration.** The Aura Score's constants (weights, curve exponents, penalty magnitudes) are hand-tuned from reasoning about well-being, not fit to data. A natural extension is to calibrate them against labelled outcomes.
- **Testing.** The prototype has no automated tests; the refactor into small, single-responsibility types is a precondition for adding them.

## 8. Summary

Aura is a compact demonstration of composing heterogeneous personal signals into one explainable score with SwiftUI, HealthKit and a weather API. The engineering emphasis is on an honest scoring model and a clean MVVM structure that makes that model easy to read, reason about, and extend.
