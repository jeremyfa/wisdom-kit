#!/usr/bin/env node
/**
 * Remove build output.
 *
 *   npm run clean          dist/ only
 *   npm run clean -- --all dist/, .haxelib/ and the Rust target directory
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being built. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();
const all = process.argv.includes('--all');

const targets = ['dist'];
if (all) targets.push('.haxelib', path.join('src-tauri', 'target'), path.join('src-tauri', 'gen'));

for (const target of targets) {
    const full = path.join(root, target);
    if (fs.existsSync(full)) {
        fs.rmSync(full, { recursive: true, force: true });
        console.log(`  removed ${target}`);
    }
}

if (all) console.log('  run `npm run setup` before building again');
