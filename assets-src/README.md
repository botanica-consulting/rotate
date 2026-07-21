# Asset sources

## site-areas/

Mounting-area overlay shapes, one SVG per site region, organized as
`<bodytype>/{front,rear}/<region>.svg`. Each file contains a single closed
path drawn in the same viewBox as the matching body silhouette in
`InsulinPumpSiteJournal/Assets.xcassets`.

`scripts/generate_site_areas.py` compiles these into
`InsulinPumpSiteJournal/Models/SiteAreaCatalog.swift` (run it with no
arguments to use this directory). Naming convention: file names are
mirror-consistent with the front view — "left" sits on the viewer's right in
BOTH views — while the rear silhouettes use standard posterior anatomy, so
the generator swaps left/right when mapping rear file names to site IDs.

## Provenance

The silhouettes and area shapes are original line art created for this
project (2026-07, drawn against Omnipod placement-zone descriptions in
Insulet's public placement guide). They are not copied from Insulet, Loop,
or any third-party artwork. The app icon is rendered by
`scripts/render_app_icon.swift` — also original vector drawing code.
