# dan_ton - Local AI Demo Assistant

> Run scripted product demos with voice narration and Q&A capabilities - entirely offline

**dan_ton** (Demo Assistant with Neural Text-to-speech, Offline and Navigable) is a Phoenix LiveView application that automates product demos using Playwright, provides AI-powered Q&A with RAG, and speaks naturally using neural TTS - all running completely locally for maximum privacy and reliability.

## Features

- **📜 YAML-Based Demo Scripts**: Define demo flows in simple YAML files
- **🎭 Playwright Automation**: Control browsers with precise step-by-step execution
- **🎙️ Neural Text-to-Speech**: Natural voice narration using Piper TTS
- **🤖 AI-Powered Q&A**: Answer questions about your docs using RAG + Ollama
- **📡 Real-Time LiveView UI**: Monitor demos with beautiful real-time updates
- **⌨️ Keyboard Shortcuts**: Hands-free operation for live presentations
- **🔒 Completely Offline**: No cloud services, no API keys, no data leaks
- **🏗️ Umbrella Architecture**: Clean separation of concerns

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Phoenix LiveView UI                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Demo    │  │   Q&A    │  │ Speaker  │  │  Status  │   │
│  │ Controls │  │  Modal   │  │ Controls │  │   Logs   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ↕ PubSub
┌─────────────────────────────────────────────────────────────┐
│                    DanCore (Business Logic)                  │
│                                                              │
│  ┌────────────────────────────┐  ┌─────────────┐           │
│  │  Demo Runner (GenServer)   │  │  Speaker    │           │
│  │  ┌──────────────────────┐  │  │  Queue      │           │
│  │  │ YAML Parser          │  │  └─────────────┘           │
│  │  │ Scenario Management  │  │                             │
│  │  │ Step Execution       │  │  ┌──────────────┐          │
│  │  │ Recovery Actions     │  │  │     TTS      │          │
│  │  └──────────────────────┘  │  │  ┌────────┐  │          │
│  └────────────────────────────┘  │  │ Piper  │  │          │
│                                   │  │ MacSay │  │          │
│  ┌────────────────────────────┐  │  │  Null  │  │          │
│  │  Playwright Bridge         │  │  └────────┘  │          │
│  │  ┌──────────────────────┐  │  └──────────────┘          │
│  │  │ Node.js Process      │  │                             │
│  │  │ Erlang Port          │  │  ┌─────────────────┐       │
│  │  │ Command Protocol     │  │  │  Q&A Engine     │       │
│  │  └──────────────────────┘  │  │  ┌───────────┐  │       │
│  │                            │  │  │  SQLite   │  │       │
│  │  Step Types:               │  │  │   FTS5    │  │       │
│  │  - goto                    │  │  ├───────────┤  │       │
│  │  - click                   │  │  │ Document  │  │       │
│  │  - fill                    │  │  │ Indexer   │  │       │
│  │  - assert_text             │  │  ├───────────┤  │       │
│  │  - take_screenshot         │  │  │  Ollama   │  │       │
│  └────────────────────────────┘  │  │  Client   │  │       │
│                                   │  └───────────┘  │       │
│                                   └─────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- **Elixir** 1.15+ with OTP 26+
- **Node.js** 18+ (for Playwright bridge)
- **PostgreSQL** 14+ (for Ecto/Oban)
- **Ollama** (for Q&A) - [Install here](https://ollama.com)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dan_ton.git
cd dan_ton

# Install dependencies
mix deps.get
npm --prefix apps/dan_web/assets install

# Setup database
mix ecto.setup

# Initialize Q&A system
mix qa.init

# Setup Piper TTS
mix piper.setup

# Download Ollama model (for Q&A)
ollama pull llama3.1:8b

# Start the server
mix phx.server
```

Visit http://localhost:4000/demo to see the demo runner!

## Usage

### Web Interface

1. **Start Server**: `mix phx.server`
2. **Open Demo**: Navigate to http://localhost:4000/demo
3. **Load Script**: Select a demo script from the dropdown
4. **Run Demo**: Click "Start" and watch the automation
5. **Ask Questions**: Press `Cmd+/` to open Q&A modal
6. **Voice Output**: Press `S` to speak Q&A answers

### CLI Tools

#### Run a Demo

```bash
# Run demo script
mix dan.demo demo/scripts/example_demo.yml

# Step-by-step with narration
mix dan.demo demo/scripts/checkout_demo.yml --step --narrate

# List available demos
mix dan.demo --list
```

#### Ask Questions

```bash
# Ask a question
mix dan.ask "How does the demo system work?"

# With voice output
mix dan.ask "What is RAG?" --speak

# Use different model
mix dan.ask "Explain LiveView" --model llama2:7b
```

#### Test Text-to-Speech

```bash
# Speak text
mix dan.speak "Hello, I am the demo assistant!"

# Use specific voice
mix dan.speak "Testing voices" --voice en_GB-alan-medium

# List available voices
mix dan.speak --list

# Run TTS test
mix dan.speak --test
```

#### Validate Demo Scripts

```bash
# Validate all scripts
mix dan.validate

# Validate specific file
mix dan.validate demo/scripts/example_demo.yml

# Validate directory
mix dan.validate demo/scripts/
```

### Keyboard Shortcuts

When using the web interface:

- `Space` - Next step
- `B` - Previous step
- `R` - Recover from error
- `Cmd+/` - Open Q&A modal
- `S` - Speak answer
- `?` - Show help

## Demo Script Format

Demo scripts are written in YAML:

```yaml
name: "Example Product Demo"
env:
  base_url: "https://example.com"

steps:
  - type: goto
    url: "${base_url}/products"
    text: "Navigate to products page"

  - type: click
    selector: "[data-testid='add-to-cart']"
    text: "Add item to cart"

  - type: fill
    selector: "#quantity"
    value: "2"
    text: "Set quantity to 2"

  - type: assert_text
    text: "Shopping Cart"

  - type: take_screenshot
    filename: "checkout-complete.png"

recovery:
  - type: goto
    url: "${base_url}"
  - type: reload
```

### Step Types

- `goto` - Navigate to URL
- `click` - Click an element
- `fill` - Fill a form field
- `assert_text` - Verify text is present
- `wait` - Pause execution
- `take_screenshot` - Capture screenshot
- `reload` - Refresh the page

See [demo/scripts/](demo/scripts/) for more examples.

## Configuration

### Environment Variables

```bash
# TTS Adapter (auto-detect by default)
export DAN_TTS_ADAPTER=piper  # or macsay, null

# Ollama URL
export OLLAMA_URL=http://localhost:11434
```

### Application Config

Edit `config/config.exs`:

```elixir
config :dan_core,
  tts_adapter: DanCore.TTS.Piper,
  ollama_base_url: "http://localhost:11434"
```

## Documentation

### Project Documentation

- [Implementation Plan](IMPLEMENTATION_PLAN.md) - Full technical specification
- [Phase 1 Complete](PHASE1_COMPLETE.md) - Umbrella structure
- [Phase 2 Complete](PHASE2_COMPLETE.md) - Demo runner system
- [Phase 3 Complete](PHASE3_COMPLETE.md) - LiveView overlay UI
- [Phase 4 Complete](PHASE4_COMPLETE.md) - Q&A engine with RAG
- [Phase 5 Complete](PHASE5_COMPLETE.md) - Voice system with Piper

### Demo Documentation

Create documentation in `demo/docs/` and the Q&A system will automatically index it:

```bash
# Add markdown files
echo "# Getting Started\n..." > demo/docs/getting-started.md

# Re-index
mix qa.init
```

## Components

### Dan Core (`apps/dan_core`)

Business logic and background jobs:

- **Demo.Runner**: GenServer managing demo execution
- **Demo.Parser**: YAML → Elixir struct conversion
- **Demo.Validator**: Script validation
- **QA.Engine**: RAG query pipeline
- **QA.Database**: SQLite FTS5 for document search
- **QA.Ollama**: Local LLM client
- **QA.Indexer**: Markdown document processing
- **Speaker**: TTS queue management
- **TTS**: Text-to-speech abstraction (Piper, MacSay)

### Dan Web (`apps/dan_web`)

Phoenix LiveView interface:

- **DemoLive**: Real-time demo control
- **Q&A Modal**: Ask questions, get answers
- **Voice Controls**: Speak answers, stop speech
- **Status Logs**: Activity feed with colors
- **Help Modal**: Keyboard shortcuts

### Node Bridge (`apps/dan_core/priv/node_bridge`)

Playwright automation layer:

- `bridge.js` - Main process with stdio communication
- `executors.js` - Playwright action implementations
- `package.json` - Playwright dependency

## Development

### Project Structure

```
dan_ton/
├── apps/
│   ├── dan_core/          # Business logic
│   │   ├── lib/
│   │   │   ├── dan_core/
│   │   │   │   ├── demo/  # Demo runner
│   │   │   │   ├── qa/    # Q&A engine
│   │   │   │   └── tts/   # Text-to-speech
│   │   │   └── mix/tasks/ # CLI tasks
│   │   └── priv/
│   │       ├── node_bridge/  # Playwright
│   │       ├── piper/        # TTS binaries
│   │       └── db/           # SQLite database
│   └── dan_web/           # Phoenix UI
│       ├── lib/dan_web/
│       │   ├── live/      # LiveView modules
│       │   └── controllers/
│       └── assets/        # JS/CSS
├── demo/
│   ├── scripts/           # Demo YAML files
│   ├── docs/             # Documentation (indexed for Q&A)
│   └── fixtures/         # Test data
├── config/               # Application config
└── test/                # Tests
```

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/dan_core/demo/parser_test.exs
```

### Code Quality

```bash
# Format code
mix format

# Run linter
mix credo --strict

# Security scan
mix sobelow --config

# All quality checks
mix precommit
```

## Troubleshooting

### Ollama Not Available

```bash
# Install Ollama
brew install ollama

# Start service
ollama serve

# Pull a model (in another terminal)
ollama pull llama3.1:8b

# Verify
curl http://localhost:11434/api/tags
```

### Piper TTS Not Working

```bash
# Setup Piper
mix piper.setup

# Test
mix dan.speak --test

# Check binary
ls -la apps/dan_core/priv/piper/

# Download additional voices
mix piper.download_voice en_GB-alan-medium
```

### Port 4000 Already in Use

```bash
# Find process
lsof -i :4000

# Kill it
kill -9 PID

# Or use different port
PORT=4001 mix phx.server
```

### Database Issues

```bash
# Reset database
mix ecto.drop
mix ecto.create
mix ecto.migrate

# Re-index documents
mix qa.init
```

## Performance

- **Demo Execution**: ~50ms per step (network dependent)
- **Q&A Response**: 2-10 seconds (LLM inference)
- **TTS Latency**: ~500ms first word, then real-time
- **LiveView Updates**: <100ms (WebSocket)
- **Memory Usage**: ~200MB base + ~100MB per active demo

## Technology Stack

- **Elixir 1.18** with OTP 28
- **Phoenix 1.8** with LiveView 1.1
- **PostgreSQL 14+** for Ecto/Oban
- **SQLite** with FTS5 for document search
- **Ollama** for local LLM inference
- **Piper** for neural TTS
- **Playwright** for browser automation
- **TailwindCSS + DaisyUI** for styling

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `mix precommit` to verify quality
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Roadmap

- [ ] Voice commands ("next step", "ask question")
- [ ] Background music for demos
- [ ] Multi-language TTS support
- [ ] Demo recording/playback
- [ ] Advanced analytics
- [ ] Docker deployment
- [ ] Cloud sync (optional)

## Credits

Built with:

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Playwright](https://playwright.dev/)
- [Piper TTS](https://github.com/rhasspy/piper)
- [Ollama](https://ollama.com/)
- [DaisyUI](https://daisyui.com/)

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/dan_ton/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/dan_ton/discussions)
- **Documentation**: See `demo/docs/` folder

---

**Made with ❤️ and Elixir**

*Powered by Phoenix LiveView, Playwright, Piper TTS, and Ollama*