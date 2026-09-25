#!/usr/bin/env node
/**
 * Minify the release bundle in place.
 *
 * Haxe's output is readable JavaScript, which is right for development and
 * about five times larger than it needs to be for a download. esbuild is used
 * purely as a minifier here: no bundling, no transform, no module resolution.
 * The input is already one self-contained ES6 file.
 *
 * Deliberately NOT part of the Haxe build. Keeping it a separate step means
 * the development build stays debuggable and the release build stays one
 * command, and swapping the minifier later touches one file.
 *
 * Skipped with a warning rather than an error when esbuild is absent, so that
 * an environment without it can still produce a working (if larger) release.
 */

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being built. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();
const file = path.join(root, 'dist', 'web', 'frontend.js');

if (!fs.existsSync(file)) {
    console.error('minify: dist/web/frontend.js does not exist; run the Haxe build first');
    process.exit(1);
}

// Resolved from the project, which lists esbuild in its devDependencies. A
// bare import would resolve from this file instead, which is wherever the kit
// really lives: outside the project when lib/wisdom-kit is a link to a local
// checkout (project.local.sh).
let esbuild;
try {
    const require = createRequire(path.join(root, 'package.json'));
    esbuild = await import(pathToFileURL(require.resolve('esbuild')).href);
}
catch {
    console.warn('  esbuild not installed; shipping the unminified bundle');
    process.exit(0);
}

const before = fs.readFileSync(file, 'utf8');

const result = await esbuild.transform(before, {
    minify: true,
    // Match -D js-es=6 in build.common.hxml. A lower target would make esbuild
    // down-level syntax Haxe deliberately emitted, for no benefit.
    target: 'es2015',
    legalComments: 'none'
});

fs.writeFileSync(file, result.code);

const after = fs.statSync(file).size;
const kb = n => Math.round(n / 1024);
console.log(`  minified frontend.js: ${kb(Buffer.byteLength(before))} KB -> ${kb(after)} KB`);
