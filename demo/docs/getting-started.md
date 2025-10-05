# Getting Started with dan_ton

## Prerequisites

1. **Elixir & Erlang**: Ensure you have Elixir 1.15+ installed
2. **PostgreSQL**: Running locally or via Docker
3. **Node.js**: For Playwright bridge (v18+)
4. **Ollama**: For local LLM capabilities

## Installation

### 1. Install Ollama

```bash
brew install ollama
ollama pull llama3.1:8b
```

### 2. Install Dependencies

```bash
# Elixir dependencies
mix deps.get

# Node.js dependencies for Playwright
cd apps/dan_core/priv/node_bridge
npm install

# Install Playwright browsers
npx playwright install chromium
```

### 3. Database Setup

```bash
mix ecto.setup
```

### 4. Build Document Index

```bash
mix dan_ton.index
```

## Running the Application

### Start Phoenix Server

```bash
iex -S mix phx.server
```

Navigate to http://localhost:4000

### Run a Demo from CLI

```bash
mix dan_ton.demo --script demo/scripts/checkout.yml
```

### Ask Questions

```bash
mix dan_ton.ask "How does the checkout flow work?"
```

## Configuration

See `config/runtime.exs` for configuration options:
- TTS engine selection
- Ollama URL and model
- Database settings

## Next Steps

- Create your first demo script in `demo/scripts/`
- Add documentation to `demo/docs/` for Q&A
- Explore keyboard shortcuts in the LiveView UI
