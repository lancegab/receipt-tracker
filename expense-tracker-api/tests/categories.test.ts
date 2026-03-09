import { describe, it, expect } from 'vitest';
import { request, createAndLoginUser, authHeader } from './setup.js';

describe('Category Routes', () => {
  describe('GET /api/categories', () => {
    it('should list categories', async () => {
      const user = await createAndLoginUser();
      const res = await request('GET', '/api/categories', {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
      expect(Array.isArray(res.json.data)).toBe(true);
    });
  });

  describe('POST /api/categories', () => {
    it('should create a custom category', async () => {
      const user = await createAndLoginUser();
      const res = await request('POST', '/api/categories', {
        headers: authHeader(user.accessToken),
        body: {
          name: 'Custom Category',
          type: 'expense',
          icon: 'shopping_bag',
          color: '#FF5722',
        },
      });

      expect(res.status).toBe(201);
      expect(res.json.data.name).toBe('Custom Category');
      expect(res.json.data.isSystem).toBe(false);
    });
  });

  describe('PATCH /api/categories/:id', () => {
    it('should update a custom category', async () => {
      const user = await createAndLoginUser();
      const createRes = await request('POST', '/api/categories', {
        headers: authHeader(user.accessToken),
        body: { name: 'Old Cat', type: 'expense' },
      });

      const id = createRes.json.data.id;
      const res = await request('PATCH', `/api/categories/${id}`, {
        headers: authHeader(user.accessToken),
        body: { name: 'New Cat' },
      });

      expect(res.status).toBe(200);
      expect(res.json.data.name).toBe('New Cat');
    });
  });

  describe('DELETE /api/categories/:id', () => {
    it('should delete a custom category', async () => {
      const user = await createAndLoginUser();
      const createRes = await request('POST', '/api/categories', {
        headers: authHeader(user.accessToken),
        body: { name: 'To Delete', type: 'income' },
      });

      const id = createRes.json.data.id;
      const res = await request('DELETE', `/api/categories/${id}`, {
        headers: authHeader(user.accessToken),
      });

      expect(res.status).toBe(200);
    });
  });
});
