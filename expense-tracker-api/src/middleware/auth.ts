import { Context, Next } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { jwtVerify } from 'jose';
import type { AuthUser, JWTPayload } from '../types/index.js';

const getSecret = () =>
  new TextEncoder().encode(process.env.JWT_SECRET!);

export async function authMiddleware(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new HTTPException(401, { message: 'Missing or invalid authorization header' });
  }

  const token = authHeader.slice(7);

  try {
    const { payload } = await jwtVerify(token, getSecret()) as { payload: JWTPayload };

    const user: AuthUser = {
      id: payload.sub,
      email: payload.email,
    };

    c.set('user', user);
    await next();
  } catch {
    throw new HTTPException(401, { message: 'Invalid or expired token' });
  }
}
