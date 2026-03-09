import { describe, it, expect } from 'vitest';
import { request, createAndLoginUser, authHeader } from './setup.js';

describe('Account Routes', () => {
  describe('POST /api/accounts', () => {
    it('should create an account', async () => {
      const user = await createAndLoginUser();
      const res = await request('POST', '/api/accounts', {
        headers: authHeader(user.accessToken),
        body: {
          name: 'Test Account',
          type: 'bank',
          currency: 'USD',
          balance: 1000,
        },
      });

      expect(res.status).toBe(201);
      expect(res.json.data.name).toBe('Test Account');
      expect(res.json.data.type).toBe('bank');
    });
  });

  describe('GET /api/accounts', () => {
    it('should list user accounts', async () => {
      const user = await createAndLoginUser();
      await request('POST', '/api/accounts', {
        headers: authHeader(user.accessToken),
        body: { name: 'Account 1', type: 'cash' },
      });
      await request('POST', '/api/accounts', {
        headers: authHeader(user.accessToken),
        body: { name: 'Account 2', type: 'bank' },
      });

      const res = await request('GET', '/api/accounts', {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
      expect(res.json.data.length).toBeGreaterThanOrEqual(2);
    });
  });

  describe('GET /api/accounts/:id', () => {
    it('should get account details', async () => {
      const user = await createAndLoginUser();
      const createRes = await request('POST', '/api/accounts', {
        headers: authHeader(user.accessToken),
        body: { name: 'Detail Account', type: 'savings' },
      });

      const id = createRes.json.data.id;
      const res = await request('GET', `/api/accounts/${id}`, {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
      expect(res.json.data.name).toBe('Detail Account');
    });

    it('should not access other user accounts', async () => {
      const user1 = await createAndLoginUser();
      const user2 = await createAndLoginUser();

      const createRes = await request('POST', '/api/accounts', {
        headers: authHeader(user1.accessToken),
        body: { name: 'Private Account', type: 'bank' },
      });

      const id = createRes.json.data.id;
      const res = await request('GET', `/api/accounts/${id}`, {
        headers: authHeader(user2.accessToken),
      });

      expect(res.status).toBe(404);
    });
  });

  describe('PATCH /api/accounts/:id', () => {
    it('should update account', async () => {
      const user = await createAndLoginUser();
      const createRes = await request('POST', '/api/accounts', {
        headers: authHeader(user.accessToken),
        body: { name: 'Old Name', type: 'cash' },
      });

      const id = createRes.json.data.id;
      const res = await request('PATCH', `/api/accounts/${id}`, {
        headers: authHeader(user.accessToken),
        body: { name: 'New Name' },
      });

      expect(res.status).toBe(200);
      expect(res.json.data.name).toBe('New Name');
    });
  });

  describe('DELETE /api/accounts/:id', () => {
    it('should archive account', async () => {
      const user = await createAndLoginUser();
      const createRes = await request('POST', '/api/accounts', {
        headers: authHeader(user.accessToken),
        body: { name: 'To Archive', type: 'wallet' },
      });

      const id = createRes.json.data.id;
      const res = await request('DELETE', `/api/accounts/${id}`, {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
    });
  });
});
