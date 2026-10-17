# La Casa Bella Resort & Events Place — Website Concept

A seven-page concept website by **Lendez Studio** for La Casa Bella Resort & Events Place,
Guimbal, Iloilo. Design direction: **Modern Tropical Luxury**.

> Concept status: not launched. Pages carry `noindex`, the inquiry form is a preview that
> sends and stores nothing, and no contact channel is labelled official until the business
> confirms it.

## Structure

```
src/
  layout.html            Shared shell: <head>, header, mobile menu, footer
  pages/*.html           Page bodies (front-matter comment sets title, path, meta)
  assets/css/styles.css  Design system + all components
  assets/js/main.js      Menu, reveals, parallax, gallery filter + lightbox, form preview
  assets/img/            Optimised photography (generated), wordmarks and icons
  data/images.csv        Photo asset map: source id, slug, gallery categories, alt text
  data/images.json       Generated manifest (sizes, widths) used by the build
tools/
  optimize-images.ps1    Resizes photos (480/960/1600/2048w), builds logo + icons + OG image
  Imaging.cs             Image helpers used by the optimiser
  build.ps1              Assembles pages into docs/ and checks every internal link
  serve.ps1              Local preview server
docs/                    Generated, publishable site (do not edit by hand)
Initial Images/          Source photography supplied for the project
```

No Node.js or Python is required. Everything runs on Windows PowerShell 5.1.

## Commands

```powershell
# 1. (Only when photos or the logo change) regenerate web images
powershell -ExecutionPolicy Bypass -File tools\optimize-images.ps1

# 2. Build the site into docs\
powershell -ExecutionPolicy Bypass -File tools\build.ps1

# 3. Preview at http://localhost:4317/
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

Pages link to folder URLs (`/staycations/`), so preview through the server rather than
opening files directly.

## Writing pages

* Images: `<img data-img="slug" sizes="...">` expands to `src`, `srcset`, `width`, `height`,
  alt text (from `images.csv`), `loading="lazy"` and `decoding="async"`. Add
  `loading="eager" fetchpriority="high"` for hero images.
  `<source data-srcset="slug" media="...">` handles art-directed mobile crops.
* `{{root}}` is the relative path to the site root; `{{arrow}}` inserts the arrow icon.
* `{{gallery}}` renders every photo that has categories in `images.csv`, in CSV order.
* Contact-channel blocks are wrapped in `<!--if:channels-->` / `<!--if:no-channels-->`.

## Publishing official contact channels (after owner confirmation)

Edit the `$Channels` block at the top of `tools\build.ps1`, set `Confirmed = $true`, fill in
only the confirmed values, and rebuild. The contact page then shows the channel list and the
authenticity notice ("please use the official contact details linked on this website").

## Deploying to GitHub Pages

Repository: https://github.com/lendezstudio/La-Casa-Bella
Pages URL (once enabled): https://lendezstudio.github.io/La-Casa-Bella/ — `$SiteUrl` and
`$BasePath` in `tools\build.ps1` are already set for this address.

The internal briefing PDFs and the original photos/logo are git-ignored and stay local;
keep them to re-run `tools\optimize-images.ps1`.

1. Create a repository and push this folder.
2. Settings → Pages → Source: *Deploy from a branch* → Branch `main`, folder `/docs`.
3. In `tools\build.ps1` set:
   * `$SiteUrl` to the final address (enables canonical URLs, absolute Open Graph images and
     `sitemap.xml`),
   * `$BasePath` to `'/<repo-name>/'` for a project site, or `'/'` for a custom domain,
   * `$ConceptMode = $false` when the business approves public indexing.
4. Rebuild and push `docs/`.

`docs/.nojekyll` is included so GitHub serves the files as-is, and `docs/404.html` handles
unknown URLs.
