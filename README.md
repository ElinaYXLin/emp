# Entropy Player

A local music player with a hand-tuned DSP effects chain — reverb, EQ, saturation, and limiting — all driven by a single macro fader. No data ever leaves your machine. Best for nostalgia and solitude.

---

> **HEARING SAFETY — READ THIS FIRST**
>
> The reverb, EQ boost, saturation, and compression stack can raise perceived loudness well above the original signal — and the effect is non-linear: a small macro move at high settings can produce a sudden, very loud burst.
>
> - **Always start with your system volume at 20–30 % and raise it gradually.**
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
| Latency | Browser audio stack (~20 ms) | Native CoreAudio, ~20–30 ms (multiple internal DSP stages) |

---

## DSP Signal Chain

Both editions run the *exact same DSP algorithms* in the same order — the macOS app doesn't call out to Apple's built-in AudioUnits for these stages (they sound and scale differently from Web Audio's equivalents); it ports the web edition's math directly into Swift so both editions are acoustically identical, not just similarly configured:

```
Audio source → Pre-Amp → Reverb → EQ (150 Hz bell) → Saturator → Limiter / Compressor → Post-Gain → Output
```

In file mode the source is an audio file. In system capture mode (macOS only) the source is any audio playing on your Mac — Spotify, YouTube, a game, anything routed through the virtual device.

| Stage | What it does | Range |
|---|---|---|
| **Pre-Amp** | Attenuates the raw signal before any processing — sits at the front, so raising it drives the whole chain (and the saturator/limiter) harder | −12 dB → 0 dB |
| **Reverb** | Real convolution with a randomly generated, exponentially decaying white-noise impulse response (not an algorithmic/comb-filter reverb) — decay time = `eff^1.5 × 60`, dry/wet mix is a constant 0.6 / 0.8 blend | 0 → 60 s (web) / 0 → 2 s (app, capped for real-time safety) |
| **EQ** | Peaking bell at 150 Hz, Q 0.1 (very wide, gentle bell) | 0 → 12 dB |
| **Saturator** | Tanh soft-clip waveshaper, identical formula on both editions | 0 → 8 dB drive |
| **Limiter** | Brickwall-ish: threshold 0 dBFS, ratio 20:1, 1 ms attack — fast enough that hot transients can still poke through and audibly distort, by design | always on when selected |
| **Compressor** | Musical 4:1 at −18 dBFS, 12 dB knee, with a fixed −6 dB makeup trim | switchable |
| **Post-Gain** *(macOS only)* | Final output trim, applied after everything else — turning this up or down changes actual loudness sent to your speakers/headphones without re-driving the saturator/limiter (unlike Pre-Amp) | −24 dB → +24 dB |

The **Macro** fader drives Reverb/EQ/Saturator simultaneously. Each stage has its own **Sensitivity** knob and a **Range** (min / max travel).

---

## Controls Reference

### Pre-Amp slider
Drag **up** for 0 dB (unity). Drag **down** for −12 dB. Sits before the reverb — it genuinely changes how hard you hit the chain, so raising it drives the saturator/limiter harder (more distortion, not just more volume).

### Post-Gain slider *(macOS only, far right)*
A clean final trim from −24 dB to +24 dB, applied after the entire DSP chain — reverb, EQ, saturator, and limiter/compressor have all already run. Use this to make the app louder or softer without changing the DSP chain's character at all. If playback sounds soft, raise this first before touching Pre-Amp.

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
1. Open `EntropyPlayer.xcodeproj` in Xcode (the macOS project lives in its own `EntropyPlayer-macOS` folder alongside this one).
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
The app is sandboxed. When you click **Open** for the first time macOS shows a folder-access prompt — grant access to your music folder. **Save Settings**/**Load Settings** use the same sandboxed file-picker mechanism to write and read your presets.

When you enable **System** capture mode for the first time, macOS will show a microphone-access prompt. Grant it — the app uses this entitlement to read from the virtual audio device (BlackHole), not from an actual microphone.

The app makes no network connections.

### Distributing to another Mac (no Xcode required on destination)
1. In Xcode: **Product → Archive**, then in Organizer: **Distribute App → Copy App**.
2. Copy the resulting `EntropyPlayer.app` to the target Mac's `/Applications`.
3. On first launch on the other machine, **right-click → Open** to bypass Gatekeeper for unsigned builds.

---

## System Audio Capture (macOS)

This lets Entropy Player process audio from any app — Spotify, Apple Music, YouTube in a browser, a game — in real time. It works by routing your Mac's system output into a free virtual audio device called **BlackHole**, which Entropy Player reads directly, runs through its full DSP chain, and sends back out to your real headphones or speakers — entirely independent of the system's own Sound settings.

> **Volume warning**: the processed signal can be louder than the original, especially with reverb/EQ/saturation dialed up. Lower your system volume before enabling this mode, then raise it gradually. See the hearing safety notice at the top of this document.

### Step 1 — Install BlackHole

BlackHole is a free, open-source virtual audio driver. Get the **BlackHole 2ch** installer from the official releases page (search "BlackHole audio macOS" — the repo is on GitHub under ExistentialAudio/BlackHole). Run the installer; no restart is needed.

### Step 2 — Route system audio into BlackHole

Open **System Settings → Sound → Output** and select **BlackHole 2ch**.

Your speakers/headphones will go silent at the system level — this is expected and correct. BlackHole is a virtual "cable," not a physical device; nothing plays out of it directly. Sound comes back once Entropy Player is capturing and sending processed audio to your real output device (next step).

You do **not** need to touch **System Settings → Sound → Input**, create an Audio MIDI Setup aggregate device, or use Apple's own audio routing tools — Entropy Player reads from BlackHole directly on its own, independent of whatever the system's default input is set to.

### Step 3 — Enable capture in Entropy Player

1. Launch Entropy Player.
2. In the top-bar row 2, click the **System** button.
3. Two device pickers appear:
   - **IN** — select **BlackHole 2ch**. This is where Entropy Player reads system audio from.
   - **OUT** — select your actual headphones or speakers (e.g. your Mac's built-in output, EarPods, AirPods). This is where the *processed* signal is sent — it is **not** the same as the system Sound Output setting from Step 2, which must stay on BlackHole for capture to keep working.
4. Click **System** again if it did not start automatically.
5. The transport area shows **LIVE — System Audio** with a red dot once capture is running.

All audio playing on your Mac now passes through the reverb → EQ → saturator → limiter → post-gain chain at whatever macro level you have set, and comes out of whatever device you picked as **OUT**.

### Step 4 — Return to normal audio output

When you are done:
1. Click **Stop** in the transport area (or click the active **System** button again).
2. Go back to **System Settings → Sound → Output** and re-select your headphones or speakers (Entropy Player does not change this setting automatically — BlackHole stays selected there until you switch it back).

### Troubleshooting

| Problem | Fix |
|---|---|
| No devices appear in either picker | BlackHole is not installed, or the app has not been granted audio-input access yet — check **System Settings → Privacy & Security → Microphone** and allow Entropy Player (it uses this entitlement to read BlackHole, not an actual microphone) |
| No sound at all | Confirm system **Sound → Output** is BlackHole (Step 2) *and* the app's own **OUT** picker (Step 3) is set to your real headphones/speakers — both need to be right, they control different things |
| You hear your own microphone instead of system audio | The **IN** picker is set to a real microphone instead of BlackHole 2ch — reselect BlackHole 2ch as IN |
| Double audio (dry + processed) | System Sound Output is set to something other than BlackHole (e.g. both BlackHole and speakers via a Multi-Output Device) — set system Output to BlackHole only |
| Distorted or silent sound after sleep/wake or unplugging headphones | The app listens for device changes and restarts automatically within under a second; if it doesn't recover, toggle **System** off and back on, or relaunch the app |
| Latency / echo feeling | Expected; each DSP stage's internal buffering adds a few milliseconds, roughly comparable to the web edition's ~20 ms end-to-end |

---

## Differences between editions

| Feature | Web | macOS |
|---|---|---|
| Reverb decay range | 0 – 60 s (generated IR) | 0 – 2 s (same algorithm, capped for real-time CPU safety) |
| Saturator algorithm | tanh waveshaper | Identical tanh waveshaper, ported to Swift |
| Limiter/Compressor algorithm | Web Audio DynamicsCompressorNode | Identical soft-knee curve, ported to Swift |
| Auto macro mode | ✓ | — |
| System audio intercept | — | ✓ (BlackHole required) |
| Post-Gain (final output trim) | — | ✓ −24 → +24 dB |
| Waveform export | ✓ WAV download | — |
| Audio latency | ~20 ms | ~20–30 ms (several internal DSP buffering stages) |
| Offline use | ✓ single HTML file, no server | ✓ no network required |

---

*No signal leaves your machine.*
