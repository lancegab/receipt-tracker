import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/transactions/presentation/screens/transactions_screen.dart';
import '../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../features/accounts/presentation/screens/accounts_screen.dart';
import '../features/accounts/presentation/screens/account_detail_screen.dart';
import '../features/accounts/presentation/screens/add_account_screen.dart';
import '../features/receipts/presentation/screens/receipt_capture_screen.dart';
import '../features/receipts/presentation/screens/receipt_review_screen.dart';
import '../features/categories/presentation/screens/categories_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/recurring/presentation/screens/recurring_screen.dart';
import '../features/recurring/presentation/screens/add_recurring_screen.dart';
import '../features/budget/presentation/screens/budget_screen.dart';
import '../features/budget/presentation/screens/budget_detail_screen.dart';
import '../features/budget/presentation/screens/create_budget_screen.dart';
import '../features/budget/presentation/screens/add_budget_item_screen.dart';
import '../features/budget/presentation/screens/installments_screen.dart';
import '../features/budget/presentation/screens/add_installment_screen.dart';
import '../features/budget/presentation/screens/budget_groups_screen.dart';
import '../features/budget/presentation/screens/budget_group_detail_screen.dart';
import '../shared/widgets/main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/budget',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/budget';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/budget',
            builder: (context, state) => const BudgetScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      // Budget routes
      GoRoute(
        path: '/budget/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => BudgetDetailScreen(
          budgetId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/create-budget',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateBudgetScreen(),
      ),
      GoRoute(
        path: '/budget/:id/add-item',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AddBudgetItemScreen(
          budgetId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/installments',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InstallmentsScreen(),
      ),
      GoRoute(
        path: '/add-installment',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddInstallmentScreen(),
      ),
      GoRoute(
        path: '/groups',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BudgetGroupsScreen(),
      ),
      GoRoute(
        path: '/groups/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => BudgetGroupDetailScreen(
          groupId: state.pathParameters['id']!,
        ),
      ),
      // Transaction routes
      GoRoute(
        path: '/add-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/add-account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddAccountScreen(),
      ),
      GoRoute(
        path: '/account/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AccountDetailScreen(
          accountId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/scan-receipt',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReceiptCaptureScreen(),
      ),
      GoRoute(
        path: '/review-receipt',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ReceiptReviewScreen(receiptData: extra);
        },
      ),
      GoRoute(
        path: '/categories',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/recurring',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecurringScreen(),
      ),
      GoRoute(
        path: '/add-recurring',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddRecurringScreen(),
      ),
    ],
  );
});
