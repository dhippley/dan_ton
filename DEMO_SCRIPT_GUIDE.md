# Demo Script Guide

## Overview

Demo scripts are YAML files that define automated browser interactions using Playwright. They're designed to create reproducible, narrated demonstrations of web applications.

## File Location

Place demo scripts in: `demo/scripts/*.yml`

## Basic Structure

```yaml
name: "Demo Name"

env:
  base_url: "http://localhost:4000"
  any_variable: "value"

steps:
  - goto: "${base_url}/path"
  - narrate: "Explain what's happening"
  - wait: 2000
  - assert_text: "Expected text"
  - take_screenshot: "screenshot.png"

recover:
  - goto: "${base_url}"
  - wait: 1000
```

## Available Step Types

### Navigation

#### goto
Navigate to a URL (absolute, relative, or with env variables)
```yaml
- goto: "https://example.com"
- goto: "/products"
- goto: "${base_url}/checkout"
```

#### reload
Reload the current page
```yaml
- reload: true
```

### Interaction

#### click
Click on an element
```yaml
- click:
    selector: ".btn-primary"
    
- click:
    role: "button"
    name: "Submit"
    
- click:
    text: "Learn More"
```

#### fill
Fill in a form field
```yaml
- fill:
    selector: "#email"
    value: "user@example.com"
    
- fill:
    field: "firstName"  # Alternative to selector
    value: "John"
```

### Verification

#### assert_text
Verify text appears on the page
```yaml
- assert_text: "Welcome"
- assert_text: "Order Confirmed"
```

### Timing

#### wait
Pause for a specified duration (milliseconds)
```yaml
- wait: 1000  # Wait 1 second
- wait: 3000  # Wait 3 seconds
```

#### pause
Pause the demo (waits for user to resume)
```yaml
- pause: true
```

### Output

#### take_screenshot
Capture the current page
```yaml
- take_screenshot: "homepage.png"
- take_screenshot: true  # Auto-generates filename
```

#### narrate
Add voice narration (if TTS is configured)
```yaml
- narrate: "Here's our product catalog"
- narrate: "Now we'll add an item to the cart"
```

## Environment Variables

Define reusable values in the `env` section:

```yaml
env:
  base_url: "http://localhost:4000"
  test_email: "demo@example.com"
  test_card: "4242 4242 4242 4242"

steps:
  - goto: "${base_url}/checkout"
  - fill:
      field: "email"
      value: "${test_email}"
```

## Recovery Steps

Optional steps to run if the demo fails:

```yaml
recover:
  - goto: "${base_url}"
  - wait: 1000
```

## Complete Example

```yaml
name: "Product Purchase Demo"

env:
  base_url: "https://shop.example.com"

steps:
  # Browse products
  - goto: "${base_url}/products"
  - narrate: "Welcome! Let's browse our product catalog"
  - wait: 2000
  - assert_text: "Products"
  
  # Add to cart
  - click:
      role: "button"
      name: "Add to Cart"
  - narrate: "Adding item to cart"
  - wait: 1000
  
  # Checkout
  - goto: "${base_url}/checkout"
  - narrate: "Proceeding to checkout"
  
  - fill:
      field: "email"
      value: "customer@example.com"
  
  - fill:
      field: "cardNumber"
      value: "4242 4242 4242 4242"
  
  - wait: 1000
  
  - click:
      selector: ".btn-submit"
  
  - narrate: "Order submitted successfully!"
  
  - assert_text: "Thank you"
  - take_screenshot: "order-complete.png"

recover:
  - goto: "${base_url}"
```

## Running Demos

### Via Web UI
1. Start the server: `mix phx.server`
2. Navigate to: http://localhost:4000/demo
3. Select a demo from the dropdown
4. Click "Start Demo"

### Via CLI
```bash
# List available demos
mix dan.demo

# Run a specific demo
mix dan.demo simple_demo
```

## Validation

Validate your demo scripts before running:

```bash
mix dan.validate
```

This checks for:
- Valid step types
- Required parameters
- URL formats
- File name formats
- Selector presence

## Tips

1. **Start Simple**: Begin with basic navigation and assertions
2. **Add Narration**: Use `narrate` steps to explain what's happening
3. **Wait Between Actions**: Add `wait` steps to let pages load
4. **Verify State**: Use `assert_text` to confirm expected outcomes
5. **Use Variables**: Define common values in `env` for reusability
6. **Test Often**: Validate and run demos frequently during development
7. **Recovery Steps**: Always include recovery steps for resilience

## Debugging

If a demo fails:
1. Check the activity log in the UI
2. Review step-by-step execution
3. Verify selectors match the actual page
4. Add more `wait` steps if timing is an issue
5. Use `take_screenshot` to capture state

## Examples

See the `demo/scripts/` directory for working examples:
- `simple_demo.yml` - Basic navigation and assertions
- `my_first_demo.yml` - Phoenix Framework website tour
- `github_demo.yml` - GitHub exploration
- `checkout_demo.yml` - E-commerce checkout flow
