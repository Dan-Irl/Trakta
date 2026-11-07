# Trakta design

Calm, precise and trustworthy: a Scandinavian fintech look for Swedish professionals checking their *traktamente* and *milersättning*. Clear numbers, few colours, restrained depth.

## Colours

Ten colours. Everything else is derived from them.

| Token | Hex | Use |
|---|---|---|
| `primary` | `#1D58A7` | Buttons, links, focus, selection |
| `navy` | `#0F2942` | Text, headings, totals, summary header, selected chips |
| `muted` | `#64748B` | Secondary text, hints, units (SEK, km) |
| `background` | `#F8FAFC` | Screen background |
| `surface` | `#FFFFFF` | Cards, inputs, sheets, dialogs, nav bar |
| `subtle` | `#F1F5F9` | Table rows, disabled fields, pressed states |
| `border` | `#E2E8F0` | Card outlines, input borders, dividers |
| `positive` | `#047857` | Deductions, tax-free amounts, "done" states |
| `warning` | `#B45309` | Needs input, in progress, check this |
| `error` | `#BA1A1A` | Errors, delete |

- **Tinted backgrounds** (badges, banners) use the colour at 12 % opacity with the full colour as text.
- **Dark mode** is derived in code from `primary`; it is not specified here.

## Typography

The platform system font: Roboto on Android, SF Pro on iOS. Only size and weight are specified. All numbers use tabular figures so amounts line up, except the single Hero number.

| Style | Size / line height | Weight | Use |
|---|---|---|---|
| Hero | 44 / 52 | Bold | The one number a screen leads with (the overview's yearly total). Proportional figures |
| Stat | 28 / 34 | Bold | Big totals |
| Headline | 20 / 28 | Semibold | Screen, sheet and trip titles |
| Title | 16 / 24 | Semibold | Card titles, amounts in lists |
| Subtitle | 14 / 20 | Semibold | Section headers |
| Body large | 16 / 24 | Regular | Form input text |
| Body | 14 / 20 | Regular | Default text |
| Small | 12 / 16 | Regular | Captions, rule explanations |
| Label | 14 / 20 | Medium | Buttons, chips |

## Spacing and shape

- **Spacing:** 8 px grid: 4, 8, 16, 24, 32. Screen margin, card padding and the gap between form fields are 16. Lists under a floating button end with 96 of padding.
- **Radius:** 8 for buttons, inputs and badges. 16 for cards, sheets and dialogs. Full (pill) for chips.
- **Depth:** flat. Cards are `surface` with a 1 px `border` and no shadow.

## Components

- **Primary button:** `primary` fill, white text, 48 high. Turns `navy` when pressed.
- **Secondary button:** `border` outline, `navy` text, 48 high.
- **Input:** `surface` fill, 1 px `border`, 2 px `primary` when focused. Units use `muted`.
- **Chip:** pill. Unselected: `surface` with `border`. Selected: `navy` fill, white text.
- **Country field:** looks like an input: flag, name, dropdown arrow. Opens a bottom sheet with a search field and one row per country (flag, name, amount per day, ISO code). Sweden first, "other countries" last.
- **Card:** `surface`, 16 radius, `border` outline, 16 padding.
- **Status text:** `positive`, `warning` or `error`. Never use colour alone; keep the words.
- **Banner:** a card tinted with the status colour at 12 %, text in that colour. Neutral notes use `subtle` with normal text.
- **Deduction amounts** (Box 2.2, business deduction) are `positive`; other totals stay `navy`.
- **Stat tile:** a small label in `muted` over a value in Title. Used in a row of two or three inside a card.
- **Navigation:** four tabs: Overview, Trips, Driving log (Körjournal), Commuting (Reseavdrag). Settings open from a gear in the Overview's app bar. Tab labels are short and the bar caps text scaling at 1.15, so every label stays on one line: a wrapped label makes its tab taller and throws the icons out of line. Screen titles can be longer ("Business driving").
- **Documents:** a list of files (icon by type, name, size, remove button), help text and an "Add document" button. Tapping a file opens it in the phone's own viewer.
- **Overview:** the first screen. One card leads with the year's expected deduction as the Hero number in `positive`. The next card, "Your tax return", has one row per box (2.2, 2.1, 1.2) with the amount to enter and a line on what it contains; only boxes with an amount are shown, and box 1.2 (income) is not `positive`. Then one card with a line per section (trips, business driving, commuting) that opens the section. No charts.
- **Commuting calendar:** a month grid, Monday first, 8 radius cells. Commuted: `positive` at 20 %. Planned (ahead): thin `positive` outline. Day off: `warning` at 16 %. Business trip: `primary` at 14 %. Holiday: `subtle` with `muted` text. Today: 2 px `primary` ring. Selected while dragging: `primary` fill, white text. A legend names every colour. The compact version tops the Commuting tab and opens the full one.
- **Today buttons:** a row of four equal buttons (icon over label) on `subtle`; the current answer is `primary` with a tick.
- **Onboarding:** three pages on first launch (what Trakta does, not tax advice, offline and your data), page dots, and a checkbox the user must tick before "Get started". The same text is under Settings → About.

## In code

| Design | Flutter |
|---|---|
| Colours, radii, spacing | `apps/trakta_app/lib/app/tokens.dart` (`Palette`, `Radii`, `Space`) |
| `positive`, `warning` | `TraktaColors.of(context)` |
| Everything else | `Theme.of(context)`: `primary`, `secondary` (navy), `onSurfaceVariant` (muted), `surface` (background), `outline` (border), `error` |
| Components and type | `apps/trakta_app/lib/app/theme.dart` |
| App icon | `design/app_icon.png` (full-bleed), `app_icon_adaptive.png` (Android safe zone), `app_icon_source.png` (original) |

Rules:

- Screens use stock Material widgets and let the theme style them. No hardcoded colours, font sizes or radii in screens.
- Read colours from the theme, not from `Palette`, so dark mode keeps working.
- New visual patterns go into this file first, then into `theme.dart`.
- No custom fonts and never `google_fonts`: it downloads at runtime, and the app is offline-only.
- After changing an icon master, run `dart run flutter_launcher_icons` in `apps/trakta_app`, then revert its change to `ios/Runner.xcodeproj/project.pbxproj` (a known bug in the tool).
