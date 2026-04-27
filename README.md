<p align="center">
  <img src="./claude-socials-logo.png" alt="claude-socials" width="400" />
</p>

# claude-socials

A collection of [Claude Code](https://claude.ai/code) plugins for posting content to social media platforms — directly from your terminal or AI-assisted workflows.

Each plugin automates the browser-based flow for a platform using [Playwright MCP](https://github.com/microsoft/playwright-mcp), so Claude can navigate, log in, and submit on your behalf.

---

## Available Plugins

| Plugin | Platform | Status |
|---|---|---|
| [`hn-submit`](./plugins/hn-submit/) | Hacker News | ✅ Available |

More platforms coming soon (Reddit, LinkedIn, Twitter/X, Lobsters, ...).

---

## Install

### Step 1 — Add the marketplace

Inside Claude Code:
```
/plugin marketplace add adityak74/claude-socials
```

Or from the terminal:
```bash
claude plugin marketplace add adityak74/claude-socials
```

### Step 2 — Install a plugin

Inside Claude Code:
```
/plugin install hn-submit@claude-socials
```

Or from the terminal:
```bash
claude plugin install hn-submit@claude-socials

# Project scope — shared with your team via .claude/settings.json
claude plugin install hn-submit@claude-socials --scope project
```

### One-liner (marketplace + plugin together)

```bash
curl -fsSL https://raw.githubusercontent.com/adityak74/claude-socials/main/scripts/install.sh | sh -s -- hn-submit
```

> After installing, restart Claude Code to activate the plugin.

---

## Prerequisites

All plugins that interact with a browser require **Playwright MCP**.

### 1. Install Playwright browsers

```bash
npx playwright install
```

### 2. Configure Playwright MCP in Claude Code

Add to your MCP config globally (`~/.claude/claude_desktop_config.json`) or per-project (`.mcp.json`):

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

See the [Playwright MCP repo](https://github.com/microsoft/playwright-mcp) for full options (headed/headless mode, browser choice, auth persistence).

---

## Usage

Once a plugin is installed, trigger it with natural language or the skill command.

### Hacker News

```
/hn-submit
```

Or just describe what you want:

```
Post this to HN
Submit to Hacker News — title: "My Article", URL: https://example.com/my-article
Share on HN
```

Claude handles login (via env vars) and submission automatically.

---

## Credentials

Plugins use environment variables for credentials — never hardcoded values.

Set them in a `.env` file in your project root (keep it in `.gitignore`):

```
HN_USERNAME=your_username
HN_PASSWORD=your_password
```

Or export in your shell:

```bash
export HN_USERNAME=your_username
export HN_PASSWORD=your_password
```

Each plugin's `SKILL.md` documents which env vars it requires.

---

## Plugin Reference

### [`hn-submit`](./plugins/hn-submit/)

Submits a URL to [Hacker News](https://news.ycombinator.com/submit).

**Requires:** `HN_USERNAME`, `HN_PASSWORD`

**Trigger:** `/hn-submit` or phrases like "post to HN", "submit to Hacker News", "share on HN"

**What it does:**
1. Logs in to your HN account via Playwright
2. Navigates to the submit page
3. Fills in the title and URL
4. Submits and reports back with the thread URL

---

## Contributing

Contributions are welcome. To add a plugin for a new platform:

1. Create `plugins/<platform-name>/`
2. Add `.claude-plugin/plugin.json` with `name`, `description`, and `version`
3. Add `skills/<platform-name>/SKILL.md` with a `description` frontmatter field and the full workflow
4. Add an entry to `.claude-plugin/marketplace.json`
5. Document required env vars, trigger phrases, and error handling in the skill
6. Open a PR

Plugin conventions:
- Use environment variables for all credentials
- Handle rate limits, login failures, and duplicate submissions gracefully
- Use Playwright MCP for browser automation
- Bump `version` in `plugin.json` and the marketplace entry on every release

---

## License

MIT
