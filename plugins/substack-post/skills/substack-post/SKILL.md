---
description: Publishes a local blog file to Substack using Playwright MCP. Trigger when the user says anything like "publish to Substack", "post this blog to Substack", "upload my markdown to Substack", "share on Substack", "save this draft to Substack", or any similar intent to send a local blog file to Substack.
---

# Substack Post

Automates publishing a local blog file (markdown) to Substack using the Playwright MCP browser tools. Defaults to saving as a draft and confirms with the user before publishing.

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

- `SUBSTACK_EMAIL` — Substack account email
- `SUBSTACK_PASSWORD` — Substack account password (only works if you've explicitly set one — magic-link-only accounts will fail; set a password at https://substack.com/account/login-options)
- `SUBSTACK_PUBLICATION` *(optional)* — your publication subdomain, e.g. `myblog` for `myblog.substack.com`. If omitted, the skill navigates to the dashboard at substack.com after login and clicks "New post".

**One-time setup:**
1. Create a `.socials` file in the project root (add it to `.gitignore`)
2. Add:
   ```
   SUBSTACK_EMAIL=your_email@example.com
   SUBSTACK_PASSWORD=your_password
   SUBSTACK_PUBLICATION=myblog
   ```
3. Or export them in your shell: `export SUBSTACK_EMAIL=... SUBSTACK_PASSWORD=...`

If the env vars are not set, ask the user before proceeding. Do NOT hardcode credentials anywhere.

## Inputs

You need one thing from the user:
- **Blog file path** — local path to a markdown blog file. Required.

Optional:
- **Title** — defaults to the first `# H1` line of the file, falling back to the filename without extension.
- **Subtitle** — Substack post subtitle.
- **Action** — `draft` (default) or `publish`. Always default to draft and confirm with the user before publishing.

If the file path is unclear, ask the user before proceeding.

## Workflow

### Step 1: Read credentials

Read `SUBSTACK_EMAIL` and `SUBSTACK_PASSWORD` (and optionally `SUBSTACK_PUBLICATION`) from environment:
```bash
echo $SUBSTACK_EMAIL
echo $SUBSTACK_PASSWORD
echo $SUBSTACK_PUBLICATION
```

If blank, check for a `.socials` file:
```bash
grep -E "^SUBSTACK_(EMAIL|PASSWORD|PUBLICATION)=" .socials 2>/dev/null
```

If still not found, ask the user to provide them.

### Step 2: Read and parse the blog file

1. Use the Read tool on the blog file path.
2. **Detect and strip frontmatter.** If the file starts with a YAML frontmatter block (lines `---` ... `---`) or a TOML block (`+++` ... `+++`), parse it and remove the entire block from the body before paste. This handles Hugo, Jekyll, Zola, Hexo, Astro, Obsidian, and similar static-site formats. Files with no frontmatter are passed through unchanged.
3. **Resolve title** in this order — first non-empty wins:
   - Explicit title from the user
   - `title` field in the frontmatter
   - First `# H1` line in the body (then strip that H1 from the body)
   - Filename without extension (skip generic names like `index`, `README`, `post` and use the parent directory name instead — e.g. `posts/gpu-util/index.md` → `gpu-util`)
4. **Resolve subtitle** in this order:
   - Explicit subtitle from the user
   - `subtitle` field in the frontmatter
   - `description` field in the frontmatter
   - `summary` field in the frontmatter
   - `excerpt` field in the frontmatter
   - Otherwise leave blank
5. The remaining markdown content (frontmatter stripped, leading H1 stripped if it was used as the title) is the post body.

### Step 3: Log in to Substack

1. Navigate to `https://substack.com/sign-in`.
2. Take a snapshot to confirm the sign-in page loaded.
3. **Click the "Sign in with password" link.** Substack defaults to magic-link sign-in; without this click the password field never appears.
4. Take a snapshot to confirm the password form is now visible.
5. Fill the email field with `SUBSTACK_EMAIL`.
6. Fill the password field with `SUBSTACK_PASSWORD`.
7. Click the sign-in / submit button.
8. Take a snapshot to verify login succeeded — the dashboard or publication page should load. If a captcha or device-verification page appears, stop and ask the user to complete it manually in the same browser session, then retry.

### Step 4: Open the editor

- If `SUBSTACK_PUBLICATION` is set: navigate to `https://<publication>.substack.com/publish/post?type=newsletter`.
- Otherwise: navigate to `https://substack.com`, take a snapshot, then click the "New post" button on the dashboard.

Take a snapshot to confirm the editor loaded.

### Step 5: Fill the post

1. Click the title field, type the title.
2. If a subtitle was provided, click the subtitle field and type it.
3. Click into the body editor.
4. **Insert content with headings styled.** Pasting markdown in one blob makes `##` headings appear as literal text. Substack only auto-styles a heading when the user *types* `## ` (or `# ` / `### `) at the start of a line and presses space — the space keystroke triggers the conversion. To preserve heading styling:
   - Split the body on lines that match `^#{1,3} ` (ATX headings).
   - For each prose segment between headings: paste it via the clipboard (or `browser_type` for short segments) so Substack still converts inline markdown (bold/italic/links/lists).
   - For each heading line: use `browser_press_key` / `browser_type` to type the literal prefix (`# `, `## `, or `### `) one character at a time so the trailing space fires Substack's auto-format, then type the heading text, then press Enter to drop back into a paragraph block.
   - Continue until the whole body is in the editor.
5. Code blocks, images, and tables still won't render correctly — flag this in the final report.
6. Take a snapshot to verify the content is in the editor and headings are styled (not literal `##` text).

### Step 6: Save as draft

1. Click "Save draft" if a button is visible — otherwise wait a few seconds for Substack's autosave to fire.
2. Take a snapshot to confirm "Draft saved" or similar status appears.
3. Capture the draft URL from the address bar.

### Step 7: Confirm before publishing

By default, **stop here**. Report to the user:
- The draft URL.
- Any markdown elements that didn't convert cleanly (code blocks, images, tables).
- Ask: "Draft saved. Want me to click Publish?"

Only if the user explicitly asked to publish (in their original request or in reply), continue:
1. Click "Continue".
2. On the audience step, choose "Send to everyone now" (or whatever the user specified).
3. Click the final publish/send button.
4. Take a snapshot to verify the post is live.
5. Report the public post URL.

## Error Handling

- **"Sign in with password" link not found**: the page layout may have changed — take a screenshot and report.
- **Password login fails / "no password set"**: tell the user to set a password at `https://substack.com/account/login-options` and retry.
- **2FA / captcha / device-verification page**: stop, ask the user to complete the challenge in the same browser session, then retry.
- **File not found / unreadable**: stop and report the path.
- **Editor element not found**: take a screenshot and report what the page shows.
- **Rate limit on login**: Substack may block rapid retries — tell the user to wait a few minutes.

## Important Notes

- **Markdown fidelity is partial.** Substack's editor accepts pasted markdown and converts headings, bold/italic, links, and lists. Code blocks, images, and tables do NOT survive the paste — they appear as plain text. Tell the user up front if their file contains these.
- **Drafts are private.** This skill stops at "Save draft" by default. The draft URL is only accessible to the user; nothing is sent to subscribers until Publish is confirmed.
- **Magic-link-only accounts won't work.** Password login requires the user to have explicitly set a password at substack.com/account/login-options.
- **Don't hardcode credentials.** Always read from env vars or `.socials`; never paste credentials into code or chat.
