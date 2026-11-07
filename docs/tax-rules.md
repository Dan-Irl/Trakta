# Tax rules

These are the rules the engine in `packages/trakta_core` applies. Amounts are for income year 2026; every number comes from the rules pack, never from code. Skatteverket's own pages are the authority (see [Sources](#sources)); several third-party blogs publish wrong amounts.

## Per diem in Sweden (traktamente)

**Eligibility.** All three must be true, otherwise the whole trip gets 0 kr:

1. **Tjänsteresa:** the employer ordered the trip, to work somewhere other than the regular workplace.
2. **More than 50 km** from both the regular workplace and the home, by the nearest possible route (not the route actually taken).
3. **Overnight stay:** the trip covers 24:00–06:00 away from the usual work area. Night workers who sleep during the day qualify too.

Day trips never qualify. The app has no maps, so the user confirms checks 1 and 2.

**Amounts (maximibelopp).** 2026: full day 300 kr, half day 150 kr, night 150 kr (2025: 290 / 145 / 145). The maximum is 0.5 % of the prisbasbelopp rounded to 10 kr; the pack stores the resulting amounts.

**Full or half day.** Every day is assessed on its own:

| Day | Full day if | Otherwise |
| --- | --- | --- |
| Departure day | the trip starts before 12:00 | half day |
| Return day | the trip ends after 19:00 | half day |
| Days in between | always | — |

Example (SKV 354): Monday 08:00 to Friday 16:00 gives four full days and a half day.

**Nights.** One per night covering 24:00–06:00. Lodging per night: *standard* gives 150 kr (abroad: half the normalbelopp of the country where the night was spent), *receipt* gives the actual cost even if lower, *employer paid* or *none* gives 0 kr.

**Free meals** reduce the day's amount (after the half-day factor). Percentages per meal, stored per meal so the combinations are sums:

| Meals received | Sweden | Abroad |
| --- | --- | --- |
| Breakfast, lunch and dinner | 90 % | 85 % |
| Lunch and dinner | 70 % | 70 % |
| Lunch or dinner | 35 % | 35 % |
| Breakfast only | 20 % | 15 % |

The reduction is rounded half up to whole kronor (0.35 × 850 = 297.50 → 298). A meal counts when it was *paid* by the employer or *included in the hotel price*; it does not count when it was mandatorily *included in a public transport ticket* or an included hotel breakfast the user *could not use*. Representation meals reduce the allowance. Meal benefit (kostförmån) taxation is the employer's job.

Legal basis: Inkomstskattelagen (1999:1229) chapter 12 §§ 5–13 and 18–22, and Skatteverket's general advice SKV A 2025:5 (from income year 2026).

## Per diem abroad (utlandstraktamente)

- Each day's amount is the **normalbelopp** of the country where the user spent the most time between 06:00 and 24:00 local time. If Sweden wins, the domestic amount applies. Full day 1 ×, half day 0.5 ×, night 0.5 × normalbelopp.
- Time on a plane or ship between countries and refuelling stopovers counts for no country; ground transfers and waiting time do. A whole day 06:00–24:00 in international transit gets the domestic full day (300 kr).
- Ties are not addressed by Skatteverket: the app flags the day and the user picks the country.
- A country missing from the list uses the fallback "Övriga länder och områden" (470 kr in 2026). Redirect rows ("Se Danmark") are resolved when the pack is built.
- Today the user picks a country for the whole trip and can change it per day; deriving it from a timeline of border crossings is planned.

Sample 2026 values used in tests: Denmark 1 226, Finland 968, France 850, Germany 760, Norway 1 054, Switzerland 1 332, United Kingdom 901, USA 1 049 kr.

## Business driving (milersättning)

| Vehicle | Business trip | Commuting |
| --- | --- | --- |
| Own car (incl. electric and hybrid; also borrowed, rented, leased, or a spouse's company car) | 25 kr/mil | 25 kr/mil |
| Company car (förmånsbil), not fully electric | 12 kr/mil | 12 kr/mil |
| Company car, fully electric | 9.50 kr/mil | 9.50 kr/mil |
| Motorcycle, mopedbil / moped | not listed | 12.50 / 6 kr/mil |
| Bicycle | — | 350 kr per year |

- **Company car:** the standard amount applies only if the user paid all the fuel. **Plug-in hybrid** company cars still qualify with employer charging at the workplace for drives from 2026-07-01 (the engine uses the drive date, not just the year).
- **Körjournal:** date, odometer start/end or distance, from/to, purpose and who was visited, vehicle. Logs kept continuously carry more weight than ones reconstructed afterwards. Congestion tax and tolls on business drives are deductible at actual cost.
- **Car allowance:** if the employer paid a car allowance (bilersättning) for the drives, the received amount is tax-free up to the standard and **no deduction** can be claimed for the rest (Avdragslexikon T).

## What the employer paid

| Situation | Result | Tax return |
| --- | --- | --- |
| Per diem equal to the standard | Nothing to do | — |
| Per diem above the standard | The excess is taxable salary (employer's job) | — |
| Per diem below the standard | Received amount as income, full standard amount as deduction | Box 1.2 and box 2.2 |
| No per diem | Standard amounts as deduction | Box 2.2 |
| No car allowance | Standard amount per mil as deduction | Box 2.2 |

Box 2.2 has no threshold. Box 2.4 (other work expenses, above 5 000 kr) is not used. A sole trader (enskild firma) deducts the same standard amounts in the business, so the app labels this as "deduction basis", not reseräkning. An aktiebolag owner is an employee of the company and follows the employee rules.

## Commuting (reseavdrag, box 2.1)

- Commuting between home and the regular workplace is never a business trip.
- Only costs above the threshold are deductible: 11 000 kr (2025), 15 000 kr (2026). The user enters the full amount; Skatteverket subtracts the threshold.
- By car: at least 5 km by the shortest route and at least 2 hours saved per day compared with public transport. Public transport: at least 2 km, actual ticket cost.
- Only days actually commuted count. The app uses the weekly schedule minus Swedish public holidays (plus Midsommarafton, Julafton and Nyårsafton), days entirely away on business trips and days marked off.
- Congestion tax and road, bridge and ferry fees count when the car trips are deductible.
- Parking is normally not deductible. It is after regular business driving with the same car: at least 300 mil over at least 60 days gives parking on those days; over at least 160 days, parking on all commuting days (`commute.parking` in the pack).

## Not supported yet

- **Long stays.** After more than three months at the same place (ort) the tax-free full day drops to 70 % (30 % as your own deduction without an allowance, no half days), and to 50 % after two years. Trakta does not apply this yet; the store listing and the website FAQ say so.
- Dubbel bosättning (double residence), GPS logging, public transport and bicycle commuting.

## Open questions

Resolve these or show them as warnings before release:

1. Do the motorcycle and moped standard amounts apply to business trips, or only to commuting? Skatteverket's business-trip page lists only cars, so the app offers only cars.
2. Is breakfast + lunch a 55 % domestic reduction (sum of the parts)? Skatteverket does not list that combination.
3. How is an odd half normalbelopp rounded (USA 1 049 / 2 = 524.50)? The engine keeps öre precision.

## Records

Users must be able to show their records if Skatteverket asks: commonly 6 years after the income year for individuals, 7 years for sole traders (Bokföringslagen). The app never deletes old trips automatically.

## Sources

| Source | Used for |
| --- | --- |
| [Traktamente](https://www.skatteverket.se/privat/skatter/arbeteochinkomst/traktamente.4.dfe345a107ebcc9baf80006547.html) | Domestic amounts, day types, meal reductions, examples |
| [Utlandstraktamenten](https://www.skatteverket.se/utlandstraktamente) | Normalbelopp per country, fallback, redirect rows |
| [Specifikation Ersättningar för reseräkning v1.4](https://skatteverket.entryscape.net/store/9/resource/2430) | Definitions, meal percentages, country rule, own car definition |
| [Avdragslexikon T](https://www.skatteverket.se/privat/skatter/arbeteochinkomst/avdragforprivatpersoner/t.4.5fc8c94513259a4ba1d800042933.html) | Box 1.2 / 2.2, mileage deduction, car allowance, plug-in hybrids, congestion tax |
| [Avdrag för resor till och från arbetet](https://www.skatteverket.se/privat/skatter/bilochtrafik/avdragforresortillochfranarbetet.4.3810a01c150939e893f25603.html) | Commuting threshold, rates, distance and time rules |
| [Help text 2.1](https://www8.skatteverket.se/hjalptexter/EfInk1b_avdtj.html) | Commuting fees |
| [Avdragslexikon, Parkeringskostnad](https://www.skatteverket.se/privat/skatter/arbeteochinkomst/avdragforprivatpersoner/np.4.5fc8c94513259a4ba1d800042822.html) | Parking with business driving |
| [SKV A 2025:5](https://www4.skatteverket.se/rattsligvagledning/466868.html) | General advice on increased living costs from 2026 |
| [Allmänna råd om normalbelopp 2026](https://www4.skatteverket.se/rattsligvagledning/467383.html?date=2025-12-15) | Legal basis for 2026 foreign amounts |
| [SKV 354](https://www.skatteverket.se/privat/etjansterochblanketter/blanketterbroschyrer/broschyrer/info/354.4.39f16f103821c58f680007497.html) | Worked examples |
| [Traktamente, utland (dataset)](https://skatteverket.entryscape.net/store/9/metadata/680) | Open data API for normalbelopp |
