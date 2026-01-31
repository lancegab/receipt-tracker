import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { receipts, transactions as transactionsTable } from '../db/schema.js';
import { eq, and, desc } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import { processReceiptSchema, paginationSchema } from '../validators/index.js';
import {
  getPresignedUploadUrl,
  getPresignedViewUrl,
  getObjectBuffer,
  deleteObject,
} from '../services/s3.service.js';
import { parseReceiptImage } from '../services/llm.service.js';
import type { AppEnv } from '../types/index.js';

const receiptsRouter = new Hono<AppEnv>();
receiptsRouter.use('*', authMiddleware);

// GET /api/receipts/presigned-url
receiptsRouter.get('/presigned-url', async (c) => {
  const user = c.get('user');
  const filename = c.req.query('filename') || 'receipt.jpg';
  const contentType = c.req.query('contentType') || 'image/jpeg';

  const result = await getPresignedUploadUrl(user.id, filename, contentType);

  return c.json({ success: true, data: result });
});

// POST /api/receipts/process
receiptsRouter.post(
  '/process',
  zValidator('json', processReceiptSchema),
  async (c) => {
    const user = c.get('user');
    const { s3Key, accountId } = c.req.valid('json');

    // Fetch image from S3
    let imageBuffer: Buffer;
    try {
      imageBuffer = await getObjectBuffer(s3Key);
    } catch {
      throw new HTTPException(400, {
        message: 'Failed to fetch image from storage',
      });
    }

    // Parse via LLM
    let parsed;
    try {
      parsed = await parseReceiptImage(imageBuffer);
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
      s3Key,
      merchantName: parsed.merchant?.name || null,
      merchantAddress: parsed.merchant?.address || null,
      transactionDate: parsed.transaction?.date ? new Date(parsed.transaction.date) : null,
      subtotal: parsed.summary?.subtotal != null ? String(parsed.summary.subtotal) : null,
      tax: parsed.summary?.tax != null ? String(parsed.summary.tax) : null,
      total: parsed.summary?.total != null ? String(parsed.summary.total) : null,
      rawLlmResponse: parsed,
      confidenceScore: parsed.confidence_score != null ? String(parsed.confidence_score) : null,
    });

    // Get presigned URL for viewing
    const imageUrl = await getPresignedViewUrl(s3Key);

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
            imageUrl,
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

// GET /api/receipts/:id/image-url
receiptsRouter.get('/:id/image-url', async (c) => {
  const user = c.get('user');
  const id = c.req.param('id');

  const [receipt] = await db
    .select()
    .from(receipts)
    .where(and(eq(receipts.id, id), eq(receipts.userId, user.id)));

  if (!receipt) {
    throw new HTTPException(404, { message: 'Receipt not found' });
  }

  const imageUrl = await getPresignedViewUrl(receipt.s3Key);

  return c.json({ success: true, data: { imageUrl } });
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

  // Delete from S3
  try {
    await deleteObject(receipt.s3Key);
    if (receipt.s3ThumbnailKey) {
      await deleteObject(receipt.s3ThumbnailKey);
    }
  } catch {
    // Log but don't fail if S3 delete fails
    console.error('Failed to delete S3 objects for receipt:', id);
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
