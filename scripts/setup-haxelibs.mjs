#!/usr/bin/env node
/**
 * Wire the kit and its libraries into a project-local haxelib repository.
 *
 * This is what makes a fresh clone build. Nothing is downloaded from haxelib:
 * the kit is a git submodule of your project, and wisdom, tracker and facile
 * are git submodules of the KIT, pinned to the exact commits it was verified
 * against. Your project therefore has one submodule, not four, and bumping the
 * kit moves all of them together.
 *
 * They are registered as haxelib "dev" links rather than added to the class
 * path, because wisdom ships an extraParams.hxml carrying
 * `--macro wisdom.XMacro.makePropsObservable()`, and Haxe only applies that
 * file for a --library. With a plain class path everything compiles and
 * @props silently stop being observable, which shows up much later as
 * components that never re-render.
 *
 * .haxelib/ records absolute paths, so it belongs to the project, is
 * gitignored, and is regenerated here on every install.
 *
 *   kit setup            report what it does
 *   kit setup --soft     stay quiet unless something is wrong
 */

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { libraryDir } from './local.mjs';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// The project being built. npm runs scripts from the directory holding
// package.json, and the kit lives under lib/ inside it.
const root = process.cwd();

const soft = process.argv.includes('--soft');

/**
 * Library name -> the directory holding its haxelib.json: the kit's
 * submodule, or the local checkout project.local.sh names (see local.mjs).
 */
const LIBS = {
    kit: KIT,
    wisdom: libraryDir(root, KIT, 'wisdom'),
    tracker: libraryDir(root, KIT, 'tracker'),
    facile: libraryDir(root, KIT, 'facile')
};

function say(message) {
    if (!soft) console.log(message);
}

function fail(message) {
    console.error('\n' + message + '\n');
    process.exit(1);
}

function run(args, options = {}) {
    return execFileSync(args[0], args.slice(1), {
        cwd: root,
        stdio: 'pipe',
        encoding: 'utf8',
        ...options
    });
}

// 1. haxelib must exist at all.
try {
    run(['haxelib', 'version']);
}
catch {
    const versionFile = path.join(root, '.haxe-version');
    const version = fs.existsSync(versionFile)
        ? fs.readFileSync(versionFile, 'utf8').trim()
        : '4.3.7';
    fail(
        'haxelib not found.\n' +
        `Install Haxe ${version} or newer:\n` +
        '  macOS   brew install haxe\n' +
        '  Linux   https://haxe.org/download/\n' +
        '  Windows https://haxe.org/download/'
    );
}

// 2. The kit itself must be checked out. A clone without --recurse-submodules
//    leaves lib/wisdom-kit empty, which fails later with a confusing
//    "Type not found : kit.App", so catch it here and say so.
if (!fs.existsSync(path.join(KIT, 'haxelib.json'))) {
    fail(
        `The kit is missing from ${path.relative(root, KIT)}.\n` +
        'It is a git submodule. Fetch it with:\n' +
        '  git submodule update --init --recursive'
    );
}

// 3. And so must the kit's own submodules.
const missing = Object.entries(LIBS)
    .filter(([name]) => name !== 'kit')
    .filter(([, dir]) => !fs.existsSync(path.join(dir, 'src')))
    .map(([name]) => name);

if (missing.length > 0) {
    say(`  fetching the kit's submodules (${missing.join(', ')} missing)...`);
    try {
        run(['git', 'submodule', 'update', '--init', '--recursive'], { cwd: KIT, stdio: 'inherit' });
    }
    catch {
        fail(
            `These libraries are missing: ${missing.join(', ')}\n` +
            'They are submodules of the kit. Fetch them with:\n' +
            `  git -C ${path.relative(root, KIT)} submodule update --init --recursive`
        );
    }
}

// 4. A project-local haxelib repo, so this never touches the global one.
if (!fs.existsSync(path.join(root, '.haxelib'))) {
    say('  creating project-local haxelib repository');
    run(['haxelib', 'newrepo']);
}

// 5. Dev-link each library. Re-run every time: the .dev file holds an absolute
//    path, so it is wrong after a move, a clone, or on another machine.
for (const [name, dir] of Object.entries(LIBS)) {
    run(['haxelib', 'dev', name, dir]);
    say(`  ${name.padEnd(8)} -> ${path.relative(root, dir)}`);
}

// 6. Prove it actually resolves, rather than trusting that it did.
for (const [name, dir] of Object.entries(LIBS)) {
    const resolved = run(['haxelib', 'libpath', name]).trim();
    if (!resolved.startsWith(dir)) {
        fail(`${name} resolves to ${resolved}, expected ${dir}. Try: npm run setup`);
    }
}

say('  haxe libraries ready');
