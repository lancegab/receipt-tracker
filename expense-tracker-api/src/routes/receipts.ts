import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { receipts, transactions as transactionsTable } from '../db/schema.js';
import { eq, and, desc } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import { processReceiptSchema, paginationSchema } from '../validators/index.js';
import { parseReceiptImage } from '../services/llm.service.js';
import type { AppEnv } from '../types/index.js';

const receiptsRouter = new Hono<AppEnv>();
receiptsRouter.use('*', authMiddleware);

// POST /api/receipts/process
receiptsRouter.post(
  '/process',
  zValidator('json', processReceiptSchema),
  async (c) => {
    const user = c.get('user');
    const { imageBase64, contentType, accountId } = c.req.valid('json');

    // Decode base64 to buffer
    let imageBuffer: Buffer;
    try {
      imageBuffer = Buffer.from(imageBase64, 'base64');
    } catch {
      throw new HTTPException(400, {
        message: 'Invalid base64 image data',
      });
    }

    // Parse via LLM
    let parsed;
    try {
      parsed = await parseReceiptImage(imageBuffer, contentType);
    } catch (err) {
      throw new HTTPException(502, {
        message: `Receipt parsing failed: ${(err as Error).message}`,
      });
    }

    // Save receipt record
    const receiptId = uuidv4();
    await db.insert(receipts).values({
      id: receiptId,
      userId: user.id,
      merchantName: parsed.merchant?.name || null,
      merchantAddress: parsed.merchant?.address || null,
      transactionDate: parsed.transaction?.date ? new Date(parsed.transaction.date) : null,
      subtotal: parsed.summary?.subtotal != null ? String(parsed.summary.subtotal) : null,
      tax: parsed.summary?.tax != null ? String(parsed.summary.tax) : null,
      total: parsed.summary?.total != null ? String(parsed.summary.total) : null,
      rawLlmResponse: parsed,
      confidenceScore: parsed.confidence_score != null ? String(parsed.confidence_score) : null,
    });

    return c.json(
      {
        success: true,
        data: {
          receipt: {
            id: receiptId,
            merchantName: parsed.merchant?.name,
            transactionDate: parsed.transaction?.date,
            total: parsed.summary?.total,
            confidenceScore: parsed.confidence_score,
          },
          lineItems: parsed.line_items,
        },
      },
      201
    );
  }
);

// GET /api/receipts
receiptsRouter.get('/', async (c) => {
  const user = c.get('user');
  const { page, limit } = paginationSchema.parse(c.req.query());
  const offset = (page - 1) * limit;

  const result = await db
    .select()
    .from(receipts)
    .where(eq(receipts.userId, user.id))
    .orderBy(desc(receipts.createdAt))
    .limit(limit)
    .offset(offset);

  return c.json({ success: true, data: result, meta: { page, limit } });
});

// GET /api/receipts/:id
receiptsRouter.get('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [receipt] = await db
    .select()
    .from(receipts)
    .where(and(eq(receipts.id, id), eq(receipts.userId, user.id)));

  if (!receipt) {
    throw new HTTPException(404, { message: 'Receipt not found' });
  }

  return c.json({ success: true, data: receipt });
});

// DELETE /api/receipts/:id
receiptsRouter.delete('/:id', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [receipt] = await db
    .select()
    .from(receipts)
    .where(and(eq(receipts.id, id), eq(receipts.userId, user.id)));

  if (!receipt) {
    throw new HTTPException(404, { message: 'Receipt not found' });
  }

  // Unlink transactions
  await db
    .update(transactionsTable)
    .set({ receiptId: null })
    .where(eq(transactionsTable.receiptId, id));

  await db.delete(receipts).where(eq(receipts.id, id));

  return c.json({ success: true, data: { message: 'Receipt deleted' } });
});

export default receiptsRouter;
