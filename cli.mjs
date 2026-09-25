#!/usr/bin/env node
/**
 * The kit's command line. Every project built on it delegates here.
 *
 *     node lib/wisdom-kit/cli.mjs <command> [arguments]
 *
 * WHY A COMMAND LINE RATHER THAN PATHS IN package.json
 *
 * A project could call `node lib/wisdom-kit/scripts/copy-static.mjs` and so on
 * directly, and for a single project it would be the same thing. The
 * difference shows the day the build gains a step: with paths spelled out in
 * every project's package.json, that change has to be repeated in each one. A
 * command means the pipeline lives in the kit, and a project picks it up by
 * bumping the submodule.
 *
 * So the rule is: package.json delegates, and never describes. Anything that
 * looks like a build pipeline belongs in this file.
 *
 * The PROJECT is `process.cwd()`. npm always runs scripts from the directory
 * holding package.json, and every command below checks that assumption rather
 * than trusting it.
 */

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)));
const ROOT = process.cwd();

const [command, ...rest] = process.argv.slice(2);

if (!command || command === '--help' || command === '-h') {
    usage();
    process.exit(command ? 0 : 1);
}

if (!fs.existsSync(path.join(ROOT, 'package.json'))) {
    fail(`This must run from a project directory; ${ROOT} has no package.json.`);
}

/// Commands

const COMMANDS = {

    setup: () => node('setup-haxelibs.mjs', rest),

    'check-config': () => node('check-config.mjs', rest),

    'sync-config': () => node('sync-config.mjs', rest),
    'sync-local': () => node('sync-local.mjs', rest),
    'sync-version': () => node('sync-version.mjs', rest),

    clean: () => node('clean.mjs', rest),

    'generate-icons': () => node('generate-icons.mjs', rest),

    'create-app': () => node('create-app.mjs', rest),

    // The build pipeline, in one place. A project that wants an extra step
    // does NOT edit its package.json. It is added here and every project
    // inherits it.
    build: () => {
        const release = rest.includes('--release');

        // Wire the Haxe libraries first, unless this is an incremental
        // rebuild from the file watcher (marked --quiet). npm install runs
        // this through postinstall, but a project where that was skipped, or
        // that was moved, or whose .haxelib was wiped, would otherwise fail
        // deep in the Haxe compiler with "Library kit is not installed". The
        // step is idempotent and only rewrites the dev links, so it is cheap
        // to run before every full build and re-heals a stale checkout.
        if (!rest.includes('--quiet')) node('setup-haxelibs.mjs', ['--soft']);

        // Local checkouts (project.local.sh) that moved since the last
        // sync-local. Read-only: a reminder, never a change.
        node('check-local.mjs', []);

        // Names first: sync-version finds the crate in Cargo.lock by the
        // name sync-config writes.
        node('sync-config.mjs', []);
        node('sync-version.mjs', []);
        // A release starts from an empty dist/web, so nothing a development
        // build left there (a source map, a file since removed) ships with it.
        if (release) fs.rmSync(path.join(ROOT, 'dist', 'web'), { recursive: true, force: true });
        node('copy-static.mjs', []);
        haxe(release ? 'build.release.hxml' : 'build.hxml');
        if (release) node('minify.mjs', []);
        tailwind(release);
    },

    dev: () => watchAnd(['npx', 'tauri', 'dev']),

    'dev:web': () => watchAnd(['node', path.join(KIT, 'scripts', 'serve-web.mjs')]),

    tauri: () => run('npx', ['tauri', ...rest]),

    export: () => {
        const target = rest[0];
        const valid = ['mac', 'linux', 'windows', 'all'];
        if (!valid.includes(target)) {
            fail(`export needs one of: ${valid.join(', ')}`);
        }
        sh(path.join(KIT, `export-${target}.sh`), rest.slice(1));
    },

    'sign-mac': () => sh(path.join(KIT, 'sign-mac.sh'), rest),

    'publish-itchio': () => sh(path.join(KIT, 'publish-itchio.sh'), rest)

};

const handler = COMMANDS[command];
if (!handler) {
    console.error(`\nUnknown command: ${command}`);
    usage();
    process.exit(1);
}
handler();

/// Steps

function haxe(hxml) {
    if (!fs.existsSync(path.join(ROOT, hxml))) fail(`${hxml} is missing from this project`);
    run('haxe', [hxml]);
}

function tailwind(minify) {
    const input = ['src/app.css', 'src/styles.css'].find(f => fs.existsSync(path.join(ROOT, f)));
    if (!input) fail('No src/app.css to build the stylesheet from');

    const args = ['@tailwindcss/cli', '-i', './' + input, '-o', './dist/web/frontend.css'];
    if (minify) args.push('--minify');
    run('npx', args);
}

/**
 * Build once, then rebuild on every source change while something else runs
 * in the foreground.
 *
 * chokidar and the foreground process are started together and killed
 * together, so closing the app or the server also stops the watcher rather
 * than leaving it behind holding the terminal.
 */
function watchAnd(foreground) {

    COMMANDS.build();

    const watch = [
        'npx', 'chokidar',
        'src/**/*.hx', 'src/**/*.css', 'web/**',
        path.relative(ROOT, path.join(KIT, 'src', 'kit')) + '/**/*.hx',
        '-c', `node ${JSON.stringify(path.join(KIT, 'cli.mjs'))} build --quiet`
    ];

    // concurrently takes each side as one shell command line. Both are built
    // token by token and quoted per token, so a path with a space stays one
    // argument and a program name never merges with its first argument.
    const result = spawnSync('npx', [
        'concurrently', '--prefix', 'none', '--kill-others',
        watch.map(quote).join(' '),
        foreground.map(quote).join(' ')
    ], { cwd: ROOT, stdio: 'inherit' });

    process.exit(result.status ?? 1);

}

/// Plumbing

function node(script, args) {
    run('node', [path.join(KIT, 'scripts', script), ...args]);
}

function sh(script, args) {
    if (!fs.existsSync(script)) fail(`${script} is missing from the kit`);
    run('bash', [script, ...args]);
}

function run(command, args) {
    const result = spawnSync(command, args, { cwd: ROOT, stdio: 'inherit' });
    if (result.error) fail(`${command} could not be started: ${result.error.message}`);
    if (result.status !== 0) process.exit(result.status ?? 1);
}

function quote(value) {
    return /[^\w@./:-]/.test(value) ? `"${value.replace(/"/g, '\\"')}"` : value;
}

function fail(message) {
    console.error(`\nkit: ${message}\n`);
    process.exit(1);
}

function usage() {
    console.log(`
The wisdom-kit command line. Run from a project directory.

  setup             wire the Haxe libraries into a project-local .haxelib
  build             build into dist/web        (--release to minify)
  dev               build, watch, and open the desktop window
  dev:web           build, watch, and serve dist/web
  clean             remove dist                (--all also clears .haxelib and target)

  check-config      verify every file agrees with project.config.sh
  sync-config       push project.config.sh's names into npm, Cargo and Tauri
  sync-local        use the local checkouts named in project.local.sh
  sync-version      push package.json's version into Cargo and Tauri
  generate-icons    rebuild the desktop icons from APP_ICON or resources/AppIcon.png

  export mac        macOS universal, signed
  export linux      .deb, .rpm, .AppImage      (x64 | arm64)
  export windows    NSIS installer and a portable zip
  export all        everything this host can build
  sign-mac          notarize and staple
  publish-itchio    push dist/bundles to itch.io

  create-app <dir>  start a new project on this kit
`);
}
