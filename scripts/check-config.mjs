#!/usr/bin/env node
/**
 * Verify that every file in a project agrees with its project.config.sh.
 *
 * That file is the single source of truth for the names a project builds
 * under, and nothing enforces that on its own. Rename a crate in Cargo.toml
 * and forget the config, and the export scripts will look for an artifact that
 * was never produced, an hour into the build. This fails in a second.
 *
 * Most names are DERIVED from the slug (see config.mjs), so a project only
 * disagrees with itself when it states one explicitly and then edits the other
 * copy.
 *
 * Run by `npm run check-config`, by every export script, and by CI.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readConfig } from './config.mjs';
import {
    KIT_MOUNT, LIBRARIES, checkoutWarnings, head, onRemote, pinned, readLocal, recorded, short, staleness
} from './local.mjs';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being checked. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();

let config;
try {
    config = readConfig(root, KIT);
}
catch (error) {
    console.error(`check-config: ${error.message}`);
    process.exit(1);
}

const problems = [];
// Problems with the local checkouts of project.local.sh, which call for
// another remedy than the names.
let localProblems = 0;

checkTauriConf();
checkCargoToml();
checkMainRs();
checkHaxeMain();
checkKitMounted();
checkTauriPlugins();
checkOpenerScope();
checkLocalCheckouts();

if (problems.length > 0) {
    console.error('Configuration is inconsistent with project.config.sh:\n');
    for (const p of problems) console.error(`  ${p}`);
    if (localProblems < problems.length) {
        console.error('\nRun `npm run sync-config` (every build does) to write the names in');
        console.error('project.config.sh into those files, or fix the file by hand.');
    }
    if (localProblems > 0) {
        console.error('\nA release must be built from commits anybody can fetch. Commit and push the');
        console.error('local checkouts, then run `npm run sync-local`, or remove project.local.sh to');
        console.error('build from the submodules.');
    }
    process.exit(1);
}

console.log(`  config consistent (${config.APP_SLUG}, ${config.APP_IDENTIFIER})`);

/// Checks

function checkTauriConf() {

    const file = 'src-tauri/tauri.conf.json';
    const conf = readJson(file);
    if (!conf) return;

    expect(file, 'productName', conf.productName, config.APP_PRODUCT_NAME);
    expect(file, 'identifier', conf.identifier, config.APP_IDENTIFIER);

    const window = (conf.app && conf.app.windows && conf.app.windows[0]) || {};
    expect(file, 'app.windows[0].title', window.title, config.APP_PRODUCT_NAME);

    // withGlobalTauri is what puts window.__TAURI__ in the page. Platform
    // detects the host by looking for it, so turning it off would silently
    // make the desktop build take the browser code path.
    if (!conf.app || conf.app.withGlobalTauri !== true) {
        problems.push(`${file}: app.withGlobalTauri must be true, or Platform falls back to the web backend`);
    }

    // dist/web is simultaneously the web build and the desktop frontend. Two
    // directories would be two chances to ship something untested.
    expect(file, 'build.frontendDist', conf.build && conf.build.frontendDist, '../dist/web');

}

function checkCargoToml() {

    const file = 'src-tauri/Cargo.toml';
    const text = readText(file);
    if (text == null) return;

    const name = firstGroup(text, /\[package\][\s\S]*?\nname\s*=\s*"([^"]*)"/);
    expect(file, '[package].name', name, config.APP_CRATE_NAME);

    const lib = firstGroup(text, /\[lib\][\s\S]*?\nname\s*=\s*"([^"]*)"/);
    expect(file, '[lib].name', lib, config.APP_LIB_NAME);

}

function checkMainRs() {

    const file = 'src-tauri/src/main.rs';
    const text = readText(file);
    if (text == null) return;

    if (!text.includes(`${config.APP_LIB_NAME}::run()`)) {
        problems.push(`${file}: should call ${config.APP_LIB_NAME}::run()`);
    }

}

function checkHaxeMain() {

    const file = 'build.hxml';
    const text = readText(file);
    if (text == null) return;

    const main = firstGroup(text, /^--main\s+(\S+)/m);
    expect(file, '--main', main, config.APP_MAIN_CLASS);

    const classPath = config.APP_MAIN_CLASS.replace(/\./g, '/') + '.hx';
    if (!fs.existsSync(path.join(root, 'src', classPath))) {
        problems.push(`src/${classPath}: the main class named in project.config.sh does not exist`);
    }

}

/**
 * The project has to actually include the kit's hxml, or it would compile
 * against whatever happens to be lying around instead of the pinned set.
 */
function checkKitMounted() {

    const text = readText('build.hxml');
    if (text == null) return;

    // Seen from the project: lib/wisdom-kit, also when it is a link to a
    // local checkout (project.local.sh), where KIT is the checkout's real path.
    const linked = fs.existsSync(path.join(root, KIT_MOUNT))
        && fs.realpathSync(path.join(root, KIT_MOUNT)) === fs.realpathSync(KIT);
    const mount = linked ? KIT_MOUNT : path.relative(root, KIT).split(path.sep).join('/');
    if (!text.includes(`${mount}/kit.hxml`)) {
        problems.push(`build.hxml: should include ${mount}/kit.hxml`);
    }

}

/**
 * opener:allow-open-url alone allows the command with an EMPTY scope, so every
 * URL is refused and Platform.openUrl fails with no visible sign. It needs
 * opener:allow-default-urls (http, https, mailto, tel) or a scope of its own.
 */
function checkOpenerScope() {

    const file = 'src-tauri/capabilities/default.json';
    const text = readText(file, true);
    if (text == null) return;
    const scoped = text.includes('"opener:allow-default-urls"') || text.includes('"opener:default"')
        || /"identifier"\s*:\s*"opener:allow-open-url"/.test(text);
    if (text.includes('"opener:allow-open-url"') && !scoped) {
        problems.push(`${file}: opener:allow-open-url has no URL scope, so every link is refused. Add "opener:allow-default-urls"`);
    }

}

/**
 * Local checkouts (project.local.sh). Out of date: a reminder. With
 * --release, which the export scripts pass: a refusal unless every local
 * checkout is exactly a pushed commit the project records, or the kit pins,
 * so a shipped build is one anybody can rebuild.
 */
function checkLocalCheckouts() {

    const local = readLocal(root);
    if (!local.exists) return;

    for (const line of staleness(root)) console.log(`  warning: ${line}: run npm run sync-local`);
    if (!process.argv.includes('--release')) return;

    const kit = fs.realpathSync(path.join(root, KIT_MOUNT));
    const checkouts = [];
    if (local.kit) checkouts.push([local.kit, recorded(root, KIT_MOUNT), 'recorded by the project']);
    for (const name of Object.keys(LIBRARIES)) {
        const dir = local.libraries[name];
        if (dir) checkouts.push([dir, pinned(kit, `lib/${name}`), 'pinned by the kit']);
    }

    const before = problems.length;
    for (const [dir, expected, by] of checkouts) {
        const label = path.relative(root, dir);
        const at = head(dir);
        if (at !== expected) problems.push(`${label} is on ${short(at)}, not ${short(expected)} ${by}`);
        if (!onRemote(dir, at)) problems.push(`${label} ${short(at)} is on no remote branch`);
        for (const w of checkoutWarnings(dir, label)) {
            if (w.includes('uncommitted')) problems.push(w);
        }
    }
    localProblems = problems.length - before;

}

/**
 * The kit registers the plugins, but Cargo has to see them here.
 *
 * Tauri's ACL collects permission manifests through Cargo's `links`
 * mechanism, which only reaches DIRECT dependents. A plugin reachable only
 * through the kit compiles and then dies at startup with
 * "Permission dialog:allow-open not found", which is a long way from the
 * cause. Comparing the two lists turns that into a one-second failure.
 */
function checkTauriPlugins() {

    const wanted = (config.KIT_TAURI_PLUGINS || '').split(/\s+/).filter(Boolean);
    if (wanted.length === 0) return;

    const text = readText('src-tauri/Cargo.toml');
    if (text == null) return;

    const missing = wanted.filter(name => !new RegExp(`^tauri-plugin-${name}\\s*=`, 'm').test(text));

    if (missing.length > 0) {
        problems.push(
            'src-tauri/Cargo.toml: missing direct dependencies for the plugins the kit registers: '
            + missing.map(n => `tauri-plugin-${n}`).join(', ')
        );
    }

}

/// Helpers

function readText(file, optional = false) {

    const full = path.join(root, file);
    if (!fs.existsSync(full)) {
        if (!optional) problems.push(`${file}: missing`);
        return null;
    }
    return fs.readFileSync(full, 'utf8');

}

function readJson(file) {

    const text = readText(file);
    if (text == null) return null;
    try {
        return JSON.parse(text);
    }
    catch (e) {
        problems.push(`${file}: not valid JSON (${e.message})`);
        return null;
    }

}

function firstGroup(text, pattern) {
    const match = text.match(pattern);
    return match ? match[1] : null;
}

function expect(file, what, found, wanted) {
    if (found !== wanted) {
        problems.push(`${file}: ${what} is ${JSON.stringify(found)}, expected ${JSON.stringify(wanted)}`);
    }
}
