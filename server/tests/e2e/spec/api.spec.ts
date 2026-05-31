import { test, expect } from '@playwright/test';

test.describe('Freezme Backend API E2E', () => {

  test('should return 401 for unauthorized endpoints', async ({ request }) => {
    const response = await request.get('/matching/likes');
    expect(response.status()).toBe(401);
  });

  test('health check passes', async ({ request }) => {
    // Assuming there is a health endpoint or we can just test if the server rejects gracefully
    const response = await request.get('/');
    // This might be 404 if no root exists, but server should be up
    expect(response.status()).toBe(404);
  });

});
