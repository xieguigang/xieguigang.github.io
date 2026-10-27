# 两篇博客：GSVA 原理 与 moGSVA 实证对照

面向高校研究生的算法科普：伪代码 + 数学公式 + 图文并茂 + 轻松诙谐。
两篇都用真实数据（TCGA-BRCA，460 例）出图，不是凭空画的示意图。

| 文件 | 内容 | 规模 |
|---|---|---|
| `blog1_gsva_principles.md` | GSVA 三步数学原理（KDE → 分位数 → 随机游走）+ moGSVA 五步 + 三个实现坑 + **`mogsva.R` 逐行解读** + **结果目录十张表的读法** | 约 1.7 万字，3 张图、9 个代码块、5 张表、10 条块级公式 |
| `blog2_mogsva_vs_single_omics.md` | 数据集与乳腺癌背景 + 单层 vs 合并 vs 池化 vs 融合的四路对照 + 网络拓扑 + 生物学机制解读 + 优劣势 | 约 1.3 万字，6 张图、5 张表 |

## 一、公式的三种写法

博客站不一定能跑 MathJax，所以公式分两层处理，正文有多个版本：

| 文件 | 块级公式 `$$…$$` | 行内公式 `$…$` | 用在哪 |
|---|---|---|---|
| `blog1_gsva_principles.md` / `blog2_…md` | 保留 LaTeX | **改写成 HTML** `<i>/<sub>/<sup>` | 编辑器支持 MathJax；或站点只认 HTML |
| `blog1_gsva_principles.images.md` | 换成透明底 PNG | 同上（HTML） | 站点完全不能跑公式 |
| `blog1_gsva_principles.html` | MathJax 现场排版 | HTML | 直接双击打开、或当网页发布 |

行内公式统一用 HTML 标记，例如 `$x_{im}$` → `<i>x</i><sub><i>im</i></sub>`、
`$10^{-16}$` → `10<sup>−16</sup>`、`$\lambda=0.25$` → `<i>λ</i> = 0.25`；
分数改成 `(1 + <i>λa</i><sub><i>j</i></sub>) / (1 + <i>λ</i>)` 这种行内写法。
映射是显式的、逐条写在 `tools/inline_math_to_html.py` 里，脚本遇到没登记的公式会直接报错。

块级公式的透明底 PNG 在 `formulas/`，规格与清单见 `formulas/README.md`。

## 二、目录

```
blog/
├── blog1_gsva_principles.md / .images.md / .html     # 上篇三种形态
├── blog2_mogsva_vs_single_omics.md / .images.md / .html
├── figures/                       # 正文插图（3 张教学图 + 6 张结果图网页版）
├── formulas/                      # 块级公式透明底 PNG + 清单
├── tools/                         # 出图与构建流水线（6 个脚本）
└── vendor/mathjax-tex-svg.js      # 本地 MathJax（离线可渲染）
```

## 三、常用命令

```bash
cd blog

# 1) 改了正文里的行内公式 → LaTeX 转 HTML（幂等：无 $ 时不动）
python tools/inline_math_to_html.py

# 2) 块级公式 → 透明底 PNG
python tools/make_formulas.py
"C:/Program Files/R/R-4.5.0/bin/Rscript.exe" --vanilla tools/crop_formulas.R
python tools/md_blocks_to_png.py        # 生成 *.images.md
python tools/make_formula_readme.py     # 更新 formulas/README.md

# 3) Markdown → 网页版
python tools/build_html.py
```

> R 必须用绝对路径的 `Rscript.exe`：PATH 上的 `Rscript` 是 GCModeller 的 R# 运行时，
> 会去找 `Z:\tmp\1` 而失败。

## 四、网页版说明

`tools/build_html.py` 直接从 `.md` 生成 HTML（Markdown 是唯一真源，没有模板了）：

* 标题、导语、日期取自文件头的 YAML；正文首个 `#` 标题就是大标题，不会重复。
* 二级/三级标题自动加 GFM 风格的 `id`，所以目录里的跳转链接可用。
* 小于 250 KB 的图片内嵌成 data URI；大图（`figures/web_Figure*.png`）保持相对路径，
  把 `figures/` 一起带着即可，避免单页几 MB。
* 公式由 `vendor/mathjax-tex-svg.js` 排版，缺失时自动回退 jsDelivr CDN。

## 五、正文数字的来源

| 结论 | 复算方式 |
|---|---|
| 通路数、覆盖度、权重 | `stats_for_legends.R` |
| 重算一致性矩阵、融合恒等式、p 值网格 | `evaluate_results.R` → `output/evaluation_report.md` |
| 与"逐层合并"的对照（ρ=0.994、ER 173 vs 185） | `compare_naive_merge.R` |
| 网络拓扑、模块 ARI、hub 重叠 | `00b_network.R` + `fig9/fig10` 脚本 |
| 上篇 §10 的手算核对（−0.0587 → −0.0430） | 直接查 `brca_tcga_pub2015_mogsva/` 下的 CSV |
| 图注里引用的每个数值 | `figure_legends.md`（Fig 1–10） |

## 六、写作约定

* 面向研究生：先讲"为什么需要"，再给公式，最后给伪代码；公式后立刻用一句大白话翻译。
* 语气轻松但结论克制：第二篇明确写出"融合不提升单变量检出""更偏向蛋白层"这类不利结论。
* 每个数字都标口径（多少条通路、哪个检验、是否校正）。
