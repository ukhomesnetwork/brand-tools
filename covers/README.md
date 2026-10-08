# Gatha social covers

Facebook, LinkedIn and YouTube channel images in the Gatha look: navy `#000321` background, purple ambient light, a neon pink floorplan in the margins (the same style as gatha.uk and the Leeds 2026 backdrop), Poppins, and the backdrop line "Property has a new home." with a pink full stop.

## Ready to upload (`exports/`)

| File | Where it goes |
|---|---|
| `gatha-facebook-cover-1640x624.png` | Gatha Facebook page cover |
| `gatha-linkedin-company-cover-1128x191.png` (and `@2x` 2256x382) | LinkedIn company page cover |
| `gatha-linkedin-personal-banner-1584x396.png` (and `@2x` 3168x792) | Personal LinkedIn background, e.g. Chris or David |
| `gatha-youtube-banner-2560x1440.png` | YouTube channel banner (one file covers TV, desktop, tablet and mobile) |
| `gatha-youtube-icon-800x800.png` | YouTube channel profile picture (shown as a circle) |
| `gatha-youtube-watermark-150x150.png` | YouTube video watermark (transparent background) |

The copy is chosen to stay accurate after launch, so there is no launch date on the covers.

## Safe zones

`exports/previews/` shows each cover with the areas that get covered or cropped:

- **Facebook:** on mobile, about 133px is cropped from each side (at 820px width), and on desktop the profile photo sits over the bottom-left corner. All text stays inside the mobile crop.
- **LinkedIn company:** the page logo covers the bottom-left corner, and only artwork sits under it.
- **LinkedIn personal:** the profile photo covers the bottom-left, so the text sits on the right.
- **YouTube banner:** TVs show the full 2560x1440. Desktop shows a 2560x423 strip across the middle, tablets the middle 1855x423, and phones only the centre 1546x423. All text sits inside that centre area, and the floorplan fills the rest on wider screens.

## Editing

Everything comes from `cover.html` (the copy is near the top of the script). To regenerate the PNGs:

```
node render.mjs            # writes exports/
node render.mjs --guides   # writes exports/previews/ with safe-zone overlays
```

You need Node and Playwright. The fonts and logo SVGs are in `assets/`, so rendering works offline.
