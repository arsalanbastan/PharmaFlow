import type { INestApplication } from '@nestjs/common';
import express from 'express';
import type { NextFunction, Request, Response } from 'express';
import { existsSync } from 'node:fs';
import { extname, join } from 'node:path';

export function mountStaffWebAssets(
  app: INestApplication,
  workingDirectory = process.cwd(),
): boolean {
  const webRoot = join(workingDirectory, 'public', 'staff');
  const indexPath = join(webRoot, 'index.html');

  if (!existsSync(indexPath)) {
    console.log('[Staff PWA] public/staff was not found; web UI is disabled.');
    return false;
  }

  app.use(
    '/staff',
    (request: Request, response: Response, next: NextFunction) => {
      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('Referrer-Policy', 'same-origin');
      response.setHeader('Permissions-Policy', 'camera=(self)');
      response.setHeader('Strict-Transport-Security', 'max-age=31536000');
      const releaseCriticalAsset =
        request.path === '/' ||
        request.path === '/index.html' ||
        request.path === '/flutter_bootstrap.js' ||
        request.path === '/flutter_service_worker.js';

      response.setHeader(
        'Cache-Control',
        releaseCriticalAsset
          ? 'no-store, no-cache, must-revalidate, max-age=0'
          : 'no-cache',
      );
      next();
    },
  );

  app.use(
    '/staff',
    express.static(webRoot, {
      index: 'index.html',
      fallthrough: true,
      etag: true,
      cacheControl: false,
      maxAge: 0,
    }),
  );

  app.use(
    '/staff',
    (request: Request, response: Response, next: NextFunction) => {
      const acceptsHtml = request.accepts('html') !== false;

      if (
        request.method !== 'GET' ||
        !acceptsHtml ||
        extname(request.path) !== ''
      ) {
        next();
        return;
      }

      response.sendFile(indexPath);
    },
  );

  console.log('[Staff PWA] mounted at /staff/.');
  return true;
}
