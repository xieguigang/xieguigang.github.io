"""Extract every block equation from the posts and render it with MathJax into a
transparent PNG (inline formulas are handled separately by inline_math_to_html.py).

Pipeline:
  1. scan the markdown (skipping fenced code, inline code and inline math),
  2. build one HTML page holding all block equations,
  3. headless Chrome renders it with MathJax (SVG output) and dumps the DOM,
     from which the bounding boxes are read,
  4. headless Chrome takes one transparent screenshot of the whole page,
  5. crop_formulas.R cuts each equation out of that screenshot.

Output: formulas/<tag>/eq01..eqNN.png plus _fx/manifest.json
"""
import json
import pathlib
import re
import subprocess

BLOG = pathlib.Path(r"G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures/blog")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
WORK = BLOG / "_fx"
SCALE = 3

POSTS = {
    "blog1": BLOG / "blog1_gsva_principles.md",
    "blog2": BLOG / "blog2_mogsva_vs_single_omics.md",
}


def mask(text: str, pattern: str) -> str:
    """Blank out matches, keeping offsets and newlines intact."""
    out = list(text)
    for m in re.finditer(pattern, text, flags=re.S | re.M):
        for i in range(m.start(), m.end()):
            if out[i] != "\n":
                out[i] = " "
    return "".join(out)


def scan_blocks(text: str):
    """Block equations, in document order, outside code fences."""
    masked = mask(text, r"^```.*?^```")
    spans = []
    for m in re.finditer(r"(?ms)^\$\$\n(.*?)\n\$\$$", masked):
        spans.append(dict(tex=text[m.start(1):m.end(1)], start=m.start(), end=m.end()))
    return spans


def build_page(items, out_html: pathlib.Path):
    body = "\n".join(
        f'<div class="row" data-fid="{i}"><span class="math">$${it["tex"]}$$</span></div>'
        for i, it in enumerate(items)
    )
    html = f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<script>
window.MathJax = {{
  tex: {{inlineMath: [['$','$']], displayMath: [['$$','$$']]}},
  svg: {{fontCache: 'none'}},
  startup: {{typeset: true}}
}};
</script>
<script src="../vendor/mathjax-tex-svg.js"></script>
<style>
html, body {{ background: transparent; margin: 0; padding: 0; }}
body {{ font-family: "Noto Sans SC","Microsoft YaHei",system-ui,sans-serif;
        font-size: 17px; color: #1d232b; }}
.row {{ padding: 26px 40px; }}
</style></head><body>
{body}
<pre id="meta"></pre>
<script>
MathJax.startup.promise.then(function () {{
  var out = [];
  document.querySelectorAll('[data-fid]').forEach(function (row) {{
    var svg = row.querySelector('svg');
    var r = svg.getBoundingClientRect();
    out.push({{ id: +row.dataset.fid,
                x: r.left + window.scrollX, y: r.top + window.scrollY,
                w: r.width, h: r.height }});
  }});
  document.getElementById('meta').textContent = JSON.stringify(out);
}});
</script>
</body></html>"""
    out_html.write_text(html, encoding="utf-8")


def run_chrome(args, timeout=180):
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
           "--default-background-color=00000000", f"--force-device-scale-factor={SCALE}"] + args
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def render(tag: str, items):
    page = WORK / f"{tag}_block.html"
    build_page(items, page)

    dom = run_chrome(["--virtual-time-budget=25000", "--window-size=1400,4000",
                      "--dump-dom", page.as_uri()])
    m = re.search(r'<pre id="meta">(.*?)</pre>', dom.stdout, flags=re.S)
    if not m or not m.group(1).strip():
        raise RuntimeError(f"meta not found for {tag}; stderr: {dom.stderr[:400]}")
    meta = json.loads(m.group(1))

    max_y = max(it["y"] + it["h"] for it in meta) + 60
    png = WORK / f"{tag}_block.png"
    run_chrome(["--virtual-time-budget=25000", f"--window-size=1400,{int(max_y) + 40}",
                f"--screenshot={png}", page.as_uri()])
    if not png.exists():
        raise RuntimeError("screenshot failed")
    return meta, png


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    jobs = []
    for tag, md in POSTS.items():
        text = md.read_text(encoding="utf-8")
        blocks = scan_blocks(text)
        print(f"{tag}: block equations = {len(blocks)}")
        (BLOG / "formulas" / tag).mkdir(parents=True, exist_ok=True)

        entries = []
        if blocks:
            meta, png = render(tag, blocks)
            for i, (it, m) in enumerate(zip(blocks, meta)):
                entries.append(dict(kind="block", file=f"{tag}/eq{i + 1:02d}.png", id=i,
                                    x=m["x"], y=m["y"], w=m["w"], h=m["h"],
                                    base=None, png=str(png), tex=it["tex"]))
        jobs.append(dict(tag=tag, manifest=entries, text=text))

    (WORK / "manifest.json").write_text(json.dumps(jobs, ensure_ascii=False, indent=1),
                                        encoding="utf-8")
    print("manifest ->", WORK / "manifest.json")


if __name__ == "__main__":
    main()
