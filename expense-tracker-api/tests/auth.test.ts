import { describe, it, expect } from 'vitest';
import { request, testUser, createAndLoginUser, authHeader } from './setup.js';

describe('Auth Routes', () => {
  describe('POST /api/auth/register', () => {
    it('should register a new user', async () => {
      const user = testUser();
      const res = await request('POST', '/api/auth/register', { body: user });

      expect(res.status).toBe(201);
      expect(res.json.success).toBe(true);
      expect(res.json.data.user.email).toBe(user.email);
      expect(res.json.data.accessToken).toBeDefined();
      expect(res.json.data.refreshToken).toBeDefined();
    });

    it('should reject duplicate email', async () => {
      const user = testUser();
      await request('POST', '/api/auth/register', { body: user });
      const res = await request('POST', '/api/auth/register', { body: user });

      expect(res.status).toBe(409);
    });

    it('should reject short password', async () => {
      const user = testUser();
      user.password = 'short';
      const res = await request('POST', '/api/auth/register', { body: user });

      expect(res.status).toBe(400);
    });
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const user = testUser();
      await request('POST', '/api/auth/register', { body: user });
      const res = await request('POST', '/api/auth/login', {
        body: { email: user.email, password: user.password },
      });

      expect(res.status).toBe(200);
      expect(res.json.success).toBe(true);
      expect(res.json.data.accessToken).toBeDefined();
    });

    it('should reject invalid password', async () => {
      const user = testUser();
      await request('POST', '/api/auth/register', { body: user });
      const res = await request('POST', '/api/auth/login', {
        body: { email: user.email, password: 'wrongpassword' },
      });

      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/auth/refresh', () => {
    it('should rotate refresh token', async () => {
      const user = await createAndLoginUser();
      const res = await request('POST', '/api/auth/refresh', {
        body: { userId: user.userId, refreshToken: user.refreshToken },
      });

      expect(res.status).toBe(200);
      expect(res.json.data.accessToken).toBeDefined();
      expect(res.json.data.refreshToken).toBeDefined();
    });
  });

  describe('GET /api/auth/me', () => {
    it('should return user profile', async () => {
      const user = await createAndLoginUser();
      const res = await request('GET', '/api/auth/me', {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
      expect(res.json.data.email).toBe(user.email);
    });

    it('should reject unauthenticated request', async () => {
      const res = await request('GET', '/api/auth/me');

      expect(res.status).toBe(401);
    });
  });

  describe('PATCH /api/auth/me', () => {
    it('should update profile', async () => {
      const user = await createAndLoginUser();
      const res = await request('PATCH', '/api/auth/me', {
        headers: authHeader(user.accessToken),
        body: { displayName: 'Updated Name' },
      });

      expect(res.status).toBe(200);
      expect(res.json.data.displayName).toBe('Updated Name');
    });
  });

  describe('DELETE /api/auth/me', () => {
    it('should delete account', async () => {
      const user = await createAndLoginUser();
      const res = await request('DELETE', '/api/auth/me', {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);

      // Verify user is gone
      const check = await request('GET', '/api/auth/me', {
        headers: authHeader(user.accessToken),
      });
      expect(check.status).toBe(404);
    });
  });
});
