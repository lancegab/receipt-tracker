import { SignJWT, jwtVerify } from 'jose';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import { users, refreshTokens, categories } from '../db/schema.js';
import { eq, and } from 'drizzle-orm';
import type { JWTPayload } from '../types/index.js';

const SALT_ROUNDS = 12;
const getSecret = () => new TextEncoder().encode(process.env.JWT_SECRET!);

function parseExpiry(expiry: string): number {
  const match = expiry.match(/^(\d+)([smhd])$/);
  if (!match) throw new Error(`Invalid expiry format: ${expiry}`);
  const value = parseInt(match[1]);
  const unit = match[2];
  const multipliers: Record<string, number> = {
    s: 1,
    m: 60,
    h: 3600,
    d: 86400,
  };
  return value * (multipliers[unit] || 60);
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export async function generateAccessToken(userId: string, email: string): Promise<string> {
  const expiresIn = process.env.JWT_ACCESS_EXPIRES || '15m';
  return new SignJWT({ sub: userId, email } as unknown as Record<string, unknown>)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(getSecret());
}

export async function generateRefreshToken(userId: string): Promise<string> {
  const token = uuidv4();
  const tokenHash = await bcrypt.hash(token, 10);
  const expiresIn = parseExpiry(process.env.JWT_REFRESH_EXPIRES || '7d');
  const expiresAt = new Date(Date.now() + expiresIn * 1000);

  await db.insert(refreshTokens).values({
    id: uuidv4(),
    userId,
    tokenHash,
    expiresAt,
  });

  return token;
}

export async function rotateRefreshToken(
  userId: string,
  oldToken: string
): Promise<{ accessToken: string; refreshToken: string } | null> {
  const userTokens = await db
    .select()
    .from(refreshTokens)
    .where(eq(refreshTokens.userId, userId));

  let matchedToken: (typeof userTokens)[0] | null = null;
  for (const t of userTokens) {
    if (await bcrypt.compare(oldToken, t.tokenHash)) {
      matchedToken = t;
      break;
    }
  }

  if (!matchedToken || new Date(matchedToken.expiresAt) < new Date()) {
    return null;
  }

  // Delete old token
  await db.delete(refreshTokens).where(eq(refreshTokens.id, matchedToken.id));

  // Get user
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  if (!user) return null;

  const accessToken = await generateAccessToken(user.id, user.email);
  const refreshToken = await generateRefreshToken(user.id);

  return { accessToken, refreshToken };
}

export async function revokeRefreshTokens(userId: string): Promise<void> {
  await db.delete(refreshTokens).where(eq(refreshTokens.userId, userId));
}

export async function findUserByEmail(email: string) {
  const [user] = await db.select().from(users).where(eq(users.email, email));
  return user || null;
}

export async function findUserById(id: string) {
  const [user] = await db.select().from(users).where(eq(users.id, id));
  return user || null;
}

const defaultExpenseCategories = [
  { name: 'Food & Dining', icon: 'restaurant', color: '#FF6B6B' },
  { name: 'Groceries', icon: 'shopping_cart', color: '#4ECDC4' },
  { name: 'Transportation', icon: 'directions_car', color: '#45B7D1' },
  { name: 'Shopping', icon: 'shopping_bag', color: '#96CEB4' },
  { name: 'Entertainment', icon: 'movie', color: '#FFEAA7' },
  { name: 'Bills & Utilities', icon: 'receipt_long', color: '#DDA0DD' },
  { name: 'Healthcare', icon: 'local_hospital', color: '#98D8C8' },
  { name: 'Personal Care', icon: 'spa', color: '#F7DC6F' },
  { name: 'Education', icon: 'school', color: '#82E0AA' },
  { name: 'Travel', icon: 'flight', color: '#85C1E9' },
  { name: 'Home', icon: 'home', color: '#F0B27A' },
  { name: 'Gifts & Donations', icon: 'card_giftcard', color: '#D7BDE2' },
  { name: 'Other', icon: 'more_horiz', color: '#BDC3C7' },
];

const defaultIncomeCategories = [
  { name: 'Salary', icon: 'work', color: '#27AE60' },
  { name: 'Freelance', icon: 'laptop', color: '#2ECC71' },
  { name: 'Investment', icon: 'trending_up', color: '#1ABC9C' },
  { name: 'Gift', icon: 'redeem', color: '#3498DB' },
  { name: 'Refund', icon: 'replay', color: '#9B59B6' },
  { name: 'Other Income', icon: 'attach_money', color: '#F39C12' },
];

export async function seedCategoriesForUser(userId: string) {
  const existing = await db
    .select()
    .from(categories)
    .where(eq(categories.userId, userId))
    .limit(1);
  if (existing.length > 0) return; // already has categories

  const values = [
    ...defaultExpenseCategories.map((c) => ({
      id: uuidv4(),
      userId,
      name: c.name,
      type: 'expense' as const,
      icon: c.icon,
      color: c.color,
      isSystem: false,
      isActive: true,
    })),
    ...defaultIncomeCategories.map((c) => ({
      id: uuidv4(),
      userId,
      name: c.name,
      type: 'income' as const,
      icon: c.icon,
      color: c.color,
      isSystem: false,
      isActive: true,
    })),
  ];

  await db.insert(categories).values(values);
}

export async function createUser(data: {
  email: string;
  passwordHash?: string;
  displayName?: string;
  authProvider: 'email' | 'google' | 'facebook' | 'apple';
  authProviderId?: string;
}) {
  const id = uuidv4();
  await db.insert(users).values({
    id,
    email: data.email,
    passwordHash: data.passwordHash || null,
    displayName: data.displayName || null,
    authProvider: data.authProvider,
    authProviderId: data.authProviderId || null,
  });

  // Seed default categories for the new user
  await seedCategoriesForUser(id);

  return findUserById(id);
}
