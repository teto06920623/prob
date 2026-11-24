import 'package:flutter/material.dart';
import '../hypothesis_test/hypothesis_screen.dart';
import '../mean_ci/mean_ci_screen.dart';
import '../probability_sampling/probability_sampling_screen.dart';
import '../proportion_ci/proportion_ci_screen.dart';
import '../tables_explorer/stat_tables_sheet.dart';
import '../variance_ci/variance_ci_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    MeanCiScreen(),
    VarianceCiScreen(),
    ProportionCiScreen(),
    HypothesisScreen(),
    ProbabilitySamplingScreen(),
  ];

  void _openTablesExplorer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const StatTablesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HUE Statistics & CI Visualizer'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _openTablesExplorer,
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('Tables'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.functions),
                  label: Text('Mean (μ)'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.show_chart),
                  label: Text('Variance (σ²)'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.pie_chart_outline),
                  label: Text('Proportion (P)'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.rule),
                  label: Text('Hypothesis'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  label: Text('Prob & F'),
                ),
              ],
            ),
          if (isDesktop) const VerticalDivider(width: 1),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.functions),
                  label: 'Mean',
                ),
                NavigationDestination(
                  icon: Icon(Icons.show_chart),
                  label: 'Variance',
                ),
                NavigationDestination(
                  icon: Icon(Icons.pie_chart_outline),
                  label: 'Prob',
                ),
                NavigationDestination(icon: Icon(Icons.rule), label: 'Hypo'),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  label: 'Prob/F',
                ),
              ],
            ),
    );
  }
}

class ResponsiveCalcLayout extends StatelessWidget {
  final Widget inputSection;
  final Widget resultAndChartSection;

  const ResponsiveCalcLayout({
    super.key,
    required this.inputSection,
    required this.resultAndChartSection,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 960) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: inputSection),
            const SizedBox(width: 20),
            Expanded(flex: 6, child: resultAndChartSection),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        inputSection,
        const SizedBox(height: 16),
        resultAndChartSection,
      ],
    );
  }
}
