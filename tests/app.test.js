const request = require('supertest');
const app = require('../src/app');

describe('lab50-ec2-deploy', () => {
  test('GET / returns greeting JSON', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello from Lab 50');
    expect(res.body.service).toBe('lab50-ec2-deploy');
  });

  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('GET /version returns version info', async () => {
    const res = await request(app).get('/version');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('commit');
  });

  test('GET /unknown returns 404', async () => {
    const res = await request(app).get('/unknown');
    expect(res.statusCode).toBe(404);
  });
});
