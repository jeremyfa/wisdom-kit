#!/usr/bin/env node
/**
 * Serve dist/web over HTTP for `npm run dev:web`.
 *
 * A dependency-free static server: the web target has no build-time server
 * needs beyond "hand these files to a browser", and adding a package for that
 * would be one more thing to keep current.
 *
 * Port comes from WEB_DEV_PORT in project.config.sh, so there is still only
 * one place where this project's names and numbers live.
 */

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readConfig } from './config.mjs';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being built. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();
const dir = path.join(root, 'dist', 'web');

const port = Number(process.env.PORT || readConfig(root, KIT).WEB_DEV_PORT);

const TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.svg': 'image/svg+xml',
    '.woff2': 'font/woff2',
    '.woff': 'font/woff',
    '.ttf': 'font/ttf',
    '.png': 'image/png',
    '.map': 'application/json; charset=utf-8'
};

const server = http.createServer((req, res) => {
    const url = decodeURIComponent((req.url || '/').split('?')[0]);
    let file = path.resolve(path.join(dir, url === '/' ? 'index.html' : url));

    // Never serve outside dist/web, whatever the request says. Resolved
    // first, so a ".." in the URL cannot walk out, and compared against the
    // directory plus a separator, so a sibling called "web-other" cannot pass
    // as a prefix match.
    if (file !== dir && !file.startsWith(dir + path.sep)) {
        res.writeHead(403).end('Forbidden');
        return;
    }

    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        file = path.join(dir, 'index.html');
    }

    if (!fs.existsSync(file)) {
        res.writeHead(404).end('Not found. Run: npm run build');
        return;
    }

    res.writeHead(200, {
        'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
        // The dev loop rewrites these files in place, so a cached copy would hide
        // every change you just made.
        'Cache-Control': 'no-store'
    });
    fs.createReadStream(file).pipe(res);
});

server.on('error', (e) => {
    if (e.code === 'EADDRINUSE') {
        console.error(`  port ${port} is already in use.`);
        console.error(`  Another dev server is probably running. Stop it, or set a`);
        console.error(`  different WEB_DEV_PORT in project.config.sh.`);
        process.exit(1);
    }
    throw e;
});

server.listen(port, () => {
    console.log(`  web build served at http://localhost:${port}`);
});
