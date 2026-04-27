# claude-socials

A collection of [Claude Code](https://claude.ai/code) skills for posting content to social media platforms — directly from your terminal or AI-assisted workflows.

Each skill automates the browser-based flow for a platform using [Playwright MCP](https://github.com/microsoft/playwright-mcp), so Claude can navigate, log in, and submit on your behalf.

---

## Available Skills

| Skill | Platform | Status |
|---|---|---|
| [`hn-submit`](./skills/hn-submit/) | Hacker News | ✅ Available |

More platforms coming soon (Reddit, LinkedIn, Twitter/X, Lobsters, ...).

---

## Prerequisites

All skills that interact with a browser require **Playwright MCP**.

### Install Playwright

```bash
npx playwright install
```

### Configure Playwright MCP in Claude Code

Add the server to your Claude Code MCP config. You can do this globally (`~/.claude/claude_desktop_config.json`) or per-project (`.mcp.json` in your project root):

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

See the [Playwright MCP repo](https://github.com/microsoft/playwright-mcp) for full setup options including headed/headless mode, browser choice, and authentication persistence.

---

## Installation

Skills are installed by copying the skill directory into your project's `.claude/skills/` folder (or your global `~/.claude/skills/` folder to make a skill available everywhere).

### Install a single skill

```bash
# Into a specific project
cp -r skills/hn-submit /path/to/your/project/.claude/skills/

# Or globally (available in all projects)
cp -r skills/hn-submit ~/.claude/skills/
```

### Install all skills

```bash
# Into a specific project
cp -r skills/. /path/to/your/project/.claude/skills/

# Or globally
cp -r skills/. ~/.claude/skills/
```

> **Tip:** After copying, restart Claude Code (or reload the window) so it picks up the new skills.

---

## Usage

Once a skill is installed, trigger it by describing what you want in plain English. Each skill's trigger phrases are listed in its `SKILL.md`.

### Hacker News

```
Post this to HN
Submit to Hacker News — title: "My Article", URL: https://example.com/my-article
Share on HN
```

Claude will handle login (using credentials from env vars) and submission automatically.

---

## Credentials

Skills use environment variables for credentials — never hardcoded values.

Set them in a `.env` file in your project root (make sure it's in `.gitignore`):

```
HN_USERNAME=your_username
HN_PASSWORD=your_password
```

Or export them in your shell session:

```bash
export HN_USERNAME=your_username
export HN_PASSWORD=your_password
```

Each skill's README documents the specific env vars it needs.

---

## Skill Reference

### [`hn-submit`](./skills/hn-submit/)

Submits a URL to [Hacker News](https://news.ycombinator.com/submit).

**Requires:** `HN_USERNAME`, `HN_PASSWORD`

**Trigger phrases:** "post to HN", "submit to Hacker News", "share on HN", "post this article to HN"

**What it does:**
1. Logs in to your HN account via Playwright
2. Navigates to the submit page
3. Fills in the title and URL
4. Submits and reports back with the thread URL

---

## Contributing

Contributions are welcome. To add a skill for a new platform:

1. Create a directory under `skills/<platform-name>/`
2. Add a `SKILL.md` following the format of existing skills (frontmatter with `name` and `description`, then workflow steps)
3. Document required env vars, trigger phrases, and error handling
4. Open a PR

Skills should:
- Use environment variables for all credentials
- Handle common error cases gracefully (rate limits, login failures, duplicate submissions)
- Use Playwright MCP for any browser automation

---

## License

MIT
