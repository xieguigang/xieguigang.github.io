"""Write formulas/README.md from the crop manifest (sizes and equation list)."""
import json
import pathlib

ROOT = pathlib.Path(r"G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures/blog")
WORK = ROOT / "_fx"


def one_line(tex, n=72):
    t = " ".join(tex.split())
    return t if len(t) <= n else t[: n - 1] + "\u2026"


def main():
    data = json.loads((WORK / "cropped.json").read_text(encoding="utf-8"))
    b1 = data["blog1"]["entries"]
    b2 = data["blog2"]["entries"]
    eqs = [e for e in b1 if e["kind"] == "block"]
    widths = [e["px_w"] / 3 for e in eqs]

    L = []
    L.append("# 块级公式图片（透明底 PNG）\n")
    L.append("两篇博客的**块级公式**（`$$…$$`）已渲染成透明背景的 PNG；**行内公式**不再用图片，")
    L.append("而是直接改写成 HTML 的 `<i>` / `<sub>` / `<sup>`（见 `blog/*.md`）。\n")
    L.append("## 一、目录结构\n")
    L.append("```text")
    L.append("formulas/")
    L.append("├── blog1/                     # 上篇《从 GSVA 到 moGSVA》")
    L.append(f"│   └── eq01..eq{len(eqs):02d}.png       # 块级公式，{len(eqs)} 张")
    L.append("├── blog2/                     # 下篇《同一批肿瘤，四种组学》")
    L.append("│                                # 下篇没有块级公式，故为空目录")
    L.append("└── README.md")
    L.append("```\n")
    L.append("> 编号按公式在文中出现的顺序，与 `blog1_gsva_principles.md` 里的顺序一致。\n")

    L.append("## 二、规格\n")
    L.append("| 项目 | 说明 |")
    L.append("|---|---|")
    L.append("| 背景 | 全透明（alpha=0），字色 `#1d232b`，四周留 2 px 透明空气 |")
    L.append("| 分辨率 | 17 px 正文字号渲染，3× 输出后按墨迹裁剪，等效 300% 缩放 |")
    L.append(f"| 尺寸 | 宽 {min(widths):.0f}–{max(widths):.0f} CSS px |")
    L.append("| 字体 | MathJax TeX（与原文公式排版一致） |\n")

    L.append("## 三、公式清单（上篇）\n")
    L.append("```text")
    for e in eqs:
        name = e["file"].split("/")[-1]
        L.append(f"{name:10s} {e['px_w'] // 3:4d}x{e['px_h'] // 3:<3d}px  {one_line(e['tex'])}")
    L.append("```\n")

    L.append("## 四、怎么用\n")
    L.append("`*.md` 与 `*.images.md` 的差别只有块级公式这一处：\n")
    L.append("| 文件 | 块级公式 | 行内公式 | 适用场景 |")
    L.append("|---|---|---|---|")
    L.append("| `blog1_gsva_principles.md` | `$$…$$` LaTeX | HTML `<i>/<sub>/<sup>` | 编辑器支持 MathJax |")
    L.append("| `blog1_gsva_principles.images.md` | PNG 图片 | HTML `<i>/<sub>/<sup>` | 博客站不支持公式 |")
    L.append("| `blog2_mogsva_vs_single_omics.md` | 无 | HTML `<i>/<sub>/<sup>` | 两种情况都可用 |\n")
    L.append("块级公式的写法（居中、限宽、窄屏自适应）：\n")
    L.append("```html")
    L.append('<p align="center"><img src="formulas/blog1/eq06.png" width="393" height="57"')
    L.append('     style="max-width:100%;height:auto" alt="b_k 与 w_k"></p>')
    L.append("```\n")
    L.append("> 平台不允许 HTML 时，可退化为纯 Markdown `![](formulas/blog1/eq06.png)`：")
    L.append("> 图本身不变，但会左对齐、失去宽度控制。\n")

    L.append("## 五、重新生成\n")
    L.append("```bash")
    L.append("# 1) 提取块级公式 → 无头 Chrome 渲染 → 读回包围盒")
    L.append("python tools/make_formulas.py")
    L.append("")
    L.append("# 2) 从整页透明截图裁图、去掉多余透明边（R）")
    L.append('"C:/Program Files/R/R-4.5.0/bin/Rscript.exe" --vanilla tools/crop_formulas.R')
    L.append("")
    L.append("# 3) 生成发布版与清单")
    L.append("python tools/md_blocks_to_png.py")
    L.append("python tools/make_formula_readme.py")
    L.append("")
    L.append("# 若改了正文里的行内公式，先跑这一步（LaTeX → HTML）")
    L.append("python tools/inline_math_to_html.py")
    L.append("```\n")
    L.append("中间产物（整页截图、包围盒 JSON）写在 `blog/_fx/`，可随时删除。\n")
    L.append("> 环境提示：R 必须用 `C:/Program Files/R/R-4.5.0/bin/Rscript.exe --vanilla`，")
    L.append("> PATH 上的 `Rscript` 是 GCModeller 的 R# 运行时，会去找 `Z:\\tmp\\1` 而失败。")

    (ROOT / "formulas" / "README.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    print("written formulas/README.md")


if __name__ == "__main__":
    main()
