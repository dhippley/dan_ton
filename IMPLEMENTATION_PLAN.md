# dan_ton Implementation Plan

> **Project:** Local AI Demo Assistant  
> **Purpose:** Run scripted demos with voice narration and Q&A capabilities - entirely offline  
> **Target Platform:** macOS (with cross-platform TTS option)

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Implementation Tasks](#implementation-tasks)
4. [Dependencies](#dependencies)
5. [Development Phases](#development-phases)

---

## Project Overview

### Core Objectives
- Run scripted demo flows locally using Playwright (no external dependencies)
- Display a LiveView overlay with controls and logs
- Provide spoken narration and verbal answers via local TTS
- Answer questions about the demo or product using RAG over local docs and Ollama
- Work entirely offline

### Key Features
1. **Demo Runner**: Execute YAML-based demo scenarios with browser automation
2. **LiveView Overlay**: Real-time UI with keyboard shortcuts and controls
3. **Q&A Engine**: Local RAG using SQLite FTS5 and Ollama
4. **Voice System**: Text-to-speech with pluggable adapters (macOS `say` or Piper)
5. **Mix Tasks**: CLI tools for demo execution, indexing, and Q&A

---

## Architecture

### Application Structure (Umbrella App)

```
dan_ton/
├── apps/
│   ├── dan_web/          # Phoenix LiveView overlay
│   │   ├── lib/
│   │   │   ├── dan_web/
│   │   │   │   ├── live/
│   │   │   │   │   └── demo_live.ex
│   │   │   │   └── components/
│   │   │   └── dan_web.ex
│   │   └── assets/
│   │
│   ├── dan_core/         # Core business logic
│   │   ├── lib/
│   │   │   ├── dan_core/
│   │   │   │   ├── demo/
│   │   │   │   │   ├── runner.ex          # GenServer orchestrator
│   │   │   │   │   ├── parser.ex          # YAML parser
│   │   │   │   │   └── playwright_port.ex # Port bridge
│   │   │   │   ├── qa/
│   │   │   │   │   ├── indexer.ex         # Document indexer
│   │   │   │   │   ├── retriever.ex       # FTS5 search
│   │   │   │   │   └── engine.ex          # RAG pipeline
│   │   │   │   ├── tts/
│   │   │   │   │   ├── behaviour.ex       # TTS behaviour
│   │   │   │   │   ├── mac_say.ex         # macOS adapter
│   │   │   │   │   └── piper.ex           # Piper adapter
│   │   │   │   ├── speaker.ex             # Queue manager
│   │   │   │   └── supervisor.ex          # Main supervisor
│   │   │   └── dan_core.ex
│   │   └── priv/
│   │       └── node_bridge/
│   │           ├── package.json
│   │           ├── bridge.js              # Playwright bridge
│   │           └── executors.js           # Step implementations
│   │
│   └── dan_node/         # Node.js Playwright bridge (optional separate app)
│
├── demo/
│   ├── scripts/          # *.yml demo scripts
│   │   └── checkout.yml
│   ├── docs/             # Documentation for RAG indexing
│   │   ├── architecture.md
│   │   ├── api-guide.md
│   │   └── adr/
│   └── fixtures/         # Demo datasets
│
├── priv/
│   └── db/
│       └── dan_ton.db    # SQLite FTS5 index
│
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── runtime.exs       # TTS engine config
│
└── mix.exs
```

### Component Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Phoenix LiveView                         │
│                    (Overlay UI + Hotkeys)                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                    PubSub Events
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    DemoRunner GenServer                      │
│              (Orchestration + State Management)              │
└───────┬────────────────────────────────┬────────────────────┘
        │                                │
   Port Comm                        Task Events
        │                                │
┌───────▼────────────────────┐  ┌───────▼──────────┐
│   Node.js Playwright       │  │  Speaker Queue   │
│       Bridge               │  │   (TTS Adapter)  │
│                            │  │                  │
│  - goto                    │  │  - MacSay        │
│  - click                   │  │  - Piper         │
│  - fill                    │  └──────────────────┘
│  - assert_text             │
│  - take_screenshot         │
└────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                      Q&A Engine                              │
│                                                              │
│  ┌──────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │  SQLite  │───▶│  Retriever  │───▶│   Ollama    │        │
│  │   FTS5   │    │   (Search)  │    │  (LLM Gen)  │        │
│  └──────────┘    └─────────────┘    └─────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

---

## Implementation Tasks

### Phase 1: Foundation & Structure (Tasks 1-2)

#### Task 1: Set up umbrella app structure
- Convert single app to umbrella app
- Create three sub-applications:
  - `dan_web`: Phoenix LiveView
  - `dan_core`: Core logic
  - Optional: `dan_node` (or keep in priv/)
- Update mix.exs files accordingly
- Configure dependencies between apps

#### Task 2: Create directory structure
```bash
mkdir -p demo/{scripts,docs/adr,fixtures}
mkdir -p priv/db
mkdir -p apps/dan_core/priv/node_bridge
```

### Phase 2: Demo Runner System (Tasks 3-6)

#### Task 3: YAML scenario parser
- Create `DanCore.Demo.Parser` module
- Parse YAML structure:
  - `name`: Demo name
  - `env`: Environment variables (base_url, etc.)
  - `steps`: Array of step definitions
  - `recover`: Recovery actions
- Validate step types and parameters
- Return structured Elixir maps

#### Task 4: DemoRunner GenServer
- Create `DanCore.Demo.Runner` GenServer
- State management:
  - Current scenario
  - Current step index
  - Step history
  - Execution status
- Public API:
  - `start_demo(script_path)`
  - `next_step()`
  - `previous_step()`
  - `recover()`
  - `restart()`
- Broadcast events via PubSub

#### Task 5: Node.js Playwright bridge
- Set up Node.js project in `priv/node_bridge/`
- Create `bridge.js` with stdio communication
- Parse commands from Elixir via Port
- Return execution results as JSON
- Handle errors and timeouts
- Package.json dependencies: playwright, yaml

#### Task 6: Playwright step executors
Create executors for each step type:
- `goto`: Navigate to URL
- `click`: Click element (by role, text, selector)
- `fill`: Fill form fields
- `assert_text`: Verify text presence
- `reload`: Reload page
- `take_screenshot`: Capture screenshot
- Error handling and recovery

### Phase 3: LiveView Overlay (Tasks 7-8)

#### Task 7: Phoenix LiveView UI
- Create `DanWeb.DemoLive` LiveView
- Components:
  - Current step display
  - Progress indicator
  - Status logs (scrollable)
  - Control buttons
  - Screenshot preview (if applicable)
- Subscribe to PubSub demo events
- Update UI in real-time
- Styling with TailwindCSS + DaisyUI

#### Task 8: Keyboard shortcuts
Implement Phoenix.LiveView.JS hooks for:
- `Space`: Next step
- `B`: Back/previous step
- `R`: Recover
- `Cmd+/`: Open Q&A modal
- `S`: Speak last answer
- `Esc`: Close modals

### Phase 4: Q&A Engine (Tasks 9-12)

#### Task 9: SQLite database setup
- Create `priv/db/dan_ton.db`
- Define FTS5 virtual table schema:
  ```sql
  CREATE VIRTUAL TABLE documents USING fts5(
    file_path,
    title,
    content,
    section,
    tokenize = 'porter unicode61'
  );
  ```
- Use `Exqlite` or `Ecto.Adapters.SQLite3`

#### Task 10: Document indexer
- Create `DanCore.QA.Indexer`
- Scan `demo/docs/` recursively
- Parse Markdown files:
  - Extract title, sections, headers
  - Split into chunks
  - Preserve metadata
- Insert into FTS5 table
- Track file checksums for incremental updates

#### Task 11: Ollama client integration
- Create `DanCore.QA.Ollama` module
- Use `Req` for HTTP communication
- Default model: `llama3.1:8b`
- API methods:
  - `generate(prompt, context)`
  - `embeddings(text)` (optional for semantic search)
- Handle streaming responses
- Error handling and timeouts

#### Task 12: RAG query engine
- Create `DanCore.QA.Engine`
- Pipeline:
  1. Query → FTS5 search (retrieve top 5-10 chunks)
  2. Build context from retrieved docs
  3. Create prompt with context + question
  4. Call Ollama for generation
  5. Parse response and add citations
- Format citations: `[doc: path/to/file.md#section]`
- Cache recent queries (optional)

### Phase 5: Voice System (Tasks 13-16)

#### Task 13: TTS behaviour module
- Create `DanCore.TTS` behaviour
- Define callbacks:
  ```elixir
  @callback speak(text :: String.t()) :: :ok | {:error, term()}
  @callback available?() :: boolean()
  @callback voice_list() :: [String.t()]
  ```

#### Task 14: MacSay adapter
- Create `DanCore.TTS.MacSay`
- Implement behaviour using System.cmd/3
- Command: `say -v [voice] "text"`
- Handle special characters and escaping
- Check availability with `which say`

#### Task 15: Piper adapter (optional)
- Create `DanCore.TTS.Piper`
- Download Piper binary and voice models
- Execute via Port or System.cmd
- Stream audio output
- More complex but cross-platform

#### Task 16: Speaker queue module
- Create `DanCore.Speaker` GenServer
- Queue speech requests
- Prevent overlapping playback
- Track speaking state
- Public API:
  ```elixir
  Speaker.speak(text)
  Speaker.stop()
  Speaker.clear_queue()
  Speaker.speaking?()
  ```

### Phase 6: Developer Experience (Tasks 17-25)

#### Task 17: mix dan_ton.demo task
```elixir
# lib/mix/tasks/dan_ton.demo.ex
defmodule Mix.Tasks.DanTon.Demo do
  use Mix.Task
  
  @shortdoc "Run a demo script"
  def run(args) do
    # Parse --script flag
    # Start application
    # Load and execute demo
    # Optional: --headless flag
  end
end
```

#### Task 18: mix dan_ton.index task
```elixir
# lib/mix/tasks/dan_ton.index.ex
defmodule Mix.Tasks.DanTon.Index do
  use Mix.Task
  
  @shortdoc "Build document index for Q&A"
  def run(args) do
    # Start app
    # Run indexer
    # Show progress and stats
  end
end
```

#### Task 19: mix dan_ton.ask task
```elixir
# lib/mix/tasks/dan_ton.ask.ex
defmodule Mix.Tasks.DanTon.Ask do
  use Mix.Task
  
  @shortdoc "Ask a question to the assistant"
  def run(args) do
    # Parse question from args
    # Query RAG engine
    # Print answer with citations
    # Optional: --speak flag
  end
end
```

#### Task 20: mix dan_ton.tts task
```elixir
# lib/mix/tasks/dan_ton.tts.ex
defmodule Mix.Tasks.DanTon.Tts do
  use Mix.Task
  
  @shortdoc "Test text-to-speech"
  def run(args) do
    # Parse text from args
    # Speak using configured TTS
    # Show available voices with --list
  end
end
```

#### Task 21: Runtime configuration
Update `config/runtime.exs`:
```elixir
config :dan_core, :tts_engine,
  if System.get_env("DAN_TON_TTS") == "piper" do
    DanCore.TTS.Piper
  else
    DanCore.TTS.MacSay
  end

config :dan_core, :ollama,
  base_url: System.get_env("OLLAMA_URL", "http://localhost:11434"),
  model: System.get_env("OLLAMA_MODEL", "llama3.1:8b")
```

#### Task 22: Supervisor tree
```elixir
# lib/dan_core/supervisor.ex
defmodule DanCore.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {DanCore.Speaker, []},
      {DanCore.Demo.Runner, []},
      {DanCore.QA.Engine, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

#### Task 23: Add dependencies
Update `mix.exs` in respective apps:
```elixir
# dan_core dependencies
{:yaml_elixir, "~> 2.9"},
{:exqlite, "~> 0.14"},
{:req, "~> 0.4"},  # Already present

# Node.js package.json
{
  "dependencies": {
    "playwright": "^1.40.0"
  }
}
```

#### Task 24: Create example demo script
```yaml
# demo/scripts/checkout.yml
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

#### Task 25: Add sample documentation
Create sample docs in `demo/docs/`:
- `architecture.md`: System architecture overview
- `checkout-flow.md`: Checkout process documentation
- `payment-handling.md`: Payment integration details
- `adr/001-payment-provider.md`: Example ADR

---

## Dependencies

### Elixir Dependencies
| Package | Purpose | App |
|---------|---------|-----|
| `phoenix_live_view` | UI framework | dan_web |
| `yaml_elixir` | YAML parsing | dan_core |
| `exqlite` | SQLite driver | dan_core |
| `req` | HTTP client for Ollama | dan_core |

### Node.js Dependencies
| Package | Purpose |
|---------|---------|
| `playwright` | Browser automation |
| `yaml` | YAML parsing (optional) |

### External Tools
| Tool | Purpose | Platform |
|------|---------|----------|
| Ollama | Local LLM | macOS/Linux/Windows |
| `say` command | TTS (default) | macOS only |
| Piper | TTS (optional) | Cross-platform |
| BlackHole 2ch | Virtual audio (optional) | macOS |

---

## Development Phases

### Phase 1: Proof of Concept (Week 1)
**Goal:** Basic demo runner working
- [ ] Task 1-2: Project structure
- [ ] Task 3-4: YAML parser + GenServer
- [ ] Task 5-6: Playwright bridge (basic steps)
- [ ] Task 24: Example script
- **Milestone:** Can run a simple demo script from command line

### Phase 2: Core Features (Week 2)
**Goal:** Full demo runner + UI
- [ ] Task 7-8: LiveView overlay + shortcuts
- [ ] Task 13-14: TTS with MacSay
- [ ] Task 16: Speaker queue
- [ ] Task 22: Supervisor tree
- **Milestone:** Interactive demo with voice narration

### Phase 3: Intelligence (Week 3)
**Goal:** Q&A system operational
- [ ] Task 9-10: SQLite + indexer
- [ ] Task 11-12: Ollama + RAG engine
- [ ] Task 25: Sample documentation
- **Milestone:** Can ask questions and get spoken answers

### Phase 4: Polish & Tools (Week 4)
**Goal:** Production-ready
- [ ] Task 17-21: Mix tasks + config
- [ ] Task 15: Piper adapter (optional)
- [ ] Task 23: Finalize dependencies
- [ ] Testing and refinement
- [ ] Documentation
- **Milestone:** Full system ready for demos

---

## Success Criteria

dan_ton is complete when it can:

1. ✅ Load and execute a YAML demo script
2. ✅ Display real-time progress in LiveView overlay
3. ✅ Navigate browser and perform actions via Playwright
4. ✅ Speak narration aloud using local TTS
5. ✅ Answer questions from indexed documentation
6. ✅ Respond to keyboard shortcuts for hands-free operation
7. ✅ Run entirely offline with no cloud dependencies
8. ✅ Recover gracefully from demo failures
9. ✅ Provide clear CLI tools for all operations

---

## Notes & Considerations

### Security
- All operations local, no cloud data exposure
- No API keys or external services required
- Demo scripts should be version controlled

### Performance
- SQLite FTS5 is fast for small-to-medium doc sets
- Ollama response time depends on model size and hardware
- Consider lazy-loading Playwright for faster startup

### Future Enhancements
- Voice input (Whisper.cpp/Vosk) for spoken questions
- Multiple demo script support
- Demo recording/playback
- Custom LLM fine-tuning on product docs
- Web-based script editor
- Multi-language support

---

## Getting Started

Once implementation begins:

```bash
# 1. Install Ollama
brew install ollama
ollama pull llama3.1:8b

# 2. Install Node.js dependencies
cd apps/dan_core/priv/node_bridge
npm install

# 3. Install Playwright browsers
npx playwright install chromium

# 4. Build doc index
mix dan_ton.index

# 5. Run a demo
mix dan_ton.demo start --script demo/scripts/checkout.yml

# 6. Or start Phoenix with overlay
iex -S mix phx.server
```

---

**Ready to build your demo autopilot!** 🚀
