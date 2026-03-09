import { z } from 'zod';

// Auth validators
export const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  displayName: z.string().min(1).max(100).optional(),
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const oauthSchema = z.object({
  idToken: z.string().min(1),
});

export const updateProfileSchema = z.object({
  displayName: z.string().min(1).max(100).optional(),
  defaultCurrency: z.string().length(3).optional(),
});

export const forgotPasswordSchema = z.object({
  email: z.string().email(),
});

export const resetPasswordSchema = z.object({
  token: z.string().min(1),
  password: z.string().min(8).max(128),
});

// Account validators
export const createAccountSchema = z.object({
  name: z.string().min(1).max(100),
  type: z.enum(['cash', 'bank', 'savings', 'wallet', 'credit_card']),
  currency: z.string().length(3).default('USD'),
  balance: z.number().default(0),
  creditLimit: z.number().optional(),
  statementCloseDay: z.number().int().min(1).max(31).optional(),
  paymentDueDay: z.number().int().min(1).max(31).optional(),
});

export const updateAccountSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  currency: z.string().length(3).optional(),
  creditLimit: z.number().optional(),
  statementCloseDay: z.number().int().min(1).max(31).optional(),
  paymentDueDay: z.number().int().min(1).max(31).optional(),
  isArchived: z.boolean().optional(),
});

// Transaction validators
export const createTransactionSchema = z.object({
  accountId: z.string().uuid(),
  type: z.enum(['expense', 'income', 'transfer']),
  amount: z.number().positive(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  time: z
    .string()
    .regex(/^\d{2}:\d{2}(:\d{2})?$/)
    .optional(),
  description: z.string().min(1).max(255),
  merchantName: z.string().max(200).optional(),
  categoryId: z.string().uuid().optional(),
  notes: z.string().optional(),
  receiptId: z.string().uuid().optional(),
  transferToAccountId: z.string().uuid().optional(),
  isPending: z.boolean().default(false),
});

export const updateTransactionSchema = createTransactionSchema.partial();

export const batchCreateTransactionSchema = z.object({
  transactions: z.array(createTransactionSchema).min(1).max(100),
});

// Receipt validators
export const processReceiptSchema = z.object({
  imageBase64: z.string().min(1),
  contentType: z.string().default('image/jpeg'),
  accountId: z.string().uuid().optional(),
});

// Category validators
export const createCategorySchema = z.object({
  name: z.string().min(1).max(50),
  type: z.enum(['expense', 'income']),
  icon: z.string().max(50).optional(),
  color: z
    .string()
    .regex(/^#[0-9A-Fa-f]{6}$/)
    .optional(),
});

export const updateCategorySchema = z.object({
  name: z.string().min(1).max(50).optional(),
  icon: z.string().max(50).optional(),
  color: z
    .string()
    .regex(/^#[0-9A-Fa-f]{6}$/)
    .optional(),
  isActive: z.boolean().optional(),
});

// Recurring transaction validators
export const createRecurringSchema = z.object({
  accountId: z.string().uuid(),
  type: z.enum(['expense', 'income', 'transfer']),
  amount: z.number().positive(),
  description: z.string().min(1).max(255),
  categoryId: z.string().uuid().optional(),
  frequency: z.enum(['daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly']),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

export const updateRecurringSchema = z.object({
  amount: z.number().positive().optional(),
  description: z.string().min(1).max(255).optional(),
  categoryId: z.string().uuid().nullable().optional(),
  frequency: z.enum(['daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly']).optional(),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
  isActive: z.boolean().optional(),
});

// Query param validators
export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const transactionFiltersSchema = paginationSchema.extend({
  accountId: z.string().uuid().optional(),
  categoryId: z.string().uuid().optional(),
  type: z.enum(['expense', 'income', 'transfer']).optional(),
  startDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  endDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  search: z.string().optional(),
});
