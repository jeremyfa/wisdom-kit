#!/usr/bin/env node
/**
 * Writes the project's licence as RTF for the macOS disk image, and prints its
 * path. Prints nothing when tauri.conf.json names no licence.
 *
 *     node scripts/license-rtf.mjs <project root> <output dir>
 *
 * The DMG bundler embeds a plain text licence as a TEXT resource, which macOS
 * reads as MacRoman: every non ASCII letter comes out garbled ("Jérémy" shows
 * as "J√©r√©my"). An RTF licence goes in as an RTF resource instead, with its
 * characters escaped, so it reads the same everywhere.
 *
 * The lines of each paragraph are joined too. The licence window is narrower
 * than the 80 columns a LICENSE file is wrapped to, and would otherwise break
 * every line twice.
 */

import fs from 'node:fs';
import path from 'node:path';

const [root, outDir] = process.argv.slice(2);
if (!root || !outDir) {
    console.error('usage: license-rtf.mjs <project root> <output dir>');
    process.exit(1);
}

const tauriDir = path.join(root, 'src-tauri');
const conf = JSON.parse(fs.readFileSync(path.join(tauriDir, 'tauri.conf.json'), 'utf8'));
const licenseFile = conf.bundle?.licenseFile;
if (!licenseFile) process.exit(0);

const source = path.resolve(tauriDir, licenseFile);
const text = fs.readFileSync(source, 'utf8').replace(/^﻿/, '');

// Already RTF: nothing to convert.
if (text.startsWith('{\\rtf')) {
    console.log(source);
    process.exit(0);
}

const paragraphs = text
    .replace(/\r\n?/g, '\n')
    .split(/\n\s*\n/)
    .map(p => p.split('\n').map(line => line.trim()).join(' ').trim())
    .filter(Boolean);

const rtf = [
    '{\\rtf1\\ansi\\ansicpg1252\\deff0',
    '{\\fonttbl{\\f0\\fswiss Helvetica;}}',
    '\\f0\\fs24',
    paragraphs.map(escape).join('\\par\\par\n'),
    '}',
    ''
].join('\n');

fs.mkdirSync(outDir, { recursive: true });
const output = path.join(outDir, 'license.rtf');
fs.writeFileSync(output, rtf);
console.log(output);

/** RTF specials escaped, and everything past ASCII as a \u escape. */
function escape(paragraph) {
    let out = '';
    for (let i = 0; i < paragraph.length; i++) {
        const c = paragraph[i];
        const code = paragraph.charCodeAt(i);
        if (c === '\\' || c === '{' || c === '}') out += `\\${c}`;
        else if (code < 0x80) out += c;
        // \u takes a signed 16 bit value; the ? is what readers without
        // Unicode show instead. Characters outside the BMP stay two escapes,
        // one per UTF-16 half, which is what RTF expects.
        else out += `\\u${code > 0x7fff ? code - 0x10000 : code}?`;
    }
    return out;
}
