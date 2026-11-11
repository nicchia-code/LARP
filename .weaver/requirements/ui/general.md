---
description: Use when drawing anything of LARP on screen, to apply its visual language, colours, fonts, components, icons and the languages of its texts.
---
# Visual language

## General
- **One visual language everywhere**, taken literally from the designer's Style Guide: flat surfaces, dark ink surfaces for the sidebar, the popover, the proposal panel and the recording surfaces, light paper surfaces for the content, white cards, one lime accent. It replaces the standard look of macOS in every view of LARP; only the system alerts, save and open panels and context menus keep the system look.
- **Fixed palette**, the same whether the Mac is in light or dark appearance; every LARP surface sets its own appearance (light on paper and white, dark on ink) so that system controls inside it draw correctly:
  - ink `#121310`: dark surfaces and main text on light surfaces;
  - paper `#FAFAF5`: background of light pages; white `#FFFFFF`: cards, fields, outline buttons;
  - lime `#D4F24A`: primary buttons, the selected item of a sidebar, switches that are on, the highlight of the current transcript line on dark, highlighted words, status chips of calls that are done;
  - secondary text `#5A5D55` on light; muted text `#A3A69B` only on dark surfaces; light text on dark `#E9EAE3`;
  - borders `#E4E4DC` (cards, fields, dividers) and `#D0D1C8` (chips and outline buttons); neutral chip `#ECECE4`; light dividers on paper `#E9EAE3`;
  - raised dark surfaces `#1D1F1A`, `#23251F` (selected sidebar item), `#2A2C26` (cards on dark) and `#3A3C36` (borders and idle bars on dark);
  - switch off `#8A8D82`; recording red `#FF5A40`; destructive text `#B42A18`; current transcript line on light `#EEF8B4`.
- **Speaker colours**, the same wherever a speaker appears (avatar, dot before a line, waveform bar, playback timeline): "Io" is ink with a white initial on light surfaces and white with an ink initial on dark ones; participants by number 1 lime `#D4F24A`, 2 lilac `#CFC6FF`, 3 peach `#FFCFAE`, 4 sky `#9FD8FF`, then again from lime; "Altri" as a whole `#A3A69B`; participant colours always carry ink text.
- **Fonts**, bundled with the app: Inter for every text (13 px body, 12 px secondary, 11–10 px small; weights 400, 500 and 600); Bricolage Grotesque for display: page titles 44 px bold with −0.03 em tracking and line height 1, the title of a call page 56 px bold with −0.03 em, card titles 19 px semibold with −0.01 em, section and card headings 20–24 px semibold; JetBrains Mono 11 px medium, upper case, tracking 0.06–0.08 em, for the small eyebrow lines above titles and sections, and for times, durations, timestamps and keyboard shortcuts.
- **Components**:
  - buttons 40 px high, radius 10, 13 px text: primary lime with ink semibold text; dark ink with lime text; outline white with a `#D0D1C8` border; destructive outline with `#B42A18` text; text links underlined with an offset of 3 px;
  - chips 32 px high, radius 16, 12 px text: selected ink with lime text, otherwise transparent with a `#D0D1C8` border; status chips 24 px high, radius 12;
  - cards white, radius 18, 1 px `#E4E4DC` border, 18–24 px padding; cards on dark `#2A2C26` or `#1D1F1A`, radius 18;
  - search and text fields white, 40 px high, radius 20 (search) or 10 (fields), 1 px `#E4E4DC` border, with a magnifying glass for search;
  - switches 36 × 22 px, radius 11, with a 16 px knob: on, ink track and lime knob; off, `#8A8D82` track and white knob;
  - choices from a list are bordered white boxes, radius 8, with the current value and a chevron;
  - avatars round, 24 px, with a 2 px ring of the surface colour and the initial in 10 px semibold, overlapping by 6 px in a row;
  - eyebrow lines in JetBrains Mono as above, `#5A5D55` on light and `#A3A69B` on dark;
  - keyboard shortcuts as JetBrains Mono 11 px text, inside a small ink box with lime text on light surfaces;
  - waveforms as rounded bars 3–4 px wide with 2–3 px gaps, coloured by speaker, idle bars `#3A3C36` on dark.
- No translucency, material, blur or glass effect on LARP's own surfaces; no focus rings drawn by the system on custom controls, which show focus with a 2 px lime or ink outline instead.
- **Icons**: the LARP mark is a rounded square (radius 30 % of its side) with four vertical bars with round ends, on a 24-unit grid at x 6, 10, 14 and 18, from y 10 to 14, 6 to 18, 8 to 16 and 11 to 13, stroke 2.6. The app icon is the lime square with ink bars; the mark beside the "LARP" wordmark (Bricolage Grotesque 20 px bold) is the lime square with ink bars; the menu bar icon is a coloured image, an ink square with lime bars, the same with light or dark menu bar.
- Lime is never used as text on light surfaces, and `#A3A69B` never as text on light surfaces.
- Moving waveforms stop moving when the Mac asks to reduce motion.
- **Languages of the texts**: every text is in Italian when the language of the Mac (or the one chosen for LARP in System Settings) is Italian, and in English in every other case. The texts quoted in the Model and in the Requirements are the Italian ones; the English interface shows their translation. The designer's English placeholder copy is replaced by the real texts of LARP in the two languages.
