import { Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { ZodError } from 'zod';

export function errorHandler(err: Error, c: Context) {
  if (err instanceof HTTPException) {
    return c.json(
      { success: false, error: err.message },
      err.status
    );
  }

  if (err instanceof ZodError) {
    return c.json(
      {
        success: false,
        error: 'Validation error',
        details: err.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      },
      400
    );
  }

  console.error('Unhandled error:', err);
  return c.json(
    { success: false, error: 'Internal server error' },
    500
  );
}
