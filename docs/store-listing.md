# Store listing

Texts for Google Play, the App Store and app catalogues such as F-Droid and IzzyOnDroid, in Swedish (primary) and English. Keep them true and in line with the app, the website and the privacy policy: no payment or tip wording, no "official" wording, and the long-stay limitation stays in the description until it is supported ([tax-rules.md](tax-rules.md#not-supported-yet)).

## Google Play, F-Droid and IzzyOnDroid

The texts live in [`fastlane/metadata/android/`](../fastlane/metadata/android/), one folder per language (`sv-SE`, `en-US`), in the layout that F-Droid, IzzyOnDroid and Google Play's upload tool (fastlane supply) read:

| File | Limit |
| --- | --- |
| `title.txt` | 30 characters (`Trakta`) |
| `short_description.txt` | 80 characters |
| `full_description.txt` | 4 000 characters (also the App Store description) |
| `changelogs/<build number>.txt` | 500 characters, one per release (`2.txt` is 1.1.0+2) |
| `images/icon.png` | 512 × 512 |
| `images/phoneScreenshots/` | written by `flutter test test_screenshots --update-goldens` in `apps/trakta_app` |

Category: Finance. Contains ads: no.

## App Store (when the iPhone version ships)

The App Store uses the same full description. Its extra fields:

| Field | Limit |
| --- | --- |
| Subtitle | 30 characters |
| Promotional text (can change without a review) | 170 characters |
| Keywords (comma separated, not shown) | 100 characters |

### Svenska

**Undertitel**

```text
Traktamente och reseavdrag
```

**Reklamtext**

```text
Håll koll på traktamente, tjänstekörning och reseavdrag under året och se vad som ska in i deklarationen. Gratis, offline och dina data stannar i telefonen.
```

**Nyckelord**

```text
traktamente,milersättning,reseavdrag,körjournal,deklaration,tjänsteresa,utlandstraktamente,avdrag
```

### English

**Subtitle**

```text
Swedish travel deductions
```

**Promotional text**

```text
Track per diem, business driving and commuting through the year and see what goes in your Swedish tax return. Free, offline, and your data stays on your phone.
```

**Keywords**

```text
per diem,mileage,driving log,commuting,tax return,sweden,business trip,deduction,traktamente
```
