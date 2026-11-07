import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/commute/commute_days_screen.dart';
import '../features/commute/commute_expense_screen.dart';
import '../features/commute/commute_route_screen.dart';
import '../features/commute/commute_screen.dart';
import '../features/mileage/mileage_edit_screen.dart';
import '../features/mileage/mileage_list_screen.dart';
import '../features/mileage/vehicle_edit_screen.dart';
import '../features/mileage/vehicles_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/overview/overview_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/glossary_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/trips/trip_detail_screen.dart';
import '../features/trips/trip_edit_screen.dart';
import '../features/trips/trips_list_screen.dart';
import '../l10n/app_localizations.dart';

/// [onboarded] is null while the profile loads, then whether the user has
/// gone through the welcome pages. Until they have, every location leads to
/// `/welcome`.
GoRouter buildRouter({ValueListenable<bool?>? onboarded}) => GoRouter(
      initialLocation: '/overview',
      refreshListenable: onboarded,
      redirect: (context, state) {
        final done = onboarded?.value;
        if (done == null) return null;
        final atWelcome = state.matchedLocation == '/welcome';
        if (!done && !atWelcome) return '/welcome';
        if (done && atWelcome) return '/overview';
        return null;
      },
      routes: [
        GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _HomeShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) => const OverviewScreen(),
                // Settings open from the overview's app bar, keeping the tab
                // bar to the four travel sections.
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(path: 'glossary', builder: (context, state) => const GlossaryScreen()),
                      GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
                    ],
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/trips',
                builder: (context, state) => const TripsListScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const TripEditScreen()),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => TripDetailScreen(tripId: int.parse(state.pathParameters['id']!)),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => TripEditScreen(tripId: int.parse(state.pathParameters['id']!)),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/mileage',
                builder: (context, state) => const MileageListScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const MileageEditScreen()),
                  GoRoute(
                    path: 'entry/:id',
                    builder: (context, state) => MileageEditScreen(entryId: int.parse(state.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'vehicles',
                    builder: (context, state) => const VehiclesScreen(),
                    routes: [
                      GoRoute(path: 'new', builder: (context, state) => const VehicleEditScreen()),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) =>
                            VehicleEditScreen(vehicleId: int.parse(state.pathParameters['id']!)),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/commute',
                builder: (context, state) => const CommuteScreen(),
                routes: [
                  GoRoute(
                    path: 'days',
                    // ?month=YYYY-MM opens a given month.
                    builder: (context, state) {
                      final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(state.uri.queryParameters['month'] ?? '');
                      return CommuteDaysScreen(
                        initialMonth: m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!)),
                      );
                    },
                  ),
                  GoRoute(path: 'route/new', builder: (context, state) => const CommuteRouteScreen()),
                  GoRoute(
                    path: 'route/:id',
                    builder: (context, state) => CommuteRouteScreen(routeId: int.parse(state.pathParameters['id']!)),
                  ),
                  GoRoute(path: 'cost/new', builder: (context, state) => const CommuteExpenseScreen()),
                  GoRoute(
                    path: 'cost/:id',
                    builder: (context, state) => CommuteExpenseScreen(expenseId: int.parse(state.pathParameters['id']!)),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
    );

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      // Tab labels must stay on one line: a label that wraps makes its tab
      // taller and pushes its icon out of line with the others. Short labels
      // plus a cap on the system text size keep all four on one line.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: l.navOverview),
            NavigationDestination(
                icon: const Icon(Icons.luggage_outlined), selectedIcon: const Icon(Icons.luggage), label: l.navTrips),
            NavigationDestination(
                icon: const Icon(Icons.directions_car_outlined),
                selectedIcon: const Icon(Icons.directions_car),
                label: l.tabMileage),
            NavigationDestination(
                icon: const Icon(Icons.commute_outlined), selectedIcon: const Icon(Icons.commute), label: l.navCommute),
          ],
        ),
      ),
    );
  }
}
