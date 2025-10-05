# Piper TTS Setup Guide

## ✅ Installation Complete!

Piper TTS has been successfully installed and configured for dan_ton.

## What Was Installed

- ✅ **Piper** neural TTS engine (via pip3)
- ✅ **en_US-lessac-medium** voice model (60MB)
- ✅ Voice models stored in `apps/dan_core/priv/piper/models/`

## Adding Piper to PATH (Recommended)

Piper was installed to `/Users/dhippley/Library/Python/3.9/bin`. To make it permanently available, add this to your shell profile:

### For Fish Shell

```fish
# Add to ~/.config/fish/config.fish
set -gx PATH /Users/dhippley/Library/Python/3.9/bin $PATH
```

### For Bash/Zsh

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="/Users/dhippley/Library/Python/3.9/bin:$PATH"
```

Then restart your terminal or run:
```bash
source ~/.bashrc  # or ~/.zshrc or ~/.config/fish/config.fish
```

## Testing TTS

```bash
# Quick test
mix dan.speak "Hello, world!"

# List voices
mix dan.speak --list

# Run full test
mix dan.speak --test
```

## Using TTS in dan_ton

### Web Interface

1. Start server: `mix phx.server`
2. Visit http://localhost:4000/demo
3. Ask a question with `Cmd+/`
4. Press `S` to speak the answer

### Command Line

```bash
# Ask with voice
mix dan.ask "How does the demo system work?" --speak

# Test demo narration
mix dan.demo demo/scripts/example_demo.yml --narrate
```

## Downloading Additional Voices

```bash
# British English
mix piper.download_voice en_GB-alan-medium

# US English (female)
mix piper.download_voice en_US-amy-medium

# List available voices
# Visit: https://github.com/rhasspy/piper/blob/master/VOICES.md
```

## Troubleshooting

### PATH Not Set

If you get "Piper not found" errors, either:

1. Add to PATH (see above)
2. Or prefix commands with PATH:
   ```bash
   export PATH="/Users/dhippley/Library/Python/3.9/bin:$PATH"
   mix dan.speak "Test"
   ```

### No Audio Output

Check your system audio:
```bash
# Test system audio
afplay /System/Library/Sounds/Ping.aiff
```

### Voice Model Not Found

Re-download the voice:
```bash
mix piper.download_voice en_US-lessac-medium
```

## Voice Quality

- **Model**: Neural TTS (ONNX)
- **Quality**: Near-human, natural prosody
- **Speed**: Real-time on modern CPUs (~300-500ms first word)
- **Size**: ~60MB per voice model

## Environment Variable

You can also set the adapter explicitly:
```bash
export DAN_TTS_ADAPTER=piper
mix phx.server
```

## Success! 🎉

Piper TTS is now ready to use in dan_ton. Try it out:

```bash
mix dan.speak "Phase 6 is complete! All systems operational!"
```
