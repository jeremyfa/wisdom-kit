#!/usr/bin/env node
/**
 * Propagate the names in project.config.sh into every file that keeps a copy.
 *
 * project.config.sh is the single source of truth for what a project is
 * called. Change APP_SLUG, APP_IDENTIFIER or APP_PRODUCT_NAME there, and the
 * next build writes them here, so no file keeps the previous name:
 *
 *   package.json         name                      APP_SLUG
 *   package-lock.json    name, packages[""].name   APP_SLUG
 *   tauri.conf.json      identifier                APP_IDENTIFIER
 *                        productName, window title APP_PRODUCT_NAME
 *   Cargo.toml           [package].name            APP_CRATE_NAME
 *                        [lib].name                APP_LIB_NAME
 *   Cargo.lock           the project's own crate   APP_CRATE_NAME
 *   src/main.rs          <lib>::run()              APP_LIB_NAME
 *
 * The Haxe side reads project.config.sh directly at compile time through
 * kit.macros.ConfigMacro (App.SLUG, App.ICON), so it needs nothing written.
 *
 * Every file is rewritten line by line, never re-serialized: a JSON round
 * trip would reformat the file and turn a rename into a meaningless diff.
 *
 * Runs before every build, ahead of sync-version, which finds the crate in
 * Cargo.lock by the name written here. `--check` reports without writing.
 *
 * Renaming does not move data. A new APP_IDENTIFIER is a new data directory
 * on every desktop system, and the local storage key follows APP_SLUG, so a
 * renamed app starts from empty storage.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readConfig } from './config.mjs';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being built. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();
const check = process.argv.includes('--check');

let config;
try {
    config = readConfig(root, KIT);
}
catch (error) {
    fail(error.message);
}

const changes = [];

syncPackageJson();
syncPackageLock();
syncTauriConf();
// The Cargo.lock entry is found by the crate name Cargo.toml had BEFORE this
// run, so read it first.
const previousCrate = crateName();
syncCargoToml();
syncCargoLock(previousCrate);
syncMainRs();

if (check) {
    if (changes.length > 0) {
        console.error('Names are out of sync with project.config.sh:');
        for (const c of changes) console.error(`  ${c}`);
        console.error('\nRun: npm run sync-config');
        process.exit(1);
    }
    console.log(`  names in sync (${config.APP_SLUG}, ${config.APP_IDENTIFIER})`);
}
else if (changes.length > 0) {
    for (const c of changes) console.log(`  updated ${c}`);
}

/// Targets

function syncPackageJson() {

    update('package.json', text => replaceJsonString(text, 'name', config.APP_SLUG, 1));

}

/** The top-level name, and the root package's entry: the first two "name"s. */
function syncPackageLock() {

    update('package-lock.json', text => replaceJsonString(text, 'name', config.APP_SLUG, 2));

}

function syncTauriConf() {

    update('src-tauri/tauri.conf.json', text => {
        text = replaceJsonString(text, 'identifier', config.APP_IDENTIFIER, 1);
        text = replaceJsonString(text, 'productName', config.APP_PRODUCT_NAME, 1);
        // The first "title" is the main window's, the one check-config reads.
        return replaceJsonString(text, 'title', config.APP_PRODUCT_NAME, 1);
    });

}

function syncCargoToml() {

    update('src-tauri/Cargo.toml', text => {
        text = text.replace(/(\[package\][\s\S]*?\nname\s*=\s*")[^"]*(")/, `$1${config.APP_CRATE_NAME}$2`);
        return text.replace(/(\[lib\][\s\S]*?\nname\s*=\s*")[^"]*(")/, `$1${config.APP_LIB_NAME}$2`);
    });

}

function syncCargoLock(previous) {

    if (!previous || previous === config.APP_CRATE_NAME) return;
    update('src-tauri/Cargo.lock', text => text.replace(
        new RegExp(`(\\[\\[package\\]\\]\\nname = ")${escapeRegExp(previous)}(")`),
        `$1${config.APP_CRATE_NAME}$2`
    ));

}

function syncMainRs() {

    update('src-tauri/src/main.rs', text => text.replace(/\b[A-Za-z_][A-Za-z0-9_]*(::run\(\))/, `${config.APP_LIB_NAME}$1`));

}

/// Helpers

function crateName() {

    const file = path.join(root, 'src-tauri', 'Cargo.toml');
    if (!fs.existsSync(file)) return null;
    const match = fs.readFileSync(file, 'utf8').match(/\[package\][\s\S]*?\nname\s*=\s*"([^"]*)"/);
    return match ? match[1] : null;

}

/** Rewrites `file` through `transform`, or records the change under --check. */
function update(file, transform) {

    const full = path.join(root, file);
    if (!fs.existsSync(full)) return;
    const text = fs.readFileSync(full, 'utf8');
    const updated = transform(text);
    if (updated === text) return;
    changes.push(file);
    if (!check) fs.writeFileSync(full, updated);

}

/** Sets the first `count` occurrences of `"key": "..."` to `value`. */
function replaceJsonString(text, key, value, count) {

    let seen = 0;
    return text.replace(new RegExp(`("${escapeRegExp(key)}"\\s*:\\s*")((?:[^"\\\\]|\\\\.)*)(")`, 'g'), (match, open, _, close) => {
        seen++;
        return seen <= count ? open + JSON.stringify(value).slice(1, -1) + close : match;
    });

}

function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function fail(message) {
    console.error(`sync-config: ${message}`);
    process.exit(1);
}
