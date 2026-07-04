# Entropy Player

A local music player with a hand-tuned DSP effects chain — reverb, EQ, saturation, and limiting — all driven by a single macro fader. No data ever leaves your machine. Best for nostalgia and solitude.

---

> **HEARING SAFETY — READ THIS FIRST**
>
> The reverb, EQ boost, saturation, and compression stack can raise perceived loudness well above the original signal — and the effect is non-linear: a small macro move at high settings can produce a sudden, very loud burst.
>
> - **Always start with your system volume at 10–20 % and raise it gradually.**
> - Never run the Vibrato mode at high macro levels with headphones on. The drifting saturation can produce sharp transient spikes.
> - The Compressor mode with makeup gain can push levels significantly above the source material's loudness.
> - If you hear ear pain, ringing, muffled sound, or discomfort — stop immediately and rest your ears.
> - Prolonged exposure to loud audio (above ~85 dB SPL) causes permanent, irreversible hearing damage.

---

Two editions ship side-by-side:

| | Web (`entropy_player_1.html`) | macOS app (`EntropyPlayer-macOS/`) |
|---|---|---|
| Runs on | Any modern browser | macOS 12 Monterey or later |
| Install | None — open the HTML file | Xcode required to build |
| Auto mode | ✓ (LUFS-based macro per track) | — (browser API only) |
| System audio intercept | — | ✓ via virtual audio device (BlackHole) |
| Latency | Browser audio stack (~20 ms) | Native CoreAudio, 256-frame buffer (~5 ms) |

---

## DSP Signal Chain

Both editions share the same chain in this order:

```
Audio source → Pre-Amp → Reverb → EQ (150 Hz bell) → Saturator → Limiter / Compressor → Output
```

In file mode the source is an audio file. In system capture mode (macOS only) the source is any audio playing on your Mac — Spotify, YouTube, a game, anything routed through the virtual device.

| Stage | What it does | Range |
|---|---|---|
| **Pre-Amp** | Attenuates the raw signal before any processing | −12 dB → 0 dB |
| **Reverb** | Algorithmic reverb; decay time scales quadratically with the knob | 0 → 60 s (web) / 20 s (app) |
| **EQ** | Peaking bell at 150 Hz, low Q (wide boost) | 0 → 12 dB |
| **Saturator** | Tanh soft-clip (web) / Soft Distortion preset (macOS) | 0 → 8 dB drive |
| **Limiter** | Brickwall at 0 dBFS, 1 ms attack | always on when selected |
| **Compressor** | Musical 4:1 at −18 dBFS with makeup gain | switchable |

The **Macro** fader drives all three middle stages simultaneously. Each stage has its own **Sensitivity** knob and a **Range** (min / max travel).

---

## Controls Reference

### Pre-Amp slider
Drag **up** for 0 dB (unity). Drag **down** for −12 dB. Sits before the reverb — it genuinely changes how hard you hit the chain.

### Sensitivity knobs
Controls how aggressively each effect responds to the macro.
- 0 % → effect is silent regardless of macro position
- 100 % → effect reaches full depth at macro 100

### Range sliders (min / max per effect)
Cap the lower and upper limits of each effect's travel. Useful to keep reverb always slightly on, or to prevent EQ going past a mild boost.

### Macro slider (right side)
The master fader. Controls all three effects proportionally through their sensitivity and range settings.

### Macro modes
- **Manual** — drag the slider freely.
- **Vibrato** — the macro drifts ±10 around the position it was at when you engaged the mode. **Reverb is held constant** during vibrato; only EQ and saturation flutter.
  - **Slow** — 10 seconds to drift to each new target
  - **Fast** — 2 seconds per drift
- **Auto** *(web only)* — measures integrated RMS loudness of each track on load and sets the macro so louder masters get less processing.

### Limiter / Compressor toggle
- **Limiter** — brickwall at 0 dBFS, 1 ms attack. Transparent unless the chain is heavily driven.
- **Compressor** — 4:1 ratio at −18 dBFS with makeup gain. Catches transients gently.

### Transport
**⏮** previous track · **▶ / ❚❚** play / pause · **⏭** next track

---

## Web App — Usage

### Requirements
Any browser with Web Audio API support: Chrome, Firefox, Safari 14+, Edge.

### Setup
1. Double-click `entropy_player_1.html` — it opens in your default browser.
   Alternatively drag it onto any open browser window.
2. Click **Open** and select a folder of audio files.
   Supported: MP3, OGG, WAV, FLAC, AAC, M4A.

### Quick start
1. Press **▶** to start.
2. Turn the **Reverb** knob up slowly to add space.
3. Raise the **Macro** slider to blend all effects together.
4. Switch to **Vibrato → Slow** for a slow drift effect.

### Saving / loading settings
**Save Settings** downloads a JSON file with all knob values, ranges, macro position, color, and order. **Upload Settings** restores any such file.

### Exporting processed audio
**Save** renders the current track through the live effect settings offline and downloads it as a WAV. Takes a few seconds for long files.

### File access and privacy
The app runs entirely in-browser. No files are uploaded anywhere. The browser's `File` API reads tracks from your local disk only.

---

## macOS App — Installation

### Requirements
- **macOS 12 Monterey** or later
- **Xcode 14** or later (free from the Mac App Store)

### Build steps
1. Open `EntropyPlayer-macOS/EntropyPlayer.xcodeproj` in Xcode.
2. In the toolbar confirm the scheme is **EntropyPlayer** and the destination is **My Mac**.
3. Press **⌘R** to build and run.

No Swift packages are fetched — everything uses built-in Apple frameworks (SwiftUI, AVFoundation, CoreAudio).

### Code signing
On first build Xcode assigns your personal team automatically. If a signing error appears:
1. Click the **EntropyPlayer** target in the Project navigator.
2. Open **Signing & Capabilities**.
3. Set **Team** to your Apple ID (a free development certificate is sufficient).
4. Change **Bundle Identifier** if a conflict is reported (e.g. `com.yourname.entropy-player`).

### File-access permissions
The app is sandboxed. When you click **Open** for the first time macOS shows a folder-access prompt — grant access to your music folder.

When you enable **System** capture mode for the first time, macOS will show a microphone-access prompt. Grant it — the app uses this entitlement to read from the virtual audio device (BlackHole), not from an actual microphone.

The app makes no network connections.

### Distributing to another Mac (no Xcode required on destination)
1. In Xcode: **Product → Archive**, then in Organizer: **Distribute App → Copy App**.
2. Copy the resulting `EntropyPlayer.app` to the target Mac's `/Applications`.
3. On first launch on the other machine, **right-click → Open** to bypass Gatekeeper for unsigned builds.

---

## System Audio Capture (macOS)

This lets Entropy Player process audio from any app — Spotify, Apple Music, YouTube in a browser, a game — in real time. It works by routing your Mac's audio output through a free virtual audio device called **BlackHole**, which Entropy Player then reads as an input.

> **Volume warning**: when you activate system capture, your Mac's output is redirected. The processed signal may be louder than the original. Lower your system volume before enabling this mode.

### Step 1 — Install BlackHole

BlackHole is a free, open-source virtual audio driver. Get the **BlackHole 2ch** installer from the official releases page (search "BlackHole audio macOS" — the repo is on GitHub under ExistentialAudio/BlackHole). Run the installer; no restart is needed.

### Step 2 — Redirect system audio to BlackHole

Open **System Preferences → Sound → Output** and select **BlackHole 2ch**.

Your speakers will go silent — this is expected. Sound will come back through Entropy Player after you activate capture mode.

### Step 3 — Enable capture in Entropy Player

1. Launch Entropy Player.
2. In the top-bar row 2, click the **System** button. A device picker appears next to it.
3. Select **BlackHole 2ch** from the picker.
4. Click **System** again if it did not start automatically.
5. The transport area shows **LIVE — System Audio** with a red dot.

All audio playing on your Mac now passes through the reverb → EQ → saturator → limiter chain at whatever macro level you have set.

### Step 4 — Return to normal audio output

When you are done:
1. Click **Stop** in the transport area (or click the active **System** button again).
2. Go back to **System Preferences → Sound → Output** and re-select your headphones or speakers.

### Troubleshooting

| Problem | Fix |
|---|---|
| No devices appear in the picker | BlackHole is not installed, or the app has not been granted microphone access yet |
| Silence after activating | Check that macOS output is set to BlackHole, not your speakers |
| Double audio (dry + processed) | System output is going to both BlackHole and speakers — remove speakers from the output |
| Latency / echo feeling | Expected; the 256-frame CoreAudio buffer adds ~5 ms. Don't run both Entropy Player and the Compressor mode simultaneously at high levels |

---

## Differences between editions

| Feature | Web | macOS |
|---|---|---|
| Reverb decay range | 0 – 60 s (generated IR) | 0 – 20 s (CoreAudio Reverb2) |
| Saturator algorithm | tanh WaveShaper (Web Audio) | Soft Distortion AudioUnit |
| Auto macro mode | ✓ | — |
| System audio intercept | — | ✓ (BlackHole required) |
| Waveform export | ✓ WAV download | — |
| Audio latency | ~20 ms | ~5 ms |
| Offline use | ✓ single HTML file, no server | ✓ no network required |

---

*No signal leaves your machine.*
