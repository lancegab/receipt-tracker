import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/reports_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    ref.read(reportsProvider.notifier).loadReport(_selectedYear, _selectedMonth);
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final userCurrency =
        ref.watch(authStateProvider).valueOrNull?.defaultCurrency ?? 'PHP';

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Month selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${_monthNames[_selectedMonth]} $_selectedYear',
                      style: context.textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary cards
                Row(
                  children: [
                    _SummaryCard(
                      label: 'Income',
                      amount: state.totalIncome,
                      color: const Color(0xFF2E7D32),
                      currency: userCurrency,
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Expense',
                      amount: state.totalExpense,
                      color: context.colorScheme.error,
                      currency: userCurrency,
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Net',
                      amount: state.net,
                      color: state.net >= 0 ? const Color(0xFF2E7D32) : context.colorScheme.error,
                      currency: userCurrency,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Pie chart - spending by category
                if (state.categoryBreakdown.isNotEmpty) ...[
                  Text(
                    'Spending by Category',
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(state.categoryBreakdown),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Bar chart - income vs expense
                Text(
                  'Income vs Expense',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.center,
                      groupsSpace: 40,
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [
                          BarChartRodData(
                            toY: state.totalIncome,
                            color: const Color(0xFF2E7D32),
                            width: 30,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ]),
                        BarChartGroupData(x: 1, barRods: [
                          BarChartRodData(
                            toY: state.totalExpense,
                            color: context.colorScheme.error,
                            width: 30,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ]),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0:
                                  return const Text('Income');
                                case 1:
                                  return const Text('Expense');
                                default:
                                  return const Text('');
                              }
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static final _pieColors = [
    const Color(0xFF2E7D32), // money green
    const Color(0xFFE53935), // logo red
    const Color(0xFFFFC107), // logo gold
    const Color(0xFF1B5E20), // dark green
    const Color(0xFFFF8F00), // deep amber
    const Color(0xFF212121), // cat black
    const Color(0xFF43A047), // light green
    const Color(0xFFD32F2F), // deep red
    const Color(0xFFFFB300), // amber
    const Color(0xFF66BB6A), // soft green
  ];

  List<PieChartSectionData> _buildPieSections(Map<String, double> breakdown) {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final pct = total > 0 ? (item.value / total * 100) : 0;
      return PieChartSectionData(
        value: item.value,
        title: '${pct.toStringAsFixed(0)}%',
        color: _pieColors[index % _pieColors.length],
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String currency;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    this.currency = 'PHP',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  CurrencyFormatter.format(amount.abs(), currency: currency),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
