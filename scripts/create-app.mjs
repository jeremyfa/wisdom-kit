#!/usr/bin/env node
/**
 * Start a new project on this kit.
 *
 *     node lib/wisdom-kit/scripts/create-app.mjs ../my-app \
 *         --name "My App" --identifier com.acme.myapp --verify
 *
 * WHAT IT PRODUCES
 *
 * A project of about two dozen files, none of which is generic: its names, its
 * own application code, and the handful of Tauri and build files that cannot
 * live anywhere but a project root. Everything reusable stays in the kit,
 * mounted as the single submodule `lib/wisdom-kit`, so a fix there reaches
 * every project by bumping one pointer instead of being copied into each.
 *
 * WHY THE SUBSTITUTION IS ONE PASS, SORTED LONGEST FIRST
 *
 * "wisdom-app" has "wisdom" as a prefix, and "wisdom" is both a dependency and
 * part of the kit's own directory name. A cascade of sequential replacements
 * would rewrite `lib/wisdom-kit` and the result would not compile. The bare
 * token "wisdom" is therefore never in the table, and a single pass means no
 * replacement's output can be fed into another's input.
 *
 * Then a residual scan over the whole result, which is what catches whatever
 * the table forgot.
 */

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';
import { defaultLibName } from './config.mjs';
import { npm } from './tools.mjs';

const KIT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const TEMPLATE = path.join(KIT, 'template');

/** Placeholder names in template/, replaced with the new project's own. */
const PLACEHOLDER = {
    slug: 'wisdom-app',
    productName: 'Wisdom App',
    identifier: 'com.example.wisdomapp',
    libName: 'wisdom_app_lib'
};

/** Copied byte for byte, never searched for tokens. */
const BINARY_EXTENSIONS = new Set([
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.icns', '.pdf',
    '.woff', '.woff2', '.ttf', '.otf', '.eot', '.zip', '.gz'
]);

main().catch(error => {
    console.error('\n' + (error && error.message ? error.message : String(error)) + '\n');
    process.exit(1);
});

async function main() {

    const options = parseArgs(process.argv.slice(2));

    if (!options.target) {
        usage();
        process.exit(1);
    }

    if (!fs.existsSync(TEMPLATE)) {
        fail(`The kit has no template/ at ${TEMPLATE}`);
    }

    const target = path.resolve(process.cwd(), options.target);

    if (target === KIT || target.startsWith(KIT + path.sep)) {
        fail('The target is inside the kit. Put the project somewhere else.');
    }
    if (fs.existsSync(target) && fs.readdirSync(target).length > 0 && !options.force) {
        fail(`${target} already exists and is not empty.\nPass --force to write into it anyway.`);
    }

    const answers = await collectAnswers(options, path.basename(target));
    const table = buildTable(answers);

    describe(target, answers, table);

    if (options.dryRun) {
        console.log('\n--dry-run: nothing was written.\n');
        return;
    }

    console.log('');
    const copied = copyTree(TEMPLATE, target, table);
    console.log(`  ${copied} files written`);

    if (answers.haxePackage !== 'app') {
        renameHaxePackage(target, answers);
        console.log(`  Haxe package app -> ${answers.haxePackage}`);
    }

    writeProjectConfig(target, answers);
    writePackageJson(target, answers);

    if (options.git) {
        setupGit(target, options);
    }
    else {
        console.log('  --no-git: lib/wisdom-kit is empty and there is no repository yet');
    }

    const residuals = scanForResiduals(target, table);
    reportResiduals(residuals);

    // Install by default so the project is ready to run. It needs the kit
    // submodule in place, so it only happens when git is on.
    if (options.git && (options.install || options.verify)) runInstall(target, options.git);
    if (options.verify) runVerification(target);

    done(target, answers, options, residuals);

}

/// Arguments

function parseArgs(argv) {

    const options = {
        target: null, name: null, slug: null, identifier: null,
        description: null, author: null, haxePackage: null,
        git: true, commit: false, install: true, verify: false,
        yes: false, dryRun: false, force: false
    };

    const takesValue = {
        '--name': 'name', '--slug': 'slug', '--identifier': 'identifier',
        '--description': 'description', '--author': 'author',
        '--haxe-package': 'haxePackage'
    };

    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];

        if (takesValue[arg]) {
            const value = argv[++i];
            if (value == null) fail(`${arg} needs a value`);
            options[takesValue[arg]] = value;
            continue;
        }

        const inline = arg.match(/^(--[a-z-]+)=(.*)$/);
        if (inline && takesValue[inline[1]]) {
            options[takesValue[inline[1]]] = inline[2];
            continue;
        }

        switch (arg) {
            case '--no-git': options.git = false; break;
            case '--commit': options.commit = true; break;
            case '--install': options.install = true; break;
            case '--no-install': options.install = false; break;
            case '--verify': options.verify = true; break;
            case '--yes': case '-y': options.yes = true; break;
            case '--dry-run': options.dryRun = true; break;
            case '--force': options.force = true; break;
            case '--help': case '-h': usage(); process.exit(0); break;
            default:
                if (arg.startsWith('-')) fail(`Unknown option: ${arg}`);
                if (options.target) fail(`Only one target directory, got "${options.target}" and "${arg}"`);
                options.target = arg;
        }
    }

    return options;

}

function usage() {
    console.log(`
Start a new project on the wisdom kit.

    node lib/wisdom-kit/scripts/create-app.mjs <target-directory> [options]

Options
    --name "My App"            Human-facing product name
    --slug my-app              kebab-case name for packages and artifacts
    --identifier com.acme.app  Reverse-DNS bundle identifier. ASKED, NEVER GUESSED
    --description "..."        One line, used in package.json and Cargo.toml
    --author "Name"            Copyright holder
    --haxe-package mypkg       Your Haxe package (default: app; the kit is always "kit")

    --no-git                   Do not create a repository or fetch the kit
    --commit                   Make an initial commit
    --no-install               Skip npm install (it runs by default)
    --verify                   Also run the config check and a real build
    --yes                      Accept the derived defaults without prompting
    --dry-run                  Show what would happen, write nothing
    --force                    Write into a non-empty directory

The project starts from the kit's bare template. For a worked example of every
convention, read the wisdom-app repository.
`);
}

/// Answers

async function collectAnswers(options, targetBasename) {

    const rl = (!options.yes && process.stdin.isTTY)
        ? readline.createInterface({ input: process.stdin, output: process.stdout })
        : null;

    const ask = async (question, fallback) => {
        if (!rl) return fallback;
        const answer = await new Promise(resolve =>
            rl.question(`${question}${fallback ? ` [${fallback}]` : ''}: `, resolve));
        return answer.trim() || fallback;
    };

    try {
        const name = options.name || await ask('Product name', titleCase(targetBasename));
        const slug = options.slug || await ask('Slug (kebab-case)', slugify(name));

        // Deliberately not derived in silence. A wrong bundle identifier is
        // invisible until release, then collides in the macOS Launch Services
        // database and the Windows registry, and changing it afterwards orphans
        // every user's existing settings.
        let identifier = options.identifier;
        if (!identifier) {
            const suggestion = `com.example.${slug.replace(/-/g, '')}`;
            identifier = await ask('Bundle identifier (reverse DNS)', rl ? suggestion : null);
            if (!identifier) {
                fail('--identifier is required.\n'
                    + '\n'
                    + 'It is the macOS bundle id, the Windows registry key and the name of\n'
                    + "each user's settings directory. Getting it wrong is invisible until\n"
                    + 'release, and changing it later loses every setting, so this script\n'
                    + 'will not guess one for you.\n'
                    + '\n'
                    + `Something like: com.example.${slug.replace(/-/g, '')}`);
            }
        }

        const description = options.description
            || await ask('Description', `${name}, built on the wisdom kit`);
        const author = options.author || await ask('Author', '') || '';
        const haxePackage = options.haxePackage || 'app';

        validate(name, slug, identifier, haxePackage);

        return {
            name, slug, identifier, description, author, haxePackage,
            mainClass: `${haxePackage}.Main`,
            libName: defaultLibName(slug)
        };
    }
    finally {
        if (rl) rl.close();
    }

}

function validate(name, slug, identifier, haxePackage) {

    if (!name) fail('The product name cannot be empty');

    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug)) {
        fail(`Slug "${slug}" is not valid.\n`
            + 'Lowercase letters, digits and single hyphens. It becomes the npm\n'
            + 'package name, the Rust crate name and the artifact file prefix.');
    }

    if (!/^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$/.test(identifier)) {
        fail(`Bundle identifier "${identifier}" is not valid.\n`
            + 'It needs at least two dot-separated parts, each starting with a\n'
            + 'letter. For example: com.example.myapp');
    }

    if (!/^[a-z][a-z0-9_]*$/.test(haxePackage)) {
        fail(`Haxe package "${haxePackage}" is not valid.\n`
            + 'Lowercase letters, digits and underscores, starting with a letter.');
    }

    if (['kit', 'wisdom', 'tracker', 'facile'].includes(haxePackage)) {
        fail(`The Haxe package cannot be called "${haxePackage}": that is the kit\n`
            + 'or one of its libraries, and the name would collide on every import.');
    }

}

/// Substitution

function buildTable(answers) {

    // No bare "wisdom": it is a dependency and part of the kit's own path.
    const pairs = [
        [PLACEHOLDER.libName, answers.libName],
        [PLACEHOLDER.identifier, answers.identifier],
        [PLACEHOLDER.productName, answers.name],
        [PLACEHOLDER.slug, answers.slug]
    ];

    const bare = PLACEHOLDER.identifier.split('.').pop();
    if (bare && bare !== PLACEHOLDER.slug) {
        pairs.push([bare, answers.identifier.split('.').pop()]);
    }

    const seen = new Set();
    const table = [];
    for (const [from, to] of pairs) {
        if (!from || seen.has(from)) continue;
        seen.add(from);
        table.push({ from, to });
    }
    // Longest first, so no shorter token can match inside a longer one.
    table.sort((a, b) => b.from.length - a.from.length);
    return table;

}

function makeReplacer(table) {
    const pattern = new RegExp(table.map(e => escapeRegExp(e.from)).join('|'), 'g');
    const lookup = new Map(table.map(e => [e.from, e.to]));
    return text => text.replace(pattern, m => lookup.get(m));
}

function copyTree(from, to, table) {

    const replace = makeReplacer(table);
    let count = 0;

    const walk = (dir, relative) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            const source = path.join(dir, entry.name);
            const rel = relative ? path.join(relative, entry.name) : entry.name;

            if (entry.isDirectory()) {
                walk(source, rel);
                continue;
            }
            if (!entry.isFile()) continue;

            const destination = path.join(to, replace(rel));
            fs.mkdirSync(path.dirname(destination), { recursive: true });

            if (BINARY_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) {
                fs.copyFileSync(source, destination);
            }
            else {
                fs.writeFileSync(destination, replace(fs.readFileSync(source, 'utf8')));
                fs.chmodSync(destination, fs.statSync(source).mode);
            }
            count++;
        }
    };

    fs.mkdirSync(to, { recursive: true });
    walk(from, '');
    return count;

}

/// Haxe package rename
//
// Targeted patterns rather than a blind token swap. "app" is an ordinary
// English word that appears in prose, in CSS class names and in Tauri's own
// configuration, so replacing it everywhere would corrupt far more than it
// fixed. What can legally follow the package name is read off the source tree
// itself, so the list cannot drift as the template grows.

function renameHaxePackage(target, answers) {

    const from = path.join(target, 'src', 'app');
    const to = path.join(target, 'src', answers.haxePackage);
    if (fs.existsSync(from)) fs.renameSync(from, to);

    const members = fs.existsSync(to)
        ? fs.readdirSync(to, { withFileTypes: true })
            .map(e => e.isDirectory() ? e.name : e.name.replace(/\.hx$/, ''))
            .filter(name => name !== 'import')
        : [];

    const pkg = answers.haxePackage;
    const patterns = [
        [/\bpackage app(\.|;)/g, `package ${pkg}$1`],
        [/\bimport app\./g, `import ${pkg}.`],
        [/\busing app\./g, `using ${pkg}.`],
        [/\bapp\.Main\b/g, `${pkg}.Main`],
        [/\bapp\.\*/g, `${pkg}.*`]
    ];
    if (members.length > 0) {
        patterns.push([
            new RegExp(`\\bapp\\.(${members.map(escapeRegExp).join('|')})\\b`, 'g'),
            `${pkg}.$1`
        ]);
    }

    for (const file of listTextFiles(target)) {
        const text = fs.readFileSync(file, 'utf8');
        let updated = text;
        for (const [pattern, replacement] of patterns) updated = updated.replace(pattern, replacement);
        if (updated !== text) fs.writeFileSync(file, updated);
    }

    // Tailwind scans this directory for class names, so it has to follow.
    const cssPath = path.join(target, 'src', 'app.css');
    if (fs.existsSync(cssPath)) {
        fs.writeFileSync(cssPath,
            fs.readFileSync(cssPath, 'utf8').replace('@source "./app"', `@source "./${pkg}"`));
    }

}

/// Config files

function writeProjectConfig(target, answers) {

    const file = path.join(target, 'project.config.sh');
    let text = fs.readFileSync(file, 'utf8');

    const assign = (key, value) => {
        const pattern = new RegExp(`^${key}="[^"]*"`, 'm');
        if (!pattern.test(text)) fail(`project.config.sh has no ${key} to set`);
        text = text.replace(pattern, `${key}="${value}"`);
    };

    assign('APP_SLUG', answers.slug);
    assign('APP_PRODUCT_NAME', answers.name);
    assign('APP_IDENTIFIER', answers.identifier);
    assign('APP_MAIN_CLASS', answers.mainClass);

    fs.writeFileSync(file, text);

}

function writePackageJson(target, answers) {

    const file = path.join(target, 'package.json');
    const pkg = JSON.parse(fs.readFileSync(file, 'utf8'));

    pkg.name = answers.slug;
    pkg.description = answers.description;
    // A fresh project starts at 0.1.0, not at whatever the template was on.
    pkg.version = '0.1.0';
    if (answers.author) pkg.author = answers.author;

    fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + '\n');

    const cargo = path.join(target, 'src-tauri', 'Cargo.toml');
    if (fs.existsSync(cargo)) {
        let text = fs.readFileSync(cargo, 'utf8');
        text = text.replace(/(\[package\][\s\S]*?\nversion\s*=\s*")[^"]*(")/, '$10.1.0$2');
        text = text.replace(/(\[package\][\s\S]*?\ndescription\s*=\s*")[^"]*(")/,
            `$1${answers.description.replace(/"/g, '\\"')}$2`);
        fs.writeFileSync(cargo, text);
    }

    const conf = path.join(target, 'src-tauri', 'tauri.conf.json');
    if (fs.existsSync(conf)) {
        fs.writeFileSync(conf,
            fs.readFileSync(conf, 'utf8').replace(/("version"\s*:\s*")[^"]*(")/, '$10.1.0$2'));
    }

}

/// Git

function setupGit(target, options) {

    run('git', ['init', '-q'], target);

    const url = kitRemoteUrl();
    const sha = run('git', ['rev-parse', 'HEAD'], KIT).trim();

    console.log('  adding the kit as a submodule');
    run('git', ['-c', 'protocol.file.allow=always', 'submodule', 'add', '-q', '--force', url, 'lib/wisdom-kit'], target);

    // Pin to the EXACT revision this kit is on, rather than to whatever its
    // default branch points at today.
    const sub = path.join(target, 'lib', 'wisdom-kit');
    run('git', ['-c', 'protocol.file.allow=always', 'fetch', '-q', 'origin', sha], sub, true);
    run('git', ['checkout', '-q', sha], sub);
    run('git', ['-c', 'protocol.file.allow=always', 'submodule', 'update', '--init', '--recursive', '-q'], sub);
    run('git', ['add', 'lib/wisdom-kit'], target);
    console.log(`    lib/wisdom-kit ${sha.slice(0, 10)}`);

    if (options.commit) {
        run('git', ['add', '-A'], target);
        run('git', ['-c', 'commit.gpgsign=false', 'commit', '-q', '-m', 'Initial commit'], target);
        console.log('  initial commit made');
    }

}

/**
 * Where a fresh clone of the new project should fetch the kit from.
 *
 * The kit's own `origin` when it has one, so the project is shareable. A kit
 * that has never been pushed leaves only its path on this machine, which works
 * here and nowhere else, so say so rather than producing a project that
 * quietly cannot be cloned.
 */
function kitRemoteUrl() {

    const origin = run('git', ['config', '--get', 'remote.origin.url'], KIT, true).trim();
    if (origin) return origin;

    console.log('  note: the kit has no origin remote, so the new project will');
    console.log('        reference it by local path. Push the kit and update');
    console.log('        .gitmodules before sharing the project.');
    return KIT;

}

/// Verification

function scanForResiduals(target, table) {

    const tokens = table.map(e => e.from);
    const pattern = new RegExp(tokens.map(escapeRegExp).join('|'), 'g');
    const findings = [];

    for (const file of listTextFiles(target)) {
        const relative = path.relative(target, file);
        fs.readFileSync(file, 'utf8').split('\n').forEach((line, index) => {
            pattern.lastIndex = 0;
            const match = pattern.exec(line);
            if (match) findings.push({ file: relative, line: index + 1, token: match[0], text: line.trim() });
        });
    }

    return findings;

}

function reportResiduals(findings) {

    if (findings.length === 0) {
        console.log('  residual scan clean');
        return;
    }

    console.log(`\n  ${findings.length} leftover reference(s) to the template:\n`);
    for (const f of findings.slice(0, 30)) {
        console.log(`    ${f.file}:${f.line}  ${f.token}`);
        console.log(`      ${f.text.slice(0, 100)}`);
    }
    if (findings.length > 30) console.log(`    ... and ${findings.length - 30} more`);
    console.log('\n  Fix these by hand, then run: npm run check-config');

}

function runInstall(target, hasKit) {

    if (!hasKit) {
        console.log('  skipping npm install, the kit was not fetched (--no-git)');
        return;
    }
    console.log('  npm install (wires the Haxe libraries through postinstall)');
    run('npm', ['install'], target, false, 'inherit');

}

function runVerification(target) {

    console.log('  npm run check-config');
    run('npm', ['run', 'check-config'], target, false, 'inherit');

    console.log('  npm run build');
    run('npm', ['run', 'build'], target, false, 'inherit');

    for (const file of ['dist/web/index.html', 'dist/web/frontend.js', 'dist/web/frontend.css']) {
        if (!fs.existsSync(path.join(target, file))) fail(`The new project built without producing ${file}`);
    }
    console.log('  build verified');

}

/// Reporting

function describe(target, answers, table) {

    console.log(`\nCreating ${answers.name} in ${target}\n`);
    console.log(`  slug          ${answers.slug}`);
    console.log(`  identifier    ${answers.identifier}`);
    console.log(`  crate         ${answers.slug}  (lib ${answers.libName})`);
    console.log(`  haxe          ${answers.haxePackage}  (main ${answers.mainClass})`);
    if (answers.author) console.log(`  author        ${answers.author}`);
    console.log(`  kit           ${KIT}`);
    console.log('\n  substitutions, applied in one pass, longest source first:');
    for (const { from, to } of table) console.log(`    ${from}  ->  ${to}`);

}

function done(target, answers, options, residuals) {

    console.log(`\n${answers.name} is ready in ${target}\n`);

    const installed = options.git && (options.install || options.verify);

    const next = [];
    if (!options.git) next.push('git init && git submodule add <kit url> lib/wisdom-kit');
    if (!installed) next.push('npm install');
    next.push('npm run dev:web   # in a browser');
    next.push('npm run dev       # as a desktop app');

    console.log('Next:');
    for (const line of next) console.log(`  ${line}`);

    if (residuals.length > 0) {
        console.log(`\nThere are still ${residuals.length} reference(s) to the template; see above.`);
    }

    console.log('');

}

/// Small helpers

function listTextFiles(root) {

    const files = [];
    const skip = new Set(['.git', 'node_modules', '.haxelib', 'dist', 'lib']);

    const walk = dir => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            if (entry.isDirectory()) {
                if (skip.has(entry.name)) continue;
                walk(path.join(dir, entry.name));
                continue;
            }
            if (!entry.isFile()) continue;
            if (BINARY_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) continue;
            files.push(path.join(dir, entry.name));
        }
    };

    walk(root);
    return files;

}

function run(command, args, cwd, allowFailure = false, stdio = 'pipe') {
    // npm is npm.cmd on Windows, which needs a shell or its own script run
    // by Node. See tools.mjs.
    let shell = false;
    if (command === 'npm') {
        const runner = npm();
        command = runner.command;
        args = [...runner.args, ...args];
        shell = runner.shell;
    }
    try {
        return execFileSync(command, args, { cwd, encoding: 'utf8', stdio, shell }) || '';
    }
    catch (error) {
        if (allowFailure) return '';
        const detail = error.stderr ? String(error.stderr).trim() : error.message;
        fail(`${command} ${args.join(' ')}\n  failed in ${cwd}\n  ${detail}`);
    }
}

function slugify(value) {
    return value
        .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
}

function titleCase(value) {
    return value.replace(/[-_]+/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function fail(message) {
    throw new Error(message);
}
