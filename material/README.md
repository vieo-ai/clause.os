# `material` — MkDocs Customization, Templates & Plugins

> **Subsystem Role:** Custom Theme Assets, Layout Templates & Documentation Build Plugins

The `material` directory contains custom overrides, MkDocs Material theme templates, custom CSS/JS assets, and documentation extension plugins used by `mkdocs.yml` when building the static site into `site/`.

---

## Directory Function

* **Theme Overrides:** Holds custom Jinja2 template overrides (e.g., `main.html`, header/footer tweaks) for the MkDocs Material theme.
* **Custom Assets:** Houses custom stylesheets (`extra.css`), JavaScript hooks (`extra.js`), and typography/branding styles.
* **Build Plugins & Extensions:** Contains custom Python plugins or Markdown extensions tailored for rendering ClauseOS architecture specifications and diagrams.

---

## Structure

```text
material/
├── assets/         # Custom stylesheets, scripts, and fonts
├── overrides/      # Theme template overrides (.html files)
└── plugins/        # Custom MkDocs build hooks and plugins
```

---

## Usage in `mkdocs.yml`

```yaml
theme:
  name: material
  custom_dir: material/overrides

extra_css:
  - material/assets/extra.css

extra_javascript:
  - material/assets/extra.js
```