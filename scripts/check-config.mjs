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

checkTauriConf();
checkCargoToml();
checkMainRs();
checkHaxeMain();
checkKitMounted();
checkTauriPlugins();

if (problems.length > 0) {
    console.error('Configuration is inconsistent with project.config.sh:\n');
    for (const p of problems) console.error(`  ${p}`);
    console.error('\nEdit project.config.sh and the file above so they agree,');
    console.error('or run `npm run create-app` to start a project under a new name.');
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

    const mount = path.relative(root, KIT).split(path.sep).join('/');
    if (!text.includes(`${mount}/kit.hxml`)) {
        problems.push(`build.hxml: should include ${mount}/kit.hxml`);
    }

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
