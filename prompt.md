# Cursor Prompt – dan_ton (Local AI Demo Assistant)

You are creating **dan_ton**, a fully local demo assistant that can **run scripted demos**, **speak** them aloud, and **answer stakeholder questions** — all without touching the cloud.  
This is built for a developer (Dan) who wants a calm, automated co-presenter for product demos.

---

## 🎯 Objectives
- Run scripted **demo flows** locally using Playwright (no external dependencies).
- Display a **LiveView overlay** with controls and logs.
- Provide **spoken narration** and **verbal answers** via local TTS.
- Answer questions about the demo or product using **RAG over local docs** and **Ollama**.
- Work **entirely offline**.

---

## 🧠 Core Capabilities

### 1. Demo Runner
- Reads a YAML scenario describing user interactions:
  ```yaml
  name: "Order Checkout Demo"
  env:
    base_url: "http://localhost:4000"
  steps:
    - goto: "/menu"
    - click: { role: "button", name: "Add to Cart" }
    - assert_text: "Added to cart"
    - goto: "/checkout"
    - fill: { field: "cardNumber", value: "4242 4242 4242 4242" }
    - click: { role: "button", name: "Pay" }
    - assert_text: "Order confirmed"
  recover:
    - reload: true
    - take_screenshot: true
  ```
- Executed by an Elixir **GenServer** that communicates via Port to a **Node.js Playwright bridge**.
- Supports `next`, `back`, `recover`, and `restart` actions.

---

### 2. Overlay (Phoenix LiveView)
- Displays:
  - Current step
  - Step status and log
  - Controls: Next / Back / Recover / Replay
- Keyboard shortcuts:
  - `Space` → Next step  
  - `B` → Back  
  - `R` → Recover  
  - `Cmd+/` → Ask a question  
  - `S` → Speak last answer

---

### 3. Q&A Engine (Local RAG)
- Indexes Markdown, ADRs, release notes, etc. from `demo/docs/` using **SQLite FTS5**.
- Local embedding/LLM via **Ollama** (`llama3.1:8b` by default).
- Returns answers with **inline file citations**.
- Example CLI call:
  ```bash
  mix dan_ton.ask "How does checkout handle failed payments?"
  ```

---

### 4. Voice (Speech Output)
- **Default (macOS)**: Uses built-in `say` command.
- **Optional (Cross-platform)**: **Piper TTS** with downloadable voices.
- Adapter pattern (`Pilot.TTS` behaviour) allows easy switching.
- **Playback queue** prevents overlapping speech.
- Trigger speech:
  - Automatically after AI answers.
  - Manually via hotkey `S`.

**Example:**
```elixir
Pilot.Speaker.speak("Welcome to the Whataburger demo! Let's start the checkout flow.")
```

---

### 5. Voice Input (Optional)
- Push-to-talk with Whisper.cpp or Vosk for speech-to-text.
- Use `Cmd+/` to toggle and transcribe a question to feed into Q&A.

---

## 📂 Folder Structure

```
dan_ton/
  apps/
    dan_web/      # Phoenix LiveView overlay
    dan_core/     # Runner, Q&A, TTS adapters, supervisor
    dan_node/     # Node.js Playwright bridge
  demo/
    scripts/      # *.yml demo scripts
    docs/         # Indexed reference docs
    fixtures/     # Demo datasets
  priv/db/        # SQLite FTS5 index
```

---

## ⚙️ Config Example

```elixir
# config/runtime.exs
config :dan_ton, :tts_engine,
  if System.get_env("DAN_TON_TTS") == "piper",
    do: DanTon.TTS.Piper,
    else: DanTon.TTS.MacSay
```

Use:
```bash
DAN_TON_TTS=piper iex -S mix phx.server
```

---

## 🛠️ Mix Tasks

| Command | Description |
|----------|--------------|
| `mix dan_ton.demo start --script demo/scripts/checkout.yml` | Run demo |
| `mix dan_ton.index` | Build doc index (RAG) |
| `mix dan_ton.ask "question"` | Ask the local assistant |
| `mix dan_ton.tts "text"` | Speak text manually |

---

## 🔊 Voice Output Routing (Optional)
To make dan_ton’s voice audible to others in a meeting:
1. Install **BlackHole 2ch** (virtual audio driver).
2. In macOS Audio MIDI Setup:
   - Create Multi-Output (BlackHole + Speakers).
3. In Teams/Zoom:
   - **Microphone:** BlackHole  
   - **Speaker:** Your physical output  
4. Now dan_ton can speak directly into the meeting.

---

## 🧩 Implementation Summary

| Component | Language | Purpose |
|------------|-----------|----------|
| Phoenix LiveView | Elixir | Overlay UI & hotkeys |
| GenServer | Elixir | Step orchestration |
| Port → Node | Elixir ↔ JS | Playwright automation |
| SQLite + Ollama | Elixir | Q&A + local LLM |
| `say` / Piper | Elixir | TTS adapter |
| Whisper.cpp (opt) | C | STT for Q&A input |

---

## ✅ Deliverable Summary

dan_ton should:
1. Run scripted demo flows locally.
2. Display a clear, controllable overlay.
3. Answer questions from local documentation.
4. Speak its narration and answers aloud.
5. Run entirely offline, on macOS.

Make it clean, modular, reliable — this is my personal **demo autopilot**.
