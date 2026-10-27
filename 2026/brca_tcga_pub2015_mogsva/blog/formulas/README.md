# 块级公式图片（透明底 PNG）

两篇博客的**块级公式**（`$$…$$`）已渲染成透明背景的 PNG；**行内公式**不再用图片，
而是直接改写成 HTML 的 `<i>` / `<sub>` / `<sup>`（见 `blog/*.md`）。

## 一、目录结构

```text
formulas/
├── blog1/                     # 上篇《从 GSVA 到 moGSVA》
│   └── eq01..eq10.png       # 块级公式，10 张
├── blog2/                     # 下篇《同一批肿瘤，四种组学》
│                                # 下篇没有块级公式，故为空目录
└── README.md
```

> 编号按公式在文中出现的顺序，与 `blog1_gsva_principles.md` 里的顺序一致。

## 二、规格

| 项目 | 说明 |
|---|---|
| 背景 | 全透明（alpha=0），字色 `#1d232b`，四周留 2 px 透明空气 |
| 分辨率 | 17 px 正文字号渲染，3× 输出后按墨迹裁剪，等效 300% 缩放 |
| 尺寸 | 宽 125–682 CSS px |
| 字体 | MathJax TeX（与原文公式排版一致） |

## 三、公式清单（上篇）

```text
eq01.png    288x61 px  \hat{F}_i(x) \;=\; \frac{1}{N h}\sum_{m=1}^{N}\Phi\!\left(\frac{x-x_{im…
eq02.png    124x30 px  z_{ij} \;=\; \hat{F}_i(x_{ij})
eq03.png    485x105px  \mathrm{ES}^{(S)}_{j} \;=\; \max_{r}\left[\; \sum_{\substack{i\in S\\ \…
eq04.png    490x29 px  X \in \mathbb{R}^{(N_1+N_2+\cdots+N_K)\times M},\qquad \text{feature} =…
eq05.png    681x68 px  \hat{F}_{i}^{(k)}(x)=\frac{1}{M h_k}\sum_{m=1}^{M}\Phi\!\left(\frac{x-x…
eq06.png    394x57 px  b_k=\frac{1}{\log_2\!\left(2+|S_k|\right)}, \qquad w_k=\frac{b_k}{\sum_…
eq07.png    261x54 px  \mathrm{ES}_{\text{raw}}^{(S)}(j)=\sum_{k\in K(S)} w_k\,\mathrm{ES}^{(S…
eq08.png    558x56 px  a_j=\frac{2}{K(K-1)}\sum_{k \lt k'}\operatorname{sign}\!\left(\mathrm{E…
eq09.png    388x50 px  \mathrm{ES}_{\text{multi}}^{(S)}(j) =\mathrm{ES}_{\text{raw}}^{(S)}(j)\…
eq10.png    486x55 px  T_S=\max_{j}\left|\mathrm{ES}^{(S)}_{\text{multi}}(j)\right|, \qquad p_…
```

## 四、怎么用

`*.md` 与 `*.images.md` 的差别只有块级公式这一处：

| 文件 | 块级公式 | 行内公式 | 适用场景 |
|---|---|---|---|
| `blog1_gsva_principles.md` | `$$…$$` LaTeX | HTML `<i>/<sub>/<sup>` | 编辑器支持 MathJax |
| `blog1_gsva_principles.images.md` | PNG 图片 | HTML `<i>/<sub>/<sup>` | 博客站不支持公式 |
| `blog2_mogsva_vs_single_omics.md` | 无 | HTML `<i>/<sub>/<sup>` | 两种情况都可用 |

块级公式的写法（居中、限宽、窄屏自适应）：

```html
<p align="center"><img src="formulas/blog1/eq06.png" width="393" height="57"
     style="max-width:100%;height:auto" alt="b_k 与 w_k"></p>
```

> 平台不允许 HTML 时，可退化为纯 Markdown `![](formulas/blog1/eq06.png)`：
> 图本身不变，但会左对齐、失去宽度控制。

## 五、重新生成

```bash
# 1) 提取块级公式 → 无头 Chrome 渲染 → 读回包围盒
python tools/make_formulas.py

# 2) 从整页透明截图裁图、去掉多余透明边（R）
"C:/Program Files/R/R-4.5.0/bin/Rscript.exe" --vanilla tools/crop_formulas.R

# 3) 生成发布版与清单
python tools/md_blocks_to_png.py
python tools/make_formula_readme.py

# 若改了正文里的行内公式，先跑这一步（LaTeX → HTML）
python tools/inline_math_to_html.py
```

中间产物（整页截图、包围盒 JSON）写在 `blog/_fx/`，可随时删除。

> 环境提示：R 必须用 `C:/Program Files/R/R-4.5.0/bin/Rscript.exe --vanilla`，
> PATH 上的 `Rscript` 是 GCModeller 的 R# 运行时，会去找 `Z:\tmp\1` 而失败。
