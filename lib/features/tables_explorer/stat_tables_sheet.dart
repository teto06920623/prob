import 'package:flutter/material.dart';
import '../../core/math/chi_square_dist.dart';
import '../../core/math/fisher_f_dist.dart';
import '../../core/math/normal_dist.dart';
import '../../core/math/student_t_dist.dart';

class StatTablesSheet extends StatefulWidget {
  const StatTablesSheet({super.key});

  @override
  State<StatTablesSheet> createState() => _StatTablesSheetState();
}

class _StatTablesSheetState extends State<StatTablesSheet> {
  int _tabIndex = 0; // 0: Z, 1: T, 2: Chi-Square, 3: Fisher F
  final _df1Ctrl = TextEditingController(text: '12');
  final _df2Ctrl = TextEditingController(text: '10');
  final _alphaCtrl = TextEditingController(text: '0.025');

  @override
  void dispose() {
    _df1Ctrl.dispose();
    _df2Ctrl.dispose();
    _alphaCtrl.dispose();
    super.dispose();
  }

  String _computeQuickLookup() {
    try {
      final alpha = double.parse(_alphaCtrl.text.trim());
      if (alpha <= 0 || alpha >= 1) return 'α must be between 0 and 1';
      final df1 = int.tryParse(_df1Ctrl.text.trim()) ?? 10;
      final df2 = int.tryParse(_df2Ctrl.text.trim()) ?? 10;

      switch (_tabIndex) {
        case 0:
          final z = NormalDist.criticalZ(alpha);
          return 'Z_($alpha) = ${z.toStringAsFixed(4)}   |   Two-Tailed ±${NormalDist.criticalZ(alpha / 2).toStringAsFixed(4)}';
        case 1:
          final t = StudentTDist.criticalT(alpha, df1.clamp(1, 500));
          return 't_($alpha, df=$df1) = ${t.toStringAsFixed(4)}';
        case 2:
          final cRight = ChiSquareDist.criticalChiSquare(
            alpha,
            df1.clamp(1, 500),
          );
          final cLeft = ChiSquareDist.criticalChiSquare(
            1.0 - alpha,
            df1.clamp(1, 500),
          );
          return 'χ²_($alpha, $df1) = ${cRight.toStringAsFixed(3)}   |   χ²_(${(1 - alpha).toStringAsFixed(3)}, $df1) = ${cLeft.toStringAsFixed(3)}';
        default:
          final f = FisherFDist.criticalF(
            alpha,
            df1.clamp(1, 200),
            df2.clamp(1, 200),
          );
          return 'F_($alpha, d₁=$df1, d₂=$df2) = ${f.toStringAsFixed(4)}';
      }
    } catch (_) {
      return 'Enter valid numeric parameters';
    }
  }

  @override
  Widget build(BuildContext context) {
    final alphas = [0.10, 0.05, 0.025, 0.01, 0.005];
    final dfs = [1, 2, 3, 4, 5, 8, 10, 11, 12, 15, 20, 25, 29, 30, 40, 60];

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Statistical Tables Explorer',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Z-Table')),
                  ButtonSegment(value: 1, label: Text('t-Table')),
                  ButtonSegment(value: 2, label: Text('χ²-Table')),
                  ButtonSegment(value: 3, label: Text('F-Table')),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (v) => setState(() => _tabIndex = v.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _alphaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tail Area (α)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_tabIndex >= 1) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _df1Ctrl,
                        decoration: InputDecoration(
                          labelText: _tabIndex == 3 ? 'd₁' : 'df',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                  if (_tabIndex == 3) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _df2Ctrl,
                        decoration: const InputDecoration(labelText: 'd₂'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withAlpha(110),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  _computeQuickLookup(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildReferenceTable(alphas, dfs),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReferenceTable(List<double> alphas, List<int> dfs) {
    if (_tabIndex == 0) {
      final zRows = [0.0, 0.5, 1.0, 1.28, 1.645, 1.96, 2.0, 2.33, 2.576, 3.0];
      return DataTable(
        columns: const [
          DataColumn(label: Text('Z')),
          DataColumn(label: Text('Φ(Z) = P(Z ≤ Z)')),
          DataColumn(label: Text('Right Tail P(Z > Z)')),
        ],
        rows: zRows.map((z) {
          final cdf = NormalDist.cdf(z);
          return DataRow(
            cells: [
              DataCell(
                Text(
                  z.toStringAsFixed(3),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(cdf.toStringAsFixed(4))),
              DataCell(Text((1.0 - cdf).toStringAsFixed(4))),
            ],
          );
        }).toList(),
      );
    }

    final d2 = int.tryParse(_df2Ctrl.text.trim()) ?? 10;

    return DataTable(
      columns: [
        DataColumn(
          label: Text(_tabIndex == 3 ? 'd₁ \\ α (d₂=$d2)' : 'df \\ α'),
        ),
        ...alphas.map((a) => DataColumn(label: Text('α=$a'))),
      ],
      rows: dfs.map((df) {
        return DataRow(
          cells: [
            DataCell(
              Text('$df', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...alphas.map((a) {
              double val;
              if (_tabIndex == 1) {
                val = StudentTDist.criticalT(a, df);
              } else if (_tabIndex == 2) {
                val = ChiSquareDist.criticalChiSquare(a, df);
              } else {
                val = FisherFDist.criticalF(a, df, d2.clamp(1, 200));
              }
              return DataCell(Text(val.toStringAsFixed(3)));
            }),
          ],
        );
      }).toList(),
    );
  }
}
