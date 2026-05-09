---
name: threads-post-thread
description: Crafts and publishes a threaded reply chain to Meta Threads — a root post followed by connected replies forming a linear thread
version: 1.0.0
author: Aditya Karnam
license: MIT
platforms: [macos, linux, windows]

metadata:
  hermes:
    tags: [Social Media, Threads, Meta, Graph API, Thread Chain, Reply]
    related_skills: [threads-post, threads-post-carousel, threads-post-spoiler]
    requires_toolsets: [web]
    requires_tools: [web_search]

required_environment_variables:
  - name: THREADS_USER_ID
    prompt: "Enter your numeric Threads user ID"
    help: "Get it via: curl 'https://graph.threads.net/v1.0/me?access_token=YOUR_TOKEN'"
    required_for: "Identifying your Threads account in API calls"
  - name: THREADS_ACCESS_TOKEN
    prompt: "Enter your long-lived Threads access token"
    help: "Generate at developers.facebook.com — needs threads_basic, threads_content_publish, and threads_manage_replies scopes"
    required_for: "Authenticating Graph API requests including reply publishing"
---

# Threads Post — Thread Chain

Publishes a root post followed by a chain of connected replies on Meta Threads. Each reply targets the previous post's live ID, creating a linear 1→2→3 thread.

**Rate limits:**
- 250 root posts per rolling 24-hour window
- 1,000 API-published replies per rolling 24-hour window

## When to Use

Trigger when the user says "create a thread on Threads", "thread this article", "post a thread", "make a multi-part thread", or "thread chain". Use `threads-post` for a single post and `threads-post-carousel` for galleries.

## Quick Reference

- Root container: `/{THREADS_USER_ID}/threads`
- Reply container: `/me/threads` with `reply_to_id`
- Publish: `/{THREADS_USER_ID}/threads_publish` (same for root and replies)
- Each post needs a 30-second wait before publish
- Credentials file: `.socials`

## Procedure

### 1. Read credentials

```bash
echo $THREADS_USER_ID
echo $THREADS_ACCESS_TOKEN
```

If blank, check `.socials`:
```bash
grep -E "^THREADS_(USER_ID|ACCESS_TOKEN)=" .socials 2>/dev/null
```

### 2. Craft the thread

When given article or long-form content:
- Break into 3–8 chunks, each under 500 characters
- Post 1: hook — strong opening
- Posts 2…N-1: one clear point each, flowing naturally
- Last post: CTA or closing takeaway
- Number them `1/N`, `2/N`, …
- Hashtags only at the end of the last post (1–3 max)

**Show the full draft to the user and wait for approval before publishing.**

### 3. Publish root post

**3a. Create container:**
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads" \
  -d "media_type=TEXT" \
  --data-urlencode "text=ROOT_POST_TEXT" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → `ROOT_CONTAINER_ID`.

**3b. Wait and publish:**
```bash
sleep 30
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=ROOT_CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → `REPLY_TO_ID` (the root post's live ID).

### 4. Publish each reply (repeat for posts 2…N)

**4a. Create reply container:**
```bash
curl -s -X POST \
  "https://graph.threads.net/v1.0/me/threads" \
  -d "media_type=TEXT" \
  --data-urlencode "text=NEXT_POST_TEXT" \
  -d "reply_to_id=${REPLY_TO_ID}" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → `REPLY_CONTAINER_ID`.

**4b. Wait and publish:**
```bash
sleep 30
curl -s -X POST \
  "https://graph.threads.net/v1.0/${THREADS_USER_ID}/threads_publish" \
  -d "creation_id=REPLY_CONTAINER_ID" \
  -d "access_token=${THREADS_ACCESS_TOKEN}"
```

Parse `id` → update `REPLY_TO_ID` before the next iteration.

### 5. Report

Tell the user: success/failure per post, root post URL (`https://www.threads.net/@{handle}/post/{ROOT_POST_ID}`), total posts published. Never expose the access token.

## Pitfalls

- Root containers use `/{THREADS_USER_ID}/threads`; reply containers use `/me/threads`. Mixing them breaks the chain.
- Publishing always uses `/{THREADS_USER_ID}/threads_publish` regardless.
- Each post needs its own 30-second wait — skipping causes `400 / not ready`.
- The chain is strictly linear (1→2→3), not a fan (1←2, 1←3).
- `threads_manage_replies` scope is required for replies — missing it causes 403.
- Long-lived tokens expire after 60 days.

## Verification

After each publish, confirm the returned `id` is non-empty. After the chain completes, the root post URL should show the thread with all replies visible.
