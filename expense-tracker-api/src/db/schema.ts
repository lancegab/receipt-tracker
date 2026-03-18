import {
  mysqlTable,
  varchar,
  char,
  decimal,
  boolean,
  timestamp,
  date,
  time,
  text,
  json,
  mysqlEnum,
  tinyint,
  index,
} from 'drizzle-orm/mysql-core';

export const users = mysqlTable(
  'users',
  {
    id: char('id', { length: 36 }).primaryKey(),
    email: varchar('email', { length: 255 }).notNull().unique(),
    passwordHash: varchar('password_hash', { length: 255 }),
    displayName: varchar('display_name', { length: 100 }),
    defaultCurrency: char('default_currency', { length: 3 }).default('USD'),
    authProvider: mysqlEnum('auth_provider', [
      'email',
      'google',
      'facebook',
      'apple',
    ]).notNull(),
    authProviderId: varchar('auth_provider_id', { length: 255 }),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    emailIdx: index('idx_email').on(table.email),
    authIdx: index('idx_auth').on(table.authProvider, table.authProviderId),
  })
);

export const accounts = mysqlTable(
  'accounts',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    name: varchar('name', { length: 100 }).notNull(),
    type: mysqlEnum('type', [
      'cash',
      'bank',
      'savings',
      'wallet',
      'credit_card',
    ]).notNull(),
    currency: char('currency', { length: 3 }).default('USD'),
    balance: decimal('balance', { precision: 15, scale: 2 }).default('0.00'),
    creditLimit: decimal('credit_limit', { precision: 15, scale: 2 }),
    statementCloseDay: tinyint('statement_close_day'),
    paymentDueDay: tinyint('payment_due_day'),
    isArchived: boolean('is_archived').default(false),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    userIdx: index('idx_user_id').on(table.userId),
  })
);

export const categories = mysqlTable(
  'categories',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 }).references(() => users.id, {
      onDelete: 'cascade',
    }),
    name: varchar('name', { length: 50 }).notNull(),
    type: mysqlEnum('type', ['expense', 'income']).notNull(),
    icon: varchar('icon', { length: 50 }),
    color: char('color', { length: 7 }),
    isSystem: boolean('is_system').default(false),
    isActive: boolean('is_active').default(true),
    createdAt: timestamp('created_at').defaultNow(),
  },
  (table) => ({
    userTypeIdx: index('idx_user_type').on(table.userId, table.type),
  })
);

export const receipts = mysqlTable(
  'receipts',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    s3Key: varchar('s3_key', { length: 500 }),
    s3ThumbnailKey: varchar('s3_thumbnail_key', { length: 500 }),
    merchantName: varchar('merchant_name', { length: 200 }),
    merchantAddress: text('merchant_address'),
    transactionDate: date('transaction_date'),
    subtotal: decimal('subtotal', { precision: 15, scale: 2 }),
    tax: decimal('tax', { precision: 15, scale: 2 }),
    total: decimal('total', { precision: 15, scale: 2 }),
    rawLlmResponse: json('raw_llm_response'),
    confidenceScore: decimal('confidence_score', { precision: 3, scale: 2 }),
    createdAt: timestamp('created_at').defaultNow(),
  },
  (table) => ({
    userIdx: index('idx_user_id').on(table.userId),
    dateIdx: index('idx_date').on(table.transactionDate),
  })
);

export const transactions = mysqlTable(
  'transactions',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    accountId: char('account_id', { length: 36 })
      .notNull()
      .references(() => accounts.id, { onDelete: 'cascade' }),
    type: mysqlEnum('type', ['expense', 'income', 'transfer']).notNull(),
    amount: decimal('amount', { precision: 15, scale: 2 }).notNull(),
    date: date('date').notNull(),
    time: time('time'),
    description: varchar('description', { length: 255 }).notNull(),
    merchantName: varchar('merchant_name', { length: 200 }),
    categoryId: char('category_id', { length: 36 }).references(
      () => categories.id,
      { onDelete: 'set null' }
    ),
    notes: text('notes'),
    receiptId: char('receipt_id', { length: 36 }).references(
      () => receipts.id,
      { onDelete: 'set null' }
    ),
    transferToAccountId: char('transfer_to_account_id', {
      length: 36,
    }).references(() => accounts.id, { onDelete: 'set null' }),
    isPending: boolean('is_pending').default(false),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    userDateIdx: index('idx_user_date').on(table.userId, table.date),
    accountIdx: index('idx_account').on(table.accountId),
    categoryIdx: index('idx_category').on(table.categoryId),
    receiptIdx: index('idx_receipt').on(table.receiptId),
  })
);

export const passwordResetTokens = mysqlTable(
  'password_reset_tokens',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tokenHash: varchar('token_hash', { length: 255 }).notNull(),
    expiresAt: timestamp('expires_at').notNull(),
    usedAt: timestamp('used_at'),
    createdAt: timestamp('created_at').defaultNow(),
  },
  (table) => ({
    userIdx: index('idx_reset_user_id').on(table.userId),
  })
);

export const recurringTransactions = mysqlTable(
  'recurring_transactions',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    accountId: char('account_id', { length: 36 })
      .notNull()
      .references(() => accounts.id, { onDelete: 'cascade' }),
    type: mysqlEnum('type', ['expense', 'income', 'transfer']).notNull(),
    amount: decimal('amount', { precision: 15, scale: 2 }).notNull(),
    description: varchar('description', { length: 255 }).notNull(),
    categoryId: char('category_id', { length: 36 }).references(
      () => categories.id,
      { onDelete: 'set null' }
    ),
    frequency: mysqlEnum('frequency', [
      'daily',
      'weekly',
      'biweekly',
      'monthly',
      'quarterly',
      'yearly',
    ]).notNull(),
    startDate: date('start_date').notNull(),
    endDate: date('end_date'),
    nextOccurrence: date('next_occurrence').notNull(),
    isActive: boolean('is_active').default(true),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    userIdx: index('idx_recurring_user_id').on(table.userId),
    nextIdx: index('idx_recurring_next').on(table.nextOccurrence),
  })
);

export const refreshTokens = mysqlTable(
  'refresh_tokens',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tokenHash: varchar('token_hash', { length: 255 }).notNull(),
    expiresAt: timestamp('expires_at').notNull(),
    createdAt: timestamp('created_at').defaultNow(),
  },
  (table) => ({
    userIdx: index('idx_user_id').on(table.userId),
    tokenIdx: index('idx_token').on(table.tokenHash),
  })
);

// ── Budget Groups ──────────────────────────────────────────────

export const budgetGroups = mysqlTable(
  'budget_groups',
  {
    id: char('id', { length: 36 }).primaryKey(),
    name: varchar('name', { length: 100 }).notNull(),
    description: varchar('description', { length: 255 }),
    currency: char('currency', { length: 3 }).default('PHP'),
    createdBy: char('created_by', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    createdByIdx: index('idx_bg_created_by').on(table.createdBy),
  })
);

export const budgetGroupMembers = mysqlTable(
  'budget_group_members',
  {
    id: char('id', { length: 36 }).primaryKey(),
    groupId: char('group_id', { length: 36 })
      .notNull()
      .references(() => budgetGroups.id, { onDelete: 'cascade' }),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    role: mysqlEnum('role', ['owner', 'member']).notNull().default('member'),
    joinedAt: timestamp('joined_at').defaultNow(),
  },
  (table) => ({
    groupIdx: index('idx_bgm_group').on(table.groupId),
    userIdx: index('idx_bgm_user').on(table.userId),
    uniqueIdx: index('idx_bgm_unique').on(table.groupId, table.userId),
  })
);

export const budgetGroupInvitations = mysqlTable(
  'budget_group_invitations',
  {
    id: char('id', { length: 36 }).primaryKey(),
    groupId: char('group_id', { length: 36 })
      .notNull()
      .references(() => budgetGroups.id, { onDelete: 'cascade' }),
    invitedEmail: varchar('invited_email', { length: 255 }).notNull(),
    invitedBy: char('invited_by', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    status: mysqlEnum('status', [
      'pending',
      'accepted',
      'declined',
      'expired',
    ])
      .notNull()
      .default('pending'),
    createdAt: timestamp('created_at').defaultNow(),
    expiresAt: timestamp('expires_at').notNull(),
  },
  (table) => ({
    groupIdx: index('idx_bgi_group').on(table.groupId),
    emailIdx: index('idx_bgi_email').on(table.invitedEmail),
  })
);

// ── Budgets ────────────────────────────────────────────────────

export const budgets = mysqlTable(
  'budgets',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 }).references(() => users.id, {
      onDelete: 'cascade',
    }),
    groupId: char('group_id', { length: 36 }).references(
      () => budgetGroups.id,
      { onDelete: 'cascade' }
    ),
    name: varchar('name', { length: 100 }).notNull(),
    month: char('month', { length: 7 }).notNull(),
    currency: char('currency', { length: 3 }).default('PHP'),
    notes: text('notes'),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    userMonthIdx: index('idx_budget_user_month').on(table.userId, table.month),
    groupMonthIdx: index('idx_budget_group_month').on(
      table.groupId,
      table.month
    ),
  })
);

export const budgetItems = mysqlTable(
  'budget_items',
  {
    id: char('id', { length: 36 }).primaryKey(),
    budgetId: char('budget_id', { length: 36 })
      .notNull()
      .references(() => budgets.id, { onDelete: 'cascade' }),
    name: varchar('name', { length: 100 }).notNull(),
    budgetedAmount: decimal('budgeted_amount', { precision: 15, scale: 2 })
      .notNull()
      .default('0.00'),
    linkedAccountId: char('linked_account_id', { length: 36 }).references(
      () => accounts.id,
      { onDelete: 'set null' }
    ),
    linkedCategoryId: char('linked_category_id', { length: 36 }).references(
      () => categories.id,
      { onDelete: 'set null' }
    ),
    manualSpent: decimal('manual_spent', { precision: 15, scale: 2 }).default(
      '0.00'
    ),
    sortOrder: tinyint('sort_order').default(0),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    budgetIdx: index('idx_bi_budget').on(table.budgetId),
    accountIdx: index('idx_bi_account').on(table.linkedAccountId),
    categoryIdx: index('idx_bi_category').on(table.linkedCategoryId),
  })
);

export const budgetItemWeeklyAdjustments = mysqlTable(
  'budget_item_weekly_adjustments',
  {
    id: char('id', { length: 36 }).primaryKey(),
    budgetItemId: char('budget_item_id', { length: 36 })
      .notNull()
      .references(() => budgetItems.id, { onDelete: 'cascade' }),
    week: tinyint('week').notNull(),
    manualAdjustment: decimal('manual_adjustment', {
      precision: 15,
      scale: 2,
    }).default('0.00'),
    notes: varchar('notes', { length: 255 }),
  },
  (table) => ({
    itemWeekIdx: index('idx_biwa_item_week').on(
      table.budgetItemId,
      table.week
    ),
  })
);

// ── Credit Card Installments ───────────────────────────────────

export const creditCardInstallments = mysqlTable(
  'credit_card_installments',
  {
    id: char('id', { length: 36 }).primaryKey(),
    userId: char('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    accountId: char('account_id', { length: 36 })
      .notNull()
      .references(() => accounts.id, { onDelete: 'cascade' }),
    description: varchar('description', { length: 255 }).notNull(),
    totalAmount: decimal('total_amount', { precision: 15, scale: 2 }).notNull(),
    monthlyAmount: decimal('monthly_amount', {
      precision: 15,
      scale: 2,
    }).notNull(),
    totalMonths: tinyint('total_months').notNull(),
    startMonth: char('start_month', { length: 7 }).notNull(),
    endMonth: char('end_month', { length: 7 }).notNull(),
    categoryId: char('category_id', { length: 36 }).references(
      () => categories.id,
      { onDelete: 'set null' }
    ),
    isActive: boolean('is_active').default(true),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
  },
  (table) => ({
    userIdx: index('idx_cci_user').on(table.userId),
    accountIdx: index('idx_cci_account').on(table.accountId),
    activeMonthIdx: index('idx_cci_active_month').on(
      table.accountId,
      table.isActive,
      table.startMonth,
      table.endMonth
    ),
  })
);
