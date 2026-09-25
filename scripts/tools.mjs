/**
 * Run the project's command line tools the same way on every system.
 *
 * Not through `npx` or `npm`: on Windows those are .cmd scripts, which Node
 * cannot start without a shell (spawn fails with ENOENT, and recent Node
 * refuses a .cmd without shell: true). Each tool is instead started as what it
 * really is, a JavaScript file run by this very Node, found through the
 * `bin` entry of its package in the project's node_modules. No shell, no
 * quoting, and the version is the one the project installed.
 */

import fs from 'node:fs';
import path from 'node:path';

/**
 * The command and first argument that run `bin` of package `pkg`, installed
 * in the project at `root`: [node, <path to the tool's script>].
 */
export function tool(root, pkg, bin) {

    const dir = path.join(root, 'node_modules', pkg);
    const manifest = path.join(dir, 'package.json');
    if (!fs.existsSync(manifest)) {
        throw new Error(`${pkg} is not installed in ${root}. Run: npm install`);
    }
    const bins = JSON.parse(fs.readFileSync(manifest, 'utf8')).bin;
    const file = typeof bins === 'string' ? bins : bins && bins[bin];
    if (!file) throw new Error(`${pkg} has no "${bin}" command`);
    return [process.execPath, path.join(dir, file)];

}

/**
 * The command and first arguments that run npm itself. Under `npm run`, npm
 * says where its own script is (npm_execpath), which Node runs directly.
 * Otherwise `npm`, through a shell on Windows, where it is npm.cmd.
 */
export function npm() {

    const execpath = process.env.npm_execpath;
    if (execpath && /\.c?js$/.test(execpath)) return { command: process.execPath, args: [execpath], shell: false };
    return { command: 'npm', args: [], shell: process.platform === 'win32' };

}
