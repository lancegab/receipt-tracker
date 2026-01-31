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
    s3Key: varchar('s3_key', { length: 500 }).notNull(),
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
