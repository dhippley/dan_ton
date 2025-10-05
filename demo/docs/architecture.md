# dan_ton Architecture

## Overview

dan_ton is a local AI demo assistant that runs scripted demos with voice narration and Q&A capabilities - entirely offline.

## System Components

### 1. Demo Runner (DanCore.Demo)
- Executes YAML-based demo scenarios
- Orchestrates browser automation via Playwright
- Manages demo state and recovery

### 2. LiveView Overlay (DanWeb)
- Real-time UI with controls and logs
- Keyboard shortcuts for hands-free operation
- Visual feedback and progress tracking

### 3. Q&A Engine (DanCore.QA)
- Local RAG using SQLite FTS5
- Document indexing and retrieval
- LLM generation via Ollama

### 4. Voice System (DanCore.TTS)
- Text-to-speech with pluggable adapters
- Queue management to prevent overlapping audio
- Support for macOS `say` and Piper TTS

## Technology Stack

- **Backend**: Elixir/Phoenix/LiveView
- **Database**: PostgreSQL (app data), SQLite (FTS5 for docs)
- **Browser Automation**: Playwright (Node.js bridge)
- **LLM**: Ollama (local)
- **TTS**: macOS `say` or Piper

## Communication Flow

```
User Input → LiveView → PubSub → Demo Runner → Playwright
                                              → TTS Speaker
                                              → Q&A Engine
```

All operations run locally with no external API dependencies.
