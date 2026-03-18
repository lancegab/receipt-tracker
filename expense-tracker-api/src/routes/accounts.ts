import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { accounts, transactions } from '../db/schema.js';
import { eq, and, desc, sql } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import {
  createAccountSchema,
  updateAccountSchema,
  paginationSchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const accountsRouter = new Hono<AppEnv>();
accountsRouter.use('*', authMiddleware);

// GET /api/accounts
accountsRouter.get('/', async (c) => {
  const user = c.get('user');

  const result = await db
    .select()
    .from(accounts)
    .where(eq(accounts.userId, user.id))
    .orderBy(accounts.name);

  return c.json({ success: true, data: result });
});

// POST /api/accounts
accountsRouter.post(
  '/',
  zValidator('json', createAccountSchema),
  async (c) => {
    const user = c.get('user');
    const body = c.req.valid('json');
    const id = uuidv4();

    await db.insert(accounts).values({
      id,
      userId: user.id,
      name: body.name,
      type: body.type,
      currency: body.currency,
      balance: String(body.balance),
      creditLimit: body.creditLimit != null ? String(body.creditLimit) : null,
      statementCloseDay: body.statementCloseDay,
      paymentDueDay: body.paymentDueDay,
    });

    const [account] = await db
      .select()
      .from(accounts)
      .where(eq(accounts.id, id));

    return c.json({ success: true, data: account }, 201);
  }
);

// POST /api/accounts/recalculate - Recalculate all account balances from transactions
accountsRouter.post('/recalculate', async (c) => {
  const user = c.get('user');

  const userAccounts = await db
    .select()
    .from(accounts)
    .where(eq(accounts.userId, user.id));

  const results: Array<{ id: string; name: string; oldBalance: string; newBalance: string }> = [];

  for (const account of userAccounts) {
    const [{ total }] = await db
      .select({
        total: sql<string>`COALESCE(
          SUM(CASE
            WHEN ${transactions.type} = 'expense' THEN -${transactions.amount}
            WHEN ${transactions.type} = 'income' THEN ${transactions.amount}
            ELSE 0
          END), 0)`,
      })
      .from(transactions)
      .where(eq(transactions.accountId, account.id));

    const [{ transferIn }] = await db
      .select({
        transferIn: sql<string>`COALESCE(SUM(${transactions.amount}), 0)`,
      })
      .from(transactions)
      .where(
        and(
          eq(transactions.transferToAccountId, account.id),
          eq(transactions.type, 'transfer')
        )
      );

    const newBalance = (parseFloat(total) + parseFloat(transferIn)).toFixed(2);

    await db
      .update(accounts)
      .set({ balance: newBalance })
      .where(eq(accounts.id, account.id));

    results.push({
      id: account.id,
      name: account.name,
      oldBalance: account.balance?.toString() ?? '0.00',
      newBalance,
    });
  }

  return c.json({ success: true, data: results });
});

// GET /api/accounts/:id
accountsRouter.get('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [account] = await db
    .select()
    .from(accounts)
    .where(and(eq(accounts.id, id), eq(accounts.userId, user.id)));

  if (!account) {
    throw new HTTPException(404, { message: 'Account not found' });
  }

  return c.json({ success: true, data: account });
});

// PATCH /api/accounts/:id
accountsRouter.patch(
  '/:id',
  zValidator('json', updateAccountSchema),
  async (c) => {
    const user = c.get('user');
    const id = c.req.param('id');
    const body = c.req.valid('json');

    const [existing] = await db
      .select()
      .from(accounts)
      .where(and(eq(accounts.id, id), eq(accounts.userId, user.id)));

    if (!existing) {
      throw new HTTPException(404, { message: 'Account not found' });
    }

    const updateData: Record<string, unknown> = {};
    if (body.name !== undefined) updateData.name = body.name;
    if (body.currency !== undefined) updateData.currency = body.currency;
    if (body.creditLimit !== undefined)
      updateData.creditLimit = String(body.creditLimit);
    if (body.statementCloseDay !== undefined)
      updateData.statementCloseDay = body.statementCloseDay;
    if (body.paymentDueDay !== undefined)
      updateData.paymentDueDay = body.paymentDueDay;
    if (body.isArchived !== undefined) updateData.isArchived = body.isArchived;

    await db.update(accounts).set(updateData).where(eq(accounts.id, id));

    const [updated] = await db
      .select()
      .from(accounts)
      .where(eq(accounts.id, id));

    return c.json({ success: true, data: updated });
  }
);

// DELETE /api/accounts/:id (archive)
accountsRouter.delete('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [existing] = await db
    .select()
    .from(accounts)
    .where(and(eq(accounts.id, id), eq(accounts.userId, user.id)));

  if (!existing) {
    throw new HTTPException(404, { message: 'Account not found' });
  }

  await db
    .update(accounts)
    .set({ isArchived: true })
    .where(eq(accounts.id, id));

  return c.json({ success: true, data: { message: 'Account archived' } });
});

// GET /api/accounts/:id/transactions
accountsRouter.get('/:id/transactions', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');
  const { page, limit } = paginationSchema.parse(c.req.query());

  const [account] = await db
    .select()
    .from(accounts)
    .where(and(eq(accounts.id, id), eq(accounts.userId, user.id)));

  if (!account) {
    throw new HTTPException(404, { message: 'Account not found' });
  }

  const offset = (page - 1) * limit;

  const result = await db
    .select()
    .from(transactions)
    .where(
      and(eq(transactions.accountId, id), eq(transactions.userId, user.id))
    )
    .orderBy(desc(transactions.date), desc(transactions.createdAt))
    .limit(limit)
    .offset(offset);

  return c.json({
    success: true,
    data: result,
    meta: { page, limit },
  });
});

export default accountsRouter;
