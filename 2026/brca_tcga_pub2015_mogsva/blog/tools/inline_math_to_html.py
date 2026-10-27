"""Rewrite inline math ($...$) in the two posts as HTML markup.

Block equations ($$...$$), fenced code and inline code are left untouched.
The mapping is explicit: every formula that appears in the posts must have an
entry here, otherwise the script aborts, so nothing is silently left as LaTeX.

Conventions
-----------
* variables        -> <i>x</i>
* function names   -> upright (max, log, ES, O)
* sub / superscript -> <sub> / <sup>, nested italics kept
* greek             -> unicode (λ, Φ, Σ, ∈, ≤, ≈, ∅, ×, ·, −, …)
* fractions         -> a / b with parentheses where needed
"""
import pathlib
import re

BLOG = pathlib.Path(r"G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures/blog")

SHARED = {
    r"|\mathrm{ES}_{\text{multi}}|\le|\mathrm{ES}_{\text{raw}}|":
        "|ES<sub>multi</sub>| ≤ |ES<sub>raw</sub>|",
    r"\frac{1+\lambda a_j}{1+\lambda}":
        "(1 + <i>λa</i><sub><i>j</i></sub>) / (1 + <i>λ</i>)",
    r"\max_j|ES|": "max<sub><i>j</i></sub> |ES|",
    "a": "<i>a</i>",
    "K": "<i>K</i>",
    r"a=-1/3": "<i>a</i> = −1/3",
    r"a=-1": "<i>a</i> = −1",
}

BLOG1 = dict(SHARED)
BLOG1.update({
    r"x_{im}": "<i>x</i><sub><i>im</i></sub>",
    "i": "<i>i</i>",
    "m": "<i>m</i>",
    "N": "<i>N</i>",
    r"\Phi": "Φ",
    "h": "<i>h</i>",
    r"z_{ij}=0.97": "<i>z</i><sub><i>ij</i></sub> = 0.97",
    "j": "<i>j</i>",
    r"z_{1j}, z_{2j}, \dots":
        "<i>z</i><sub>1<i>j</i></sub>, <i>z</i><sub>2<i>j</i></sub>, …",
    "z": "<i>z</i>",
    "S": "<i>S</i>",
    r"|z|^p": "|<i>z</i>|<sup><i>p</i></sup>",
    r"N_H=|S|": "<i>N</i><sub><i>H</i></sub> = |<i>S</i>|",
    "p": "<i>p</i>",
    r"N_R^{+}=\sum_{i\in S}|z_{ij}|^p":
        "<i>N</i><sub><i>R</i></sub><sup>+</sup> = Σ<sub><i>i</i>∈<i>S</i></sub> "
        "|<i>z</i><sub><i>ij</i></sub>|<sup><i>p</i></sup>",
    r"\max-\min": "max − min",
    r"O(G\cdot N)": "<i>O</i>(<i>G</i> · <i>N</i>)",
    r"+\ O(P\cdot N\cdot G\log G)":
        "+ <i>O</i>(<i>P</i> · <i>N</i> · <i>G</i> log <i>G</i>)",
    "G": "<i>G</i>",
    "P": "<i>P</i>",
    "k": "<i>k</i>",
    r"S_k": "<i>S</i><sub><i>k</i></sub>",
    r"S_k=\varnothing": "<i>S</i><sub><i>k</i></sub> = ∅",
    "K(S)": "<i>K</i>(<i>S</i>)",
    r"\sum_k w_k=1": "Σ<sub><i>k</i></sub> <i>w</i><sub><i>k</i></sub> = 1",
    r"|S_k|=0": "|<i>S</i><sub><i>k</i></sub>| = 0",
    "n": "<i>n</i>",
    r"b_k=1/\log_2(2+|S_k|)":
        "<i>b</i><sub><i>k</i></sub> = 1 / log<sub>2</sub>(2 + |<i>S</i><sub><i>k</i></sub>|)",
    r"b\approx0.32": "<i>b</i> ≈ 0.32",
    r"a_j=1": "<i>a</i><sub><i>j</i></sub> = 1",
    r"a_j=0": "<i>a</i><sub><i>j</i></sub> = 0",
    r"a_j=-1": "<i>a</i><sub><i>j</i></sub> = −1",
    r"\lambda=0.25": "<i>λ</i> = 0.25",
    r"\lambda=0": "<i>λ</i> = 0",
    "a=1": "<i>a</i> = 1",
    "q": "<i>q</i>",
    "K(K-1)/2": "<i>K</i>(<i>K</i> − 1)/2",
    r"\{-1,-\tfrac13,0,1\}": "{−1, −1/3, 0, 1}",
    r"\{-1,-\tfrac13,1\}": "{−1, −1/3, 1}",
    "B": "<i>B</i>",
    "1/1001": "1/1001",
    r"b_k=1/\log_2(2+\lvert S_k\rvert)":
        "<i>b</i><sub><i>k</i></sub> = 1 / log<sub>2</sub>(2 + |<i>S</i><sub><i>k</i></sub>|)",
    r"a_j\in[-1,1]": "<i>a</i><sub><i>j</i></sub> ∈ [−1, 1]",
    "r": "<i>r</i>",
    r"335\times460=154{,}100": "335 × 460 = 154,100",
    "T=0.239": "<i>T</i> = 0.239",
    "p=0.970": "<i>p</i> = 0.970",
    "q=1": "<i>q</i> = 1",
    "r=0.602": "<i>r</i> = 0.602",
    r"10^{-16}": "10<sup>−16</sup>",
    r"w_k": "<i>w</i><sub><i>k</i></sub>",
    r"c_k=w_k\cdot \mathrm{ES}_k":
        "<i>c</i><sub><i>k</i></sub> = <i>w</i><sub><i>k</i></sub> · ES<sub><i>k</i></sub>",
    r"c_k/\sum_k\lvert c_k\rvert":
        "<i>c</i><sub><i>k</i></sub> / Σ<sub><i>k</i></sub>|<i>c</i><sub><i>k</i></sub>|",
    r"1/1001 \approx 0.000999": "1/1001 ≈ 0.000999",
    "B=1000": "<i>B</i> = 1000",
    r"10^{-3}": "10<sup>−3</sup>",
    "p=1": "<i>p</i> = 1",
    "q=0.057": "<i>q</i> = 0.057",
    r"10^{-27}": "10<sup>−27</sup>",
    "K=1": "<i>K</i> = 1",
})

BLOG2 = dict(SHARED)
BLOG2.update({
    r"a_j": "<i>a</i><sub><i>j</i></sub>",
    r"1/\log_2(2+|S|)": "1 / log<sub>2</sub>(2 + |<i>S</i>|)",
    r"1/(B+1)": "1/(<i>B</i> + 1)",
})

POSTS = [("blog1_gsva_principles.md", BLOG1), ("blog2_mogsva_vs_single_omics.md", BLOG2)]


def mask_code(text):
    out = list(text)
    for m in __import__("re").finditer(r"(?ms)^```.*?^```", text):
        for i in range(m.start(), m.end()):
            if out[i] != "\n":
                out[i] = " "
    import re
    for m in re.finditer(r"`[^`\n]+`", "".join(out)):
        for i in range(m.start(), m.end()):
            if out[i] != "\n":
                out[i] = " "
    return "".join(out)


def inline_spans(text):
    import re
    masked = list(mask_code(text))
    blocks = list(re.finditer(r"(?ms)^\$\$\n.*?\n\$\$$", "".join(masked)))
    keep = list(masked)
    for m in blocks:
        for i in range(m.start(), m.end()):
            if keep[i] != "\n":
                keep[i] = " "
    keep = "".join(keep)
    return [(m.start(1), m.end(1), text[m.start(1):m.end(1)])
            for m in re.finditer(r"(?<!\$)\$([^$\n]{1,300})\$(?!\$)", keep)], len(blocks)


def fix_table_pipes(text: str) -> str:
    """GFM splits a table cell on every unescaped pipe, so an inline absolute value
    such as |c_k| would break the row. Replace those with &#124;.

    A pipe is a cell delimiter only at the row edges or when surrounded by spaces
    (how these tables are written); anything else is content."""
    out = []
    for line in text.split("\n"):
        st = line.strip()
        if not (st.startswith("|") and st.endswith("|")):
            out.append(line)
            continue
        if re.fullmatch(r"\|[\s:|-]+\|", st) and "---" in st:
            out.append(st)          # separator row: never touch
            continue
        cells = [c.strip().replace("|", "&#124;")
                 for c in re.split(r"(?<=\s)\|(?=\s)", st[1:-1])]
        out.append("| " + " | ".join(cells) + " |")
    return "\n".join(out)


def main():
    for name, table in POSTS:
        p = BLOG / name
        text = p.read_text(encoding="utf-8")
        spans, nblock = inline_spans(text)
        missing = sorted({t for _, _, t in spans if t not in table})
        if missing:
            raise SystemExit(f"{name}: no mapping for {missing}")
        out = text
        for s, e, tex in sorted(spans, key=lambda x: -x[0]):
            out = out[:s - 1] + table[tex] + out[e + 1:]
        out = fix_table_pipes(out)
        p.write_text(out, encoding="utf-8")
        print(f"{name}: replaced {len(spans)} inline formulas "
              f"({len({t for _, _, t in spans})} unique), block equations kept: {nblock}")


if __name__ == "__main__":
    main()
