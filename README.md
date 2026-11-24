# HUE Statistics & CI Visualizer

[![Live Web App](https://img.shields.io/badge/Live_Demo-math.tetomohamad.me-0D9488?style=for-the-badge&logo=googlechrome&logoColor=white)](https://math.tetomohamad.me)
[![GitHub Release](https://img.shields.io/github/v/release/teto06920623/prob?style=for-the-badge&color=1E3A8A&logo=github)](https://github.com/teto06920623/prob/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Web-38BDF8?style=for-the-badge)](#downloads--live-demo)

An interactive cross-platform statistical analysis and probability visualization application built with **Flutter**, designed for the **Probability & Statistics** curriculum at the **Faculty of Artificial Intelligence, Horus University in Egypt (HUE)**.

Instead of relying on hardcoded static lookup tables, the application implements a custom **numerical probability engine** in pure Dart from scratch, paired with real-time `CustomPainter` distribution curves and step-by-step mathematical derivations.

---

## Downloads & Live Demo

* **Web Application (Live):** [https://math.tetomohamad.me](https://math.tetomohamad.me)
* **All Releases:** [GitHub Releases Page](https://github.com/teto06920623/prob/releases)
  * **Android:** `HUE-Statistics-Android.apk`
  * **Windows Desktop (Installer):** `HUE-Statistics-Setup.exe`
  * **Web Bundle:** `HUE-Statistics-Web.zip`

---

## Core Modules & Mathematical Coverage

### 1. Population Mean ($\mu$) & Sample Size ($n$)
* Supports three input modes: **Summary Statistics** ($\bar{X}, \sigma/s, n$), **Raw Data Lists**, and **Summations** ($\Sigma x, \Sigma x^2$).
* Automatically selects between **Standard Normal ($Z$)** and **Student's $t$** distributions based on $\sigma$ availability and sample size ($n \ge 30$).
* Includes a **Required Sample Size ($n$)** calculator for a target margin of error $e$:
  $$n = \left\lceil \left(\frac{Z_{\alpha/2} \cdot \sigma}{e}\right)^2 \right\rceil$$

### 2. Variance ($\sigma^2$) & Standard Deviation ($\sigma$)
* Computes asymmetric confidence intervals using the **Chi-Square ($\chi^2$)** distribution from either raw sample values or summary statistics.
* Supports the large-sample normal approximation for $df > 30$:
  $$\chi^2 \approx \frac{1}{2}\left(Z + \sqrt{2v - 1}\right)^2$$

### 3. Population Proportion ($P$) & Sample Size ($n$)
* Computes confidence intervals from success counts ($X, n$) or sample proportions ($\hat{P}, n$), plus minimum sample size estimation for a specified margin of error.

### 4. Hypothesis Testing ($\mu$)
* Supports **Left-Tailed** ($H_1: \mu < \mu_0$), **Right-Tailed** ($H_1: \mu > \mu_0$), and **Two-Tailed** ($H_1: \mu \neq \mu_0$) tests using $Z$ or $t$ statistics with summary or raw data inputs.
* Evaluates decisions simultaneously across three statistical approaches:
  1. **Classical Critical Value Method**
  2. **P-Value Method** ($P\text{-value} \le \alpha$)
  3. **Confidence Interval Equivalence Method**

### 5. Probabilities, Sampling Distributions & Fisher's $F$
* **Normal Distribution:** Computes $P(X < a)$, $P(X > a)$, $P(a < X < b)$, and inverse quantiles $k$ for a given tail probability.
* **Sampling Distributions:** Models $\bar{X}$, $\hat{P}$ (with automatic $nP \ge 5$ and $n(1-P) \ge 5$ normal approximation validation), and $s^2$.
* **Fisher's $F(d_1, d_2)$:** Computes upper and lower critical values using the reciprocal property $F_{1-\alpha}(d_1, d_2) = \frac{1}{F_{\alpha}(d_2, d_1)}$.

### 6. Interactive Statistical Tables Explorer
* Built-in modal sheet providing instant critical-value lookup and reference grids for **$Z$**, **$t$**, **$\chi^2$**, and **$F$** distributions.

---

## Key Engineering Highlights

* **Zero-Dependency Numerical Math Engine:** Implements error functions ($\text{erf}$), regularized incomplete Beta and Gamma functions, and numerical root-finding solvers in pure Dart.
* **Dynamic `CustomPainter` Charts:** Renders smooth probability density curves with shaded acceptance/confidence and critical rejection regions, plus a live scale toggle between standardized scores ($Z/T$) and actual problem values ($\text{LCL}, \bar{X}, \text{UCL}$).
* **Step-by-Step Solution Cards:** Expandable derivation panels showing symbolic formulas, numerical substitutions, and final conclusions for every calculation.
* **Built-in Lecture Presets:** One-click presets loaded with solved examples and exercises from Lectures 1 through 6.
* **Adaptive Material 3 UI:** Automatically adapts to system Light/Dark themes and switches between `NavigationRail` on desktop/web and `NavigationBar` on mobile viewports.
* **Automated CI/CD Pipeline:** GitHub Actions workflow (`release_and_deploy.yml`) builds Android APKs, packages a single Windows installer via Inno Setup, deploys the web build to GitHub Pages, and publishes multi-platform releases automatically.

---

## Project Architecture

```text
├── .github/workflows/
│   └── release_and_deploy.yml         # Multi-platform CI/CD (Android, Windows, Web)
└── lib/
    ├── main.dart
    ├── core/
    │   ├── math/
    │   │   ├── normal_dist.dart       # Standard Normal PDF, CDF & inverse Z solver
    │   │   ├── student_t_dist.dart    # Student-t PDF, tail probability & critical t
    │   │   ├── chi_square_dist.dart   # Chi-Square PDF, critical values & df>30 approx
    │   │   └── fisher_f_dist.dart     # Fisher-F PDF, CDF & reciprocal critical F
    │   ├── models/
    │   │   └── ci_result.dart         # Unified statistical result & steps model
    │   └── theme/
    │       └── app_theme.dart         # Material 3 Light & Dark theme definitions
    └── features/
        ├── navigation/
        │   └── app_shell.dart         # Responsive NavigationRail / NavigationBar shell
        ├── chart_visualizer/
        │   ├── distribution_painter.dart       # CustomPainter curve & region renderer
        │   ├── distribution_chart_widget.dart  # Interactive chart card & scale toggle
        │   └── step_by_step_card.dart          # Expandable mathematical steps UI
        ├── mean_ci/
        │   └── mean_ci_screen.dart             # Mean CI & Sample Size (n)
        ├── variance_ci/
        │   └── variance_ci_screen.dart         # Variance & Std Dev CI
        ├── proportion_ci/
        │   └── proportion_ci_screen.dart       # Proportion CI & Sample Size (n)
        ├── hypothesis_test/
        │   └── hypothesis_screen.dart          # Hypothesis testing (Critical, P-val, CI)
        ├── probability_sampling/
        │   └── probability_sampling_screen.dart # Normal, Sampling & Fisher-F module
        └── tables_explorer/
            └── stat_tables_sheet.dart          # Interactive Z, t, χ², F tables sheet
