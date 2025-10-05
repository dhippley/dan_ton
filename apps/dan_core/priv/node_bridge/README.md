# Playwright Bridge

Node.js bridge for executing browser automation via Playwright.

## Installation

```bash
npm install
npx playwright install chromium
```

## Usage

The bridge communicates via stdio (standard input/output) with the Elixir application using JSON messages.

### Command Format

```json
{
  "action": "goto",
  "params": "https://example.com"
}
```

### Response Format

```json
{
  "status": "ok",
  "action": "goto",
  "url": "https://example.com",
  "title": "Example Domain"
}
```

### Error Format

```json
{
  "status": "error",
  "message": "Navigation failed",
  "error": {
    "message": "Timeout",
    "stack": "..."
  }
}
```

## Supported Actions

### init
Initialize the browser and create a new page.

```json
{"action": "init"}
```

### goto
Navigate to a URL.

```json
{"action": "goto", "params": "https://example.com"}
```

or

```json
{"action": "goto", "params": {"url": "https://example.com", "waitUntil": "load"}}
```

### click
Click an element using various selectors.

```json
{"action": "click", "params": {"role": "button", "name": "Submit"}}
{"action": "click", "params": {"text": "Click me"}}
{"action": "click", "params": {"selector": "#submit-btn"}}
```

### fill
Fill an input field.

```json
{"action": "fill", "params": {"field": "email", "value": "test@example.com"}}
```

### assert_text
Verify text exists on the page.

```json
{"action": "assert_text", "params": "Success"}
```

or

```json
{"action": "assert_text", "params": {"text": "Success", "timeout": 5000}}
```

### reload
Reload the current page.

```json
{"action": "reload"}
```

### take_screenshot
Capture a screenshot.

```json
{"action": "take_screenshot", "params": {"path": "screenshot.png"}}
```

### wait
Wait for a duration.

```json
{"action": "wait", "params": 1000}
```

or

```json
{"action": "wait", "params": {"duration": 1000}}
```

### close
Close the browser and exit.

```json
{"action": "close"}
```

## Testing

You can test the bridge manually:

```bash
node bridge.js
```

Then send JSON commands via stdin:

```json
{"action": "init"}
{"action": "goto", "params": "https://example.com"}
{"action": "take_screenshot", "params": {"path": "test.png"}}
{"action": "close"}
```

## Architecture

- `bridge.js` - Main bridge process, handles stdio communication
- `executors.js` - Helper functions for complex step execution
- Communicates with Elixir via Port (stdin/stdout)
