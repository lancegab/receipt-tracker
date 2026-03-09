import { describe, it, expect } from 'vitest';
import { request, createAndLoginUser, authHeader } from './setup.js';

async function createAccount(accessToken: string) {
  const res = await request('POST', '/api/accounts', {
    headers: authHeader(accessToken),
    body: { name: 'Test Account', type: 'bank', balance: 5000 },
  });
  return res.json.data.id as string;
}

describe('Transaction Routes', () => {
  describe('POST /api/transactions', () => {
    it('should create a transaction', async () => {
      const user = await createAndLoginUser();
      const accountId = await createAccount(user.accessToken);

      const res = await request('POST', '/api/transactions', {
        headers: authHeader(user.accessToken),
        body: {
          accountId,
          type: 'expense',
          amount: 50.00,
          date: '2024-01-15',
          description: 'Lunch',
        },
      });

      expect(res.status).toBe(201);
      expect(res.json.data.description).toBe('Lunch');
    });
  });

  describe('GET /api/transactions', () => {
    it('should list transactions', async () => {
      const user = await createAndLoginUser();
      const accountId = await createAccount(user.accessToken);

      await request('POST', '/api/transactions', {
        headers: authHeader(user.accessToken),
        body: {
          accountId,
          type: 'expense',
          amount: 25,
          date: '2024-01-15',
          description: 'Coffee',
        },
      });

      const res = await request('GET', '/api/transactions', {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
      expect(Array.isArray(res.json.data)).toBe(true);
    });

    it('should filter by type', async () => {
      const user = await createAndLoginUser();
      const accountId = await createAccount(user.accessToken);

      await request('POST', '/api/transactions', {
        headers: authHeader(user.accessToken),
        body: {
          accountId,
          type: 'income',
          amount: 1000,
          date: '2024-01-15',
          description: 'Salary',
        },
      });

      await request('POST', '/api/transactions', {
        headers: authHeader(user.accessToken),
        body: {
          accountId,
          type: 'expense',
          amount: 50,
          date: '2024-01-15',
          description: 'Groceries',
        },
      });

      const res = await request('GET', '/api/transactions?type=income', {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
      const allIncome = res.json.data.every(
        (t: Record<string, unknown>) => t.type === 'income'
      );
      expect(allIncome).toBe(true);
    });
  });

  describe('POST /api/transactions/batch', () => {
    it('should create batch transactions', async () => {
      const user = await createAndLoginUser();
      const accountId = await createAccount(user.accessToken);

      const res = await request('POST', '/api/transactions/batch', {
        headers: authHeader(user.accessToken),
        body: {
          transactions: [
            {
              accountId,
              type: 'expense',
              amount: 10,
              date: '2024-01-15',
              description: 'Item 1',
            },
            {
              accountId,
              type: 'expense',
              amount: 20,
              date: '2024-01-15',
              description: 'Item 2',
            },
          ],
        },
      });

      expect(res.status).toBe(201);
    });
  });

  describe('PATCH /api/transactions/:id', () => {
    it('should update a transaction', async () => {
      const user = await createAndLoginUser();
      const accountId = await createAccount(user.accessToken);

      const createRes = await request('POST', '/api/transactions', {
        headers: authHeader(user.accessToken),
        body: {
          accountId,
          type: 'expense',
          amount: 50,
          date: '2024-01-15',
          description: 'Original',
        },
      });

      const id = createRes.json.data.id;
      const res = await request('PATCH', `/api/transactions/${id}`, {
        headers: authHeader(user.accessToken),
        body: { description: 'Updated' },
      });

      expect(res.status).toBe(200);
      expect(res.json.data.description).toBe('Updated');
    });
  });

  describe('DELETE /api/transactions/:id', () => {
    it('should delete a transaction', async () => {
      const user = await createAndLoginUser();
      const accountId = await createAccount(user.accessToken);

      const createRes = await request('POST', '/api/transactions', {
        headers: authHeader(user.accessToken),
        body: {
          accountId,
          type: 'expense',
          amount: 30,
          date: '2024-01-15',
          description: 'To Delete',
        },
      });

      const id = createRes.json.data.id;
      const res = await request('DELETE', `/api/transactions/${id}`, {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
    });
  });
});
