import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';

/// A Swedish tax term with a plain explanation in both app languages. The
/// term itself is never translated: it is what Skatteverket, employers and
/// the tax return use.
class GlossaryEntry {
  const GlossaryEntry(this.term, this.sv, this.en);
  final String term;
  final String sv;
  final String en;
}

const glossary = <GlossaryEntry>[
  GlossaryEntry('Traktamente', 'Ersättning för ökade levnadskostnader (mat och småutgifter) på tjänsteresa med övernattning.',
      'Per diem: an allowance for extra living costs (food and small expenses) on a business trip with an overnight stay.'),
  GlossaryEntry('Nattraktamente', 'Schablonersättning för logi när du inte har något kvitto och arbetsgivaren inte betalar logi.',
      'Night allowance: a standard amount for lodging when you have no receipt and your employer does not pay for lodging.'),
  GlossaryEntry('Schablonbelopp / maximibelopp', 'Skatteverkets fasta belopp som kan betalas ut skattefritt eller dras av.',
      "Skatteverket's fixed standard amounts that can be paid tax-free or deducted."),
  GlossaryEntry('Normalbelopp', 'Skatteverkets dagsbelopp per land för tjänsteresor utomlands.',
      "Skatteverket's daily amount per country for business trips abroad."),
  GlossaryEntry('Tjänsteresa', 'En resa som arbetsgivaren beordrat, för arbete på annan plats än den vanliga arbetsplatsen.',
      'Business trip: travel ordered by your employer to work somewhere other than your regular workplace.'),
  GlossaryEntry('Vanliga verksamhetsorten', 'Området inom 50 km från den vanliga arbetsplatsen och från bostaden.',
      'Your usual work area: within 50 km of your regular workplace and of your home.'),
  GlossaryEntry('Milersättning', 'Ersättning per mil (10 km) för resor i tjänsten med egen bil eller förmånsbil.',
      'Mileage allowance: an amount per mil (10 km) for business driving in your own car or a company car.'),
  GlossaryEntry('Körjournal', 'Löpande anteckningar om tjänsteresor med bil: datum, sträcka, ärende och vem du besökte.',
      'Driving log: ongoing notes of business drives: date, distance, purpose and who you visited.'),
  GlossaryEntry('Förmånsbil', 'Bil som arbetsgivaren ställer till ditt privata förfogande.', 'Company car you are also allowed to use privately.'),
  GlossaryEntry('Reseräkning', 'Underlag till arbetsgivaren för ersättning av resekostnader.',
      'Travel expense claim you give your employer to get reimbursed.'),
  GlossaryEntry('Ruta 1.2 – Kostnadsersättningar', 'Ruta i inkomstdeklarationen för skattepliktiga kostnadsersättningar.',
      'Box in the income tax return for taxable expense allowances.'),
  GlossaryEntry('Ruta 2.2 – Tjänsteresor', 'Ruta i inkomstdeklarationen där du drar av ökade levnadskostnader och bilkostnader för tjänsteresor.',
      'Box in the income tax return where you deduct extra living costs and car costs for business trips.'),
  GlossaryEntry('Enskild firma', 'Enskild näringsverksamhet. Du får inget traktamente men gör avdrag med samma schablonbelopp.',
      'Sole trader business. You get no per diem but deduct the same standard amounts in the business.'),
  GlossaryEntry('Skatteverket', 'Den svenska skattemyndigheten.', 'The Swedish Tax Agency.'),
];

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final swedish = l.localeName.startsWith('sv');
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.glossary)),
      body: ListView(
        children: [
          Padding(padding: const EdgeInsets.all(Space.md), child: Text(l.glossaryIntro)),
          for (final e in glossary)
            ListTile(
              title: Text(e.term, style: theme.textTheme.titleSmall),
              subtitle: Text(swedish ? e.sv : e.en),
            ),
        ],
      ),
    );
  }
}
