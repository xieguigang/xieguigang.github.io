"""Build the publish-ready variant: block equations ($$...$$) become <img> of the
transparent PNGs, inline formulas are already HTML so they stay as they are.

Sizes are read straight from the PNG headers (width/height are 3x the CSS px).
"""
import pathlib
import re
import struct

BLOG = pathlib.Path(r"G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures/blog")
SCALE = 3

POSTS = {"blog1": "blog1_gsva_principles.md", "blog2": "blog2_mogsva_vs_single_omics.md"}


def png_size(path: pathlib.Path):
    head = path.read_bytes()[:24]
    w, h = struct.unpack(">II", head[16:24])
    return round(w / SCALE), round(h / SCALE)


def alt_text(tex: str, limit: int = 70) -> str:
    t = re.sub(r"\\[a-zA-Z]+", " ", tex)
    t = re.sub(r"[{}$^_\\]", "", t)
    t = re.sub(r"\s+", " ", t).strip()
    return (t[:limit] or "formula").replace('"', "'")


def main():
    for tag, name in POSTS.items():
        md = BLOG / name
        text = md.read_text(encoding="utf-8")
        # block equations sit on their own lines: "$$" / body / "$$"
        pat = re.compile(r"(?ms)^\$\$\n(.*?)\n\$\$$")
        n = len(pat.findall(text))

        out, pos, idx = [], 0, 0
        for m in pat.finditer(text):
            idx += 1
            png = BLOG / "formulas" / tag / f"eq{idx:02d}.png"
            if not png.exists():
                raise SystemExit(f"missing {png}")
            w, h = png_size(png)
            tag_html = (
                f'<p align="center"><img src="formulas/{tag}/eq{idx:02d}.png" '
                f'width="{w}" height="{h}" style="max-width:100%;height:auto" '
                f'alt="{alt_text(m.group(1))}"></p>'
            )
            out.append(text[pos:m.start()])
            out.append(tag_html)
            pos = m.end()
        out.append(text[pos:])
        text = "".join(out)

        dest = md.with_suffix(".images.md")
        dest.write_text(text, encoding="utf-8")
        left = len(re.findall(r"(?m)^\$\$$", text))
        print(f"{dest.name}: {n} block equations -> PNG, leftover $$: {left}")


if __name__ == "__main__":
    main()
