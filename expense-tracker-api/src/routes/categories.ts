import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { categories, users } from '../db/schema.js';
import { eq, and, isNull, inArray } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import { seedCategoriesForUser } from '../services/auth.service.js';
import {
  createCategorySchema,
  updateCategorySchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const categoriesRouter = new Hono<AppEnv>();
categoriesRouter.use('*', authMiddleware);

// GET /api/categories — returns only this user's categories
categoriesRouter.get('/', async (c) => {
  const user = c.get('user');
  const type = c.req.query('type') as 'expense' | 'income' | undefined;

  // Ensure user has categories (lazy migration from global system cats)
  await seedCategoriesForUser(user.id);

  const conditions = [eq(categories.userId, user.id)];
  if (type) {
    conditions.push(eq(categories.type, type));
  }

  const result = await db
    .select()
    .from(categories)
    .where(and(...conditions))
    .orderBy(categories.name);

  return c.json({ success: true, data: result });
});

// POST /api/categories
categoriesRouter.post(
  '/',
  zValidator('json', createCategorySchema),
  async (c) => {
    const user = c.get('user');
    const body = c.req.valid('json');
    const id = uuidv4();

    await db.insert(categories).values({
      id,
      userId: user.id,
      name: body.name,
      type: body.type,
      icon: body.icon || null,
      color: body.color || null,
      isSystem: false,
      isActive: true,
    });

    const [category] = await db
      .select()
      .from(categories)
      .where(eq(categories.id, id));

    return c.json({ success: true, data: category }, 201);
  }
);

// PATCH /api/categories/:id
categoriesRouter.patch(
  '/:id',
  zValidator('json', updateCategorySchema),
  async (c) => {
    const user = c.get('user');
    const id = c.req.param('id');
    const body = c.req.valid('json');

    const [existing] = await db
      .select()
      .from(categories)
      .where(
        and(eq(categories.id, id), eq(categories.userId, user.id))
      );

    if (!existing) {
      throw new HTTPException(404, { message: 'Category not found' });
    }

    const updateData: Record<string, unknown> = {};
    if (body.name !== undefined) updateData.name = body.name;
    if (body.icon !== undefined) updateData.icon = body.icon;
    if (body.color !== undefined) updateData.color = body.color;
    if (body.isActive !== undefined) updateData.isActive = body.isActive;

    await db.update(categories).set(updateData).where(eq(categories.id, id));

    const [updated] = await db
      .select()
      .from(categories)
      .where(eq(categories.id, id));

    return c.json({ success: true, data: updated });
  }
);

// POST /api/categories/dedup — migrate global system categories to per-user and clean up
categoriesRouter.post('/dedup', async (c) => {
  // 1. Delete all global system categories (userId IS NULL)
  const globalCats = await db
    .select()
    .from(categories)
    .where(isNull(categories.userId));

  if (globalCats.length > 0) {
    await db.delete(categories).where(isNull(categories.userId));
  }

  // 2. Seed categories for all existing users who don't have their own
  const allUsers = await db.select({ id: users.id }).from(users);
  let seeded = 0;
  for (const u of allUsers) {
    const existing = await db
      .select()
      .from(categories)
      .where(eq(categories.userId, u.id))
      .limit(1);
    if (existing.length === 0) {
      await seedCategoriesForUser(u.id);
      seeded++;
    }
  }

  return c.json({
    success: true,
    data: {
      globalDeleted: globalCats.length,
      usersSeeded: seeded,
      totalUsers: allUsers.length,
    },
  });
});

// DELETE /api/categories/:id
categoriesRouter.delete('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [existing] = await db
    .select()
    .from(categories)
    .where(
      and(eq(categories.id, id), eq(categories.userId, user.id))
    );

  if (!existing) {
    throw new HTTPException(404, { message: 'Category not found' });
  }

  await db.delete(categories).where(eq(categories.id, id));

  return c.json({ success: true, data: { message: 'Category deleted' } });
});

export default categoriesRouter;
