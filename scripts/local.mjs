/**
 * Local checkouts in place of the submodules: shared by sync-local, setup,
 * build and check-config.
 *
 * A project normally gets the kit as the submodule lib/wisdom-kit, and the
 * libraries as submodules of the kit. On a machine that also has its own
 * checkouts of them (../wisdom-kit, ../wisdom...), project.local.sh, which is
 * gitignored, says to use those instead:
 *
 *   KIT_LOCAL_DIR="../wisdom-kit"
 *   WISDOM_LOCAL_DIR="../wisdom"
 *   TRACKER_LOCAL_DIR="../tracker"
 *   FACILE_LOCAL_DIR="../facile"
 *
 * The kit is used through a symbolic link at lib/wisdom-kit, because that
 * path is written in files that cannot read a setting (build.hxml, app.css,
 * Cargo.toml...). The libraries are only ever reached through haxelib, so
 * they need no link: the project's .haxelib simply points at the checkouts.
 *
 * Nothing here writes to the kit or the libraries. A project may not be
 * allowed to, so the only thing ever committed is the project's own pointer
 * to the kit, by sync-local.
 */

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { parseShellConfig } from './config.mjs';

export const LOCAL_FILE = 'project.local.sh';

/** Where the kit is mounted in a project. */
export const KIT_MOUNT = 'lib/wisdom-kit';

/** The kit's libraries, and the key that points one at a local checkout. */
export const LIBRARIES = {
    wisdom: 'WISDOM_LOCAL_DIR',
    tracker: 'TRACKER_LOCAL_DIR',
    facile: 'FACILE_LOCAL_DIR'
};

/**
 * The local checkouts project.local.sh asks for, as absolute paths.
 * `kit` and each library are null when not overridden.
 */
export function readLocal(root) {

    const file = path.join(root, LOCAL_FILE);
    const values = parseShellConfig(file);
    // Real paths: haxelib and git report those, so comparisons must use them too.
    const resolve = key => {
        if (!values[key]) return null;
        const dir = path.resolve(root, values[key]);
        return fs.existsSync(dir) ? fs.realpathSync(dir) : dir;
    };

    const libraries = {};
    for (const [name, key] of Object.entries(LIBRARIES)) libraries[name] = resolve(key);

    return {
        exists: fs.existsSync(file),
        kit: resolve('KIT_LOCAL_DIR'),
        libraries
    };

}

/** Where haxelib should find library `name`: its local checkout, or the kit's submodule. */
export function libraryDir(root, kit, name) {

    return readLocal(root).libraries[name] || path.join(kit, 'lib', name);

}

/** Runs git in `cwd` and returns its output, or null when it fails. */
export function git(cwd, args) {

    try {
        return execFileSync('git', args, { cwd, stdio: ['ignore', 'pipe', 'ignore'], encoding: 'utf8' }).trim();
    }
    catch {
        return null;
    }

}

/** The commit a repository has checked out, or null. */
export function head(dir) {

    return git(dir, ['rev-parse', 'HEAD']);

}

/** The commit `repo` records for the submodule at `entry`, from its index. */
export function recorded(repo, entry) {

    const line = git(repo, ['ls-files', '-s', '--', entry]);
    const match = line && line.match(/^160000 ([0-9a-f]{40}) /);
    return match ? match[1] : null;

}

/** The commit `repo`'s current commit pins for the submodule at `entry`. */
export function pinned(repo, entry) {

    const line = git(repo, ['ls-tree', 'HEAD', '--', entry]);
    const match = line && line.match(/^160000 commit ([0-9a-f]{40})\t/);
    return match ? match[1] : null;

}

/** Whether `link` is a symbolic link resolving to `target`. */
export function isLinkTo(link, target) {

    try {
        return fs.lstatSync(link).isSymbolicLink() && fs.realpathSync(link) === fs.realpathSync(target);
    }
    catch {
        return false;
    }

}

/** Warnings about a checkout: uncommitted work, detached HEAD, commit not pushed. */
export function checkoutWarnings(dir, label) {

    const warnings = [];
    if (git(dir, ['status', '--porcelain', '--ignore-submodules=dirty'])) {
        warnings.push(`${label} has uncommitted changes: they are used here but are in no commit`);
    }
    if (git(dir, ['symbolic-ref', '-q', 'HEAD']) == null) {
        warnings.push(`${label} is on a detached HEAD`);
    }
    if (!onRemote(dir, head(dir))) {
        warnings.push(`${label} ${short(head(dir))} is not on any remote branch yet: push it before others can fetch it`);
    }
    return warnings;

}

/** Whether `commit` is on one of `dir`'s remote-tracking branches. */
export function onRemote(dir, commit) {

    if (!commit) return false;
    const branches = git(dir, ['branch', '-r', '--contains', commit]);
    return branches != null && branches !== '';

}

export function short(sha) {

    return sha ? sha.slice(0, 7) : '(none)';

}

/**
 * What no longer matches project.local.sh, without changing anything: cheap
 * enough to run on every build. Empty when there is nothing to sync.
 */
export function staleness(root) {

    const local = readLocal(root);
    const mount = path.join(root, KIT_MOUNT);
    const linked = (() => { try { return fs.lstatSync(mount).isSymbolicLink(); } catch { return false; } })();
    const stale = [];

    if (local.kit) {
        if (!isLinkTo(mount, local.kit)) stale.push(`${KIT_MOUNT} does not point at ${path.relative(root, local.kit)}`);
        else if (recorded(root, KIT_MOUNT) !== head(local.kit)) stale.push(`${KIT_MOUNT} records another commit than ${path.relative(root, local.kit)}`);
    }
    else if (linked) {
        stale.push(`${KIT_MOUNT} is still a link, but ${LOCAL_FILE} no longer asks for one`);
    }

    const kit = (() => { try { return fs.realpathSync(mount); } catch { return null; } })();
    for (const [name, dir] of Object.entries(local.libraries)) {
        const dev = path.join(root, '.haxelib', name, '.dev');
        const current = fs.existsSync(dev) ? fs.readFileSync(dev, 'utf8').trim() : null;
        if (dir && current !== dir) stale.push(`haxelib ${name} does not point at ${path.relative(root, dir)}`);
        if (!dir && kit && current && current !== path.join(kit, 'lib', name)) {
            stale.push(`haxelib ${name} still points at ${path.relative(root, current)}, which ${LOCAL_FILE} no longer asks for`);
        }
    }

    return stale;

}
