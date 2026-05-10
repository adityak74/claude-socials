---
name: substack-post
description: Publishes a local markdown blog file to Substack using Playwright browser automation
version: 1.0.0
author: Aditya Karnam
license: MIT
platforms: [macos, linux, windows]

metadata:
  hermes:
    tags: [Social Media, Substack, Browser Automation, Publishing, Blog]
    related_skills: []
    requires_toolsets: [browser]
    requires_tools: [browser_navigate, browser_fill_form, browser_click, browser_type, browser_snapshot]

required_environment_variables:
  - name: SUBSTACK_EMAIL
    prompt: "Enter your Substack account email"
    help: "The email address used to log in to substack.com"
    required_for: "Logging in to Substack"
  - name: SUBSTACK_PASSWORD
    prompt: "Enter your Substack account password"
    help: "Your Substack password (set one at https://substack.com/account/login-options if you only use magic-link)"
    required_for: "Logging in to Substack"
  - name: SUBSTACK_PUBLICATION
    prompt: "Enter your Substack publication subdomain (optional)"
    help: "The subdomain of your publication, e.g. 'myblog' for myblog.substack.com. Leave blank to use the default publication shown on the dashboard."
    required_for: "Targeting a specific publication directly"
---

# Substack Post

Automates publishing a local markdown blog file to Substack using Playwright browser tools. Defaults to saving as a draft and confirms before publishing.

## When to Use

Trigger when the user says "publish to Substack", "post this blog to Substack", "upload my markdown to Substack", "share on Substack", "save this draft to Substack", or any similar intent to send a local blog file to Substack. Do not trigger for general Substack browsing or subscriber management.

## Quick Reference

- Sign-in URL: `https://substack.com/sign-in`
- Editor URL (with publication): `https://<publication>.substack.com/publish/post?type=newsletter`
- Dashboard fallback: `https://substack.com` → click "New post"
- Credentials file: `.socials`
- Default action: save as draft (do not publish without explicit user confirmation)

## Procedure

### 1. Read credentials

```bash
echo $SUBSTACK_EMAIL
echo $SUBSTACK_PASSWORD
echo $SUBSTACK_PUBLICATION
```

If blank, check `.socials`:
```bash
grep -E "^SUBSTACK_(EMAIL|PASSWORD|PUBLICATION)=" .socials 2>/dev/null
```

If still missing, ask the user or run `hermes setup substack-post`.

### 2. Read and parse the blog file

1. Read the markdown file from disk.
2. **Detect and strip frontmatter.** If the file begins with a YAML block (`---` ... `---`) or a TOML block (`+++` ... `+++`), parse it and remove the block from the body. Handles Hugo, Jekyll, Zola, Hexo, Astro, Obsidian, etc. Files without frontmatter pass through unchanged.
3. **Resolve title** (first non-empty wins): explicit user input → frontmatter `title` → first `# H1` in body (strip from body if used) → filename without extension. For generic filenames (`index`, `README`, `post`), use the parent directory name instead.
4. **Resolve subtitle**: explicit user input → frontmatter `subtitle` → `description` → `summary` → `excerpt` → blank.
5. Body = remaining markdown after frontmatter is stripped (and after the leading H1 is stripped if it was used as the title).

### 3. Log in

1. Navigate to `https://substack.com/sign-in`.
2. Click the **"Sign in with password"** link — Substack defaults to magic-link, and the password field is hidden until this link is clicked.
3. Fill the email and password fields, then click sign-in.
4. Verify login. If a captcha or device-verification page appears, stop and hand off to the user.

### 4. Open the editor

- If `SUBSTACK_PUBLICATION` is set: navigate to `https://<publication>.substack.com/publish/post?type=newsletter`.
- Otherwise: navigate to `https://substack.com` and click "New post".

### 5. Fill the post

1. Type the title in the title field.
2. If a subtitle was supplied, type it in the subtitle field.
3. Click into the body editor. Do not paste the whole body — pasted `##` lines stay as literal text. Substack only auto-styles a heading when `# `/`## `/`### ` is *typed* at line start and the trailing space is pressed (space triggers the conversion). Split the body on lines matching `^#{1,3} `: paste prose chunks between headings (preserves inline markdown), and for each heading line type the prefix + space + heading text + Enter. Code blocks, images, and tables still won't render — flag in the report.

### 6. Save as draft

Click "Save draft" or wait for autosave. Capture the draft URL.

### 7. Confirm before publishing

Stop at draft by default. Report the draft URL and any markdown elements that didn't convert. Only click Publish if the user explicitly confirmed.

## Pitfalls

- **No password set**: password sign-in fails — direct the user to `https://substack.com/account/login-options`.
- **2FA / captcha**: stop and let the user complete it in the same browser session.
- **Markdown fidelity is partial**: code blocks, images, and tables paste as plain text — flag this in the final report.
- **Drafts are private**: this skill stops at draft; nothing is sent to subscribers without explicit confirmation.
- **Login rate limit**: rapid retries may be blocked — wait a few minutes.

## Verification

After saving, the editor URL changes to a draft URL like `https://<publication>.substack.com/publish/post/<id>`. Capture and report it. After publishing (if confirmed), Substack redirects to the public post URL — capture and report that too.
