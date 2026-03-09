import app from '../src/app.js';

export async function request(
  method: string,
  path: string,
  options: {
    body?: Record<string, unknown>;
    headers?: Record<string, string>;
  } = {}
) {
  const init: RequestInit = {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  };

  if (options.body) {
    init.body = JSON.stringify(options.body);
  }

  const url = new URL(path, 'http://localhost');
  const response = await app.request(url.pathname + url.search, init);
  const json = await response.json();
  return { status: response.status, json, headers: response.headers };
}

let userCounter = 0;

export function testUser() {
  userCounter++;
  return {
    email: `test${userCounter}_${Date.now()}@example.com`,
    password: 'TestPassword123!',
    displayName: `Test User ${userCounter}`,
  };
}

export async function createAndLoginUser() {
  const user = testUser();
  const res = await request('POST', '/api/auth/register', { body: user });
  return {
    ...user,
    accessToken: res.json.data.accessToken as string,
    refreshToken: res.json.data.refreshToken as string,
    userId: res.json.data.user.id as string,
  };
}

export function authHeader(token: string): Record<string, string> {
  return { Authorization: `Bearer ${token}` };
}
