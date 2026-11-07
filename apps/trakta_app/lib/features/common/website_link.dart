import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

/// Pages on trakta.app that the app links to, in Swedish and English. The app
/// only ever opens trakta.app (AGENTS.md, Offline); the site redirects
/// /kallkod and /source to the code on GitHub.
enum WebsitePage {
  home('', ''),
  source('/kallkod', '/source'),
  download('/ladda-ner/', '/en/download/');

  const WebsitePage(this.sv, this.en);

  final String sv;
  final String en;

  Uri uri(Locale locale) => Uri.parse('$websiteUrl${locale.languageCode == 'en' ? en : sv}');
}

/// Opens a page on trakta.app in the phone's browser, or says where to find it.
Future<void> openWebsite(BuildContext context, WidgetRef ref, [WebsitePage page = WebsitePage.home]) async {
  final l = AppLocalizations.of(context);
  final uri = page.uri(Localizations.localeOf(context));
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref.read(openLinkProvider)(uri);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.websiteFailed)));
}
