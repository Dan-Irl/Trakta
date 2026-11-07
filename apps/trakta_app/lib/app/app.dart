import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

/// Resolves the app language: the user's choice in settings, otherwise the
/// device language when it is English, otherwise Swedish.
Locale resolveAppLocale(String? chosen, Locale? device) {
  if (chosen == 'sv' || chosen == 'en') return Locale(chosen!);
  return device?.languageCode == 'en' ? const Locale('en') : const Locale('sv');
}

class TraktaApp extends ConsumerStatefulWidget {
  const TraktaApp({super.key, this.router});

  /// Injected in tests.
  final GoRouter? router;

  @override
  ConsumerState<TraktaApp> createState() => _TraktaAppState();
}

class _TraktaAppState extends ConsumerState<TraktaApp> {
  /// Whether the welcome pages are done; null until the profile has loaded.
  final _onboarded = ValueNotifier<bool?>(null);
  late final GoRouter _router = widget.router ?? buildRouter(onboarded: _onboarded);

  @override
  void initState() {
    super.initState();
    ref.listenManual(profileProvider, (_, next) {
      if (next.hasValue) _onboarded.value = next.requireValue.onboardingDone;
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _onboarded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final chosen = profile.hasValue ? profile.requireValue.localeCode : null;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: _router,
      // A chosen language wins; otherwise follow the device (English devices
      // get English, everything else Swedish).
      locale: chosen == null ? null : resolveAppLocale(chosen, null),
      localeResolutionCallback: (device, supported) => resolveAppLocale(null, device),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
