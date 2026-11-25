import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

plt.rcParams["mathtext.fontset"] = "cm"
plt.rcParams["font.family"] = "serif"

OUT = "blog/assets/formulas/"

def render(name, tex, fontsize=19):
    fig = plt.figure(figsize=(0.01, 0.01))
    fig.text(0, 0, tex, fontsize=fontsize, color="#1f2328")
    fig.savefig(OUT + name + ".png", dpi=300, transparent=True,
                bbox_inches="tight", pad_inches=0.07)
    plt.close(fig)
    print("ok", name)

# ---------------- 第一篇 ----------------
render("f01_target",
       r"$\mathbf{X}\;\approx\;\sum_{k=1}^{K}\mathbf{V}^{(k)},\qquad V_{gj}^{(k)}=w_{g}\,h_{j}^{(k)}$")

render("f02_nmf",
       r"$\min_{\mathbf{W},\mathbf{H}\geq 0}\;\;\frac{1}{2}\left\|\mathbf{A}-\mathbf{W}\mathbf{H}\right\|_{F}^{2}$")

render("f03_dnmf",
       r"$J=\frac{1}{2}\left\|\mathbf{A}-\mathbf{W}\mathbf{H}\right\|_{F}^{2}"
       r"+\frac{\lambda_{W}}{2}\,\mathrm{tr}\!\left(\mathbf{W}^{\top}\mathbf{S}_{w}\mathbf{W}\right)"
       r"-\frac{\lambda_{B}}{2}\,\mathrm{tr}\!\left(\mathbf{W}^{\top}\mathbf{S}_{b}\mathbf{W}\right)$",
       fontsize=18)

render("f04_update_w",
       r"$\mathbf{W}\leftarrow\mathbf{W}\odot"
       r"\frac{\mathbf{A}\mathbf{H}^{\top}+\lambda_{W}\mathbf{W}\mathbf{S}_{w}^{-}+\lambda_{B}\mathbf{W}\mathbf{S}_{b}^{+}+\epsilon}"
       r"{\mathbf{W}\mathbf{H}\mathbf{H}^{\top}+\lambda_{W}\mathbf{W}\mathbf{S}_{w}^{+}+\lambda_{B}\mathbf{W}\mathbf{S}_{b}^{-}+\epsilon}$",
       fontsize=15)

render("f05_update_h",
       r"$\mathbf{H}\leftarrow\mathbf{H}\odot"
       r"\frac{\mathbf{W}^{\top}\mathbf{A}+\epsilon}{\mathbf{W}^{\top}\mathbf{W}\mathbf{H}+\epsilon}$",
       fontsize=17)

render("f06_weight",
       r"$w_{g}\;\leftarrow\;\frac{\mathbf{A}_{g}\cdot\mathbf{h}_{s}}{\mathbf{h}_{s}\cdot\mathbf{h}_{s}}"
       r"\qquad g\in\mathcal{G}_{s}$")

render("f07_activity",
       r"$\mathbf{h}_{s}\;\leftarrow\;"
       r"\frac{\sum_{g\in\mathcal{M}_{s}}w_{g}\,\mathbf{A}_{g}}{\sum_{g\in\mathcal{M}_{s}}w_{g}^{2}}$")

render("f08_mixing",
       r"$y=(1-r)\,x+\frac{r}{m-1}\left(\sum_{i=1}^{m}x_{i}-x\right)$")

render("f09_unmix",
       r"$x=\bar{y}+\frac{y-\bar{y}}{1-r},\qquad \bar{y}=\frac{1}{m}\sum_{i=1}^{m}y_{i}$")

render("f10_rescale",
       r"$\tilde{V}_{gj}^{(k)}=V_{gj}^{(k)}\cdot s_{j},\qquad "
       r"s_{j}=\frac{\sum_{g}X_{gj}}{\sum_{k}\sum_{g}V_{gj}^{(k)}}$")

# ---------------- 第二篇 ----------------
render("g01_contribution",
       r"$\hat{S}_{pj}=\sum_{k}a_{k}(j)\,S_{pj}^{(k)}$")

render("g02_specificity",
       r"$H=-\sum_{k=1}^{K}p_{k}\log_{2}p_{k},\qquad \mathrm{spec}=1-\frac{H}{\log_{2}K}$")
print("all done")
