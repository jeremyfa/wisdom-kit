#!/usr/bin/env node
/**
 * Propagate package.json's version into the Rust and Tauri side of a project.
 *
 * package.json is the single source of truth. This writes it into
 * src-tauri/tauri.conf.json, src-tauri/Cargo.toml and, when present,
 * src-tauri/Cargo.lock. The Haxe side reads package.json directly at compile
 * time through kit.macros.VersionMacro, so all four always agree.
 *
 * MUST RUN BEFORE `tauri build`, never from tauri.conf.json's
 * beforeBuildCommand: the Tauri CLI parses tauri.conf.json once when it
 * starts, so a version written from inside the build would be read only on the
 * NEXT build and every bundle would ship stamped one release behind.
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

const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const version = pkg.version;

if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(version || '')) {
    fail(`package.json version "${version}" is not a valid semver`);
}

const config = readConfig(root, KIT);
const problems = [];

syncTauriConf();
syncCargoToml();
syncCargoLock();

if (check) {
    if (problems.length > 0) {
        console.error('Version is out of sync:');
        for (const p of problems) console.error(`  ${p}`);
        console.error('\nRun: npm run sync-version');
        process.exit(1);
    }
    console.log(`  version ${version} is in sync`);
}
else if (problems.length > 0) {
    for (const p of problems) console.log(`  updated ${p}`);
    console.log(`  version ${version} synced`);
}
else {
    console.log(`  version ${version} already in sync`);
}

/// Targets

function syncTauriConf() {

    const file = path.join(root, 'src-tauri', 'tauri.conf.json');
    if (!fs.existsSync(file)) return;

    const text = fs.readFileSync(file, 'utf8');
    const conf = JSON.parse(text);
    if (conf.version === version) return;

    problems.push(`src-tauri/tauri.conf.json (${conf.version} -> ${version})`);
    if (check) return;

    // Rewrite the one line rather than re-serializing the whole document: a
    // JSON.stringify round trip would reformat the file and lose nothing but
    // produce a large, meaningless diff on every release.
    if (!/("version"\s*:\s*")[^"]*(")/.test(text)) fail('No "version" in tauri.conf.json');
    fs.writeFileSync(file, text.replace(/("version"\s*:\s*")[^"]*(")/, `$1${version}$2`));

}

function syncCargoToml() {

    const file = path.join(root, 'src-tauri', 'Cargo.toml');
    if (!fs.existsSync(file)) return;

    const text = fs.readFileSync(file, 'utf8');

    // Only the [package] version, which is the first `version =` in the file.
    // A blind replace would rewrite every dependency's version requirement.
    const pattern = /(\[package\][\s\S]*?\nversion\s*=\s*")[^"]*(")/;
    const match = text.match(pattern);
    if (!match) fail('No [package] version in src-tauri/Cargo.toml');

    const found = text.slice(match.index).match(/version\s*=\s*"([^"]*)"/)[1];
    if (found === version) return;

    problems.push(`src-tauri/Cargo.toml (${found} -> ${version})`);
    if (check) return;

    fs.writeFileSync(file, text.replace(pattern, `$1${version}$2`));

}

function syncCargoLock() {

    const file = path.join(root, 'src-tauri', 'Cargo.lock');
    if (!fs.existsSync(file)) return;

    const text = fs.readFileSync(file, 'utf8');

    // The lock file entry for the project's own crate. Left alone if cargo has
    // not written one yet. The next build regenerates it.
    const pattern = new RegExp(
        `(\\[\\[package\\]\\]\\nname = "${escapeRegExp(config.APP_CRATE_NAME)}"\\nversion = ")[^"]*(")`
    );
    const match = text.match(pattern);
    if (!match) return;

    const found = text.slice(match.index).match(/version = "([^"]*)"/)[1];
    if (found === version) return;

    problems.push(`src-tauri/Cargo.lock (${found} -> ${version})`);
    if (check) return;

    fs.writeFileSync(file, text.replace(pattern, `$1${version}$2`));

}

/// Helpers

function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function fail(message) {
    console.error(`sync-version: ${message}`);
    process.exit(1);
}
