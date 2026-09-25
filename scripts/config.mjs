/**
 * Read a project's configuration, applying the kit's defaults.
 *
 * One reader, used by every script in the kit, so the defaults cannot drift
 * between the JavaScript side and `scripts/lib.sh`. The two files must agree,
 * and `check-config` fails loudly if a project disagrees with either.
 *
 * MOST OF THESE ARE DERIVED. A project states its slug, its product name, its
 * bundle identifier and its main class. Everything else follows from the slug
 * unless the project deliberately says otherwise. That is what keeps
 * project.config.sh down to the handful of lines nobody else can guess.
 */

import fs from 'node:fs';
import path from 'node:path';

/**
 * Parse the assignments out of a shell config file.
 *
 * Assignments only, by design: these files are documented as regex-parsable
 * so that bash, the JavaScript scripts and the clone script all read exactly
 * the same thing out of them.
 */
export function parseShellConfig(file) {

    if (!fs.existsSync(file)) return {};

    const out = {};
    for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
        const match = line.match(/^([A-Z][A-Z0-9_]*)="(.*)"\s*$/);
        if (match) out[match[1]] = match[2];
    }
    return out;

}

/** The library name Cargo wants: underscores, and a suffix that cannot collide. */
export function defaultLibName(slug) {
    return slug.replace(/-/g, '_') + '_lib';
}

/**
 * Everything the scripts need, with defaults filled in.
 *
 * `kitDir` is optional; pass it to pick up the kit's own settings, which a
 * project may override.
 */
export function readConfig(root, kitDir) {

    const file = path.join(root, 'project.config.sh');
    if (!fs.existsSync(file)) {
        throw new Error(`No project.config.sh in ${root}. Is this a project built on the kit?`);
    }

    const kit = kitDir ? parseShellConfig(path.join(kitDir, 'kit.config.sh')) : {};
    const declared = { ...kit, ...parseShellConfig(file) };

    for (const required of ['APP_SLUG', 'APP_PRODUCT_NAME', 'APP_IDENTIFIER']) {
        if (!declared[required]) {
            throw new Error(`project.config.sh is missing ${required}`);
        }
    }

    const slug = declared.APP_SLUG;

    return {
        ...declared,

        APP_SLUG: slug,
        APP_PRODUCT_NAME: declared.APP_PRODUCT_NAME,
        APP_IDENTIFIER: declared.APP_IDENTIFIER,

        // Derived from the slug unless stated.
        APP_CRATE_NAME: declared.APP_CRATE_NAME || slug,
        APP_LIB_NAME: declared.APP_LIB_NAME || defaultLibName(slug),
        ARTIFACT_PREFIX: declared.ARTIFACT_PREFIX || slug,
        DOCKER_PREFIX: declared.DOCKER_PREFIX || slug,

        APP_HAXE_PACKAGE: declared.APP_HAXE_PACKAGE || 'app',
        APP_MAIN_CLASS: declared.APP_MAIN_CLASS || 'app.Main',

        WEB_DEV_PORT: declared.WEB_DEV_PORT || '5173',
        ITCH_TARGET: declared.ITCH_TARGET || '',
        // The app icon, drawn from a Lucide icon. Empty means the icons come
        // from resources/AppIcon.png instead.
        APP_ICON: declared.APP_ICON || '',
        APP_ICON_BACKGROUND: declared.APP_ICON_BACKGROUND || '#6366f1 #4338ca',
        APP_ICON_FOREGROUND: declared.APP_ICON_FOREGROUND || '#ffffff',
        APP_ICON_STROKE: declared.APP_ICON_STROKE || '2.25',

        /** Which keys the project actually wrote down, for the clone script. */
        declared: parseShellConfig(file)
    };

}
