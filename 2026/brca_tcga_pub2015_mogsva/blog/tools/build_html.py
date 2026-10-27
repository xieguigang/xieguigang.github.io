"""Build a styled, single-file HTML page from a blog post.

The Markdown is the single source of truth: inline formulas are already HTML
(<i>/<sub>/<sup>), block equations stay as $$...$$ and are typeset by MathJax
(local copy first, CDN as fallback). Local images are inlined as data URIs so the
resulting .html can be published on its own.
"""
import base64
import html
import mimetypes
import pathlib
import re

BLOG = pathlib.Path(r"G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures/blog")
POSTS = ["blog1_gsva_principles.md", "blog2_mogsva_vs_single_omics.md"]

CSS = """
:root{--ink:#1d232b;--ink2:#4a5560;--line:#e3e7ec;--accent:#3C5488;--accent2:#E64B35;--soft:#f6f8fa;--code:#f3f5f7}
*{box-sizing:border-box}
body{margin:0;background:#fff;color:var(--ink);font-family:"Noto Sans SC","PingFang SC","Microsoft YaHei",system-ui,-apple-system,sans-serif;
     font-size:17px;line-height:1.85;-webkit-font-smoothing:antialiased}
.wrap{max-width:780px;margin:0 auto;padding:52px 24px 90px}
h1{font-size:2.02em;line-height:1.35;margin:0 0 .4em;letter-spacing:-.01em}
h2{font-size:1.4em;margin:2.3em 0 .6em;padding-bottom:.32em;border-bottom:1px solid var(--line)}
h3{font-size:1.13em;margin:1.8em 0 .5em}
h4{font-size:1em;margin:1.4em 0 .4em;color:var(--ink2)}
p{margin:.95em 0}
a{color:var(--accent)}
.kicker{display:inline-block;font-size:.78em;letter-spacing:.14em;text-transform:uppercase;color:var(--accent);font-weight:700;margin-bottom:.9em}
.lede{font-size:1.06em;color:var(--ink2);margin-bottom:1.2em}
.meta{font-size:.85em;color:#8a949e;margin-bottom:2em}
blockquote{margin:1.5em 0;padding:.2em 1.1em;border-left:3px solid var(--accent);color:var(--ink2);background:linear-gradient(90deg,var(--soft),transparent)}
pre{background:var(--code);border:1px solid var(--line);border-radius:10px;padding:16px 18px;overflow-x:auto;font-size:.86em;line-height:1.65;
    font-family:"JetBrains Mono",ui-monospace,Consolas,monospace}
code{font-family:"JetBrains Mono",ui-monospace,Consolas,monospace;background:var(--code);padding:.1em .35em;border-radius:4px;font-size:.88em}
pre code{background:none;padding:0}
figure{margin:2.1em 0}
figure img{width:100%;height:auto;display:block;border:1px solid var(--line);border-radius:8px;background:#fff}
p.cap{font-size:.85em;color:#6b7580;margin-top:.7em;line-height:1.6}
table{width:100%;border-collapse:collapse;margin:1.5em 0;font-size:.92em}
th,td{padding:.5em .65em;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
th{background:var(--soft);font-weight:600}
hr{border:none;border-top:1px solid var(--line);margin:2.8em 0}
ul,ol{padding-left:1.35em}
li{margin:.3em 0}
.disp{text-align:center;margin:1.6em 0}
sub,sup{font-size:.72em;line-height:0}
img[align]{max-width:100%}
@media (min-width:900px){figure{margin-left:-60px;margin-right:-60px}}
"""

MATHJAX = """<script>
window.MathJax = {tex: {inlineMath: [['\\\\(','\\\\)']], displayMath: [['$$','$$']], tags: 'none'}};
</script>
<script>
(function () {
  var s = document.createElement('script');
  s.src = 'vendor/mathjax-tex-svg.js'; s.async = true;
  s.onerror = function () {
    var d = document.createElement('script');
    d.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js';
    d.async = true; document.head.appendChild(d);
  };
  document.head.appendChild(s);
})();
</script>"""


def slug(text: str) -> str:
    """GitHub-style anchor: lowercase, drop punctuation, spaces to hyphens."""
    t = re.sub(r"<[^>]+>", "", text)
    t = t.strip().lower()
    t = re.sub(r"[^\w\u4e00-\u9fff \-]", "", t)
    return t.replace(" ", "-")


def inline(t: str) -> str:
    t = re.sub(r"`([^`]+)`", lambda m: "<code>" + html.escape(m.group(1)) + "</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', t)
    return t


def cells(row: str):
    return [c.strip() for c in re.split(r"(?<!\\)\|", row)[1:-1]]


INLINE_LIMIT = 250 * 1024   # inline small images, keep big figures external


def data_uri(path: pathlib.Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    blob = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{blob}"


def render(md_path: pathlib.Path) -> str:
    lines = md_path.read_text(encoding="utf-8").split("\n")
    fm = {}
    if lines and lines[0].strip() == "---":
        end = lines.index("---", 1)
        for l in lines[1:end]:
            if ":" in l:
                k, v = l.split(":", 1)
                fm[k.strip()] = v.strip().strip('"')
        lines = lines[end + 1:]

    out, i, n = [], 0, len(lines)
    while i < n:
        s = lines[i].strip()
        if not s:
            i += 1
            continue
        if s.startswith("```"):
            j, buf = i + 1, []
            while j < n and not lines[j].strip().startswith("```"):
                buf.append(lines[j])
                j += 1
            out.append("<pre><code>" + html.escape("\n".join(buf)) + "</code></pre>")
            i = j + 1
            continue
        m = re.match(r"^(#{1,4}) (.+)$", s)
        if m:
            lvl = len(m.group(1))
            out.append(f'<h{lvl} id="{slug(m.group(2))}">{inline(m.group(2))}</h{lvl}>')
            i += 1
            continue
        if s == "---":
            out.append("<hr>")
            i += 1
            continue
        if s == "$$":
            j, buf = i + 1, []
            while j < n and lines[j].strip() != "$$":
                buf.append(lines[j])
                j += 1
            out.append('<div class="disp">$$' + " ".join(buf) + "$$</div>")
            i = j + 1
            continue
        if s.startswith("|"):
            rows = []
            while i < n and lines[i].strip().startswith("|"):
                rows.append(lines[i].strip())
                i += 1
            head, body = cells(rows[0]), [cells(r) for r in rows[2:]]
            t = ["<table><thead><tr>"] + [f"<th>{inline(c)}</th>" for c in head] + ["</tr></thead><tbody>"]
            for r in body:
                t.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>")
            t.append("</tbody></table>")
            out.append("\n".join(t))
            continue
        if s.startswith(">"):
            buf = []
            while i < n and lines[i].strip().startswith(">"):
                buf.append(lines[i].strip().lstrip(">").strip())
                i += 1
            out.append("<blockquote><p>" + inline(" ".join(buf)) + "</p></blockquote>")
            continue
        if re.match(r"^[-*] ", s) or re.match(r"^\d+\. ", s):
            tag = "ol" if re.match(r"^\d+\. ", s) else "ul"
            items = []
            while i < n and (re.match(r"^[-*] ", lines[i].strip()) or re.match(r"^\d+\. ", lines[i].strip())):
                items.append(re.sub(r"^([-*]|\d+\.)\s+", "", lines[i].strip()))
                i += 1
            out.append(f"<{tag}>" + "".join(f"<li>{inline(x)}</li>" for x in items) + f"</{tag}>")
            continue
        if s.startswith("!["):
            m2 = re.match(r"!\[([^\]]*)\]\(([^)]+)\)", s)
            src = m2.group(2)
            local = md_path.parent / src
            url = data_uri(local) if (local.exists() and local.stat().st_size <= INLINE_LIMIT) else src
            out.append(f'<figure><img src="{url}" alt="{html.escape(m2.group(1))}"></figure>')
            i += 1
            continue
        buf = []
        while i < n and lines[i].strip() and not lines[i].strip().startswith(("```", "#", "|", ">")) \
                and lines[i].strip() != "---" and not lines[i].strip().startswith("!["):
            buf.append(lines[i].strip())
            i += 1
        txt = " ".join(buf)
        cls = ""
        if txt.startswith("*") and txt.endswith("*") and not txt.startswith("**"):
            txt, cls = txt[1:-1], ' class="cap"'
        out.append(txt if txt.startswith('<p align="center">') else f"<p{cls}>{inline(txt)}</p>")

    title = fm.get("title", md_path.stem)
    kicker = "算法笔记 · 上篇" if "blog1" in md_path.name else "算法笔记 · 下篇"
    lede = fm.get("subtitle", "")
    meta = " ｜ ".join(x for x in [fm.get("date", ""), fm.get("series", "")] if x)

    body = "\n".join(out)
    # inline the block-equation PNGs too (they are referenced by <img src="formulas/…">)
    def repl(m):
        src = m.group(1)
        if src.startswith("data:") or src.startswith("http"):
            return m.group(0)
        p = md_path.parent / src
        use = p.exists() and p.stat().st_size <= INLINE_LIMIT
        return f'src="{data_uri(p) if use else src}"'

    body = re.sub(r'src="([^"]+)"', repl, body)

    return f"""<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
{MATHJAX}
<style>{CSS}</style>
</head><body><div class="wrap">
<div class="kicker">{kicker}</div>
<p class="lede">{html.escape(lede)}</p>
<p class="meta">{html.escape(meta)}</p>
{body}
</div></body></html>
"""


def main():
    for name in POSTS:
        md = BLOG / name
        out = md.with_suffix(".html")
        html_text = render(md)
        out.write_text(html_text, encoding="utf-8")
        print(f"{out.name}: {len(html_text) / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
