import express from 'express';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';

import { mountStaffWebAssets } from './staff-web-assets';

describe('Staff PWA static assets', () => {
  let root: string;
  let logSpy: jest.SpyInstance;

  beforeEach(() => {
    root = mkdtempSync(join(tmpdir(), 'pharmaflow-staff-pwa-'));
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => undefined);
  });

  afterEach(() => {
    logSpy.mockRestore();
    rmSync(root, { recursive: true, force: true });
  });

  it('stays disabled when the built web bundle is absent', () => {
    const app = express();

    expect(mountStaffWebAssets(app as never, root)).toBe(false);
  });

  it('serves the PWA shell and applies browser security headers', async () => {
    const webRoot = join(root, 'public', 'staff');
    mkdirSync(webRoot, { recursive: true });
    writeFileSync(join(webRoot, 'index.html'), '<html>Staff PWA</html>');
    writeFileSync(join(webRoot, 'manifest.json'), '{"name":"Staff"}');

    const app = express();

    expect(mountStaffWebAssets(app as never, root)).toBe(true);

    const shell = await request(app).get('/staff/').expect(200);
    expect(shell.text).toContain('Staff PWA');
    expect(shell.headers['x-content-type-options']).toBe('nosniff');
    expect(shell.headers['permissions-policy']).toBe('camera=(self)');
    expect(shell.headers['strict-transport-security']).toBe('max-age=31536000');
    expect(shell.headers['cache-control']).toContain('no-store');

    const fallback = await request(app)
      .get('/staff/request/new')
      .set('Accept', 'text/html')
      .expect(200);
    expect(fallback.text).toContain('Staff PWA');

    const manifest = await request(app).get('/staff/manifest.json').expect(200);
    expect(manifest.headers['cache-control']).toBe('no-cache');

    const serviceWorker = await request(app)
      .get('/staff/flutter_service_worker.js')
      .expect(404);
    expect(serviceWorker.headers['cache-control']).toContain('no-store');
  });
});
