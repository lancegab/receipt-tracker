import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import {
  recurringTransactions,
  transactions,
  accounts,
} from '../db/schema.js';
import { eq, and, lte, sql } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import {
  createRecurringSchema,
  updateRecurringSchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const recurring = new Hono<AppEnv>();
recurring.use('*', authMiddleware);

// GET /api/recurring — list active recurring transactions
recurring.get('/', async (c) => {
  const user = c.get('user');

  const result = await db
    .select()
    .from(recurringTransactions)
    .where(
      and(
        eq(recurringTransactions.userId, user.id),
        eq(recurringTransactions.isActive, true)
      )
    );

  return c.json({ success: true, data: result });
});

// POST /api/recurring — create
recurring.post(
  '/',
  zValidator('json', createRecurringSchema),
  async (c) => {
    const user = c.get('user');
    const body = c.req.valid('json');

    // Verify account ownership
    const [account] = await db
      .select()
      .from(accounts)
      .where(and(eq(accounts.id, body.accountId), eq(accounts.userId, user.id)));

    if (!account) {
      throw new HTTPException(404, { message: 'Account not found' });
    }

    const id = uuidv4();
    await db.insert(recurringTransactions).values({
      id,
      userId: user.id,
      accountId: body.accountId,
      type: body.type,
      amount: String(body.amount),
      description: body.description,
      categoryId: body.categoryId || null,
      frequency: body.frequency,
      startDate: new Date(body.startDate),
      endDate: body.endDate ? new Date(body.endDate) : null,
      nextOccurrence: new Date(body.startDate),
      isActive: true,
    });

    const [created] = await db
      .select()
      .from(recurringTransactions)
      .where(eq(recurringTransactions.id, id));

    return c.json({ success: true, data: created }, 201);
  }
);

// PATCH /api/recurring/:id — update
recurring.patch(
  '/:id',
  zValidator('json', updateRecurringSchema),
  async (c) => {
    const user = c.get('user');
    const id = c.req.param('id');
    const body = c.req.valid('json');

    const [existing] = await db
      .select()
      .from(recurringTransactions)
      .where(
        and(
          eq(recurringTransactions.id, id),
          eq(recurringTransactions.userId, user.id)
        )
      );

    if (!existing) {
      throw new HTTPException(404, { message: 'Recurring transaction not found' });
    }

    const updates: Record<string, unknown> = {};
    if (body.amount !== undefined) updates.amount = String(body.amount);
    if (body.description !== undefined) updates.description = body.description;
    if (body.categoryId !== undefined) updates.categoryId = body.categoryId;
    if (body.frequency !== undefined) updates.frequency = body.frequency;
    if (body.endDate !== undefined) updates.endDate = body.endDate ? new Date(body.endDate) : null;
    if (body.isActive !== undefined) updates.isActive = body.isActive;

    if (Object.keys(updates).length > 0) {
      await db
        .update(recurringTransactions)
        .set(updates)
        .where(eq(recurringTransactions.id, id));
    }

    const [updated] = await db
      .select()
      .from(recurringTransactions)
      .where(eq(recurringTransactions.id, id));

    return c.json({ success: true, data: updated });
  }
);

// DELETE /api/recurring/:id — deactivate
recurring.delete('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [existing] = await db
    .select()
    .from(recurringTransactions)
    .where(
      and(
        eq(recurringTransactions.id, id),
        eq(recurringTransactions.userId, user.id)
      )
    );

  if (!existing) {
    throw new HTTPException(404, { message: 'Recurring transaction not found' });
  }

  await db
    .update(recurringTransactions)
    .set({ isActive: false })
    .where(eq(recurringTransactions.id, id));

  return c.json({ success: true, data: { message: 'Recurring transaction deactivated' } });
});

// POST /api/recurring/process — process due recurring transactions
recurring.post('/process', async (c) => {
  const user = c.get('user');
  const today = new Date().toISOString().split('T')[0];

  const due = await db
    .select()
    .from(recurringTransactions)
    .where(
      and(
        eq(recurringTransactions.userId, user.id),
        eq(recurringTransactions.isActive, true),
        lte(recurringTransactions.nextOccurrence, new Date(today))
      )
    );

  const created: string[] = [];

  for (const rec of due) {
    // Create actual transaction
    const txnId = uuidv4();
    await db.insert(transactions).values({
      id: txnId,
      userId: user.id,
      accountId: rec.accountId,
      type: rec.type,
      amount: rec.amount,
      date: new Date(rec.nextOccurrence),
      description: rec.description,
      categoryId: rec.categoryId,
      isPending: false,
    });

    // Update account balance
    const amountNum = parseFloat(rec.amount);
    const balanceChange = rec.type === 'income' ? amountNum : -amountNum;
    await db
      .update(accounts)
      .set({ balance: sql`balance + ${balanceChange}` })
      .where(eq(accounts.id, rec.accountId));

    // Advance next occurrence
    const next = advanceDate(new Date(rec.nextOccurrence), rec.frequency);

    // Check if past end date
    if (rec.endDate && next > new Date(rec.endDate)) {
      await db
        .update(recurringTransactions)
        .set({ isActive: false })
        .where(eq(recurringTransactions.id, rec.id));
    } else {
      await db
        .update(recurringTransactions)
        .set({ nextOccurrence: next })
        .where(eq(recurringTransactions.id, rec.id));
    }

    created.push(txnId);
  }

  return c.json({
    success: true,
    data: { processedCount: created.length, transactionIds: created },
  });
});

function advanceDate(
  date: Date,
  frequency: string
): Date {
  const result = new Date(date);
  switch (frequency) {
    case 'daily':
      result.setDate(result.getDate() + 1);
      break;
    case 'weekly':
      result.setDate(result.getDate() + 7);
      break;
    case 'biweekly':
      result.setDate(result.getDate() + 14);
      break;
    case 'monthly':
      result.setMonth(result.getMonth() + 1);
      break;
    case 'quarterly':
      result.setMonth(result.getMonth() + 3);
      break;
    case 'yearly':
      result.setFullYear(result.getFullYear() + 1);
      break;
  }
  return result;
}

export default recurring;
