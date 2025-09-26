// lib/widgets/earnings_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';

class PaymentDetail {
  final String client;
  final double netAmount;
  final bool isPaid;
  final DateTime? date;

  PaymentDetail({required this.client, required this.netAmount, required this.isPaid, this.date});
}

enum EarningPeriod { total, weekly, monthly }

extension EarningPeriodExtension on EarningPeriod {
  String get displayName {
    switch (this) {
      case EarningPeriod.total:
        return 'Total';
      case EarningPeriod.weekly:
        return 'Weekly';
      case EarningPeriod.monthly:
        return 'Monthly';
    }
  }
}

class EarningsCard extends StatefulWidget {
  final double grossTotal;
  final double netTotal;

  final double grossWeekly;
  final double netWeekly;
  final String weeklySubtitle;

  final double grossMonthly;
  final double netMonthly;
  final String monthlySubtitle;

  final List<PaymentDetail> weeklyPaymentsTableData;
  final List<PaymentDetail> monthlyPaymentsTableData;

  final double platformFeePercent;

  const EarningsCard({
    Key? key,
    required this.grossTotal,
    required this.netTotal,
    required this.grossWeekly,
    required this.netWeekly,
    required this.weeklySubtitle,
    required this.grossMonthly,
    required this.netMonthly,
    required this.monthlySubtitle,
    required this.weeklyPaymentsTableData,
    required this.monthlyPaymentsTableData,
    this.platformFeePercent = 10.0,
  }) : super(key: key);

  @override
  State<EarningsCard> createState() => _EarningsCardState();
}

class _EarningsCardState extends State<EarningsCard> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  EarningPeriod _selectedPeriod = EarningPeriod.weekly;
  DateTime? _selectedDate; // for week/month selection

  // Formatters
  final DateFormat _monthFmt = DateFormat('MMMM yyyy');
  final DateFormat _rangeFmt = DateFormat('d MMM');

  // compute current list based on selected period
  List<PaymentDetail> get _currentPayments {
    switch (_selectedPeriod) {
      case EarningPeriod.total:
        return widget.monthlyPaymentsTableData;
      case EarningPeriod.weekly:
        return widget.weeklyPaymentsTableData;
      case EarningPeriod.monthly:
        return widget.monthlyPaymentsTableData;
    }
  }

  Future<void> _pickWeek(BuildContext ctx) async {
    DateTime now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      // TODO: fetch filtered weekly data based on selected week
    }
  }

  Future<void> _pickMonth(BuildContext ctx) async {
    DateTime now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Pick a date within the month you want',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      // TODO: fetch filtered monthly data based on selected month
    }
  }

  String _selectedPeriodSubtitle() {
    if (_selectedDate == null) {
      switch (_selectedPeriod) {
        case EarningPeriod.total:
          return 'All time';
        case EarningPeriod.weekly:
          return widget.weeklySubtitle.isNotEmpty ? widget.weeklySubtitle : 'This week';
        case EarningPeriod.monthly:
          return widget.monthlySubtitle.isNotEmpty ? widget.monthlySubtitle : 'This month';
      }
    }

    if (_selectedPeriod == EarningPeriod.weekly) {
      final d = _selectedDate!;
      final weekday = d.weekday; // Mon = 1
      final monday = d.subtract(Duration(days: weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return '${_rangeFmt.format(monday)} - ${_rangeFmt.format(sunday)}';
    } else if (_selectedPeriod == EarningPeriod.monthly) {
      return _monthFmt.format(_selectedDate!);
    } else {
      return 'All time';
    }
  }

  // Show the recent payments in a modal bottom sheet
  void _showRecentPaymentsSheet(BuildContext ctx, List<PaymentDetail> items) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (c) {
        final theme = Theme.of(c);
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.35,
            maxChildSize: 0.95,
            builder: (context, ctrl) {
              return Column(
                children: [
                  Container(height: 6, width: 56, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(6))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Text('Recent Payments', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(_selectedPeriod.displayName, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? Center(child: Text('No payments found', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)))
                        : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, i) {
                        final p = items[i];
                        final isPaid = p.isPaid;
                        final chipColor = isPaid ? AppColors.secondary.withOpacity(0.12) : AppColors.primary.withOpacity(0.12);
                        final chipTextColor = isPaid ? AppColors.secondary : AppColors.primary;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          leading: CircleAvatar(radius: 22, backgroundColor: Colors.grey.shade100, child: Text(_initials(p.client), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87))),
                          title: Text(p.client, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: p.date != null ? Text(DateFormat('d MMM, yyyy').format(p.date!), style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)) : null,
                          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(_currency.format(p.netAmount), style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(8)),
                              child: Text(isPaid ? 'Paid' : 'Pending', style: theme.textTheme.labelSmall?.copyWith(color: chipTextColor, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  IconData _detailIconForPeriod() {
    switch (_selectedPeriod) {
      case EarningPeriod.total:
        return Icons.summarize_outlined;
      case EarningPeriod.weekly:
        return Icons.calendar_view_week_outlined;
      case EarningPeriod.monthly:
        return Icons.calendar_month_outlined;
    }
  }

  String _detailTitleForPeriod() {
    switch (_selectedPeriod) {
      case EarningPeriod.total:
        return 'Total Earnings';
      case EarningPeriod.weekly:
        return 'Weekly Snapshot';
      case EarningPeriod.monthly:
        return 'Monthly Snapshot';
    }
  }

  List<Widget> _detailRowsForPeriod(ThemeData theme) {
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600);
    final valueStyle = theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800);
    final highlight = theme.textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800);

    switch (_selectedPeriod) {
      case EarningPeriod.total:
        final fee = (widget.grossTotal * widget.platformFeePercent) / 100;
        return [
          _detailRow('Gross', _currency.format(widget.grossTotal), labelStyle, valueStyle),
          _detailRow('Platform fee (${widget.platformFeePercent.toStringAsFixed(0)}%)', '- ${_currency.format(fee)}', labelStyle, valueStyle?.copyWith(color: Colors.orangeAccent)),
          _detailRow('Net', _currency.format(widget.netTotal), labelStyle, highlight),
        ];
      case EarningPeriod.weekly:
        return [
          _detailRow('Gross (week)', _currency.format(widget.grossWeekly), labelStyle, valueStyle),
          _detailRow('Net (week)', _currency.format(widget.netWeekly), labelStyle, highlight),
        ];
      case EarningPeriod.monthly:
        return [
          _detailRow('Gross (month)', _currency.format(widget.grossMonthly), labelStyle, valueStyle),
          _detailRow('Net (month)', _currency.format(widget.netMonthly), labelStyle, highlight),
        ];
    }
  }

  Widget _detailRow(String label, String value, TextStyle? labelStyle, TextStyle? valueStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: labelStyle), Text(value, style: valueStyle)]),
    );
  }

  Widget _platformFeeFooter(ThemeData theme) {
    double gross = 0;
    switch (_selectedPeriod) {
      case EarningPeriod.total:
        gross = widget.grossTotal;
        break;
      case EarningPeriod.weekly:
        gross = widget.grossWeekly;
        break;
      case EarningPeriod.monthly:
        gross = widget.grossMonthly;
        break;
    }
    final fee = (gross * widget.platformFeePercent) / 100;
    if (gross == 0) return const SizedBox.shrink();
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Platform fee (${widget.platformFeePercent.toStringAsFixed(0)}%)', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
      Text(_currency.format(fee), style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _periodTabs(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(24)),
      child: Row(children: EarningPeriod.values.map((p) {
        final selected = _selectedPeriod == p;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedPeriod = p;
              // clear selected date when switching period (optional)
              // _selectedDate = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.secondary.withOpacity(0.95) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(p.displayName, style: theme.textTheme.bodyLarge?.copyWith(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)),
            ),
          ),
        );
      }).toList()),
    );
  }

  Widget _smallActionButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return '';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient card
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // header
              Row(
                children: [
                  Expanded(child: Text('Earnings', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Gross: ${_currency.format(widget.grossTotal)}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text('Net: ${_currency.format(widget.netTotal)}', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
              const SizedBox(height: 14),

              // Period selector + pickers on the right
              Row(children: [
                Expanded(child: _periodTabs(theme)),
                const SizedBox(width: 8),
                if (_selectedPeriod == EarningPeriod.weekly)
                  _smallActionButton(label: 'week', icon: Icons.date_range, onTap: () => _pickWeek(context))
                else if (_selectedPeriod == EarningPeriod.monthly)
                  _smallActionButton(label: 'month', icon: Icons.calendar_today, onTap: () => _pickMonth(context))
                else
                  const SizedBox.shrink(),
              ]),
              const SizedBox(height: 12),

              // Details card (dark semi-transparent block inside gradient)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(_detailIconForPeriod(), color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_detailTitleForPeriod(), style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
                    Text(_selectedPeriodSubtitle(), style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ]),
                  const SizedBox(height: 10),
                  ..._detailRowsForPeriod(theme),
                ]),
              ),

              const SizedBox(height: 96), // room for the white sheet below
            ]),
          ),

          // White sheet overlapping - but now contains only the button to open recent payments
          Positioned(
            left: 0,
            right: 0,
            bottom: -28,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))]),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(children: [
                Container(width: 44, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(6))),
                Row(children: [
                  Text('Payments', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(_selectedPeriod.displayName, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                ]),
                const SizedBox(height: 12),

                // NEW: Recent Payments button (opens modal sheet)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRecentPaymentsSheet(context, _currentPayments),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Recent Payments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Platform fee footer for the selected period
                _platformFeeFooter(theme),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
