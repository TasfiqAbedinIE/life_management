import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/budgeting_models.dart';

class BudgetingDB {
  BudgetingDB._();

  static final BudgetingDB instance = BudgetingDB._();

  static const _dbName = 'budgeting.db';
  static const _dbVersion = 4;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE budget_transactions ADD COLUMN source TEXT NOT NULL DEFAULT 'Cash'",
          );
          await db.execute(
            "ALTER TABLE budget_profile ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'BDT'",
          );
          await db.execute(
            "ALTER TABLE budget_profile ADD COLUMN expense_categories TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute(
            "ALTER TABLE budget_profile ADD COLUMN income_categories TEXT NOT NULL DEFAULT '[]'",
          );

          final defaults = BudgetProfile.defaultProfile();
          await db.update('budget_profile', {
            'currency_code': defaults.currencyCode,
            'expense_categories': jsonEncode(defaults.expenseCategories),
            'income_categories': jsonEncode(defaults.incomeCategories),
          });
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE budget_category_plans(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              month_key TEXT NOT NULL,
              category TEXT NOT NULL,
              amount REAL NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE(month_key, category)
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_budget_category_plans_month_key ON budget_category_plans(month_key)',
          );

          final profileRows = await db.query('budget_profile', limit: 1);
          if (profileRows.isNotEmpty) {
            final profile = profileRows.first;
            final oldMonthlyBudget =
                (profile['monthly_budget'] as num?)?.toDouble() ?? 0;
            if (oldMonthlyBudget > 0) {
              final categories =
                  BudgetProfile.defaultProfile().expenseCategories;
              final perCategory = oldMonthlyBudget / categories.length;
              final now = DateTime.now();
              for (final category in categories) {
                await db.insert(
                  'budget_category_plans',
                  {
                    'month_key': budgetMonthKey(now),
                    'category': category,
                    'amount': perCategory,
                    'updated_at': now.toIso8601String(),
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
        }

        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE budget_expense_categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE budget_income_categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              created_at TEXT NOT NULL
            )
          ''');

          final profileRows = await db.query('budget_profile', limit: 1);
          final fallback = BudgetProfile.defaultProfile();
          List<String> expenseCategories = fallback.expenseCategories;
          List<String> incomeCategories = fallback.incomeCategories;

          if (profileRows.isNotEmpty) {
            final profile = BudgetProfile.fromMap(profileRows.first);
            expenseCategories = profile.expenseCategories;
            incomeCategories = profile.incomeCategories;
          }

          final now = DateTime.now().toIso8601String();
          for (final name in expenseCategories) {
            await db.insert(
              'budget_expense_categories',
              {'name': name, 'created_at': now},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          for (final name in incomeCategories) {
            await db.insert(
              'budget_income_categories',
              {'name': name, 'created_at': now},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE budget_profile(
        id INTEGER PRIMARY KEY,
        monthly_budget REAL NOT NULL DEFAULT 0,
        monthly_income_goal REAL NOT NULL,
        savings_goal REAL NOT NULL,
        currency_code TEXT NOT NULL,
        expense_categories TEXT NOT NULL,
        income_categories TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_category_plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(month_key, category)
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_expense_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_income_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_budget_transactions_occurred_at ON budget_transactions(occurred_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_budget_transactions_type ON budget_transactions(type)',
    );
    await db.execute(
      'CREATE INDEX idx_budget_transactions_category ON budget_transactions(category)',
    );
    await db.execute(
      'CREATE INDEX idx_budget_category_plans_month_key ON budget_category_plans(month_key)',
    );

    final profile = BudgetProfile.defaultProfile();
    await db.insert('budget_profile', profile.toMap());

    final now = DateTime.now().toIso8601String();
    for (final name in profile.expenseCategories) {
      await db.insert('budget_expense_categories', {
        'name': name,
        'created_at': now,
      });
    }
    for (final name in profile.incomeCategories) {
      await db.insert('budget_income_categories', {
        'name': name,
        'created_at': now,
      });
    }
  }
}
