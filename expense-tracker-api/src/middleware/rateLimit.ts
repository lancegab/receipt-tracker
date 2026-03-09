import { Context, Next } from 'hono';
import { HTTPException } from 'hono/http-exception';

interface RateLimitEntry {
  count: number;
  resetTime: number;
}

interface RateLimitOptions {
  windowMs: number;
  maxRequests: number;
}

export function rateLimitMiddleware({ windowMs, maxRequests }: RateLimitOptions) {
  const store = new Map<string, RateLimitEntry>();

  // Cleanup expired entries every 60 seconds
  setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of store) {
      if (entry.resetTime <= now) {
        store.delete(key);
      }
    }
  }, 60_000);

  return async (c: Context, next: Next) => {
    const ip = c.req.header('x-forwarded-for')?.split(',')[0]?.trim()
      || c.req.header('x-real-ip')
      || 'unknown';

    const now = Date.now();
    const entry = store.get(ip);

    if (!entry || entry.resetTime <= now) {
      store.set(ip, { count: 1, resetTime: now + windowMs });
      await next();
      return;
    }

    entry.count++;

    if (entry.count > maxRequests) {
      const retryAfter = Math.ceil((entry.resetTime - now) / 1000);
      c.header('Retry-After', String(retryAfter));
      throw new HTTPException(429, { message: 'Too many requests, please try again later' });
    }

    await next();
  };
}
