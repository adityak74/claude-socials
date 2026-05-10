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

You also need **node** on PATH. The skill installs the `marked` markdown→HTML library on demand into a temporary directory; no global install required.

See https://github.com/microsoft/playwright-mcp for full setup instructions.

## Credentials Setup

Credentials come from environment variables. Before using this plugin, ensure these are set:

- `SUBSTACK_EMAIL` — Substack account email
- `SUBSTACK_PASSWORD` — Substack account password (only works if you've explicitly set one — magic-link-only accounts will fail; set a password at https://substack.com/account/login-options)
- `SUBSTACK_PUBLICATION` *(optional)* — your publication subdomain, e.g. `myblog` for `myblog.substack.com`. If omitted, the skill navigates to the dashboard at substack.com after login and clicks "New post".

**One-time setup:**
1. Create a `.socials` file in the project root (add it to `.gitignore`)
2. Add (the file may use `export KEY=VALUE` form too):
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

## How content gets into Substack — the working approach

Substack's editor is a TipTap/ProseMirror instance. Three things matter:

1. **It accepts `text/html` from the system clipboard.** A `ClipboardItem` containing a `text/html` Blob, written via `navigator.clipboard.write([item])` and then pasted with `Ctrl/Cmd+V`, gets parsed by ProseMirror's clipboard handler — headings, bold/italic, links, ordered/unordered lists, fenced code blocks, horizontal rules and inline `<code>` all survive.
2. **It does NOT support tables.** ProseMirror strips `<table>` entirely on paste. The "More" menu has Code block, Divider, Footnote, LaTeX, Poetry, Poll, Prediction market, Recipe — no table item. The only reliable way to ship a table is to render it as a PNG and paste the PNG.
3. **It accepts pasted images.** A `ClipboardItem` with an `image/png` Blob, pasted with `Ctrl/Cmd+V`, gets uploaded to substackcdn.com automatically.

Synthetic `ClipboardEvent` dispatch with `dataTransfer` does **not** work — ProseMirror only honors paste events that come from a real `Ctrl/Cmd+V` after `navigator.clipboard.write`. Plan accordingly.

The pipeline therefore is:

```
markdown → strip frontmatter → marked → HTML
        → split out <table> blocks (replace each with a unique placeholder paragraph)
        → write HTML to clipboard, Ctrl+V into editor (gives most of the post)
        → for each table: render PNG, copy PNG to clipboard, position cursor at the
                          placeholder, Ctrl+V (image uploads to Substack CDN)
```

## Workflow

### Step 1: Read credentials

Read `SUBSTACK_EMAIL` and `SUBSTACK_PASSWORD` (and optionally `SUBSTACK_PUBLICATION`) from environment:
```bash
echo $SUBSTACK_EMAIL
echo $SUBSTACK_PASSWORD
echo $SUBSTACK_PUBLICATION
```

If blank, check for a `.socials` file (note the `export` prefix variant):
```bash
grep -E "^(export )?SUBSTACK_(EMAIL|PASSWORD|PUBLICATION)=" .socials 2>/dev/null
```

If still not found, ask the user to provide them. To load a `.socials` file with `export` lines into the environment:
```bash
set -a; source .socials; set +a
```

### Step 2: Read and parse the blog file

1. Use the Read tool on the blog file path.
2. **Detect and strip frontmatter.** If the file starts with a YAML frontmatter block (`---` ... `---`) or a TOML block (`+++` ... `+++`), parse it and remove the entire block from the body before HTML conversion. This handles Hugo, Jekyll, Zola, Hexo, Astro, Obsidian, etc. Files with no frontmatter are passed through unchanged.
3. **Resolve title** in this order — first non-empty wins:
   - Explicit title from the user
   - `title` field in the frontmatter
   - First `# H1` line in the body (then strip that H1 from the body)
   - Filename without extension (skip generic names like `index`, `README`, `post` and use the parent directory name instead — e.g. `posts/gpu-util/index.md` → `gpu-util`)
4. **Resolve subtitle** in this order:
   - Explicit subtitle from the user
   - `subtitle` field in the frontmatter
   - `description` / `summary` / `excerpt` field in the frontmatter
   - Otherwise leave blank
5. The remaining markdown (frontmatter stripped, leading H1 stripped if it was used as the title) is the post body.

### Step 3: Convert markdown to HTML and split out tables

In a tmp working directory (e.g. `/tmp/substack-post-<timestamp>`):

1. Install `marked` if not already there:
   ```bash
   mkdir -p /tmp/substack-post-$$ && cd /tmp/substack-post-$$
   npm i marked --silent
   ```
2. Write a tiny converter script (`md2html.mjs`):
   ```js
   import { readFileSync } from 'fs';
   import { marked } from 'marked';
   const md = readFileSync(process.argv[2], 'utf8').replace(/^---\n[\s\S]*?\n---\n/, '');
   console.log(marked.parse(md));
   ```
3. Run it on the body file (or write the body to disk first):
   ```bash
   node md2html.mjs body.md > body.html
   ```
4. **Split out tables.** Use a small node script to walk the HTML, extract every `<table>...</table>` block, and replace each with a unique placeholder paragraph like `<p data-substack-table="N"></p>`. Save the extracted tables (keyed by index) so they can be rendered to PNG in Step 5.
5. **Optionally prepend a canonical-link header** if the user requested one (e.g. "READ THE FULL ARTICLE AT https://example.com/post/"). Insert it as `<p><strong>READ FULL ARTICLE AT </strong><a href="...">...</a></p><hr>` at the top.

### Step 4: Log in to Substack and open the editor

1. Navigate to `https://substack.com/sign-in`.
2. If you're already signed in (Substack redirects you to substack.com home), skip the rest of this step.
3. Click the **"Sign in with password"** link. Substack defaults to magic-link sign-in; without this click the password field never appears.
4. Fill `SUBSTACK_EMAIL` and `SUBSTACK_PASSWORD`, submit.
5. If `SUBSTACK_PUBLICATION` is set, navigate to `https://<publication>.substack.com/publish/post?type=newsletter`. This auto-creates a new draft and redirects to `/publish/post/<id>`. Otherwise navigate to `https://substack.com` and click "New post" on the dashboard.

If a captcha or device-verification page appears, stop and ask the user to complete it manually in the same browser session, then retry.

### Step 5: Fill title, subtitle, and body

1. **Title.** Click the `[data-testid="post-title"]` textarea (or `getByRole('textbox', { name: 'Add a title…' })`) and type the title via `browser_type`. After typing, the page title updates to the post title — that's your verification.
2. **Subtitle.** Click `getByRole('textbox', { name: 'Add a subtitle…' })` and type the subtitle.
3. **Body — write HTML to clipboard, then paste:**

   In the Substack tab, run a `browser_evaluate` that puts the body HTML on the clipboard:
   ```js
   async () => {
     const html = `__BODY_HTML_GOES_HERE__`; // includes table-placeholder paragraphs
     const plain = html.replace(/<[^>]+>/g, '');
     const item = new ClipboardItem({
       'text/html': new Blob([html], {type: 'text/html'}),
       'text/plain': new Blob([plain], {type: 'text/plain'})
     });
     await navigator.clipboard.write([item]);
     return { ok: true, len: html.length };
   }
   ```

   Then click the editor (`getByTestId('editor')`) and press `ControlOrMeta+v` ONCE.

   **Verify only one paste happened** by counting headings/`children.length` afterwards. A double-paste produces interleaved duplicate content. If you see duplication, do `Ctrl/Cmd+A` followed by `Delete` to clear, then paste once more.

   The `browser_evaluate` `function` parameter accepts ~20 KB of inline source comfortably; embed the HTML literal directly. For very long posts (>30 KB), serve the HTML from a temporary localhost HTTP server (see Step 6) and `fetch()` it inside the evaluate.

4. **Verify rendering.** Snapshot the editor and check that headings, bold spans, lists, links, and any code blocks have proper structure. Tables will be missing — that's expected, the placeholders are still there.

### Step 6: Render and insert each table as a PNG

This is the only reliable way to put tables into Substack. The pattern:

1. **Build a single HTML page that contains every table** in `tables.html` under a tmp dir, each wrapped in `<div id="t1">…</div>`, `<div id="t2">…</div>`, etc. Style it with a clean white background and tabular-nums so it renders sharply. Example styles:
   ```css
   body { margin: 0; padding: 24px; background: white;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
   .wrap { display: inline-block; padding: 16px; background: white; }
   h3 { margin: 0 0 12px; font-size: 18px; }
   table { border-collapse: collapse; font-size: 14px; }
   th, td { padding: 8px 14px; text-align: left; }
   thead tr { border-bottom: 2px solid #888; }
   tbody tr { border-bottom: 1px solid #e6e6e6; }
   tbody tr:last-child { border-bottom: 1px solid #888; }
   td { font-variant-numeric: tabular-nums; }
   ```
2. **Start a local HTTP server** rooted in the tmp dir. The browser tab can't read `file://` URLs, but `http://127.0.0.1:<port>` works:
   ```bash
   cd /tmp/substack-post-$$ && python3 -m http.server 8765 > srv.log 2>&1 & echo $! > srv.pid
   ```
3. **Open a new browser tab** to `http://127.0.0.1:8765/tables.html` (use `browser_tabs` action `new`).
4. **Screenshot each table element** with `browser_take_screenshot` targeting `#t1`, `#t2`, …, saving as `table1.png`, `table2.png`, … (the screenshot file is written under the playwright-mcp working dir; or save to the tmp HTTP-served dir directly).
5. **For each table N:**
   - **Switch to the localhost tab** (`browser_tabs` action `select`).
   - In a `browser_evaluate`, fetch the PNG and write to clipboard:
     ```js
     async () => {
       const r = await fetch('/tableN.png');
       const blob = await r.blob();
       await navigator.clipboard.write([new ClipboardItem({'image/png': blob})]);
       return { ok: true, size: blob.size };
     }
     ```
   - **Switch back to the Substack tab.**
   - In a `browser_evaluate`, find the placeholder paragraph for table N and place the cursor inside it:
     ```js
     () => {
       const editor = document.querySelector('.ProseMirror');
       editor.focus();
       const placeholder = editor.querySelector('[data-substack-table="N"]')
         || /* fallback: find empty <p> right after a known H3 heading */;
       const range = document.createRange();
       range.setStart(placeholder, 0);
       range.collapse(true);
       const sel = window.getSelection();
       sel.removeAllRanges();
       sel.addRange(range);
     }
     ```
     Note: ProseMirror often strips unknown `data-*` attributes during paste. If your placeholder attribute is gone, locate the insertion point by the heading that preceded the table (e.g. the empty `<p>` immediately after the H3 with the table's title).
   - Press `ControlOrMeta+v`. Wait ~2 s for Substack to upload the image; the `<img>` will appear with `src="https://substackcdn.com/image/fetch/…"`.

6. **Stop the local HTTP server:**
   ```bash
   kill $(cat /tmp/substack-post-$$/srv.pid)
   ```

### Step 7: Save as draft

1. Substack autosaves continuously. Wait a few seconds and verify the toolbar shows a "Saved" status button.
2. Capture the draft URL from `location.href` (it'll be `https://<publication>.substack.com/publish/post/<id>`).

### Step 8: Confirm before publishing

By default, **stop here**. Report to the user:
- The draft URL.
- Each PNG that was uploaded for a table (so they can re-render or replace if styling is off).
- Any remaining markdown elements that didn't convert cleanly (currently: relative-path images like `./foo.png` — those need manual upload because the source PNGs aren't reachable from Substack).
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
- **Paste produced double content**: don't try to surgically delete duplicates — `Ctrl/Cmd+A`, `Delete`, then paste once more. Manual deletion can cascade and lose unrelated paragraphs (Substack's `Shift+End` selects across more than one visual line in long paragraphs).
- **Table image didn't insert**: confirm the localhost server is still running (`curl -I http://127.0.0.1:8765/tableN.png`), confirm the clipboard write succeeded (look for `ok: true`), and confirm the cursor is inside the editor (not in a textarea like the title). Re-run the localhost-tab `clipboard.write` then `Ctrl/Cmd+V` in the Substack tab.

## Important Notes

- **Markdown fidelity is high *via the HTML clipboard route*.** Headings, bold/italic, links, ordered/unordered lists, fenced code blocks, horizontal rules, and inline `<code>` all render correctly when you paste `text/html`. **Tables** require the screenshot detour because Substack has no table primitive. **Images with relative paths** (`./foo.png`) won't work — Substack can't reach the local file. If the post needs them, either upload manually after the draft is saved, or upload them to a public host (S3, the user's blog CDN, GitHub raw) and rewrite the `src` to an absolute URL before pasting.
- **Synthetic clipboard events do not work.** Don't try `editor.dispatchEvent(new ClipboardEvent('paste', { clipboardData }))` — ProseMirror ignores it. Always use `navigator.clipboard.write` followed by a real `Ctrl/Cmd+V` keypress.
- **Drafts are private.** This skill stops at "Save draft" by default. Nothing is sent to subscribers until Publish is confirmed.
- **Magic-link-only accounts won't work.** Password login requires the user to have explicitly set a password at substack.com/account/login-options.
- **Don't hardcode credentials.** Always read from env vars or `.socials`; never paste credentials into code or chat.
- **Clean up the tmp working dir** at the end — `rm -rf /tmp/substack-post-$$` — and stop the HTTP server.
