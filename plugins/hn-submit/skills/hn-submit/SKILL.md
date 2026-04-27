---
description: Submits a post to Hacker News (news.ycombinator.com) using Playwright MCP. Trigger when the user says anything like "post to HN", "submit to Hacker News", "share on HN", "submit this to hackernews", "post this article to HN", or any similar intent to share a URL or article on Hacker News.
---

# HN Submit

Automates posting content to Hacker News using the Playwright MCP browser tools.

## Prerequisites

This plugin requires the **Playwright MCP** server to be installed and configured.

Install browsers:
```bash
npx playwright install
```

Add to your Claude Code MCP config (`~/.claude/claude_desktop_config.json` or project-level `.mcp.json`):
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

See https://github.com/microsoft/playwright-mcp for full setup instructions.

## Credentials Setup

Credentials come from environment variables. Before using this plugin, ensure these are set:

- `HN_USERNAME` — Hacker News username
- `HN_PASSWORD` — Hacker News password

**One-time setup:**
1. Create a `.env` file in the project root (add it to `.gitignore`)
2. Add:
   ```
   HN_USERNAME=your_hn_username
   HN_PASSWORD=your_hn_password
   ```
3. Or export them in your shell: `export HN_USERNAME=... HN_PASSWORD=...`

If the env vars are not set, ask the user for their HN credentials before proceeding. Do NOT hardcode credentials anywhere.

## Inputs

You need two things from the user:
- **Title** — the submission title
- **URL** — the full public URL to submit

If either is unclear, ask the user before proceeding.

## Workflow

### Step 1: Read credentials

Read `HN_USERNAME` and `HN_PASSWORD` from environment:
```bash
echo $HN_USERNAME
echo $HN_PASSWORD
```

If blank, check for a `.env` file:
```bash
grep -E "^HN_(USERNAME|PASSWORD)=" .env 2>/dev/null
```

If still not found, ask the user to provide them.

### Step 2: Log in to Hacker News

1. Navigate to `https://news.ycombinator.com/login`
2. Take a snapshot to confirm the login form is present
3. Fill in the `acct` field with the username
4. Fill in the `pw` field with the password
5. Click the login button (`<input type="submit" value="login">`)
6. Take a snapshot to verify login succeeded — the username should appear in the top nav bar. If login failed, stop and tell the user.

### Step 3: Submit

1. Navigate to `https://news.ycombinator.com/submit`
2. Take a snapshot to confirm the submit form is present
3. Fill in the `title` field with the submission title
4. Fill in the `url` field with the URL (leave `text` blank — per HN guidelines, text is optional when a URL is provided)
5. Click the submit button
6. Take a snapshot to verify submission succeeded

### Step 4: Confirm and report

After submission, tell the user:
- Whether it succeeded or failed
- The submission thread URL if visible (HN usually redirects to the post thread)
- Any error messages if it failed

## Error Handling

- **Already submitted**: HN will say "You have already submitted this link." — report this and provide the existing thread URL if shown.
- **Rate limited**: HN may say you're submitting too fast. Tell the user to wait a few minutes.
- **Login failure**: Stop immediately, report the error, ask the user to verify credentials.
- **Form not found**: Take a screenshot and report what the page shows instead.

## Important Notes

- HN has a rate limit — don't submit the same URL twice.
- Leave the `text` field blank when posting a URL (per HN norms).
- Titles should match the actual article title; avoid editorializing per HN community guidelines.
- After submitting, the post may not appear on the front page immediately — that's normal, ranking is based on votes and time.
