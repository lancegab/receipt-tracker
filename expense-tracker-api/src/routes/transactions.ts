import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { transactions, accounts } from '../db/schema.js';
import { eq, and, desc, gte, lte, like, sql } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import {
  createTransactionSchema,
  updateTransactionSchema,
  batchCreateTransactionSchema,
  transactionFiltersSchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const transactionsRouter = new Hono<AppEnv>();
transactionsRouter.use('*', authMiddleware);

async function updateAccountBalance(
  accountId: string,
  amount: number,
  type: string,
  isReversal: boolean = false
) {
  const multiplier = isReversal ? -1 : 1;

  if (type === 'expense') {
    await db
      .update(accounts)
      .set({
        balance: sql`balance - ${String(amount * multiplier)}`,
      })
      .where(eq(accounts.id, accountId));
  } else if (type === 'income') {
    await db
      .update(accounts)
      .set({
        balance: sql`balance + ${String(amount * multiplier)}`,
      })
      .where(eq(accounts.id, accountId));
  }
}

// GET /api/transactions
transactionsRouter.get('/', async (c) => {
  const user = c.get('user');
  const filters = transactionFiltersSchema.parse(c.req.query());
  const { page, limit } = filters;
  const offset = (page - 1) * limit;

  const conditions = [eq(transactions.userId, user.id)];

  if (filters.accountId) {
    conditions.push(eq(transactions.accountId, filters.accountId));
  }
  if (filters.categoryId) {
    conditions.push(eq(transactions.categoryId, filters.categoryId));
  }
  if (filters.type) {
    conditions.push(eq(transactions.type, filters.type));
  }
  if (filters.startDate) {
    conditions.push(gte(transactions.date, new Date(filters.startDate)));
  }
  if (filters.endDate) {
    conditions.push(lte(transactions.date, new Date(filters.endDate)));
  }
  if (filters.search) {
    conditions.push(like(transactions.description, `%${filters.search}%`));
  }

  const whereClause = and(...conditions);

  const [countResult] = await db
    .select({ count: sql<number>`count(*)` })
    .from(transactions)
    .where(whereClause);

  const total = Number(countResult.count);

  const result = await db
    .select()
    .from(transactions)
    .where(whereClause)
    .orderBy(desc(transactions.date), desc(transactions.createdAt))
    .limit(limit)
    .offset(offset);

  return c.json({
    success: true,
    data: result,
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  });
});

// POST /api/transactions
transactionsRouter.post(
  '/',
  zValidator('json', createTransactionSchema),
  async (c) => {
    const user = c.get('user');
    const body = c.req.valid('json');
    const id = uuidv4();

    // Verify account belongs to user
    const [account] = await db
      .select()
      .from(accounts)
      .where(
        and(eq(accounts.id, body.accountId), eq(accounts.userId, user.id))
      );

    if (!account) {
      throw new HTTPException(404, { message: 'Account not found' });
    }

    // For transfers, verify destination account
    if (body.type === 'transfer' && body.transferToAccountId) {
      const [destAccount] = await db
        .select()
        .from(accounts)
        .where(
          and(
            eq(accounts.id, body.transferToAccountId),
            eq(accounts.userId, user.id)
          )
        );

      if (!destAccount) {
        throw new HTTPException(404, {
          message: 'Destination account not found',
        });
      }
    }

    await db.insert(transactions).values({
      id,
      userId: user.id,
      accountId: body.accountId,
      type: body.type,
      amount: String(body.amount),
      date: new Date(body.date),
      time: body.time || null,
      description: body.description,
      merchantName: body.merchantName || null,
      categoryId: body.categoryId || null,
      notes: body.notes || null,
      receiptId: body.receiptId || null,
      transferToAccountId: body.transferToAccountId || null,
      isPending: body.isPending,
    });

    // Update account balances
    await updateAccountBalance(body.accountId, body.amount, body.type);

    if (body.type === 'transfer' && body.transferToAccountId) {
      // Credit destination account
      await db
        .update(accounts)
        .set({
          balance: sql`balance + ${String(body.amount)}`,
        })
        .where(eq(accounts.id, body.transferToAccountId));
    }

    const [transaction] = await db
      .select()
      .from(transactions)
      .where(eq(transactions.id, id));

    return c.json({ success: true, data: transaction }, 201);
  }
);

// POST /api/transactions/batch
transactionsRouter.post(
  '/batch',
  zValidator('json', batchCreateTransactionSchema),
  async (c) => {
    const user = c.get('user');
    const { transactions: txns } = c.req.valid('json');

    const createdIds: string[] = [];

    for (const txn of txns) {
      const id = uuidv4();
      createdIds.push(id);

      await db.insert(transactions).values({
        id,
        userId: user.id,
        accountId: txn.accountId,
        type: txn.type,
        amount: String(txn.amount),
        date: new Date(txn.date),
        time: txn.time || null,
        description: txn.description,
        merchantName: txn.merchantName || null,
        categoryId: txn.categoryId || null,
        notes: txn.notes || null,
        receiptId: txn.receiptId || null,
        transferToAccountId: txn.transferToAccountId || null,
        isPending: txn.isPending,
      });

      await updateAccountBalance(txn.accountId, txn.amount, txn.type);

      if (txn.type === 'transfer' && txn.transferToAccountId) {
        await db
          .update(accounts)
          .set({
            balance: sql`balance + ${String(txn.amount)}`,
          })
          .where(eq(accounts.id, txn.transferToAccountId));
      }
    }

    const created = await db
      .select()
      .from(transactions)
      .where(sql`${transactions.id} IN (${sql.join(createdIds.map((id) => sql`${id}`), sql`, `)})`);

    return c.json({ success: true, data: created }, 201);
  }
);

// GET /api/transactions/:id
transactionsRouter.get('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [transaction] = await db
    .select()
    .from(transactions)
    .where(and(eq(transactions.id, id), eq(transactions.userId, user.id)));

  if (!transaction) {
    throw new HTTPException(404, { message: 'Transaction not found' });
  }

  return c.json({ success: true, data: transaction });
});

// PATCH /api/transactions/:id
transactionsRouter.patch(
  '/:id',
  zValidator('json', updateTransactionSchema),
  async (c) => {
    const user = c.get('user');
    const id = c.req.param('id');
    const body = c.req.valid('json');

    const [existing] = await db
      .select()
      .from(transactions)
      .where(and(eq(transactions.id, id), eq(transactions.userId, user.id)));

    if (!existing) {
      throw new HTTPException(404, { message: 'Transaction not found' });
    }

    // Reverse old balance impact
    await updateAccountBalance(
      existing.accountId,
      Number(existing.amount),
      existing.type,
      true
    );

    const updateData: Record<string, unknown> = {};
    if (body.accountId !== undefined) updateData.accountId = body.accountId;
    if (body.type !== undefined) updateData.type = body.type;
    if (body.amount !== undefined) updateData.amount = String(body.amount);
    if (body.date !== undefined) updateData.date = body.date;
    if (body.time !== undefined) updateData.time = body.time;
    if (body.description !== undefined)
      updateData.description = body.description;
    if (body.merchantName !== undefined)
      updateData.merchantName = body.merchantName;
    if (body.categoryId !== undefined) updateData.categoryId = body.categoryId;
    if (body.notes !== undefined) updateData.notes = body.notes;
    if (body.isPending !== undefined) updateData.isPending = body.isPending;

    await db.update(transactions).set(updateData).where(eq(transactions.id, id));

    // Apply new balance impact
    const newAccountId = body.accountId || existing.accountId;
    const newAmount = body.amount || Number(existing.amount);
    const newType = body.type || existing.type;
    await updateAccountBalance(newAccountId, newAmount, newType);

    const [updated] = await db
      .select()
      .from(transactions)
      .where(eq(transactions.id, id));

    return c.json({ success: true, data: updated });
  }
);

// DELETE /api/transactions/:id
transactionsRouter.delete('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [existing] = await db
    .select()
    .from(transactions)
    .where(and(eq(transactions.id, id), eq(transactions.userId, user.id)));

  if (!existing) {
    throw new HTTPException(404, { message: 'Transaction not found' });
  }

  // Reverse balance impact
  await updateAccountBalance(
    existing.accountId,
    Number(existing.amount),
    existing.type,
    true
  );

  if (existing.type === 'transfer' && existing.transferToAccountId) {
    await db
      .update(accounts)
      .set({
        balance: sql`balance - ${existing.amount}`,
      })
      .where(eq(accounts.id, existing.transferToAccountId));
  }

  await db.delete(transactions).where(eq(transactions.id, id));

  return c.json({ success: true, data: { message: 'Transaction deleted' } });
});

export default transactionsRouter;
