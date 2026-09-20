#!/usr/bin/env node
/**
 * Regenerate the desktop icon set from one source image.
 *
 *     npm run generate-icons
 *
 * Input: resources/AppIcon.png, square, 1024x1024, with transparency, and with
 * the artwork FILLING the canvas edge to edge.
 *
 * WHY THERE ARE TWO PASSES
 *
 * macOS does not want a full-bleed icon. Since Big Sur every app icon is the
 * same rounded square drawn inside a canvas with a margin, and the Dock, the
 * Finder and Launchpad all lay icons out assuming that margin is there. Hand
 * macOS a full-bleed image and it is drawn at the full tile size, so it looms
 * over every neighbour in the Dock. The icon is not too large, it is missing
 * its margin.
 *
 * Apple's grid for a 1024pt canvas puts the artwork in the middle 824pt, which
 * is the 80.5% below. Windows and Linux have no such rule and want the
 * artwork full-bleed, so they keep the original.
 *
 * So: one pass produces everything from the source, a second produces only
 * icon.icns from an inset copy, and that .icns replaces the one from the first
 * pass.
 *
 * Needs ImageMagick for the inset step (`brew install imagemagick`). Without
 * it the script stops before changing anything and says so: the icons already
 * committed stay valid, which is better than half-regenerating them.
 */

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being built. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();

const SOURCE = path.join(root, 'resources', 'AppIcon.png');
const ICONS_DIR = path.join(root, 'src-tauri', 'icons');

/** Apple's icon grid: the artwork occupies the middle 824 of a 1024 canvas. */
const MACOS_CANVAS = 1024;
const MACOS_ARTWORK = 824;

function fail(message, ...details) {
    console.error(`\ngenerate-icons: ${message}`);
    for (const line of details) console.error(`  ${line}`);
    console.error('');
    process.exit(1);
}

function run(command, args, options = {}) {
    return execFileSync(command, args, { cwd: root, stdio: 'inherit', ...options });
}

function has(command) {
    try {
        execFileSync(command, ['--version'], { stdio: 'ignore' });
        return true;
    }
    catch {
        return false;
    }
}

if (!fs.existsSync(SOURCE)) {
    fail(`${path.relative(root, SOURCE)} is missing`,
        'Put a square 1024x1024 PNG with transparency there, artwork filling the canvas.');
}

const magick = has('magick') ? 'magick' : (has('convert') ? 'convert' : null);
if (!magick) {
    fail('ImageMagick is not installed, and the macOS icon cannot be inset without it',
        '    brew install imagemagick        # macOS',
        '    sudo apt install imagemagick    # Debian or Ubuntu',
        '',
        'Nothing was changed. The icons already in src-tauri/icons are still valid.');
}

// Pass 1: everything, from the full-bleed source.
console.log('  generating the icon set from resources/AppIcon.png');
run('npx', ['tauri', 'icon', path.relative(root, SOURCE)]);

// Pass 2: macOS only, from an inset copy.
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'icons-'));
const inset = path.join(work, 'AppIcon-macos.png');
const macIcons = path.join(work, 'icons-macos');

try {
    console.log(`  insetting the artwork to ${MACOS_ARTWORK} on a ${MACOS_CANVAS} canvas for macOS`);
    run(magick, [
        SOURCE,
        '-resize', `${MACOS_ARTWORK}x${MACOS_ARTWORK}`,
        '-background', 'none',
        '-gravity', 'center',
        '-extent', `${MACOS_CANVAS}x${MACOS_CANVAS}`,
        inset
    ]);

    run('npx', ['tauri', 'icon', inset, '-o', macIcons]);

    const icns = path.join(macIcons, 'icon.icns');
    if (!fs.existsSync(icns)) fail('the second pass produced no icon.icns');
    fs.copyFileSync(icns, path.join(ICONS_DIR, 'icon.icns'));
    console.log('  icon.icns replaced with the inset version');
}
finally {
    fs.rmSync(work, { recursive: true, force: true });
}

// Mobile is out of scope for this template, and `tauri icon` writes these
// every time. Dropping them keeps the repository to what it actually ships.
for (const dir of ['android', 'ios']) {
    const full = path.join(ICONS_DIR, dir);
    if (fs.existsSync(full)) {
        fs.rmSync(full, { recursive: true, force: true });
        console.log(`  removed the unused ${dir} icons`);
    }
}

console.log('\nIcons regenerated. Rebuild the desktop app to see them.\n');
