#!/usr/bin/env node

/**
 * Playwright Bridge for dan_ton
 * 
 * Communicates with Elixir via stdio (Port)
 * Receives commands as JSON, executes them via Playwright, returns results
 */

const { chromium } = require('playwright');
const readline = require('readline');

class PlaywrightBridge {
  constructor() {
    this.browser = null;
    this.context = null;
    this.page = null;
    this.initialized = false;
  }

  async init() {
    try {
      this.browser = await chromium.launch({
        headless: false, // Set to true for headless mode
      });
      this.context = await this.browser.newContext();
      this.page = await this.context.newPage();
      this.initialized = true;
      this.sendResponse({ status: 'ok', message: 'Playwright initialized' });
    } catch (error) {
      this.sendError('Initialization failed', error);
    }
  }

  async close() {
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
      this.context = null;
      this.page = null;
      this.initialized = false;
    }
  }

  async executeCommand(command) {
    if (!this.initialized && command.action !== 'init') {
      return this.sendError('Bridge not initialized. Send "init" command first.');
    }

    try {
      switch (command.action) {
        case 'init':
          await this.init();
          break;

        case 'goto':
          await this.handleGoto(command.params);
          break;

        case 'click':
          await this.handleClick(command.params);
          break;

        case 'fill':
          await this.handleFill(command.params);
          break;

        case 'assert_text':
          await this.handleAssertText(command.params);
          break;

        case 'reload':
          await this.handleReload(command.params);
          break;

        case 'take_screenshot':
          await this.handleScreenshot(command.params);
          break;

        case 'wait':
          await this.handleWait(command.params);
          break;

        case 'close':
          await this.close();
          this.sendResponse({ status: 'ok', message: 'Browser closed' });
          process.exit(0);
          break;

        default:
          this.sendError(`Unknown action: ${command.action}`);
      }
    } catch (error) {
      this.sendError(`Command execution failed: ${command.action}`, error);
    }
  }

  // Command Handlers

  async handleGoto(params) {
    const url = typeof params === 'string' ? params : params.url;
    await this.page.goto(url, { waitUntil: 'networkidle' });
    this.sendResponse({
      status: 'ok',
      action: 'goto',
      url: url,
      title: await this.page.title()
    });
  }

  async handleClick(params) {
    if (params.role && params.name) {
      // Click by role and name (accessibility selector)
      await this.page.getByRole(params.role, { name: params.name }).click();
    } else if (params.text) {
      // Click by text
      await this.page.getByText(params.text).click();
    } else if (params.selector) {
      // Click by CSS selector
      await this.page.click(params.selector);
    } else {
      throw new Error('Invalid click parameters. Need role+name, text, or selector');
    }

    this.sendResponse({
      status: 'ok',
      action: 'click',
      params: params
    });
  }

  async handleFill(params) {
    const { field, value } = params;
    
    // Try different selector strategies
    try {
      // Try by label
      await this.page.getByLabel(field).fill(value);
    } catch {
      try {
        // Try by placeholder
        await this.page.getByPlaceholder(field).fill(value);
      } catch {
        // Try by name attribute
        await this.page.fill(`[name="${field}"]`, value);
      }
    }

    this.sendResponse({
      status: 'ok',
      action: 'fill',
      field: field
    });
  }

  async handleAssertText(params) {
    const text = typeof params === 'string' ? params : params.text;
    const timeout = params.timeout || 5000;

    try {
      await this.page.waitForSelector(`text=${text}`, { timeout });
      this.sendResponse({
        status: 'ok',
        action: 'assert_text',
        text: text,
        found: true
      });
    } catch (error) {
      this.sendError(`Text not found: "${text}"`, error);
    }
  }

  async handleReload(params) {
    await this.page.reload({ waitUntil: 'networkidle' });
    this.sendResponse({
      status: 'ok',
      action: 'reload'
    });
  }

  async handleScreenshot(params) {
    const path = params.path || `screenshot_${Date.now()}.png`;
    const fullPath = params.fullPath || `./screenshots/${path}`;
    
    await this.page.screenshot({ path: fullPath, fullPage: params.fullPage || false });
    
    this.sendResponse({
      status: 'ok',
      action: 'take_screenshot',
      path: fullPath
    });
  }

  async handleWait(params) {
    const duration = typeof params === 'number' ? params : params.duration || 1000;
    await this.page.waitForTimeout(duration);
    
    this.sendResponse({
      status: 'ok',
      action: 'wait',
      duration: duration
    });
  }

  // Communication

  sendResponse(data) {
    const response = JSON.stringify(data);
    console.log(response);
  }

  sendError(message, error = null) {
    const errorData = {
      status: 'error',
      message: message,
      error: error ? {
        message: error.message,
        stack: error.stack
      } : null
    };
    console.error(JSON.stringify(errorData));
  }
}

// Main execution

const bridge = new PlaywrightBridge();

// Set up readline interface for stdio communication
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', async (line) => {
  try {
    const command = JSON.parse(line);
    await bridge.executeCommand(command);
  } catch (error) {
    bridge.sendError('Invalid JSON command', error);
  }
});

// Handle process termination
process.on('SIGTERM', async () => {
  await bridge.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  await bridge.close();
  process.exit(0);
});

// Send ready signal
bridge.sendResponse({ status: 'ready', message: 'Playwright bridge started' });
