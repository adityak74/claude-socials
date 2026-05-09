---
name: hn-submit
description: Submits a URL to Hacker News using Playwright browser automation
version: 1.0.0
author: Aditya Karnam
license: MIT
platforms: [macos, linux, windows]

metadata:
  hermes:
    tags: [Social Media, Hacker News, Browser Automation, Submission]
    related_skills: []
    requires_toolsets: [browser]
    requires_tools: [browser_navigate, browser_fill_form, browser_click]

required_environment_variables:
  - name: HN_USERNAME
    prompt: "Enter your Hacker News username"
    help: "Your login username at news.ycombinator.com"
    required_for: "Logging in to Hacker News"
  - name: HN_PASSWORD
    prompt: "Enter your Hacker News password"
    help: "Your login password at news.ycombinator.com"
    required_for: "Logging in to Hacker News"
---

# HN Submit

Automates posting a URL to Hacker News using Playwright browser tools.

## When to Use

Trigger when the user says "post to HN", "submit to Hacker News", "share on HN", "submit this to hackernews", or any similar intent to share a URL on Hacker News. Do not trigger for general HN browsing or reading.

## Quick Reference

- Login URL: `https://news.ycombinator.com/login`
- Submit URL: `https://news.ycombinator.com/submit`
- Fields: `acct` (username), `pw` (password), `title`, `url`
- Credentials file: `.socials`

## Procedure

### 1. Read credentials

```bash
echo $HN_USERNAME
echo $HN_PASSWORD
```

If blank, check `.socials`:
```bash
grep -E "^HN_(USERNAME|PASSWORD)=" .socials 2>/dev/null
```

If still missing, ask the user to provide them or run `hermes setup hn-submit`.

### 2. Gather submission details

Ask the user for:
- **Title** — the submission title (should match the article's actual title per HN guidelines)
- **URL** — the full public URL to submit

### 3. Log in

1. Navigate to `https://news.ycombinator.com/login`
2. Confirm the login form is present
3. Fill `acct` with username, `pw` with password
4. Click the submit button
5. Verify login succeeded — username should appear in the nav bar. Stop and report if it failed.

### 4. Submit

1. Navigate to `https://news.ycombinator.com/submit`
2. Confirm the submit form is present
3. Fill `title` and `url`; leave `text` blank (per HN norms for URL posts)
4. Click the submit button
5. Verify submission succeeded

### 5. Report

Tell the user whether it succeeded or failed, and provide the thread URL if shown.

## Pitfalls

- **Duplicate**: HN rejects a URL you've already submitted — report the existing thread URL.
- **Rate limited**: HN blocks rapid re-submissions — tell the user to wait a few minutes.
- **Login failure**: Stop immediately, report the error, ask the user to verify credentials.
- **Form not found**: Take a screenshot, report what the page shows.
- Never leave the `text` field filled when submitting a URL post.

## Verification

After submission, HN redirects to the thread page. Confirm the thread URL is visible and report it to the user.
