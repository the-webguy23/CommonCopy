# CommonCopy website

This folder contains the static CommonCopy download website. It has no package manager, build step, cookies, analytics, external fonts, or runtime dependencies.

## Preview locally

Open `dist/index.html` in a browser. All pages and navigation work directly from the filesystem.

## Add release downloads

After creating the Windows release files under `artifacts/release`, run this from the repository root in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\website\scripts\sync-release.ps1
```

The script copies these files into `dist/downloads`:

- `CommonCopy-Setup-x64.exe`
- `CommonCopy-Portable-x64.zip`
- `SHA256SUMS.txt`

## Current continuation (2026-10-16)

The existing three-page site is retained, with a compact-menu example, Windows/macOS copy, and explicit coming-soon
release controls. macOS core workflows and automatic dismissal after Save passed
maintainer testing; the new compact Windows menu still needs device acceptance.
No private test binaries are exposed by this website.

Advertising is approved for the website only. A third-party ad-space reseller is
planned but has not been selected or connected. Do not add an advertising script
until its integration and privacy information are prepared. The desktop app stays
ad-free. The interactive example uses temporary browser memory only.

Static hosting preview uses a Sites source snapshot of this folder. Keep the
repository's `website/` folder as the project source, and synchronize changes
before deployment. No public launch, domain purchase, paid provider enrollment,
or application release is implied by publishing the owner-private preview.

## Before public launch

- Verify public source availability before enabling repository links.
- Confirm both platform versions and release notes; enable download links only for approved public binaries.
- Select and integrate the website ad reseller, keeping ads clearly separate from download controls.
- Update privacy information and any required choices before advertising is enabled.
- Test every download from the deployed site.
- Add privacy-conscious aggregate analytics only after a separate review.

Public launch is deferred pending approved installers and compatibility testing. An owner-private website preview may be deployed for review.

## Approved design revision (2026-10-16)

The maintainer requested a simpler modular direction, referencing
https://openai.com/open-models/ and ChatGPT navigation: white and black, thin
black rules, filled and outlined buttons, restrained typography and fewer
competing controls. This supersedes the previous copper/cream website styling.
Website first; desktop utility redesign follows after website review. No desktop
source is modified by this website revision.

The three existing pages remain. The interactive example now dismisses its
menu after insertion or saving and has an explicit reopen control. Public
downloads stay disabled and advertising remains website-only and unconnected.

Validation includes JavaScript syntax, local links/assets/fragments, unique IDs,
labels/control targets, monochrome colors, and balanced stylesheet blocks. Automated
browser rendering/interaction QA is unavailable in the current environment;
responsive layout and real browser interaction remain review items.

## Approved refinements and logo (2026-10-16)

Maintainer approved the monochrome modular layout and interactive demo. Bounded
refinements invert the full 02 / How it works module and the Mac download card,
while keeping the Windows card light. FAQ title: "Common questions. Clear answers."
Demo categories now insert realistic reusable GPT instructions, an image prompt,
valid JavaScript/CSS snippets, and everyday replies/sign-offs. Reset retains every
built-in prompt and removes only phrases saved during the demo.

Approved logo is the solid upper C with dotted lower copy. Original Library file:
CommonCopy_Approved_Logo.png, libfile_77b400cffbd8819196af1d1555c73dcf. It is copied
unchanged as dist/commoncopy-approved-logo.png (Git blob
43f93281b2e033e8d264758461c9d84a3e8843a7), used in the header/footer on all pages
and as the browser icon. No regeneration, tracing, cropping or recoloring.

Checks: JavaScript syntax, page links/IDs/control targets/labels, two original-logo
placements per page, a single inverted download card, exact FAQ title, and release
gating pass. Browser/mobile visual review remains unavailable in this environment.


## SVG logo kit integration (2026-10-16)

All three pages now use the exact production SVG contour master from
CommonCopy_Logo_Kit_v1.0 for their two header/footer marks. Existing navigation,
wordmark text, system typography and approved layout are retained. The SVG has
transparent surroundings; no white background tile is added. Primary and reverse
masters are preserved unchanged under dist/assets/brand.

All pages declare the kit's dedicated compact SVG favicon and multi-size ICO
fallback, Apple touch icon and web manifest with 192/512 icons. Versioned favicon
URLs distinguish them from the former raster tab icon. Icons are copied from the
kit, not produced by shrinking the detailed full mark. Body fonts remain native
system fonts, as the kit recommends for interfaces. No external font requests,
tracking, ads, public utility downloads or new publishing audience are introduced.

Validation: exact kit-byte comparisons, SVG vector-only structure, ICO dimensions,
manifest icon links, local page asset/fragment references and favicon declarations.
Browser visual QA is unavailable without the required browser-control capability.


## Help center (2026-10-16)

Help is linked from the header, footer, and download guidance. The guide covers both platforms, capture/paste, nested Prompts examples, troubleshooting and backups. Public downloads remain disabled; private-build security repairs are explicitly separated. Identical help sections ship offline with each utility and open from Settings.

Validated local asset/fragment links, headings, navigation, offline content parity and JavaScript syntax. Existing private audience is preserved. Native utility builds and on-device Help launch review are tracked on their respective draft branches.


## Homepage help tabs — 2026-10-17

All six Help topics now appear directly beneath the homepage download cards. The responsive module shows one panel at a time, with black selected tabs, thin borders, arrow/Home/End/Enter/Space controls, ARIA relationships and direct topic links. Header/footer Help links target the homepage module. Existing help.html remains available; all original guide content and disabled public download buttons are preserved. Without JavaScript, anchor links and full content remain accessible.

Validation: HTML asset/fragment links and unique IDs, exact guide-content parity, tab selection and keyboard/focus/hash behavior, JavaScript syntax and whitespace checks passed. Browser visual QA was unavailable. Private preview source: 72847b11254ceb72cf61382cfce07e9602301586.


## Direct sponsorship program — 2026-10-17


Replaces the planned ad-reseller model with Supporter, Development Sponsor and Founding Sponsor tiers. Founding recognition is permanent; prominent logo/link placement lasts 30 days from going live, optionally renewable for another 30-day term subject to availability. Early-access invitations depend on preview availability; no dates or custom work are promised. Pricing, terms, enquiry contact, payments and signups remain pending rather than invented. Footer links, homepage support strip/FAQ and privacy wording now reflect sponsorship. Sponsor recognition remains website-only, with no access to local phrase or clipboard data.
