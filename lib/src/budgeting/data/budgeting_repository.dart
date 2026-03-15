import 'package:sqflite/sqflite.dart';

import '../models/budgeting_models.dart';
import 'budgeting_db.dart';

class BudgetingRepository {
  BudgetingRepository._();

  static final BudgetingRepository instance = BudgetingRepository._();

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
    return db.insert(
      'budget_transactions',
      transaction.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTransaction(BudgetTransaction transaction) async {
    final id = transaction.id;
    if (id == null) throw ArgumentError('Transaction id is null');

    final db = await BudgetingDB.instance.database;
    return db.update(
      'budget_transactions',
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await BudgetingDB.instance.database;
    return db.delete('budget_transactions', where: 'id = ?', whereArgs: [id]);
  }
}
