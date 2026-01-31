import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { categories } from '../db/schema.js';
import { eq, and, or, isNull } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import {
  createCategorySchema,
  updateCategorySchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const categoriesRouter = new Hono<AppEnv>();
categoriesRouter.use('*', authMiddleware);

// GET /api/categories
categoriesRouter.get('/', async (c) => {
  const user = c.get('user');
  const type = c.req.query('type') as 'expense' | 'income' | undefined;

  const conditions = [
    or(eq(categories.userId, user.id), isNull(categories.userId)),
  ];

  if (type) {
    conditions.push(eq(categories.type, type));
  }

  const result = await db
    .select()
    .from(categories)
    .where(and(...conditions))
    .orderBy(categories.isSystem, categories.name);

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

    if (existing.isSystem) {
      throw new HTTPException(403, {
        message: 'Cannot modify system categories',
      });
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

  if (existing.isSystem) {
    throw new HTTPException(403, {
      message: 'Cannot delete system categories',
    });
  }

  await db.delete(categories).where(eq(categories.id, id));

  return c.json({ success: true, data: { message: 'Category deleted' } });
});

export default categoriesRouter;
