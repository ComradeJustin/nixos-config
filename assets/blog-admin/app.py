"""
Blog admin panel — internal-only web UI for writing and managing blog posts.
Posts are stored as markdown files. Publishing converts them to static HTML.
"""
import os
import json
import subprocess
import re
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs, unquote

POSTS_DIR = "/var/lib/blog/posts"
PUBLIC_DIR = "/var/lib/blog/public"
TEMPLATE_DIR = os.path.join(os.path.dirname(__file__), "templates")
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")
PORT = 8090


def ensure_dirs():
    os.makedirs(POSTS_DIR, exist_ok=True)
    os.makedirs(PUBLIC_DIR, exist_ok=True)
    os.makedirs(os.path.join(PUBLIC_DIR, "posts"), exist_ok=True)


def slugify(title):
    s = title.lower().strip()
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'[\s_]+', '-', s)
    return s.strip('-')


def get_posts():
    """Read all posts, return sorted by date descending."""
    posts = []
    if not os.path.isdir(POSTS_DIR):
        return posts
    for f in os.listdir(POSTS_DIR):
        if not f.endswith(".md"):
            continue
        path = os.path.join(POSTS_DIR, f)
        meta, body = parse_post(path)
        meta["filename"] = f
        meta["slug"] = f[:-3]
        posts.append(meta)
    posts.sort(key=lambda p: p.get("date", ""), reverse=True)
    return posts


def parse_post(path):
    """Parse a markdown post with YAML-like frontmatter."""
    with open(path) as fh:
        content = fh.read()
    meta = {}
    body = content
    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            for line in parts[1].strip().split("\n"):
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip().strip('"')
            body = parts[2].strip()
    return meta, body


def save_post(slug, title, date, body, draft=False):
    """Save a post as a markdown file with frontmatter."""
    ensure_dirs()
    content = f"""---
title: "{title}"
date: "{date}"
draft: {"true" if draft else "false"}
---

{body}"""
    path = os.path.join(POSTS_DIR, f"{slug}.md")
    with open(path, "w") as fh:
        fh.write(content)
    return path


def delete_post(slug):
    path = os.path.join(POSTS_DIR, f"{slug}.md")
    pub = os.path.join(PUBLIC_DIR, "posts", f"{slug}.html")
    if os.path.exists(path):
        os.remove(path)
    if os.path.exists(pub):
        os.remove(pub)


def build_post(slug):
    """Convert a single post to HTML using pandoc."""
    src = os.path.join(POSTS_DIR, f"{slug}.md")
    if not os.path.exists(src):
        return False
    meta, body = parse_post(src)
    if meta.get("draft") == "true":
        return False

    # Write just the body to a temp file for pandoc
    tmp = os.path.join(POSTS_DIR, f".{slug}.tmp.md")
    with open(tmp, "w") as fh:
        fh.write(body)

    try:
        result = subprocess.run(
            ["pandoc", "--from=markdown", "--to=html5"],
            input=body, capture_output=True, text=True
        )
        html_body = result.stdout
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)

    title = meta.get("title", slug)
    date = meta.get("date", "")

    html = post_template(title, date, html_body)
    out = os.path.join(PUBLIC_DIR, "posts", f"{slug}.html")
    with open(out, "w") as fh:
        fh.write(html)
    return True


def build_index():
    """Build the blog index page listing all published posts."""
    posts = get_posts()
    published = [p for p in posts if p.get("draft") != "true"]

    items = ""
    for p in published:
        items += f"""
        <a href="posts/{p['slug']}.html" class="post-link">
          <div class="post-date">{p.get('date', '')}</div>
          <div class="post-title">{p.get('title', p['slug'])}</div>
        </a>"""

    html = blog_index_template(items if items else '<p class="empty">No posts yet.</p>')
    with open(os.path.join(PUBLIC_DIR, "index.html"), "w") as fh:
        fh.write(html)


def build_all():
    """Rebuild all posts and the index."""
    ensure_dirs()
    for f in os.listdir(POSTS_DIR):
        if f.endswith(".md") and not f.startswith("."):
            build_post(f[:-3])
    build_index()


def post_template(title, date, body):
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <link rel="stylesheet" href="../blog.css">
</head>
<body>
  <nav>
    <div class="nav-inner">
      <a href="/" class="logo">guest@justin:~$</a>
      <div class="nav-links">
        <a href="/">home</a>
        <a href="/blog/">blog</a>
      </div>
    </div>
  </nav>
  <article class="container">
    <header>
      <h1>{title}</h1>
      <time>{date}</time>
    </header>
    <div class="content">{body}</div>
    <a href="/blog/" class="back">Back to posts</a>
  </article>
</body>
</html>"""


def blog_index_template(items):
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Blog — Justin</title>
  <link rel="stylesheet" href="blog.css">
</head>
<body>
  <nav>
    <div class="nav-inner">
      <a href="/" class="logo">guest@justin:~$</a>
      <div class="nav-links">
        <a href="/">home</a>
        <a href="/blog/">blog</a>
      </div>
    </div>
  </nav>
  <div class="container">
    <h1>## blog</h1>
    <div class="post-list">{items}</div>
  </div>
</body>
</html>"""


def read_file(path):
    with open(path) as fh:
        return fh.read()


class BlogHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "":
            self.send_page(self.admin_page())
        elif self.path.startswith("/edit/"):
            slug = unquote(self.path[6:].rstrip("/"))
            self.send_page(self.editor_page(slug))
        elif self.path == "/new":
            self.send_page(self.editor_page(None))
        elif self.path.startswith("/delete/"):
            slug = unquote(self.path[8:].rstrip("/"))
            delete_post(slug)
            build_index()
            self.redirect("/")
        elif self.path.startswith("/static/"):
            fpath = os.path.join(STATIC_DIR, self.path[8:])
            if os.path.exists(fpath):
                self.send_file(fpath)
            else:
                self.send_error(404)
        elif self.path == "/preview":
            self.send_page(self.preview_page())
        else:
            self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        data = parse_qs(self.rfile.read(length).decode())

        if self.path == "/save":
            title = data.get("title", [""])[0]
            body = data.get("body", [""])[0]
            date = data.get("date", [datetime.now().strftime("%Y-%m-%d")])[0]
            old_slug = data.get("old_slug", [""])[0]
            draft = "draft" in data
            slug = slugify(title)

            # If renaming, delete old file
            if old_slug and old_slug != slug:
                delete_post(old_slug)

            save_post(slug, title, date, body, draft)
            if not draft:
                build_post(slug)
            build_index()
            self.redirect("/")

        elif self.path == "/publish-all":
            build_all()
            self.redirect("/")
        else:
            self.send_error(404)

    def send_page(self, html):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())

    def send_file(self, path):
        self.send_response(200)
        if path.endswith(".css"):
            self.send_header("Content-Type", "text/css")
        elif path.endswith(".js"):
            self.send_header("Content-Type", "application/javascript")
        self.end_headers()
        with open(path, "rb") as fh:
            self.wfile.write(fh.read())

    def redirect(self, url):
        self.send_response(303)
        self.send_header("Location", url)
        self.end_headers()

    def admin_page(self):
        posts = get_posts()
        rows = ""
        for p in posts:
            draft = ' <span class="draft-badge">draft</span>' if p.get("draft") == "true" else ""
            rows += f"""
            <tr>
              <td><a href="/edit/{p['slug']}">{p.get('title', p['slug'])}</a>{draft}</td>
              <td>{p.get('date', '')}</td>
              <td>
                <a href="/edit/{p['slug']}" class="btn-sm">Edit</a>
                <a href="/delete/{p['slug']}" class="btn-sm danger" onclick="return confirm('Delete this post?')">Delete</a>
              </td>
            </tr>"""

        if not rows:
            rows = '<tr><td colspan="3" class="empty">No posts yet. Write your first one!</td></tr>'

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Blog Admin</title>
  <link rel="stylesheet" href="/static/admin.css">
</head>
<body>
  <div class="container">
    <header>
      <h1>Blog Admin</h1>
      <div class="header-actions">
        <a href="/new" class="btn primary">New Post</a>
        <form method="post" action="/publish-all" style="display:inline">
          <button type="submit" class="btn secondary">Rebuild All</button>
        </form>
      </div>
    </header>
    <table>
      <thead><tr><th>Title</th><th>Date</th><th>Actions</th></tr></thead>
      <tbody>{rows}</tbody>
    </table>
  </div>
</body>
</html>"""

    def editor_page(self, slug):
        title = ""
        body = ""
        date = datetime.now().strftime("%Y-%m-%d")
        is_draft = False

        if slug:
            path = os.path.join(POSTS_DIR, f"{slug}.md")
            if os.path.exists(path):
                meta, body = parse_post(path)
                title = meta.get("title", "")
                date = meta.get("date", date)
                is_draft = meta.get("draft") == "true"

        checked = "checked" if is_draft else ""
        old_slug = slug or ""

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{"Edit" if slug else "New"} Post — Blog Admin</title>
  <link rel="stylesheet" href="/static/admin.css">
</head>
<body>
  <div class="container">
    <header>
      <h1>{"Edit" if slug else "New"} Post</h1>
      <a href="/" class="btn secondary">Back</a>
    </header>
    <form method="post" action="/save">
      <input type="hidden" name="old_slug" value="{old_slug}">
      <div class="field">
        <label>Title</label>
        <input type="text" name="title" value="{title}" placeholder="Post title..." required>
      </div>
      <div class="field">
        <label>Date</label>
        <input type="date" name="date" value="{date}">
      </div>
      <div class="field">
        <label>Content (Markdown)</label>
        <textarea name="body" rows="20" placeholder="Write your post...">{body}</textarea>
      </div>
      <div class="field row">
        <label class="checkbox"><input type="checkbox" name="draft" {checked}> Save as draft</label>
      </div>
      <div class="actions">
        <button type="submit" class="btn primary">Save &amp; Publish</button>
        <a href="/" class="btn secondary">Cancel</a>
      </div>
    </form>
  </div>
</body>
</html>"""

    def log_message(self, fmt, *args):
        pass  # Silence access logs


if __name__ == "__main__":
    ensure_dirs()
    build_all()
    server = HTTPServer(("0.0.0.0", PORT), BlogHandler)
    print(f"Blog admin running at http://0.0.0.0:{PORT}")
    server.serve_forever()
