import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../models/budgeting_models.dart';
import 'budgeting_db.dart';

class BudgetMonthlySummary {
  const BudgetMonthlySummary({
    required this.month,
    required this.currencyCode,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final String currencyCode;
  final double income;
  final double expense;

  double get balance => income - expense;
}

class BudgetingRepository {
  BudgetingRepository._();

  static final BudgetingRepository instance = BudgetingRepository._();

  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changes.stream;

  Future<BudgetProfile> fetchProfile() async {
    final db = await BudgetingDB.instance.database;
    final rows = await db.query('budget_profile', limit: 1);

    if (rows.isEmpty) {
      final profile = BudgetProfile.defaultProfile();
      await db.insert(
        'budget_profile',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return profile;
    }

    return BudgetProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(BudgetProfile profile) async {
    final db = await BudgetingDB.instance.database;
    await db.insert(
      'budget_profile',
      profile.copyWith(updatedAt: DateTime.now()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.add(null);
  }

  Future<BudgetMonthlySummary> fetchMonthlySummary([DateTime? forMonth]) async {
    final month = forMonth ?? DateTime.now();
    final monthStart = DateTime(month.year, month.month);
    final nextMonthStart = DateTime(month.year, month.month + 1);
    final db = await BudgetingDB.instance.database;
    final profile = await fetchProfile();
    final rows = await db.rawQuery(
      '''
      SELECT type, COALESCE(SUM(amount), 0) AS total
      FROM budget_transactions
      WHERE occurred_at >= ? AND occurred_at < ?
      GROUP BY type
      ''',
      [monthStart.toIso8601String(), nextMonthStart.toIso8601String()],
    );

    var income = 0.0;
    var expense = 0.0;
    for (final row in rows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (row['type'] == BudgetTransactionType.income.value) {
        income = total;
      } else if (row['type'] == BudgetTransactionType.expense.value) {
        expense = total;
      }
    }

    return BudgetMonthlySummary(
      month: monthStart,
      currencyCode: profile.currencyCode,
      income: income,
      expense: expense,
    );
  }

  Future<List<String>> fetchExpenseCategories() async {
    final db = await BudgetingDB.instance.database;
    final rows = await db.query(
      'budget_expense_categories',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<List<String>> fetchIncomeCategories() async {
    final db = await BudgetingDB.instance.database;
    final rows = await db.query(
      'budget_income_categories',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<void> replaceExpenseCategories(List<String> categories) async {
    final db = await BudgetingDB.instance.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    final unique = categories.toSet().toList()..sort();

    batch.delete('budget_expense_categories');
    for (final category in unique) {
      batch.insert('budget_expense_categories', {
        'name': category,
        'created_at': now,
      });
    }

    final placeholders = List.filled(unique.length, '?').join(',');
    if (unique.isEmpty) {
      batch.delete('budget_category_plans');
    } else {
      batch.delete(
        'budget_category_plans',
        where: 'category NOT IN ($placeholders)',
        whereArgs: unique,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> replaceIncomeCategories(List<String> categories) async {
    final db = await BudgetingDB.instance.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    final unique = categories.toSet().toList()..sort();

    batch.delete('budget_income_categories');
    for (final category in unique) {
      batch.insert('budget_income_categories', {
        'name': category,
        'created_at': now,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<BudgetCategoryPlan>> fetchCategoryPlans(String monthKey) async {
    final db = await BudgetingDB.instance.database;
    final rows = await db.query(
      'budget_category_plans',
      where: 'month_key = ?',
      whereArgs: [monthKey],
      orderBy: 'category COLLATE NOCASE ASC',
    );
    return rows.map(BudgetCategoryPlan.fromMap).toList();
  }

  Future<void> saveCategoryPlans({
    required String monthKey,
    required Map<String, double> plans,
  }) async {
    final db = await BudgetingDB.instance.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    batch.delete(
      'budget_category_plans',
      where: 'month_key = ?',
      whereArgs: [monthKey],
    );

    plans.forEach((category, amount) {
      if (amount <= 0) return;
      batch.insert('budget_category_plans', {
        'month_key': monthKey,
        'category': category,
        'amount': amount,
        'updated_at': now,
      });
    });

    await batch.commit(noResult: true);
  }

  Future<List<BudgetTransaction>> fetchTransactions() async {
    final db = await BudgetingDB.instance.database;
    final rows = await db.query(
      'budget_transactions',
      orderBy: 'occurred_at DESC, created_at DESC, id DESC',
    );
    return rows.map(BudgetTransaction.fromMap).toList();
  }

  Future<int> addTransaction(BudgetTransaction transaction) async {
    final db = await BudgetingDB.instance.database;
    final id = await db.insert(
      'budget_transactions',
      transaction.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.add(null);
    return id;
  }

  Future<int> updateTransaction(BudgetTransaction transaction) async {
    final id = transaction.id;
    if (id == null) throw ArgumentError('Transaction id is null');

    final db = await BudgetingDB.instance.database;
    final changed = await db.update(
      'budget_transactions',
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed > 0) _changes.add(null);
    return changed;
  }

  Future<int> deleteTransaction(int id) async {
    final db = await BudgetingDB.instance.database;
    final changed = await db.delete(
      'budget_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed > 0) _changes.add(null);
    return changed;
  }
}
