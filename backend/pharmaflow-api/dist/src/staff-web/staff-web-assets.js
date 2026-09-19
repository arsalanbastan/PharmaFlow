"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.mountStaffWebAssets = mountStaffWebAssets;
const express_1 = __importDefault(require("express"));
const node_fs_1 = require("node:fs");
const node_path_1 = require("node:path");
function mountStaffWebAssets(app, workingDirectory = process.cwd()) {
    const webRoot = (0, node_path_1.join)(workingDirectory, 'public', 'staff');
    const indexPath = (0, node_path_1.join)(webRoot, 'index.html');
    if (!(0, node_fs_1.existsSync)(indexPath)) {
        console.log('[Staff PWA] public/staff was not found; web UI is disabled.');
        return false;
    }
    app.use('/staff', (request, response, next) => {
        response.setHeader('X-Content-Type-Options', 'nosniff');
        response.setHeader('Referrer-Policy', 'same-origin');
        response.setHeader('Permissions-Policy', 'camera=(self)');
        response.setHeader('Strict-Transport-Security', 'max-age=31536000');
        const releaseCriticalAsset = request.path === '/' ||
            request.path === '/index.html' ||
            request.path === '/flutter_bootstrap.js' ||
            request.path === '/flutter_service_worker.js';
        response.setHeader('Cache-Control', releaseCriticalAsset
            ? 'no-store, no-cache, must-revalidate, max-age=0'
            : 'no-cache');
        next();
    });
    app.use('/staff', express_1.default.static(webRoot, {
        index: 'index.html',
        fallthrough: true,
        etag: true,
        cacheControl: false,
        maxAge: 0,
    }));
    app.use('/staff', (request, response, next) => {
        const acceptsHtml = request.accepts('html') !== false;
        if (request.method !== 'GET' ||
            !acceptsHtml ||
            (0, node_path_1.extname)(request.path) !== '') {
            next();
            return;
        }
        response.sendFile(indexPath);
    });
    console.log('[Staff PWA] mounted at /staff/.');
    return true;
}
//# sourceMappingURL=staff-web-assets.js.map