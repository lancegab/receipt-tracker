import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { v4 as uuidv4 } from 'uuid';
import bcrypt from 'bcryptjs';
import {
  registerSchema,
  loginSchema,
  oauthSchema,
  updateProfileSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
} from '../validators/index.js';
import {
  hashPassword,
  verifyPassword,
  generateAccessToken,
  generateRefreshToken,
  rotateRefreshToken,
  revokeRefreshTokens,
  findUserByEmail,
  findUserById,
  createUser,
} from '../services/auth.service.js';
import { sendPasswordResetEmail } from '../services/email.service.js';
import { authMiddleware } from '../middleware/auth.js';
import { db } from '../db/index.js';
import { users, passwordResetTokens } from '../db/schema.js';
import { eq, and, isNull } from 'drizzle-orm';
import type { AppEnv } from '../types/index.js';

const APPLE_JWKS = createRemoteJWKSet(
  new URL('https://appleid.apple.com/auth/keys')
);

const auth = new Hono<AppEnv>();

// POST /api/auth/register
auth.post('/register', zValidator('json', registerSchema), async (c) => {
  const { email, password, displayName } = c.req.valid('json');

  const existing = await findUserByEmail(email);
  if (existing) {
    throw new HTTPException(409, { message: 'Email already registered' });
  }

  const passwordHash = await hashPassword(password);
  const user = await createUser({
    email,
    passwordHash,
    displayName,
    authProvider: 'email',
  });

  if (!user) {
    throw new HTTPException(500, { message: 'Failed to create user' });
  }

  const accessToken = await generateAccessToken(user.id, user.email);
  const refreshToken = await generateRefreshToken(user.id);

  return c.json({
    success: true,
    data: {
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        defaultCurrency: user.defaultCurrency,
      },
      accessToken,
      refreshToken,
    },
  }, 201);
});

// POST /api/auth/login
auth.post('/login', zValidator('json', loginSchema), async (c) => {
  const { email, password } = c.req.valid('json');

  const user = await findUserByEmail(email);
  if (!user || !user.passwordHash) {
    throw new HTTPException(401, { message: 'Invalid email or password' });
  }

  const valid = await verifyPassword(password, user.passwordHash);
  if (!valid) {
    throw new HTTPException(401, { message: 'Invalid email or password' });
  }

  const accessToken = await generateAccessToken(user.id, user.email);
  const refreshToken = await generateRefreshToken(user.id);

  return c.json({
    success: true,
    data: {
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        defaultCurrency: user.defaultCurrency,
      },
      accessToken,
      refreshToken,
    },
  });
});

// POST /api/auth/google
auth.post('/google', zValidator('json', oauthSchema), async (c) => {
  const { idToken } = c.req.valid('json');

  // Verify Google ID token
  let payload: { email: string; sub: string; name?: string };
  try {
    const resp = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`
    );
    if (!resp.ok) throw new Error('Invalid token');
    payload = (await resp.json()) as { email: string; sub: string; name?: string };
  } catch {
    throw new HTTPException(401, { message: 'Invalid Google token' });
  }

  let user = await findUserByEmail(payload.email);
  if (!user) {
    user = await createUser({
      email: payload.email,
      displayName: payload.name,
      authProvider: 'google',
      authProviderId: payload.sub,
    });
  }

  if (!user) {
    throw new HTTPException(500, { message: 'Failed to create user' });
  }

  const accessToken = await generateAccessToken(user.id, user.email);
  const refreshToken = await generateRefreshToken(user.id);

  return c.json({
    success: true,
    data: {
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        defaultCurrency: user.defaultCurrency,
      },
      accessToken,
      refreshToken,
    },
  });
});

// POST /api/auth/facebook
auth.post('/facebook', zValidator('json', oauthSchema), async (c) => {
  const { idToken: accessTokenFb } = c.req.valid('json');

  let payload: { email: string; id: string; name?: string };
  try {
    const resp = await fetch(
      `https://graph.facebook.com/me?fields=id,name,email&access_token=${accessTokenFb}`
    );
    if (!resp.ok) throw new Error('Invalid token');
    payload = (await resp.json()) as { email: string; id: string; name?: string };
  } catch {
    throw new HTTPException(401, { message: 'Invalid Facebook token' });
  }

  if (!payload.email) {
    throw new HTTPException(400, { message: 'Email not provided by Facebook' });
  }

  let user = await findUserByEmail(payload.email);
  if (!user) {
    user = await createUser({
      email: payload.email,
      displayName: payload.name,
      authProvider: 'facebook',
      authProviderId: payload.id,
    });
  }

  if (!user) {
    throw new HTTPException(500, { message: 'Failed to create user' });
  }

  const accessToken = await generateAccessToken(user.id, user.email);
  const refreshToken = await generateRefreshToken(user.id);

  return c.json({
    success: true,
    data: {
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        defaultCurrency: user.defaultCurrency,
      },
      accessToken,
      refreshToken,
    },
  });
});

// POST /api/auth/apple
auth.post('/apple', zValidator('json', oauthSchema), async (c) => {
  const { idToken } = c.req.valid('json');

  // Verify Apple ID token using JWKS
  let payload: { email?: string; sub: string };
  try {
    const audience = process.env.APPLE_SERVICE_ID || process.env.APPLE_BUNDLE_ID;
    const { payload: verified } = await jwtVerify(idToken, APPLE_JWKS, {
      issuer: 'https://appleid.apple.com',
      audience: audience || undefined,
    });
    payload = { email: verified.email as string | undefined, sub: verified.sub! };
  } catch {
    throw new HTTPException(401, { message: 'Invalid Apple token' });
  }

  if (!payload.email) {
    throw new HTTPException(400, { message: 'Email not provided by Apple' });
  }

  let user = await findUserByEmail(payload.email);
  if (!user) {
    user = await createUser({
      email: payload.email,
      authProvider: 'apple',
      authProviderId: payload.sub,
    });
  }

  if (!user) {
    throw new HTTPException(500, { message: 'Failed to create user' });
  }

  const accessToken = await generateAccessToken(user.id, user.email);
  const refreshToken = await generateRefreshToken(user.id);

  return c.json({
    success: true,
    data: {
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        defaultCurrency: user.defaultCurrency,
      },
      accessToken,
      refreshToken,
    },
  });
});

// POST /api/auth/refresh
auth.post('/refresh', async (c) => {
  const body = await c.req.json<{ userId: string; refreshToken: string }>();

  if (!body.userId || !body.refreshToken) {
    throw new HTTPException(400, {
      message: 'userId and refreshToken are required',
    });
  }

  const tokens = await rotateRefreshToken(body.userId, body.refreshToken);
  if (!tokens) {
    throw new HTTPException(401, { message: 'Invalid refresh token' });
  }

  return c.json({ success: true, data: tokens });
});

// POST /api/auth/logout
auth.post('/logout', authMiddleware, async (c) => {
  const user = c.get('user');
  await revokeRefreshTokens(user.id);
  return c.json({ success: true, data: { message: 'Logged out' } });
});

// POST /api/auth/forgot-password
auth.post(
  '/forgot-password',
  zValidator('json', forgotPasswordSchema),
  async (c) => {
    const { email } = c.req.valid('json');

    // Always return success to prevent email enumeration
    const user = await findUserByEmail(email);
    if (user && user.authProvider === 'email') {
      const token = uuidv4();
      const tokenHash = await bcrypt.hash(token, 10);
      const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

      await db.insert(passwordResetTokens).values({
        id: uuidv4(),
        userId: user.id,
        tokenHash,
        expiresAt,
      });

      await sendPasswordResetEmail(email, token);
    }

    return c.json({
      success: true,
      data: { message: 'If that email exists, a reset link has been sent' },
    });
  }
);

// POST /api/auth/reset-password
auth.post(
  '/reset-password',
  zValidator('json', resetPasswordSchema),
  async (c) => {
    const { token, password } = c.req.valid('json');

    // Find unused, non-expired reset tokens
    const allTokens = await db
      .select()
      .from(passwordResetTokens)
      .where(isNull(passwordResetTokens.usedAt));

    let matchedToken: (typeof allTokens)[0] | null = null;
    for (const t of allTokens) {
      if (new Date(t.expiresAt) < new Date()) continue;
      if (await bcrypt.compare(token, t.tokenHash)) {
        matchedToken = t;
        break;
      }
    }

    if (!matchedToken) {
      throw new HTTPException(400, { message: 'Invalid or expired reset token' });
    }

    // Update password
    const passwordHash = await hashPassword(password);
    await db
      .update(users)
      .set({ passwordHash })
      .where(eq(users.id, matchedToken.userId));

    // Mark token as used
    await db
      .update(passwordResetTokens)
      .set({ usedAt: new Date() })
      .where(eq(passwordResetTokens.id, matchedToken.id));

    return c.json({
      success: true,
      data: { message: 'Password has been reset successfully' },
    });
  }
);

// GET /api/auth/me
auth.get('/me', authMiddleware, async (c) => {
  const authUser = c.get('user');
  const user = await findUserById(authUser.id);

  if (!user) {
    throw new HTTPException(404, { message: 'User not found' });
  }

  return c.json({
    success: true,
    data: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      defaultCurrency: user.defaultCurrency,
      authProvider: user.authProvider,
      createdAt: user.createdAt,
    },
  });
});

// PATCH /api/auth/me
auth.patch(
  '/me',
  authMiddleware,
  zValidator('json', updateProfileSchema),
  async (c) => {
    const authUser = c.get('user');
    const updates = c.req.valid('json');

    await db.update(users).set(updates).where(eq(users.id, authUser.id));

    const user = await findUserById(authUser.id);
    return c.json({
      success: true,
      data: {
        id: user!.id,
        email: user!.email,
        displayName: user!.displayName,
        defaultCurrency: user!.defaultCurrency,
      },
    });
  }
);

// DELETE /api/auth/me
auth.delete('/me', authMiddleware, async (c) => {
  const authUser = c.get('user');
  await db.delete(users).where(eq(users.id, authUser.id));
  return c.json({ success: true, data: { message: 'Account deleted' } });
});

export default auth;
