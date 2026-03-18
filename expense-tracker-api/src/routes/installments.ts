import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { creditCardInstallments, accounts } from '../db/schema.js';
import { eq, and, lte, gte } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import {
  createInstallmentSchema,
  updateInstallmentSchema,
  installmentFiltersSchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const installmentsRouter = new Hono<AppEnv>();
installmentsRouter.use('*', authMiddleware);

// Helper: compute end month from start month + total months
function computeEndMonth(startMonth: string, totalMonths: number): string {
  const [year, month] = startMonth.split('-').map(Number);
  const totalFromEpoch = year * 12 + (month - 1) + (totalMonths - 1);
  const endYear = Math.floor(totalFromEpoch / 12);
  const endMonth = (totalFromEpoch % 12) + 1;
  return `${endYear}-${String(endMonth).padStart(2, '0')}`;
}

// GET /api/installments
installmentsRouter.get('/', async (c) => {
  const user = c.get('user');
  const filters = installmentFiltersSchema.parse(c.req.query());

  const conditions = [eq(creditCardInstallments.userId, user.id)];

  if (filters.accountId) {
    conditions.push(eq(creditCardInstallments.accountId, filters.accountId));
  }
  if (filters.active !== undefined) {
    conditions.push(eq(creditCardInstallments.isActive, filters.active));
  }
  if (filters.month) {
    conditions.push(lte(creditCardInstallments.startMonth, filters.month));
    conditions.push(gte(creditCardInstallments.endMonth, filters.month));
  }

  const result = await db
    .select()
    .from(creditCardInstallments)
    .where(and(...conditions))
    .orderBy(creditCardInstallments.createdAt);

  return c.json({ success: true, data: result });
});

// POST /api/installments
installmentsRouter.post(
  '/',
  zValidator('json', createInstallmentSchema),
  async (c) => {
    const user = c.get('user');
    const body = c.req.valid('json');

    // Verify account exists and is a credit card
    const [account] = await db
      .select()
      .from(accounts)
      .where(
        and(eq(accounts.id, body.accountId), eq(accounts.userId, user.id))
      );

    if (!account) {
      throw new HTTPException(404, { message: 'Account not found' });
    }
    if (account.type !== 'credit_card') {
      throw new HTTPException(400, {
        message: 'Installments can only be added to credit card accounts',
      });
    }

    const monthlyAmount = body.totalAmount / body.totalMonths;
    const endMonth = computeEndMonth(body.startMonth, body.totalMonths);

    const id = uuidv4();
    await db.insert(creditCardInstallments).values({
      id,
      userId: user.id,
      accountId: body.accountId,
      description: body.description,
      totalAmount: String(body.totalAmount),
      monthlyAmount: String(monthlyAmount.toFixed(2)),
      totalMonths: body.totalMonths,
      startMonth: body.startMonth,
      endMonth,
      categoryId: body.categoryId || null,
      isActive: true,
    });

    const [created] = await db
      .select()
      .from(creditCardInstallments)
      .where(eq(creditCardInstallments.id, id));

    return c.json({ success: true, data: created }, 201);
  }
);

// GET /api/installments/:id
installmentsRouter.get('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [installment] = await db
    .select()
    .from(creditCardInstallments)
    .where(
      and(
        eq(creditCardInstallments.id, id),
        eq(creditCardInstallments.userId, user.id)
      )
    );

  if (!installment) {
    throw new HTTPException(404, { message: 'Installment not found' });
  }

  return c.json({ success: true, data: installment });
});

// PATCH /api/installments/:id
installmentsRouter.patch(
  '/:id',
  zValidator('json', updateInstallmentSchema),
  async (c) => {
    const user = c.get('user');
    const id = c.req.param('id');
    const body = c.req.valid('json');

    const [existing] = await db
      .select()
      .from(creditCardInstallments)
      .where(
        and(
          eq(creditCardInstallments.id, id),
          eq(creditCardInstallments.userId, user.id)
        )
      );

    if (!existing) {
      throw new HTTPException(404, { message: 'Installment not found' });
    }

    const updates: Record<string, unknown> = {};
    if (body.description !== undefined) updates.description = body.description;
    if (body.categoryId !== undefined) updates.categoryId = body.categoryId;
    if (body.isActive !== undefined) updates.isActive = body.isActive;

    if (Object.keys(updates).length > 0) {
      await db
        .update(creditCardInstallments)
        .set(updates)
        .where(eq(creditCardInstallments.id, id));
    }

    const [updated] = await db
      .select()
      .from(creditCardInstallments)
      .where(eq(creditCardInstallments.id, id));

    return c.json({ success: true, data: updated });
  }
);

// DELETE /api/installments/:id (soft delete)
installmentsRouter.delete('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [existing] = await db
    .select()
    .from(creditCardInstallments)
    .where(
      and(
        eq(creditCardInstallments.id, id),
        eq(creditCardInstallments.userId, user.id)
      )
    );

  if (!existing) {
    throw new HTTPException(404, { message: 'Installment not found' });
  }

  await db
    .update(creditCardInstallments)
    .set({ isActive: false })
    .where(eq(creditCardInstallments.id, id));

  return c.json({
    success: true,
    data: { message: 'Installment deactivated' },
  });
});

export default installmentsRouter;
