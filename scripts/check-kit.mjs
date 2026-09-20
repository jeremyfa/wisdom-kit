#!/usr/bin/env node
/**
 * The kit checking itself. Run by the kit's own CI, not by projects.
 *
 * Two things no single file can assert on its own:
 *
 *   The pinned Tauri CLI revision appears in kit.config.sh and again in
 *   docker/linux-appimage.Dockerfile, because Docker needs it as a build
 *   argument and the native Linux path needs it as a shell variable. They
 *   must agree, or the AppImage is built from a revision nobody chose.
 *
 *   Nothing under src/kit may reference an `app` package. The shell is
 *   reusable precisely because it knows nothing about the application built
 *   on it, and a single import would quietly weld it to one.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseShellConfig } from './config.mjs';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const problems = [];

checkTauriPin();
checkNoAppReferences();

if (problems.length > 0) {
    console.error('\nThe kit is inconsistent with itself:\n');
    for (const p of problems) console.error(`  ${p}`);
    console.error('');
    process.exit(1);
}

console.log('  kit consistent');

function checkTauriPin() {

    const config = parseShellConfig(path.join(KIT, 'kit.config.sh'));
    const dockerfile = path.join(KIT, 'docker', 'linux-appimage.Dockerfile');

    if (!fs.existsSync(dockerfile)) {
        problems.push('docker/linux-appimage.Dockerfile is missing');
        return;
    }

    const text = fs.readFileSync(dockerfile, 'utf8');
    const rev = (text.match(/^ARG\s+TAURI_CLI_REV=(\S+)/m) || [])[1];

    if (rev !== config.TAURI_CLI_FORK_REV) {
        problems.push(
            `docker/linux-appimage.Dockerfile pins ${rev || '(nothing)'}, `
            + `kit.config.sh pins ${config.TAURI_CLI_FORK_REV}. `
            + 'The AppImage bundler must be built from the revision the config names.'
        );
    }

}

function checkNoAppReferences() {

    const files = [];
    const walk = dir => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            const full = path.join(dir, entry.name);
            if (entry.isDirectory()) walk(full);
            else if (entry.name.endsWith('.hx')) files.push(full);
        }
    };
    walk(path.join(KIT, 'src', 'kit'));

    // Comments and strings are stripped first: prose says "the app" constantly
    // and means the English word.
    for (const file of files) {
        const code = stripNonCode(fs.readFileSync(file, 'utf8'));
        code.split('\n').forEach((line, index) => {
            if (/(?:^|[^A-Za-z0-9_.])app\.[A-Za-z_]/.test(line)) {
                problems.push(`${path.relative(KIT, file)}:${index + 1} references the app package`);
            }
        });
    }

}

function stripNonCode(source) {

    let out = '';
    let i = 0;
    while (i < source.length) {
        const two = source.slice(i, i + 2);
        if (two === '/*') {
            const end = source.indexOf('*/', i + 2);
            i = end === -1 ? source.length : end + 2;
            out += ' ';
            continue;
        }
        if (two === '//') {
            const end = source.indexOf('\n', i);
            i = end === -1 ? source.length : end;
            out += ' ';
            continue;
        }
        const c = source[i];
        if (c === '"' || c === "'") {
            // Markup strings are single-quoted and carry real code inside
            // ${...}, so those interpolations are kept.
            let j = i + 1;
            let inner = '';
            while (j < source.length) {
                if (source[j] === '\\') { j += 2; continue; }
                if (source[j] === c) break;
                inner += source[j];
                j++;
            }
            for (const match of inner.matchAll(/\$\{([\s\S]*?)\}/g)) out += ' ' + match[1] + ' ';
            i = j + 1;
            continue;
        }
        out += c;
        i++;
    }
    return out;

}
