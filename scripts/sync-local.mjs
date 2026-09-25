#!/usr/bin/env node
/**
 * Make the project match project.local.sh: use the local checkouts it names,
 * and point the project at the kit commit they are on.
 *
 *     npm run sync-local
 *
 * The one command to run after editing project.local.sh, or after the local
 * checkouts moved. Safe to run again: it only changes what differs.
 *
 * The kit (KIT_LOCAL_DIR):
 *   - lib/wisdom-kit becomes a symbolic link to the checkout, marked
 *     skip-worktree so git status stays clean. It refuses while the submodule
 *     has uncommitted changes; its history stays in .git/modules.
 *   - The project's pointer to the kit is moved to the checkout's HEAD and
 *     committed as "Update wisdom-kit", that path only. Not when that commit
 *     is on no remote yet: a clone of the project could not fetch it.
 *
 * The libraries (WISDOM_LOCAL_DIR, TRACKER_LOCAL_DIR, FACILE_LOCAL_DIR):
 *   - .haxelib points at the checkouts. No git write at all.
 *   - A checkout on another commit than the one the kit pins is reported,
 *     not corrected: the kit belongs to whoever may commit to it.
 *
 * Removing a line from project.local.sh brings the submodule back, on the
 * commit last recorded.
 *
 * Never commits to the kit or to a library: a project may not have the right
 * to. See local.mjs.
 */

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
    KIT_MOUNT, LOCAL_FILE, checkoutWarnings, git, head, isLinkTo, onRemote, pinned, readLocal, recorded, short
} from './local.mjs';

// The project being synced. npm runs scripts from the directory holding
// package.json.
const root = process.cwd();
const mount = path.join(root, KIT_MOUNT);
const local = readLocal(root);
const report = [];
const warnings = [];

if (!git(root, ['rev-parse', '--git-dir'])) fail(`${root} is not a git repository`);

syncKit();
setupHaxelibs();
checkLibraries();

for (const line of report) console.log(`  ${line}`);
for (const line of warnings) console.log(`  warning: ${line}`);
if (report.length === 0 && warnings.length === 0) console.log('  nothing to sync');

/// The kit

function syncKit() {

    if (!local.kit) {
        unlinkKit();
        configureRecursion(false);
        return;
    }

    if (!fs.existsSync(path.join(local.kit, 'haxelib.json'))) {
        fail(`${LOCAL_FILE}: KIT_LOCAL_DIR ${path.relative(root, local.kit)} is not a wisdom-kit checkout`);
    }

    linkKit();
    configureRecursion(true);
    recordKit();
    warnings.push(...checkoutWarnings(local.kit, path.relative(root, local.kit)));

}

/** Replaces the submodule with a link to the local checkout. */
function linkKit() {

    const target = path.relative(path.dirname(mount), local.kit);
    if (isLinkTo(mount, local.kit)) return;

    if (fs.existsSync(mount) && !fs.lstatSync(mount).isSymbolicLink()) refuseToLoseWork();

    if (fs.existsSync(mount) || isSymlink(mount)) {
        if (isSymlink(mount)) fs.unlinkSync(mount);
        else {
            gitOrFail(root, ['submodule', 'deinit', '-q', '-f', '--', KIT_MOUNT]);
            fs.rmSync(mount, { recursive: true, force: true });
        }
    }

    fs.symlinkSync(target, mount, 'dir');
    gitOrFail(root, ['update-index', '--skip-worktree', '--', KIT_MOUNT]);
    report.push(`${KIT_MOUNT} -> ${target}`);

}

/**
 * The submodule is about to go. Its git directory stays in .git/modules, with
 * every branch and stash, so the only thing deinit really loses is the
 * uncommitted work in the folder: refuse on that. Branches the local checkout
 * lacks are only reported, with where they stay.
 */
function refuseToLoseWork() {

    const status = git(mount, ['status', '--porcelain']);
    if (status) {
        fail(`${KIT_MOUNT} has uncommitted changes, which replacing it would lose:\n` +
            status.split('\n').map(l => `    ${l}`).join('\n') +
            `\n  Commit them, or move them to ${path.relative(root, local.kit)}, then run this again.`);
    }

    const tips = (git(mount, ['for-each-ref', '--format=%(objectname) %(refname:short)', 'refs/heads']) || '')
        .split('\n').filter(Boolean);
    for (const tip of tips) {
        const [sha, name] = tip.split(' ');
        if (git(local.kit, ['cat-file', '-e', `${sha}^{commit}`]) == null) {
            warnings.push(`branch ${name} (${short(sha)}) of the old submodule is not in ${path.relative(root, local.kit)}: ` +
                `it stays in .git/modules/${KIT_MOUNT}`);
        }
    }

}

/** Moves the project's pointer to the checkout's HEAD, and commits it. */
function recordKit() {

    const target = head(local.kit);
    const before = recorded(root, KIT_MOUNT);
    if (target === before) return;

    // Only a commit others can fetch may be recorded.
    git(local.kit, ['fetch', '-q', '--no-recurse-submodules']);
    if (!onRemote(local.kit, target)) {
        warnings.push(`${path.relative(root, local.kit)} is on ${short(target)}, which is on no remote branch: ` +
            `the project still records ${short(before)}. Push it (or have it pushed), then run this again.`);
        return;
    }

    setPointer(target);

    if (git(root, ['rev-parse', '-q', '--verify', 'HEAD']) == null) {
        report.push(`${KIT_MOUNT} ${short(before)} -> ${short(target)}, staged (the project has no commit yet)`);
        return;
    }
    commitPointer(target, 'Update wisdom-kit');
    report.push(`${KIT_MOUNT} ${short(before)} -> ${short(target)}, committed "Update wisdom-kit"`);

}

/** Sets the pointer in the index, around the skip-worktree flag. */
function setPointer(sha) {

    gitOrFail(root, ['update-index', '--no-skip-worktree', '--', KIT_MOUNT]);
    gitOrFail(root, ['update-index', '--cacheinfo', `160000,${sha},${KIT_MOUNT}`]);
    gitOrFail(root, ['update-index', '--skip-worktree', '--', KIT_MOUNT]);

}

/**
 * Commits the pointer alone. Built from HEAD's tree in a scratch index, so
 * nothing else the user has staged goes into it, and so the link on disk is
 * never read in place of the gitlink.
 */
function commitPointer(sha, message) {

    const index = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'sync-local-')), 'index');
    const env = { ...process.env, GIT_INDEX_FILE: index };
    const run = args => execFileSync('git', args, { cwd: root, env, encoding: 'utf8' }).trim();
    try {
        run(['read-tree', 'HEAD']);
        run(['update-index', '--cacheinfo', `160000,${sha},${KIT_MOUNT}`]);
        const tree = run(['write-tree']);
        const parent = run(['rev-parse', 'HEAD']);
        const commit = execFileSync('git', ['commit-tree', tree, '-p', parent, '-m', message],
            { cwd: root, encoding: 'utf8' }).trim();
        gitOrFail(root, ['update-ref', '-m', `sync-local: ${message}`, 'HEAD', commit, parent]);
    }
    finally {
        fs.rmSync(path.dirname(index), { recursive: true, force: true });
    }

}

/**
 * git fetch, pull and checkout recurse into submodules by default, and stop
 * on the link with "expected submodule path ... not to be a symbolic link".
 * While the kit is a link, this project's own git config turns that off;
 * back to the submodule, the defaults return. Nothing else is touched.
 */
function configureRecursion(linked) {

    for (const key of ['fetch.recurseSubmodules', 'submodule.recurse']) {
        const current = git(root, ['config', '--local', '--get', key]);
        if (linked && current !== 'false') {
            gitOrFail(root, ['config', '--local', key, 'false']);
            report.push(`git config ${key} false (while ${KIT_MOUNT} is a link)`);
        }
        if (!linked && current === 'false') {
            gitOrFail(root, ['config', '--local', '--unset', key]);
            report.push(`git config ${key} back to its default`);
        }
    }

}

/** Back to the submodule, on the commit last recorded. */
function unlinkKit() {

    if (!isSymlink(mount)) return;
    fs.unlinkSync(mount);
    gitOrFail(root, ['update-index', '--no-skip-worktree', '--', KIT_MOUNT]);
    gitOrFail(root, ['submodule', 'update', '-q', '--init', '--recursive', '--', KIT_MOUNT]);
    report.push(`${KIT_MOUNT} is the submodule again, on ${short(recorded(root, KIT_MOUNT))}`);

}

/// The libraries

/** .haxelib, from the kit now in place. It reads project.local.sh itself. */
function setupHaxelibs() {

    const script = path.join(mount, 'scripts', 'setup-haxelibs.mjs');
    execFileSync('node', [script, '--soft'], { cwd: root, stdio: 'inherit' });

}

function checkLibraries() {

    const kit = fs.realpathSync(mount);
    for (const [name, dir] of Object.entries(local.libraries)) {
        if (!dir) continue;
        const label = path.relative(root, dir);
        const at = head(dir);
        const pin = pinned(kit, `lib/${name}`);
        report.push(`${name.padEnd(7)} -> ${label}  ${short(at)}` + (at === pin ? '  (the version the kit pins)' : ''));
        if (at !== pin) {
            warnings.push(`${label} is on ${short(at)}, but the kit pins ${short(pin)}: a clone of this project ` +
                `builds with ${short(pin)}. To move the kit, whoever may commit to it updates lib/${name} in ` +
                `${path.relative(root, kit)}, commits and pushes, then this runs again.`);
        }
        warnings.push(...checkoutWarnings(dir, label));
    }

}

/// Helpers

function isSymlink(file) {

    try {
        return fs.lstatSync(file).isSymbolicLink();
    }
    catch {
        return false;
    }

}

function gitOrFail(cwd, args) {

    try {
        return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    }
    catch (error) {
        fail(`git ${args.join(' ')} failed in ${path.relative(root, cwd) || '.'}:\n  ${String(error.stderr || error.message).trim()}`);
    }

}

function fail(message) {

    console.error(`\nsync-local: ${message}\n`);
    process.exit(1);

}
