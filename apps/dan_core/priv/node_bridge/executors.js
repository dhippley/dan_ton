/**
 * Playwright Step Executors
 * 
 * Additional helper functions for complex step execution
 */

class StepExecutors {
  constructor(page) {
    this.page = page;
  }

  /**
   * Navigate to a URL with options
   */
  async goto(url, options = {}) {
    const defaultOptions = {
      waitUntil: 'networkidle',
      timeout: 30000
    };
    
    await this.page.goto(url, { ...defaultOptions, ...options });
    
    return {
      url: this.page.url(),
      title: await this.page.title()
    };
  }

  /**
   * Smart click that tries multiple strategies
   */
  async smartClick(params) {
    const strategies = [
      // By role and name
      () => params.role && params.name 
        ? this.page.getByRole(params.role, { name: params.name }).click()
        : null,
      
      // By text
      () => params.text
        ? this.page.getByText(params.text).click()
        : null,
      
      // By selector
      () => params.selector
        ? this.page.click(params.selector)
        : null,
      
      // By test ID
      () => params.testId
        ? this.page.getByTestId(params.testId).click()
        : null
    ];

    for (const strategy of strategies) {
      try {
        const result = strategy();
        if (result) {
          await result;
          return { clicked: true };
        }
      } catch (error) {
        // Try next strategy
        continue;
      }
    }

    throw new Error('Could not find element to click with provided parameters');
  }

  /**
   * Smart fill that tries multiple input selection strategies
   */
  async smartFill(field, value) {
    const strategies = [
      // By label
      () => this.page.getByLabel(field).fill(value),
      
      // By placeholder
      () => this.page.getByPlaceholder(field).fill(value),
      
      // By name attribute
      () => this.page.fill(`[name="${field}"]`, value),
      
      // By ID
      () => this.page.fill(`#${field}`, value),
      
      // By test ID
      () => this.page.getByTestId(field).fill(value)
    ];

    for (const strategy of strategies) {
      try {
        await strategy();
        return { filled: true, field: field };
      } catch (error) {
        continue;
      }
    }

    throw new Error(`Could not find input field: ${field}`);
  }

  /**
   * Assert text exists on page
   */
  async assertText(text, options = {}) {
    const timeout = options.timeout || 5000;
    
    try {
      await this.page.waitForSelector(`text=${text}`, { timeout });
      return { found: true, text: text };
    } catch (error) {
      const pageText = await this.page.textContent('body');
      const snippet = pageText.substring(0, 500);
      throw new Error(`Text "${text}" not found. Page contains: ${snippet}...`);
    }
  }

  /**
   * Wait for navigation to complete
   */
  async waitForNavigation(options = {}) {
    await this.page.waitForLoadState(options.waitUntil || 'networkidle');
    return {
      url: this.page.url(),
      ready: true
    };
  }

  /**
   * Take a screenshot with smart path handling
   */
  async takeScreenshot(options = {}) {
    const timestamp = Date.now();
    const filename = options.filename || `screenshot_${timestamp}.png`;
    const dir = options.dir || './screenshots';
    const path = `${dir}/${filename}`;

    // Ensure directory exists
    const fs = require('fs');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    await this.page.screenshot({
      path: path,
      fullPage: options.fullPage !== false
    });

    return { path: path, timestamp: timestamp };
  }

  /**
   * Select from dropdown
   */
  async select(selector, value) {
    await this.page.selectOption(selector, value);
    return { selected: value, selector: selector };
  }

  /**
   * Check a checkbox
   */
  async check(selector) {
    await this.page.check(selector);
    return { checked: true, selector: selector };
  }

  /**
   * Uncheck a checkbox
   */
  async uncheck(selector) {
    await this.page.uncheck(selector);
    return { checked: false, selector: selector };
  }

  /**
   * Get element text
   */
  async getText(selector) {
    const text = await this.page.textContent(selector);
    return { text: text, selector: selector };
  }

  /**
   * Get element attribute
   */
  async getAttribute(selector, attribute) {
    const value = await this.page.getAttribute(selector, attribute);
    return { attribute: attribute, value: value, selector: selector };
  }

  /**
   * Execute custom JavaScript
   */
  async evaluate(script) {
    const result = await this.page.evaluate(script);
    return { result: result };
  }

  /**
   * Press keyboard keys
   */
  async press(key) {
    await this.page.keyboard.press(key);
    return { key: key };
  }

  /**
   * Type text with realistic delays
   */
  async type(selector, text, options = {}) {
    await this.page.type(selector, text, {
      delay: options.delay || 100
    });
    return { typed: text.length, selector: selector };
  }

  /**
   * Hover over element
   */
  async hover(selector) {
    await this.page.hover(selector);
    return { hovered: true, selector: selector };
  }
}

module.exports = StepExecutors;
