---
name: substack-post
description: Publishes a local blog file (markdown) to Substack using Playwright MCP browser automation. Trigger when the user says anything like "publish to Substack", "post this blog to Substack", "upload my markdown to Substack", "share on Substack", "save this draft to Substack", or any similar intent to send a local blog file to Substack. Defaults to saving as a draft. Do NOT trigger for general Substack browsing or subscriber management.
---

# Substack Post

Automates publishing a local markdown blog file to Substack using Playwright MCP browser tools. Defaults to saving as a draft and confirms with the user before publishing.

## Prerequisites

This skill requires the **Playwright MCP** server to be installed and configured.

Install browsers:
```bash
npx playwright install
```

Add to your Codex MCP config:
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

Credentials come from environment variables. Before using this skill, ensure these are set:

- `SUBSTACK_EMAIL` — Substack account email
- `SUBSTACK_PASSWORD` — Substack account password (only works if explicitly set — magic-link-only accounts will fail)
- `SUBSTACK_PUBLICATION` *(optional)* — publication subdomain, e.g. `myblog` for `myblog.substack.com`

**One-time setup:**
1. Create a `.socials` file in the project root (add it to `.gitignore`)
2. Add:
   ```
   SUBSTACK_EMAIL=your_email@example.com
   SUBSTACK_PASSWORD=your_password
   SUBSTACK_PUBLICATION=myblog
   ```
3. Or export them in your shell.

If the env vars are not set, ask the user before proceeding. Do NOT hardcode credentials anywhere.

## Inputs

Required:
- **Blog file path** — local path to a markdown blog file.

Optional:
- **Title** — defaults to the first `# H1` line of the file, falling back to the filename without extension.
- **Subtitle**
- **Action** — `draft` (default) or `publish`.

## Workflow

### Step 1: Read credentials

```bash
echo $SUBSTACK_EMAIL
echo $SUBSTACK_PASSWORD
echo $SUBSTACK_PUBLICATION
```

If blank, check `.socials`:
```bash
grep -E "^SUBSTACK_(EMAIL|PASSWORD|PUBLICATION)=" .socials 2>/dev/null
```

If still missing, ask the user.

### Step 2: Read and parse the blog file

1. Read the file from disk.
2. **Detect and strip frontmatter.** If the file begins with a YAML block (`---` ... `---`) or TOML block (`+++` ... `+++`), parse it and remove it from the body. Handles Hugo, Jekyll, Zola, Hexo, Astro, Obsidian, etc. Files without frontmatter pass through unchanged.
3. **Resolve title** (first non-empty wins): explicit user input → frontmatter `title` → first `# H1` in body (strip from body if used) → filename without extension. For generic filenames (`index`, `README`, `post`), use the parent directory name instead.
4. **Resolve subtitle**: explicit user input → frontmatter `subtitle` → `description` → `summary` → `excerpt` → blank.
5. Body = remaining markdown after frontmatter is stripped (and after the leading H1 is stripped if it was used as the title).

### Step 3: Log in

1. Navigate to `https://substack.com/sign-in`.
2. Click the **"Sign in with password"** link — Substack defaults to magic-link, the password field is hidden until this is clicked.
3. Fill the email field with `SUBSTACK_EMAIL` and the password field with `SUBSTACK_PASSWORD`.
4. Click the sign-in button.
5. Verify login succeeded. If a captcha / device check appears, stop and ask the user to complete it in the same browser session.

### Step 4: Open the editor

- If `SUBSTACK_PUBLICATION` is set: navigate to `https://<publication>.substack.com/publish/post?type=newsletter`.
- Otherwise: navigate to `https://substack.com`, then click "New post" on the dashboard.

### Step 5: Fill the post

1. Type the title in the title field.
2. If a subtitle was given, type it in the subtitle field.
3. Click into the body editor. **Do not paste the whole body as one blob** — pasted `##` lines come through as literal text. Substack only auto-styles a heading when `# `/`## `/`### ` is *typed* at line start and the space key is pressed (the space triggers the conversion). Split the body on lines matching `^#{1,3} `; paste prose chunks between headings (so inline markdown still converts), and for each heading line type the prefix + space + heading text + Enter via the type/keypress tools. Code blocks, images, and tables still won't render — flag in the final report.

### Step 6: Save as draft

Click "Save draft" or wait for autosave. Capture the draft URL.

### Step 7: Confirm before publishing

Stop at draft by default. Report the draft URL and any markdown elements that didn't convert cleanly. Ask the user before clicking Publish.

If the user confirmed publish: Continue → "Send to everyone now" → submit. Verify and report the public URL.

## Error Handling

- **"Sign in with password" link missing**: take a screenshot, report.
- **Password login fails**: user likely never set a password — tell them to set one at `https://substack.com/account/login-options`.
- **2FA / captcha**: stop, hand off to the user, retry.
- **File missing / unreadable**: stop and report.
- **Editor element not found**: screenshot and report.
- **Login rate limit**: tell the user to wait a few minutes.

## Important Notes

- Markdown auto-conversion is partial — code blocks, images, and tables don't survive a paste.
- Drafts are private until published; default behavior stops at draft.
- Magic-link-only accounts cannot use this skill.
