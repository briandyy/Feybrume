# Typography and icons

Phase 2 implements native font selection and fallback by role. It creates Roblox Font values and can apply them to labels, buttons and editable text. A valid Font value does not establish permission or glyph coverage. Feybrume has verified rendering for **0** of the target **1,000** font families, and has audited three upstream samples. Roblox documents more than 80 Creator Store fonts. [Theme font API](design-system.md) · [Roblox assets](https://create.roblox.com/docs/projects/assets) · [Font](https://create.roblox.com/docs/reference/engine/datatypes/Font) · [Enum.Font](https://create.roblox.com/docs/reference/engine/enums/Font)

| Backend | Target | Contract |
|---|---|---|
| NativeFontFace | TextLabel, TextButton, TextBox | Resolve a family or asset ID with Roblox Font APIs. Use native text for editable fields, engine layout and RichText where supported. |
| VerifiedGlyphAtlas | Display text and optional previews | Planned raster pages, script-specific shaping, caches and pooled sprites. Switch to native text for editing, selectable text and missing glyphs. |
| RegisteredCustomFontResolver | Developer-provided fonts | Planned registry allows valid native references, schema-checked atlases or a verified renderer adapter. A raw TTF/OTF URL requires an import pipeline. |

The full font API is planned to expose provenance, coverage, fallback and availability, with bounded preload, atomic registration, filtering, comparisons and eviction of unused entries. Typography roles cover headings, body, caption, controls, table, code, navigation and auth. Respect backend-specific tracking, wrapping and strokes. Virtualize the browser, load visible previews first, pin active entries and bound memory. Surface fallbacks and coverage for emoji and CJK instead of assuming a font covers them.

## License audit

Google Fonts includes metadata and notices per family. The samples reference a pinned revision. Weight, style and variable axes count as one family. Reuse notices with distributed font software and review Reserved Font Names for modified distributions. [Google Fonts revision](https://github.com/google/fonts/commit/7af0d90b4d532ffa4b041937b560c6df4e7b1e95) · [Metadata format](https://github.com/googlefonts/googlefonts.github.io/blob/main/gf-guide/metadata.md) · [SIL OFL FAQ](https://openfontlicense.org/ofl-faq/)

| Family | Evidence | Audit point |
|---|---|---|
| Archivo | [Metadata](https://github.com/google/fonts/blob/main/ofl/archivo/METADATA.pb) · [OFL](https://github.com/google/fonts/blob/main/ofl/archivo/OFL.txt) | Regular and italic variable styles count as one family. |
| Open Sans | [Metadata](https://github.com/google/fonts/blob/main/ofl/opensans/METADATA.pb) · [OFL](https://github.com/google/fonts/blob/main/ofl/opensans/OFL.txt) | Count it once across native and atlas backends. |
| Share | [Metadata](https://github.com/google/fonts/blob/main/ofl/share/METADATA.pb) · [OFL](https://github.com/google/fonts/blob/main/ofl/share/OFL.txt) | The source notice has a Reserved Font Name. |

An ordinary rendered image differs from a reusable atlas with glyph and layout data. For reusable packs, record source and derivative provenance, license and notice, any Reserved Font Name changes, and Roblox moderation and distribution status. Use native references without copying protected font files.

1. Pin metadata, OpenType fonts and notices. Reject missing or conflicting entries.
2. Normalize families with NFKC, case folding and reviewed aliases. Collapse variants and duplicate backends. Record hashes and use outline samples to spot collisions.
3. Pilot ten families with Basic Latin and declared English and Indonesian samples. Use pinned FreeType and HarfBuzz for rasterization and shaping. Record metrics, kerning, fallback and missing glyphs.
4. Pack inspected images with asset ownership, licenses and hashes. Submit assets for moderation and grant access to a published test place. Record denied or pending access.
5. Capture a render sample and lookup for each family on every target profile. Save the Studio or client version, manifest hash, timing, memory, fallback code and evidence ID. A fallback render does not count for the requested family.
6. Expand from 10 to 100 to 1,000 only when the pipeline works. Publish the measured count. A 50 KiB page per family would transfer about 49 MiB for 1,000 families. A decoded 512×512 RGBA page takes 1 MiB before overhead.

Each manifest entry records the family ID, name and category, native or atlas reference, license URL and notice hash, asset owner, permission status, source and version, Unicode coverage, supported weights and styles, preview, memory estimate, fallback, availability and render evidence. Publish versioned and hashed packs, with the baseline catalog available offline.

## Icons

Candidate packs include Lucide, Material, Solar, Phosphor, Heroicons and original or owner-approved artwork. Check pack licenses and ownership. Count distinct verified glyphs and omit aliases from the count. Use permissioned sprites and preserve a text label when an icon is unavailable. The target is at least 2,500 verified glyphs. The current verified count is **0**. Raw SVG and remote URLs require an importer or compatible adapter. [Lucide license](https://lucide.dev/license) · [Heroicons](https://github.com/tailwindlabs/heroicons) · [Phosphor](https://github.com/phosphor-icons/core)
