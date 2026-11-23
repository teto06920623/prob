import 'package:flutter/material.dart';
import '../mean_ci/mean_ci_screen.dart';
import '../variance_ci/variance_ci_screen.dart';
import '../proportion_ci/proportion_ci_screen.dart';
import '../hypothesis_test/hypothesis_screen.dart';

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
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(icon: Icon(Icons.functions), label: 'Mean (μ)'),
    NavigationDestination(icon: Icon(Icons.ssid_chart), label: 'Variance (σ²)'),
    NavigationDestination(
      icon: Icon(Icons.pie_chart_outline),
      label: 'Proportion (P)',
    ),
    NavigationDestination(icon: Icon(Icons.rule), label: 'Hypothesis'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        return Scaffold(
          appBar: AppBar(
            title: const Text('HUE Statistics & CI Visualizer'),
            centerTitle: !isDesktop,
          ),
          body: Row(
            children: [
              if (isDesktop)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  extended: constraints.maxWidth >= 1050,
                  onDestinationSelected: (idx) =>
                      setState(() => _selectedIndex = idx),
                  destinations: _destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: d.icon,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
              if (isDesktop) const VerticalDivider(width: 1),
              Expanded(child: _screens[_selectedIndex]),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) =>
                      setState(() => _selectedIndex = idx),
                  destinations: _destinations,
                ),
        );
      },
    );
  }
}

/// Widget موحد لتوزيع المدخلات والنتائج حسب حجم الشاشة (موبايل vs ديسكتوب/متصفح)
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 850) {
          // وضع الويندوز والمتصفح العريض: المدخلات يسار والنتائج والرسمة يمين
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: inputSection,
                ),
              ),
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: resultAndChartSection,
                ),
              ),
            ],
          );
        }

        // وضع الأندرويد والشاشات الضيقة: عناصر رأسية متتالية
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              inputSection,
              const SizedBox(height: 16),
              resultAndChartSection,
            ],
          ),
        );
      },
    );
  }
}
