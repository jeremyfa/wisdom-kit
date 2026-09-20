#!/usr/bin/env node
/**
 * Assemble the static shell into the build output.
 *
 * Two layers, in order:
 *
 *   1. the KIT's web/, holding the host page and the icon font, identical in
 *      every project built on it
 *   2. the PROJECT's web/, if it has one, holding anything it wants to add or
 *      override, typically just its favicon
 *
 * Second wins, so a project can replace index.html outright by putting its own
 * there, without the kit needing to know about it.
 *
 * dist/web is simultaneously the deployable web build and Tauri's
 * frontendDist, so this is the only place static assets enter the output.
 * Everything generated lives under dist/, which means .gitignore needs a
 * single entry and `kit clean` is complete.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being built. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();

const to = path.join(root, 'dist', 'web');
fs.mkdirSync(to, { recursive: true });

const kitWeb = path.join(KIT, 'web');
if (!fs.existsSync(kitWeb)) {
    console.error(`copy-static: the kit has no web/ at ${kitWeb}`);
    process.exit(1);
}
fs.cpSync(kitWeb, to, { recursive: true });

// A project with nothing of its own to add is perfectly normal.
const projectWeb = path.join(root, 'web');
if (fs.existsSync(projectWeb)) {
    fs.cpSync(projectWeb, to, { recursive: true });
}

// The two generated siblings (frontend.js, frontend.css) are written straight
// into dist/web by haxe and tailwind, so nothing else to do here.
