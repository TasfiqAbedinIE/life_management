import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/budgeting_repository.dart';
import '../models/budgeting_models.dart';
import 'budget_settings_page.dart';

class BudgetingPage extends StatefulWidget {
  const BudgetingPage({super.key});

  @override
  State<BudgetingPage> createState() => _BudgetingPageState();
}

class _BudgetingPageState extends State<BudgetingPage> {
  final BudgetingRepository _repository = BudgetingRepository.instance;
  late Future<_BudgetViewData> _future;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  _BudgetSection _section = _BudgetSection.transactions;
  _TransactionView _transactionView = _TransactionView.daily;

  @override
  void initState() {
    super.initState();
    _future = _loadViewData();
  }

  Future<_BudgetViewData> _loadViewData() async {
    final baseProfile = await _repository.fetchProfile();
    final expenseCategories = await _repository.fetchExpenseCategories();
    final incomeCategories = await _repository.fetchIncomeCategories();
    final transactions = await _repository.fetchTransactions();
    final month = _visibleMonth;
    final plans = await _repository.fetchCategoryPlans(budgetMonthKey(month));
    final profile = baseProfile.copyWith(
      expenseCategories: expenseCategories.isEmpty
          ? baseProfile.expenseCategories
          : expenseCategories,
      incomeCategories: incomeCategories.isEmpty
          ? baseProfile.incomeCategories
          : incomeCategories,
    );
    return _BudgetViewData(
      profile: profile,
      transactions: transactions,
      month: DateTime(month.year, month.month),
      plans: plans,
    );
  }

  Future<void> _refresh() async {
    final future = _loadViewData();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openSettings(_BudgetViewData data) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BudgetSettingsPage(
          initialProfile: data.profile,
          initialMonth: data.month,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _future = _loadViewData();
    });
  }

  Future<void> _saveTransaction(
    BudgetTransaction tx, {
    required bool isEdit,
  }) async {
    if (isEdit) {
      await _repository.updateTransaction(tx);
    } else {
      await _repository.addTransaction(tx);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Transaction updated.' : 'Transaction saved.'),
      ),
    );
    await _refresh();
  }

  Future<void> _openEditor(
    BudgetProfile profile, {
    BudgetTransaction? tx,
  }) async {
    final result = await showModalBottomSheet<BudgetTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionEditorSheet(profile: profile, initial: tx),
    );
    if (result == null) return;
    await _saveTransaction(result, isEdit: tx != null);
  }

  Future<void> _deleteTransaction(BudgetTransaction tx) async {
    final id = tx.id;
    if (id == null) return;
    await _repository.deleteTransaction(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_BudgetViewData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final data = snapshot.requireData;
            return _BudgetShell(
              data: data,
              section: _section,
              transactionView: _transactionView,
              onBack: () => Navigator.of(context).maybePop(),
              onSectionChanged: (section) => setState(() {
                _section = section;
              }),
              onTransactionViewChanged: (view) => setState(() {
                _transactionView = view;
              }),
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onOpenSettings: () => _openSettings(data),
              onAddTransaction: () => _openEditor(data.profile),
              onEditTransaction: (tx) => _openEditor(data.profile, tx: tx),
              onDeleteTransaction: _deleteTransaction,
            );
          },
        ),
      ),
      floatingActionButton: FutureBuilder<_BudgetViewData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null || _section == _BudgetSection.accounts) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 82),
            child: FloatingActionButton(
              onPressed: () => _openEditor(data.profile),
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 34),
            ),
          );
        },
      ),
    );
  }
}

class _BudgetViewData {
  const _BudgetViewData({
    required this.profile,
    required this.transactions,
    required this.month,
    required this.plans,
  });

  final BudgetProfile profile;
  final List<BudgetTransaction> transactions;
  final DateTime month;
  final List<BudgetCategoryPlan> plans;
}

enum _BudgetSection { transactions, stats, accounts }

enum _TransactionView { daily, calendar, monthly, total, note }

class _LedgerColors {
  const _LedgerColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.text,
    required this.muted,
    required this.income,
    required this.expense,
    required this.accent,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color line;
  final Color text;
  final Color muted;
  final Color income;
  final Color expense;
  final Color accent;

  static _LedgerColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _LedgerColors(
        background: Color(0xFF202228),
        surface: Color(0xFF25272E),
        surfaceAlt: Color(0xFF1D1F25),
        line: Color(0xFF343741),
        text: Color(0xFFF5F5F7),
        muted: Color(0xFF9EA1AA),
        income: Color(0xFF5CA8FF),
        expense: Color(0xFFFF6969),
        accent: Color(0xFFFF5F5F),
      );
    }
    return const _LedgerColors(
      background: Color(0xFFF7F7F4),
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFF0F1EC),
      line: Color(0xFFE0E0DA),
      text: Color(0xFF212329),
      muted: Color(0xFF7C7F87),
      income: Color(0xFF2478CC),
      expense: Color(0xFFD84545),
      accent: Color(0xFFE95454),
    );
  }
}

class _BudgetShell extends StatelessWidget {
  const _BudgetShell({
    required this.data,
    required this.section,
    required this.transactionView,
    required this.onBack,
    required this.onSectionChanged,
    required this.onTransactionViewChanged,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onOpenSettings,
    required this.onAddTransaction,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final _BudgetViewData data;
  final _BudgetSection section;
  final _TransactionView transactionView;
  final VoidCallback onBack;
  final ValueChanged<_BudgetSection> onSectionChanged;
  final ValueChanged<_TransactionView> onTransactionViewChanged;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddTransaction;
  final ValueChanged<BudgetTransaction> onEditTransaction;
  final ValueChanged<BudgetTransaction> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    final stats = _BudgetStats.fromData(data);

    return Column(
      children: [
        _LedgerHeader(
          month: data.month,
          section: section,
          onBack: onBack,
          onOpenSettings: onOpenSettings,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
        ),
        if (section == _BudgetSection.transactions)
          _TransactionTabs(
            selected: transactionView,
            onChanged: onTransactionViewChanged,
          ),
        _LedgerTotalsBar(
          currencyCode: data.profile.currencyCode,
          income: stats.monthIncome,
          expense: stats.monthExpense,
          total: stats.monthIncome - stats.monthExpense,
        ),
        Expanded(
          child: switch (section) {
            _BudgetSection.transactions => _TransactionSectionView(
              data: data,
              view: transactionView,
              onOpenSettings: onOpenSettings,
              onEditTransaction: onEditTransaction,
              onDeleteTransaction: onDeleteTransaction,
            ),
            _BudgetSection.stats => _StatsSectionView(data: data),
            _BudgetSection.accounts => _AccountsSectionView(data: data),
          },
        ),
        _LedgerBottomNav(selected: section, onChanged: onSectionChanged),
      ],
    );
  }
}

class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader({
    required this.month,
    required this.section,
    required this.onBack,
    required this.onOpenSettings,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final _BudgetSection section;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final label = section == _BudgetSection.accounts
        ? 'Accounts'
        : DateFormat('MMM yyyy').format(month);

    return Container(
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(8, 12, 10, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: colors.text,
          ),
          Expanded(
            child: Text(
              section == _BudgetSection.accounts ? label : 'Budgeting',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: colors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (section != _BudgetSection.accounts)
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompactHeaderButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: onPreviousMonth,
                    color: colors.text,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _CompactHeaderButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: onNextMonth,
                    color: colors.text,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Budget settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            color: colors.text,
            style: IconButton.styleFrom(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.line),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactHeaderButton extends StatelessWidget {
  const _CompactHeaderButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: color,
      ),
    );
  }
}

class _TransactionTabs extends StatelessWidget {
  const _TransactionTabs({required this.selected, required this.onChanged});

  final _TransactionView selected;
  final ValueChanged<_TransactionView> onChanged;

  static const _labels = {
    _TransactionView.daily: 'Daily',
    _TransactionView.calendar: 'Calendar',
    _TransactionView.monthly: 'Monthly',
    _TransactionView.total: 'Total',
    _TransactionView.note: 'Note',
  };

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    return Container(
      color: colors.background,
      child: Row(
        children: _TransactionView.values.map((view) {
          final active = selected == view;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(view),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Text(
                      _labels[view]!,
                      style: TextStyle(
                        color: active ? colors.text : colors.muted,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 4,
                      width: active ? 72 : 0,
                      color: colors.accent,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LedgerTotalsBar extends StatelessWidget {
  const _LedgerTotalsBar({
    required this.currencyCode,
    required this.income,
    required this.expense,
    required this.total,
  });

  final String currencyCode;
  final double income;
  final double expense;
  final double total;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _LedgerTotalItem(
              label: 'Income',
              value: _money(currencyCode, income),
              color: colors.income,
            ),
          ),
          Expanded(
            child: _LedgerTotalItem(
              label: 'Expenses',
              value: _money(currencyCode, expense),
              color: colors.expense,
            ),
          ),
          Expanded(
            child: _LedgerTotalItem(
              label: 'Total',
              value: _money(currencyCode, total),
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTotalItem extends StatelessWidget {
  const _LedgerTotalItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LedgerBottomNav extends StatelessWidget {
  const _LedgerBottomNav({required this.selected, required this.onChanged});

  final _BudgetSection selected;
  final ValueChanged<_BudgetSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, math.max(12, bottomInset)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.line.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.32
                    : 0.12,
              ),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              _LedgerNavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Trans.',
                isSelected: selected == _BudgetSection.transactions,
                colors: colors,
                onTap: () => onChanged(_BudgetSection.transactions),
              ),
              _LedgerNavItem(
                icon: Icons.bar_chart_outlined,
                selectedIcon: Icons.bar_chart_rounded,
                label: 'Stats',
                isSelected: selected == _BudgetSection.stats,
                colors: colors,
                onTap: () => onChanged(_BudgetSection.stats),
              ),
              _LedgerNavItem(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                label: 'Accounts',
                isSelected: selected == _BudgetSection.accounts,
                colors: colors,
                onTap: () => onChanged(_BudgetSection.accounts),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerNavItem extends StatelessWidget {
  const _LedgerNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final _LedgerColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : colors.muted;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isSelected ? selectedIcon : icon, color: color, size: 25),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isSelected
                      ? Padding(
                          key: ValueKey(label),
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('hidden'), height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionSectionView extends StatelessWidget {
  const _TransactionSectionView({
    required this.data,
    required this.view,
    required this.onOpenSettings,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final _BudgetViewData data;
  final _TransactionView view;
  final VoidCallback onOpenSettings;
  final ValueChanged<BudgetTransaction> onEditTransaction;
  final ValueChanged<BudgetTransaction> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      _TransactionView.daily => _DailyLedgerView(
        data: data,
        onEditTransaction: onEditTransaction,
        onDeleteTransaction: onDeleteTransaction,
      ),
      _TransactionView.calendar => _CalendarLedgerView(data: data),
      _TransactionView.monthly => _MonthlyLedgerView(data: data),
      _TransactionView.total => _BudgetTotalView(
        data: data,
        onOpenSettings: onOpenSettings,
      ),
      _TransactionView.note => _BudgetNoteView(data: data),
    };
  }
}

class _DailyLedgerView extends StatelessWidget {
  const _DailyLedgerView({
    required this.data,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final _BudgetViewData data;
  final ValueChanged<BudgetTransaction> onEditTransaction;
  final ValueChanged<BudgetTransaction> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    final groups = _groupedTransactions(_monthTransactions(data));
    final colors = _LedgerColors.of(context);
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'No transactions for this month.',
          style: TextStyle(color: colors.muted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final income = _sum(group.items, BudgetTransactionType.income);
        final expense = _sum(group.items, BudgetTransactionType.expense);
        return _DailyGroupRow(
          date: group.date,
          income: income,
          expense: expense,
          currencyCode: data.profile.currencyCode,
          transactions: group.items,
          onEditTransaction: onEditTransaction,
          onDeleteTransaction: onDeleteTransaction,
        );
      },
    );
  }
}

class _DailyGroupRow extends StatelessWidget {
  const _DailyGroupRow({
    required this.date,
    required this.income,
    required this.expense,
    required this.currencyCode,
    required this.transactions,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final DateTime date;
  final double income;
  final double expense;
  final String currencyCode;
  final List<BudgetTransaction> transactions;
  final ValueChanged<BudgetTransaction> onEditTransaction;
  final ValueChanged<BudgetTransaction> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  DateFormat('dd').format(date),
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MM.yyyy').format(date),
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _money(currencyCode, income),
                  style: TextStyle(color: colors.income, fontSize: 14),
                ),
                const SizedBox(width: 18),
                Text(
                  _money(currencyCode, expense),
                  style: TextStyle(color: colors.expense, fontSize: 14),
                ),
              ],
            ),
          ),
          ...transactions.map(
            (tx) => _LedgerTransactionLine(
              transaction: tx,
              currencyCode: currencyCode,
              onTap: () => onEditTransaction(tx),
              onDelete: () => onDeleteTransaction(tx),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTransactionLine extends StatelessWidget {
  const _LedgerTransactionLine({
    required this.transaction,
    required this.currencyCode,
    required this.onTap,
    required this.onDelete,
  });

  final BudgetTransaction transaction;
  final String currencyCode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final amountColor = transaction.type.isIncome
        ? colors.income
        : colors.expense;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                transaction.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.muted, fontSize: 14),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                transaction.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.muted, fontSize: 14),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _money(currencyCode, transaction.amount),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: amountColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: PopupMenuButton<String>(
                iconSize: 18,
                padding: EdgeInsets.zero,
                color: colors.surface,
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLedgerView extends StatelessWidget {
  const _CalendarLedgerView({required this.data});

  final _BudgetViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final first = DateTime(data.month.year, data.month.month);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final daily = _dailyTotals(data.transactions, data.month);
    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final day = start.add(Duration(days: index));
        final totals = daily[_dateKey(day)] ?? const _DayTotals();
        final isMonth = day.month == data.month.month;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isMonth ? colors.surface : colors.surfaceAlt,
            border: Border.all(color: colors.line, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                index < 7 ? DateFormat('EEE').format(day) : '${day.day}',
                style: TextStyle(
                  color: isMonth ? colors.text : colors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (totals.income > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _money(data.profile.currencyCode, totals.income),
                    style: TextStyle(color: colors.income, fontSize: 10),
                  ),
                ),
              if (totals.expense > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _money(data.profile.currencyCode, totals.expense),
                    style: TextStyle(color: colors.expense, fontSize: 10),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthlyLedgerView extends StatelessWidget {
  const _MonthlyLedgerView({required this.data});

  final _BudgetViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final monthRows = List.generate(data.month.month, (index) {
      final month = DateTime(data.month.year, data.month.month - index);
      final stats = _BudgetStats.forMonth(data.transactions, data.plans, month);
      return (month: month, stats: stats);
    });
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        ..._weeklyRows(data).map(
          (row) => _PeriodRow(
            label: row.label,
            income: row.income,
            expense: row.expense,
            currencyCode: data.profile.currencyCode,
            highlight: row.expense > row.income && row.expense > 0,
          ),
        ),
        ...monthRows.map(
          (row) => _PeriodRow(
            label: DateFormat('MMM').format(row.month),
            income: row.stats.monthIncome,
            expense: row.stats.monthExpense,
            currencyCode: data.profile.currencyCode,
            labelStyle: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetTotalView extends StatelessWidget {
  const _BudgetTotalView({required this.data, required this.onOpenSettings});

  final _BudgetViewData data;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final stats = _BudgetStats.fromData(data);
    final spentByCategory = stats.expenseByCategory;
    final totalBudget = data.plans.fold<double>(
      0,
      (sum, plan) => sum + plan.amount,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: colors.text, size: 30),
              const SizedBox(width: 10),
              Text(
                'Budget',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Budget Setting'),
              ),
            ],
          ),
        ),
        _BudgetProgressRow(
          label: 'Total Budget',
          budget: totalBudget,
          spent: stats.monthExpense,
          currencyCode: data.profile.currencyCode,
        ),
        ...data.plans.map(
          (plan) => _BudgetProgressRow(
            label: plan.category,
            budget: plan.amount,
            spent: spentByCategory[plan.category] ?? 0,
            currencyCode: data.profile.currencyCode,
          ),
        ),
      ],
    );
  }
}

class _BudgetNoteView extends StatelessWidget {
  const _BudgetNoteView({required this.data});

  final _BudgetViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final notes = _BudgetScore.fromStats(
      data,
      _BudgetStats.fromData(data),
    ).suggestions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
      children: notes
          .map(
            (note) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(note, style: TextStyle(color: colors.text)),
            ),
          )
          .toList(),
    );
  }
}

class _StatsSectionView extends StatelessWidget {
  const _StatsSectionView({required this.data});

  final _BudgetViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final stats = _BudgetStats.fromData(data);
    final entries = _pieEntries(stats.expenseByCategory);
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
          child: Row(
            children: [
              Expanded(
                child: _LedgerTotalItem(
                  label: 'Income',
                  value: _money(data.profile.currencyCode, stats.monthIncome),
                  color: colors.income,
                ),
              ),
              Expanded(
                child: _LedgerTotalItem(
                  label: 'Expenses',
                  value: _money(data.profile.currencyCode, stats.monthExpense),
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 360,
          child: CustomPaint(
            painter: _PieChartPainter(
              entries: entries,
              totalAmount: stats.monthExpense,
              surfaceColor: colors.background,
              textColor: colors.text,
            ),
          ),
        ),
        ...entries.map((entry) {
          final percent = stats.monthExpense == 0
              ? 0.0
              : (entry.amount / stats.monthExpense) * 100;
          return _StatsCategoryRow(
            color: entry.color,
            percent: percent,
            category: entry.category,
            amount: _money(data.profile.currencyCode, entry.amount),
          );
        }),
      ],
    );
  }
}

class _AccountsSectionView extends StatelessWidget {
  const _AccountsSectionView({required this.data});

  final _BudgetViewData data;

  @override
  Widget build(BuildContext context) {
    final balances = _sourceBalances(data.transactions);
    final totalAssets = balances.values
        .where((value) => value > 0)
        .fold<double>(0, (sum, value) => sum + value);
    final totalLiabilities = balances.values
        .where((value) => value < 0)
        .fold<double>(0, (sum, value) => sum + value.abs());
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _LedgerTotalsBar(
          currencyCode: data.profile.currencyCode,
          income: totalAssets,
          expense: totalLiabilities,
          total: totalAssets - totalLiabilities,
        ),
        ...BudgetingDefaults.moneySources.map(
          (source) => _AccountBalanceRow(
            source: source,
            balance: balances[source] ?? 0,
            currencyCode: data.profile.currencyCode,
          ),
        ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.label,
    required this.income,
    required this.expense,
    required this.currencyCode,
    this.highlight = false,
    this.labelStyle,
  });

  final String label;
  final double income;
  final double expense;
  final String currencyCode;
  final bool highlight;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final total = income - expense;
    return Container(
      color: highlight ? colors.expense.withValues(alpha: 0.2) : colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  labelStyle ??
                  TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              _money(currencyCode, income),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.income,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(currencyCode, expense),
                  style: TextStyle(
                    color: colors.expense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _money(currencyCode, total),
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressRow extends StatelessWidget {
  const _BudgetProgressRow({
    required this.label,
    required this.budget,
    required this.spent,
    required this.currencyCode,
  });

  final String label;
  final double budget;
  final double spent;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final ratio = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final remaining = budget - spent;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 145,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(currencyCode, budget),
                  style: TextStyle(color: colors.text, fontSize: 15),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 26,
                          color: colors.income,
                          backgroundColor: colors.surfaceAlt,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(ratio * 100).round()}%',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _money(currencyCode, spent),
                      style: TextStyle(color: colors.income, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      _money(currencyCode, remaining),
                      style: TextStyle(color: colors.text, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCategoryRow extends StatelessWidget {
  const _StatsCategoryRow({
    required this.color,
    required this.percent,
    required this.category,
    required this.amount,
  });

  final Color color;
  final double percent;
  final String category;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${percent.round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AccountBalanceRow extends StatelessWidget {
  const _AccountBalanceRow({
    required this.source,
    required this.balance,
    required this.currencyCode,
  });

  final String source;
  final double balance;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = _LedgerColors.of(context);
    final color = balance < 0 ? colors.expense : colors.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              source,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            _money(currencyCode, balance.abs()),
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionEditorSheet extends StatefulWidget {
  const _TransactionEditorSheet({required this.profile, this.initial});

  final BudgetProfile profile;
  final BudgetTransaction? initial;

  @override
  State<_TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends State<_TransactionEditorSheet> {
  late BudgetTransactionType _type;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late String _category;
  late String _source;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final tx = widget.initial;
    _type = tx?.type ?? BudgetTransactionType.expense;
    _amountController = TextEditingController(
      text: tx == null ? '' : tx.amount.toStringAsFixed(0),
    );
    _descriptionController = TextEditingController(text: tx?.description ?? '');
    _source = tx?.source ?? BudgetingDefaults.moneySources.first;
    _date = tx?.occurredAt ?? DateTime.now();
    _category = _categories.first;
    if (tx != null && _categories.contains(tx.category)) {
      _category = tx.category;
    }
  }

  List<String> get _categories => _type.isIncome
      ? widget.profile.incomeCategories
      : widget.profile.expenseCategories;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
    });
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    Navigator.of(context).pop(
      BudgetTransaction(
        id: widget.initial?.id,
        type: _type,
        amount: amount,
        category: _category,
        description: _descriptionController.text.trim(),
        source: _source,
        occurredAt: DateTime(_date.year, _date.month, _date.day),
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_categories.contains(_category)) {
      _category = _categories.first;
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171F35) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null ? 'Add transaction' : 'Edit transaction',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<BudgetTransactionType>(
                segments: const [
                  ButtonSegment(
                    value: BudgetTransactionType.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: BudgetTransactionType.income,
                    label: Text('Income'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (value) {
                  setState(() {
                    _type = value.first;
                    _category = _categories.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _source,
                decoration: const InputDecoration(labelText: 'Source'),
                items: BudgetingDefaults.moneySources
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _source = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(DateFormat('dd MMM yyyy').format(_date)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.initial == null ? 'Save' : 'Update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxGroup {
  const _TxGroup({required this.date, required this.items});

  final DateTime date;
  final List<BudgetTransaction> items;
}

class _DayTotals {
  const _DayTotals({this.income = 0, this.expense = 0});

  final double income;
  final double expense;

  _DayTotals add(BudgetTransaction transaction) {
    if (transaction.type.isIncome) {
      return _DayTotals(income: income + transaction.amount, expense: expense);
    }
    return _DayTotals(income: income, expense: expense + transaction.amount);
  }
}

class _PeriodSummary {
  const _PeriodSummary({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;
}

List<BudgetTransaction> _monthTransactions(_BudgetViewData data) {
  return data.transactions.where((transaction) {
    return transaction.occurredAt.year == data.month.year &&
        transaction.occurredAt.month == data.month.month;
  }).toList();
}

double _sum(List<BudgetTransaction> transactions, BudgetTransactionType type) {
  return transactions
      .where((transaction) => transaction.type == type)
      .fold<double>(0, (sum, transaction) => sum + transaction.amount);
}

Map<String, _DayTotals> _dailyTotals(
  List<BudgetTransaction> transactions,
  DateTime month,
) {
  final totals = <String, _DayTotals>{};
  for (final transaction in transactions) {
    if (transaction.occurredAt.year != month.year ||
        transaction.occurredAt.month != month.month) {
      continue;
    }
    final key = _dateKey(transaction.occurredAt);
    totals[key] = (totals[key] ?? const _DayTotals()).add(transaction);
  }
  return totals;
}

List<_PeriodSummary> _weeklyRows(_BudgetViewData data) {
  final daysInMonth = DateTime(data.month.year, data.month.month + 1, 0).day;
  final rows = <_PeriodSummary>[];
  for (var startDay = daysInMonth; startDay >= 1; startDay -= 7) {
    final endDay = startDay;
    final beginDay = math.max(1, startDay - 6);
    final transactions = data.transactions.where((transaction) {
      return transaction.occurredAt.year == data.month.year &&
          transaction.occurredAt.month == data.month.month &&
          transaction.occurredAt.day >= beginDay &&
          transaction.occurredAt.day <= endDay;
    }).toList();
    rows.add(
      _PeriodSummary(
        label:
            '${DateFormat('MM.dd').format(DateTime(data.month.year, data.month.month, beginDay))}  ~  ${DateFormat('MM.dd').format(DateTime(data.month.year, data.month.month, endDay))}',
        income: _sum(transactions, BudgetTransactionType.income),
        expense: _sum(transactions, BudgetTransactionType.expense),
      ),
    );
  }
  return rows;
}

Map<String, double> _sourceBalances(List<BudgetTransaction> transactions) {
  final balances = {
    for (final source in BudgetingDefaults.moneySources) source: 0.0,
  };
  for (final transaction in transactions) {
    balances.update(
      transaction.source,
      (value) =>
          value +
          (transaction.type.isIncome
              ? transaction.amount
              : -transaction.amount),
      ifAbsent: () =>
          transaction.type.isIncome ? transaction.amount : -transaction.amount,
    );
  }
  return balances;
}

String _dateKey(DateTime date) =>
    DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));

List<_TxGroup> _groupedTransactions(List<BudgetTransaction> transactions) {
  final grouped = <String, List<BudgetTransaction>>{};
  for (final tx in transactions) {
    final key = DateFormat('yyyy-MM-dd').format(tx.occurredAt);
    grouped.putIfAbsent(key, () => []).add(tx);
  }
  final list = grouped.entries.map((entry) {
    final items = List<BudgetTransaction>.from(entry.value)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _TxGroup(date: DateTime.parse(entry.key), items: items);
  }).toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

class _BudgetStats {
  const _BudgetStats({
    required this.balance,
    required this.monthIncome,
    required this.monthExpense,
    required this.totalBudget,
    required this.remainingBudget,
    required this.expenseByCategory,
  });

  final double balance;
  final double monthIncome;
  final double monthExpense;
  final double totalBudget;
  final double remainingBudget;
  final Map<String, double> expenseByCategory;

  factory _BudgetStats.fromData(_BudgetViewData data) {
    return _BudgetStats.forMonth(data.transactions, data.plans, data.month);
  }

  factory _BudgetStats.forMonth(
    List<BudgetTransaction> transactions,
    List<BudgetCategoryPlan> plans,
    DateTime month,
  ) {
    double balance = 0;
    double monthIncome = 0;
    double monthExpense = 0;
    final expenseByCategory = <String, double>{};
    for (final tx in transactions) {
      balance += tx.type.isIncome ? tx.amount : -tx.amount;
      final inMonth =
          tx.occurredAt.year == month.year &&
          tx.occurredAt.month == month.month;
      if (inMonth && tx.type.isIncome) {
        monthIncome += tx.amount;
      }
      if (inMonth && tx.type.isExpense) {
        monthExpense += tx.amount;
        expenseByCategory.update(
          tx.category,
          (value) => value + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }
    final totalBudget = plans.fold<double>(0, (sum, plan) => sum + plan.amount);
    return _BudgetStats(
      balance: balance,
      monthIncome: monthIncome,
      monthExpense: monthExpense,
      totalBudget: totalBudget,
      remainingBudget: totalBudget - monthExpense,
      expenseByCategory: expenseByCategory,
    );
  }
}

class _PieEntry {
  const _PieEntry({
    required this.category,
    required this.amount,
    required this.color,
  });

  final String category;
  final double amount;
  final Color color;
}

List<_PieEntry> _pieEntries(Map<String, double> expenseByCategory) {
  const colors = [
    Color(0xFF4B76E5),
    Color(0xFF3BB273),
    Color(0xFFFF8A5B),
    Color(0xFFF3C14B),
    Color(0xFF8E6CFF),
    Color(0xFF2AB7CA),
  ];
  final entries = expenseByCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return List.generate(
    entries.length,
    (index) => _PieEntry(
      category: entries[index].key,
      amount: entries[index].value,
      color: colors[index % colors.length],
    ),
  );
}

class _BudgetScore {
  const _BudgetScore({
    required this.value,
    required this.tone,
    required this.suggestions,
  });

  final int value;
  final String tone;
  final List<String> suggestions;

  factory _BudgetScore.fromStats(_BudgetViewData data, _BudgetStats stats) {
    final incomeGoalRatio = data.profile.monthlyIncomeGoal <= 0
        ? 1.0
        : (stats.monthIncome / data.profile.monthlyIncomeGoal).clamp(0.0, 1.2);
    final savings = stats.monthIncome - stats.monthExpense;
    final savingsRatio = data.profile.savingsGoal <= 0
        ? 1.0
        : (savings / data.profile.savingsGoal).clamp(0.0, 1.2);
    final budgetRatio = stats.totalBudget <= 0
        ? 0.6
        : (1 - ((stats.monthExpense - stats.totalBudget) / stats.totalBudget))
              .clamp(0.0, 1.2);
    final score =
        ((incomeGoalRatio * 30) + (savingsRatio * 35) + (budgetRatio * 35))
            .round()
            .clamp(0, 100);
    final suggestions = <String>[
      if (stats.totalBudget > 0 && stats.monthExpense > stats.totalBudget)
        'You are above this month\'s budget. Tighten the categories with the biggest spend first.',
      if (data.profile.monthlyIncomeGoal > 0 &&
          stats.monthIncome < data.profile.monthlyIncomeGoal)
        'Income is below your target, so this month benefits from a more defensive spending plan.',
      if (savings < data.profile.savingsGoal)
        'Your savings runway is behind goal. Consider trimming one flexible expense category this week.',
      if (stats.expenseByCategory.isNotEmpty)
        'Highest pressure category: ${_topExpenseCategory(stats.expenseByCategory)}. Review recent transactions there for quick wins.',
    ];
    return _BudgetScore(
      value: score,
      tone: score >= 80
          ? 'Strong control'
          : score >= 60
          ? 'Mostly healthy'
          : 'Needs attention',
      suggestions: suggestions.isEmpty
          ? const [
              'You are on track. Keep recording transactions to maintain a reliable score.',
            ]
          : suggestions,
    );
  }
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({
    required this.entries,
    required this.totalAmount,
    required this.surfaceColor,
    required this.textColor,
  });

  final List<_PieEntry> entries;
  final double totalAmount;
  final Color surfaceColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.amount);
    if (total <= 0) return;

    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = shortest * 0.34;
    final stroke = (shortest * 0.13).clamp(18.0, 30.0);
    final labelSize = (shortest * 0.035).clamp(8.0, 11.0);
    final labelRadius = outerRadius + stroke * 0.95;
    final labelMaxWidth = shortest * 0.3;

    var startAngle = -math.pi / 2;
    for (final entry in entries) {
      final sweep = (entry.amount / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = entry.color;
      final rect = Rect.fromCircle(center: center, radius: outerRadius);
      canvas.drawArc(rect, startAngle, sweep, false, paint);

      if (sweep > 0.22) {
        final labelAngle = startAngle + (sweep / 2);
        final labelCenter = Offset(
          center.dx + math.cos(labelAngle) * labelRadius,
          center.dy + math.sin(labelAngle) * labelRadius,
        );
        final percent = totalAmount == 0
            ? 0
            : (entry.amount / totalAmount) * 100;
        final labelPainter = TextPainter(
          text: TextSpan(
            text:
                '${_shortCategoryLabel(entry.category)} ${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              color: textColor,
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          maxLines: 1,
          ellipsis: '...',
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: labelMaxWidth);

        final paddingX = 8.0;
        final paddingY = 5.0;
        var left = labelCenter.dx - (labelPainter.width / 2) - paddingX;
        var top = labelCenter.dy - (labelPainter.height / 2) - paddingY;
        final maxLeft = size.width - labelPainter.width - (paddingX * 2);
        final maxTop = size.height - labelPainter.height - (paddingY * 2);
        left = left.clamp(0.0, maxLeft);
        top = top.clamp(0.0, maxTop);

        final bubbleRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            top,
            labelPainter.width + (paddingX * 2),
            labelPainter.height + (paddingY * 2),
          ),
          const Radius.circular(999),
        );

        final bubblePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = surfaceColor.withValues(alpha: 0.94);
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = entry.color.withValues(alpha: 0.9);
        canvas.drawRRect(bubbleRect, bubblePaint);
        canvas.drawRRect(bubbleRect, borderPaint);
        labelPainter.paint(canvas, Offset(left + paddingX, top + paddingY));
      }

      startAngle += sweep;
    }

    final holePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = surfaceColor;
    canvas.drawCircle(center, outerRadius - stroke, holePaint);

    final totalPainter = TextPainter(
      text: TextSpan(
        text: _money('', totalAmount).trim(),
        style: TextStyle(
          color: textColor.withValues(alpha: 0.78),
          fontSize: (shortest * 0.048).clamp(9.0, 14.0),
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: shortest * 0.24);
    totalPainter.paint(
      canvas,
      Offset(
        center.dx - (totalPainter.width / 2),
        center.dy - (totalPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.totalAmount != totalAmount ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.textColor != textColor;
  }
}

String _shortCategoryLabel(String category) {
  final words = category.split(' ');
  if (category.length <= 12) return category;
  if (words.length >= 2) {
    return '${words.first} ${words[1]}';
  }
  return category.substring(0, 12);
}

String _topExpenseCategory(Map<String, double> expenseByCategory) {
  var topLabel = 'Other';
  var topValue = -1.0;
  for (final entry in expenseByCategory.entries) {
    if (entry.value > topValue) {
      topLabel = entry.key;
      topValue = entry.value;
    }
  }
  return topLabel;
}

String _money(String currencyCode, double amount) {
  return NumberFormat.currency(
    symbol: '$currencyCode ',
    decimalDigits: 0,
  ).format(amount);
}
