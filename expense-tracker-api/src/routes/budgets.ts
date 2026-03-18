import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import {
  budgets,
  budgetItems,
  budgetItemWeeklyAdjustments,
  budgetGroupMembers,
  transactions,
  accounts,
  categories,
  creditCardInstallments,
} from '../db/schema.js';
import { eq, and, sql, gte, lte, inArray } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import {
  createBudgetSchema,
  updateBudgetSchema,
  copyBudgetSchema,
  createBudgetItemSchema,
  updateBudgetItemSchema,
  generateBudgetItemsSchema,
  weeklyAdjustmentSchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const budgetsRouter = new Hono<AppEnv>();
budgetsRouter.use('*', authMiddleware);

// Helper: verify budget access for personal or group budgets
async function verifyBudgetAccess(
  budgetId: string,
  userId: string
): Promise<{
  budget: typeof budgets.$inferSelect;
  role: 'personal' | 'owner' | 'member';
}> {
  const [budget] = await db
    .select()
    .from(budgets)
    .where(eq(budgets.id, budgetId));

  if (!budget) {
    throw new HTTPException(404, { message: 'Budget not found' });
  }

  if (budget.userId && budget.userId === userId) {
    return { budget, role: 'personal' };
  }

  if (budget.groupId) {
    const [membership] = await db
      .select()
      .from(budgetGroupMembers)
      .where(
        and(
          eq(budgetGroupMembers.groupId, budget.groupId),
          eq(budgetGroupMembers.userId, userId)
        )
      );
    if (!membership) {
      throw new HTTPException(403, { message: 'Not a member of this group' });
    }
    return {
      budget,
      role: membership.role as 'owner' | 'member',
    };
  }

  throw new HTTPException(403, { message: 'Access denied' });
}

// Helper: get month date range
function getMonthRange(month: string): { start: string; end: string } {
  const [year, m] = month.split('-').map(Number);
  const lastDay = new Date(year, m, 0).getDate();
  return {
    start: `${month}-01`,
    end: `${month}-${String(lastDay).padStart(2, '0')}`,
  };
}

// Helper: determine week number (1-4) from day of month
function getWeekNumber(day: number): number {
  if (day <= 7) return 1;
  if (day <= 14) return 2;
  if (day <= 21) return 3;
  return 4;
}

// ── Budget CRUD ────────────────────────────────────────────────

// GET /api/budgets
budgetsRouter.get('/', async (c) => {
  const user = c.get('user');
  const month = c.req.query('month');
  const groupId = c.req.query('groupId');

  if (groupId) {
    // Verify membership
    const [membership] = await db
      .select()
      .from(budgetGroupMembers)
      .where(
        and(
          eq(budgetGroupMembers.groupId, groupId),
          eq(budgetGroupMembers.userId, user.id)
        )
      );
    if (!membership) {
      throw new HTTPException(403, { message: 'Not a member of this group' });
    }

    const conditions = [eq(budgets.groupId, groupId)];
    if (month) conditions.push(eq(budgets.month, month));

    const result = await db
      .select()
      .from(budgets)
      .where(and(...conditions));

    return c.json({ success: true, data: result });
  }

  // Personal budgets
  const conditions = [eq(budgets.userId, user.id)];
  if (month) conditions.push(eq(budgets.month, month));

  const result = await db
    .select()
    .from(budgets)
    .where(and(...conditions));

  return c.json({ success: true, data: result });
});

// POST /api/budgets
budgetsRouter.post(
  '/',
  zValidator('json', createBudgetSchema),
  async (c) => {
    const user = c.get('user');
    const body = c.req.valid('json');

    if (body.groupId) {
      const [membership] = await db
        .select()
        .from(budgetGroupMembers)
        .where(
          and(
            eq(budgetGroupMembers.groupId, body.groupId),
            eq(budgetGroupMembers.userId, user.id)
          )
        );
      if (!membership) {
        throw new HTTPException(403, {
          message: 'Not a member of this group',
        });
      }
    }

    const id = uuidv4();
    await db.insert(budgets).values({
      id,
      userId: body.groupId ? null : user.id,
      groupId: body.groupId || null,
      name: body.name,
      month: body.month,
      currency: body.currency,
      notes: body.notes || null,
    });

    const [created] = await db
      .select()
      .from(budgets)
      .where(eq(budgets.id, id));

    return c.json({ success: true, data: created }, 201);
  }
);

// GET /api/budgets/:id
budgetsRouter.get('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');
  const { budget } = await verifyBudgetAccess(id, user.id);
  return c.json({ success: true, data: budget });
});

// PATCH /api/budgets/:id
budgetsRouter.patch(
  '/:id',
  zValidator('json', updateBudgetSchema),
  async (c) => {
    const user = c.get('user');
    const id = c.req.param('id');
    const body = c.req.valid('json');

    await verifyBudgetAccess(id, user.id);

    const updates: Record<string, unknown> = {};
    if (body.name !== undefined) updates.name = body.name;
    if (body.notes !== undefined) updates.notes = body.notes;

    if (Object.keys(updates).length > 0) {
      await db.update(budgets).set(updates).where(eq(budgets.id, id));
    }

    const [updated] = await db
      .select()
      .from(budgets)
      .where(eq(budgets.id, id));

    return c.json({ success: true, data: updated });
  }
);

// DELETE /api/budgets/:id
budgetsRouter.delete('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');
  const { role } = await verifyBudgetAccess(id, user.id);

  if (role === 'member') {
    throw new HTTPException(403, {
      message: 'Only the owner can delete a group budget',
    });
  }

  await db.delete(budgets).where(eq(budgets.id, id));
  return c.json({ success: true, data: { message: 'Budget deleted' } });
});

// POST /api/budgets/:id/copy
budgetsRouter.post(
  '/:id/copy',
  zValidator('json', copyBudgetSchema),
  async (c) => {
    const user = c.get('user');
    const id = c.req.param('id');
    const { targetMonth } = c.req.valid('json');

    const { budget } = await verifyBudgetAccess(id, user.id);

    // Get all items from source budget
    const items = await db
      .select()
      .from(budgetItems)
      .where(eq(budgetItems.budgetId, id));

    // Create new budget
    const newBudgetId = uuidv4();
    await db.insert(budgets).values({
      id: newBudgetId,
      userId: budget.userId,
      groupId: budget.groupId,
      name: budget.name,
      month: targetMonth,
      currency: budget.currency,
      notes: budget.notes,
    });

    // Copy items with reset spend
    for (const item of items) {
      await db.insert(budgetItems).values({
        id: uuidv4(),
        budgetId: newBudgetId,
        name: item.name,
        budgetedAmount: item.budgetedAmount,
        linkedAccountId: item.linkedAccountId,
        linkedCategoryId: item.linkedCategoryId,
        manualSpent: '0.00',
        sortOrder: item.sortOrder,
      });
    }

    const [created] = await db
      .select()
      .from(budgets)
      .where(eq(budgets.id, newBudgetId));

    return c.json({ success: true, data: created }, 201);
  }
);

// GET /api/budgets/:id/summary — computed summary with auto-tracked spend
budgetsRouter.get('/:id/summary', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const { budget } = await verifyBudgetAccess(id, user.id);
  const { start, end } = getMonthRange(budget.month);

  const items = await db
    .select()
    .from(budgetItems)
    .where(eq(budgetItems.budgetId, id))
    .orderBy(budgetItems.sortOrder);

  // Get all weekly adjustments for this budget's items
  const itemIds = items.map((i) => i.id);
  const weeklyAdj =
    itemIds.length > 0
      ? await db
          .select()
          .from(budgetItemWeeklyAdjustments)
          .where(inArray(budgetItemWeeklyAdjustments.budgetItemId, itemIds))
      : [];

  // Build weekly adjustments map: itemId -> week -> adjustment
  const adjMap = new Map<string, Map<number, { amount: string; notes: string | null }>>();
  for (const adj of weeklyAdj) {
    if (!adjMap.has(adj.budgetItemId)) adjMap.set(adj.budgetItemId, new Map());
    adjMap.get(adj.budgetItemId)!.set(adj.week, {
      amount: adj.manualAdjustment || '0.00',
      notes: adj.notes,
    });
  }

  // Determine which user IDs to include for transaction queries
  let userIds: string[] = [user.id];
  if (budget.groupId) {
    const members = await db
      .select({ userId: budgetGroupMembers.userId })
      .from(budgetGroupMembers)
      .where(eq(budgetGroupMembers.groupId, budget.groupId));
    userIds = members.map((m) => m.userId);
  }

  const summaryItems = [];
  let totalBudgeted = 0;
  let totalSpent = 0;

  for (const item of items) {
    let autoSpent = 0;
    const weeklyBreakdown: Record<
      number,
      { autoSpent: number; manualAdjustment: number }
    > = {
      1: { autoSpent: 0, manualAdjustment: 0 },
      2: { autoSpent: 0, manualAdjustment: 0 },
      3: { autoSpent: 0, manualAdjustment: 0 },
      4: { autoSpent: 0, manualAdjustment: 0 },
    };

    // Auto-calculate from transactions
    if (item.linkedAccountId || item.linkedCategoryId) {
      const conditions = [
        inArray(transactions.userId, userIds),
        gte(transactions.date, new Date(start)),
        lte(transactions.date, new Date(end)),
        eq(transactions.type, 'expense'),
      ];

      if (item.linkedAccountId) {
        conditions.push(eq(transactions.accountId, item.linkedAccountId));
      }
      if (item.linkedCategoryId) {
        conditions.push(eq(transactions.categoryId, item.linkedCategoryId));
      }

      const txns = await db
        .select({
          amount: transactions.amount,
          date: transactions.date,
        })
        .from(transactions)
        .where(and(...conditions));

      for (const txn of txns) {
        const amt = parseFloat(txn.amount);
        autoSpent += amt;
        const txnDate = new Date(txn.date);
        const week = getWeekNumber(txnDate.getDate());
        weeklyBreakdown[week].autoSpent += amt;
      }
    }

    // Apply weekly manual adjustments
    const itemAdj = adjMap.get(item.id);
    if (itemAdj) {
      for (const [week, adj] of itemAdj) {
        weeklyBreakdown[week].manualAdjustment = parseFloat(adj.amount);
      }
    }

    // Calculate installment amount for credit card items
    let installmentAmount = 0;
    if (item.linkedAccountId) {
      const installments = await db
        .select({ monthlyAmount: creditCardInstallments.monthlyAmount })
        .from(creditCardInstallments)
        .where(
          and(
            eq(creditCardInstallments.accountId, item.linkedAccountId),
            eq(creditCardInstallments.isActive, true),
            lte(creditCardInstallments.startMonth, budget.month),
            gte(creditCardInstallments.endMonth, budget.month)
          )
        );

      for (const inst of installments) {
        installmentAmount += parseFloat(inst.monthlyAmount);
      }
    }

    const manualSpent = parseFloat(item.manualSpent || '0');
    // Sum weekly manual adjustments (negative = spending)
    const weeklyManualTotal = Object.values(weeklyBreakdown).reduce(
      (sum, w) => sum + Math.abs(w.manualAdjustment),
      0
    );
    const itemTotalSpent = autoSpent + manualSpent + weeklyManualTotal + installmentAmount;
    const budgetedAmount = parseFloat(item.budgetedAmount);
    const remaining = budgetedAmount - itemTotalSpent;

    totalBudgeted += budgetedAmount;
    totalSpent += itemTotalSpent;

    summaryItems.push({
      id: item.id,
      name: item.name,
      budgetedAmount: budgetedAmount.toFixed(2),
      linkedAccountId: item.linkedAccountId,
      linkedCategoryId: item.linkedCategoryId,
      manualSpent: manualSpent.toFixed(2),
      autoSpent: autoSpent.toFixed(2),
      installmentAmount: installmentAmount.toFixed(2),
      totalSpent: itemTotalSpent.toFixed(2),
      remaining: remaining.toFixed(2),
      sortOrder: item.sortOrder,
      weeklyBreakdown: {
        1: {
          autoSpent: weeklyBreakdown[1].autoSpent.toFixed(2),
          manualAdjustment: weeklyBreakdown[1].manualAdjustment.toFixed(2),
        },
        2: {
          autoSpent: weeklyBreakdown[2].autoSpent.toFixed(2),
          manualAdjustment: weeklyBreakdown[2].manualAdjustment.toFixed(2),
        },
        3: {
          autoSpent: weeklyBreakdown[3].autoSpent.toFixed(2),
          manualAdjustment: weeklyBreakdown[3].manualAdjustment.toFixed(2),
        },
        4: {
          autoSpent: weeklyBreakdown[4].autoSpent.toFixed(2),
          manualAdjustment: weeklyBreakdown[4].manualAdjustment.toFixed(2),
        },
      },
    });
  }

  return c.json({
    success: true,
    data: {
      budget,
      items: summaryItems,
      totals: {
        totalBudgeted: totalBudgeted.toFixed(2),
        totalSpent: totalSpent.toFixed(2),
        totalRemaining: (totalBudgeted - totalSpent).toFixed(2),
      },
    },
  });
});

// ── Budget Items ───────────────────────────────────────────────

// POST /api/budgets/:id/items
budgetsRouter.post(
  '/:id/items',
  zValidator('json', createBudgetItemSchema),
  async (c) => {
    const user = c.get('user');
    const budgetId = c.req.param('id');
    const body = c.req.valid('json');

    await verifyBudgetAccess(budgetId, user.id);

    const itemId = uuidv4();
    await db.insert(budgetItems).values({
      id: itemId,
      budgetId,
      name: body.name,
      budgetedAmount: String(body.budgetedAmount),
      linkedAccountId: body.linkedAccountId || null,
      linkedCategoryId: body.linkedCategoryId || null,
      sortOrder: body.sortOrder,
    });

    const [created] = await db
      .select()
      .from(budgetItems)
      .where(eq(budgetItems.id, itemId));

    return c.json({ success: true, data: created }, 201);
  }
);

// PATCH /api/budgets/:id/items/:itemId
budgetsRouter.patch(
  '/:id/items/:itemId',
  zValidator('json', updateBudgetItemSchema),
  async (c) => {
    const user = c.get('user');
    const budgetId = c.req.param('id');
    const itemId = c.req.param('itemId');
    const body = c.req.valid('json');

    await verifyBudgetAccess(budgetId, user.id);

    const [existing] = await db
      .select()
      .from(budgetItems)
      .where(
        and(eq(budgetItems.id, itemId), eq(budgetItems.budgetId, budgetId))
      );

    if (!existing) {
      throw new HTTPException(404, { message: 'Budget item not found' });
    }

    const updates: Record<string, unknown> = {};
    if (body.name !== undefined) updates.name = body.name;
    if (body.budgetedAmount !== undefined)
      updates.budgetedAmount = String(body.budgetedAmount);
    if (body.linkedAccountId !== undefined)
      updates.linkedAccountId = body.linkedAccountId;
    if (body.linkedCategoryId !== undefined)
      updates.linkedCategoryId = body.linkedCategoryId;
    if (body.manualSpent !== undefined)
      updates.manualSpent = String(body.manualSpent);
    if (body.sortOrder !== undefined) updates.sortOrder = body.sortOrder;

    if (Object.keys(updates).length > 0) {
      await db
        .update(budgetItems)
        .set(updates)
        .where(eq(budgetItems.id, itemId));
    }

    const [updated] = await db
      .select()
      .from(budgetItems)
      .where(eq(budgetItems.id, itemId));

    return c.json({ success: true, data: updated });
  }
);

// DELETE /api/budgets/:id/items/:itemId
budgetsRouter.delete('/:id/items/:itemId', async (c) => {
  const user = c.get('user');
  const budgetId = c.req.param('id');
  const itemId = c.req.param('itemId');

  await verifyBudgetAccess(budgetId, user.id);

  const [existing] = await db
    .select()
    .from(budgetItems)
    .where(
      and(eq(budgetItems.id, itemId), eq(budgetItems.budgetId, budgetId))
    );

  if (!existing) {
    throw new HTTPException(404, { message: 'Budget item not found' });
  }

  await db.delete(budgetItems).where(eq(budgetItems.id, itemId));
  return c.json({ success: true, data: { message: 'Budget item deleted' } });
});

// POST /api/budgets/:id/items/generate
budgetsRouter.post(
  '/:id/items/generate',
  zValidator('json', generateBudgetItemsSchema),
  async (c) => {
    const user = c.get('user');
    const budgetId = c.req.param('id');
    const body = c.req.valid('json');

    await verifyBudgetAccess(budgetId, user.id);

    // Get existing items to avoid duplicates
    const existingItems = await db
      .select()
      .from(budgetItems)
      .where(eq(budgetItems.budgetId, budgetId));

    const existingAccountIds = new Set(
      existingItems
        .map((i) => i.linkedAccountId)
        .filter(Boolean)
    );
    const existingCategoryIds = new Set(
      existingItems
        .map((i) => i.linkedCategoryId)
        .filter(Boolean)
    );

    const created: string[] = [];
    let sortOrder = existingItems.length;

    if (body.fromAccounts && body.accountTypes) {
      const userAccounts = await db
        .select()
        .from(accounts)
        .where(
          and(
            eq(accounts.userId, user.id),
            eq(accounts.isArchived, false),
            inArray(accounts.type, body.accountTypes)
          )
        );

      for (const acct of userAccounts) {
        if (existingAccountIds.has(acct.id)) continue;
        const itemId = uuidv4();
        await db.insert(budgetItems).values({
          id: itemId,
          budgetId,
          name: acct.name,
          budgetedAmount: '0.00',
          linkedAccountId: acct.id,
          sortOrder: sortOrder++,
        });
        created.push(itemId);
      }
    }

    if (body.fromCategories) {
      const userCategories = await db
        .select()
        .from(categories)
        .where(
          and(
            eq(categories.type, body.categoryType),
            eq(categories.isActive, true)
          )
        );

      // Filter to user's own categories
      const filtered = userCategories.filter(
        (cat) => cat.userId === user.id
      );

      for (const cat of filtered) {
        if (existingCategoryIds.has(cat.id)) continue;
        const itemId = uuidv4();
        await db.insert(budgetItems).values({
          id: itemId,
          budgetId,
          name: cat.name,
          budgetedAmount: '0.00',
          linkedCategoryId: cat.id,
          sortOrder: sortOrder++,
        });
        created.push(itemId);
      }
    }

    return c.json({
      success: true,
      data: { generatedCount: created.length, itemIds: created },
    });
  }
);

// PATCH /api/budgets/:id/items/:itemId/weekly/:week
budgetsRouter.patch(
  '/:id/items/:itemId/weekly/:week',
  zValidator('json', weeklyAdjustmentSchema),
  async (c) => {
    const user = c.get('user');
    const budgetId = c.req.param('id');
    const itemId = c.req.param('itemId');
    const week = parseInt(c.req.param('week'));
    const body = c.req.valid('json');

    if (week < 1 || week > 4) {
      throw new HTTPException(400, { message: 'Week must be 1-4' });
    }

    await verifyBudgetAccess(budgetId, user.id);

    const [item] = await db
      .select()
      .from(budgetItems)
      .where(
        and(eq(budgetItems.id, itemId), eq(budgetItems.budgetId, budgetId))
      );

    if (!item) {
      throw new HTTPException(404, { message: 'Budget item not found' });
    }

    // Upsert weekly adjustment
    const [existing] = await db
      .select()
      .from(budgetItemWeeklyAdjustments)
      .where(
        and(
          eq(budgetItemWeeklyAdjustments.budgetItemId, itemId),
          eq(budgetItemWeeklyAdjustments.week, week)
        )
      );

    if (existing) {
      await db
        .update(budgetItemWeeklyAdjustments)
        .set({
          manualAdjustment: String(body.manualAdjustment),
          notes: body.notes || null,
        })
        .where(eq(budgetItemWeeklyAdjustments.id, existing.id));
    } else {
      await db.insert(budgetItemWeeklyAdjustments).values({
        id: uuidv4(),
        budgetItemId: itemId,
        week,
        manualAdjustment: String(body.manualAdjustment),
        notes: body.notes || null,
      });
    }

    return c.json({ success: true, data: { message: 'Weekly adjustment saved' } });
  }
);

export default budgetsRouter;
