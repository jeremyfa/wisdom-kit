# wisdom-kit

Starter kit to create apps with Haxe and Wisdom.

You write your application in Haxe. The kit gives it a window, a theme, a set
of UI primitives, a platform layer that works the same in a browser and on the
desktop, and the whole build and release pipeline. The same code runs as a web
page and as a native app built with Tauri.

Your project keeps this kit as a git submodule under `lib/wisdom-kit`. Your
code, your names and a little Tauri glue live in the project. Everything else
lives in the kit, so a fix here reaches every project you have built on it.

## Create a project

```bash
git clone --recurse-submodules https://github.com/jeremyfa/wisdom-kit.git
node wisdom-kit/scripts/create-app.mjs ../my-app \
    --name "My App" --identifier com.acme.myapp --verify
```

That gives you a working project in `../my-app` with the kit already wired in.
`--verify` builds it once before handing it over, so you know it runs. Pass
`--help` to see the other options.

## Running and building

From inside a project:

```bash
npm run dev          # desktop window, rebuilding as you edit
npm run dev:web      # the same, in a browser at localhost:5173
npm run build        # a one-off build into dist/web
```

`dist/web` is the whole output. It is what a browser loads, and it is what
Tauri embeds in the native app, so there is only ever one thing to test.

The full list:

| command | what it does |
|---|---|
| `npm run setup` | wire the Haxe libraries into a local `.haxelib` |
| `npm run build` | build into `dist/web` (`build:release` minifies) |
| `npm run dev` | build, watch, and open the desktop window |
| `npm run dev:web` | build, watch, and serve `dist/web` |
| `npm run check-config` | check every file agrees on the project's names |
| `npm run sync-config` | copy `project.config.sh`'s names into npm, Cargo and Tauri |
| `npm run sync-local` | use the local checkouts named in `project.local.sh` |
| `npm run sync-version` | copy `package.json`'s version into Cargo and Tauri |
| `npm run generate-icons` | draw the desktop icons from `APP_ICON`, or `resources/AppIcon.png` |
| `npm run export mac` | build distributables (also `linux`, `windows`, `all`) |
| `npm run sign-mac` | notarize and staple the macOS build |

These all run through the kit rather than being spelled out in your
`package.json`, so when the build gains a step, you get it by updating the
submodule. `node lib/wisdom-kit/cli.mjs --help` lists them from inside a
project.

## Working on the kit locally

To work on the kit, or on wisdom, tracker or facile, from their own checkouts
next to the project rather than through the submodules, copy
`project.local.sh.example` to `project.local.sh` (it is gitignored), keep the
lines you need, and run:

```bash
npm run sync-local
```

- `lib/wisdom-kit` becomes a link to `KIT_LOCAL_DIR`, and git still sees the
  submodule. The project's pointer to the kit then follows that checkout: each
  run commits `Update wisdom-kit` when it moved, but only once that commit is
  pushed, so a clone of the project can always fetch it.
- `WISDOM_LOCAL_DIR` and the others point haxelib at those checkouts. The kit's
  own pointers to them are left alone, since a project may not be allowed to
  commit to the kit: `sync-local` reports a checkout that is not on the version
  the kit pins, and whoever maintains the kit updates it there.
- Remove a line, or the whole file, and run it again to go back to the
  submodule, on the commit last recorded.

`npm run build` says when the checkouts moved since the last sync, and the
export scripts refuse to ship a build of checkouts that are not exactly pushed,
recorded commits.

The first time, from a project whose submodule predates `sync-local`, run it
from the checkout instead: `node ../wisdom-kit/cli.mjs sync-local`.

## What is in the kit

```
src/kit/          the Haxe you write against: platform, model, ui, App, Keys, Dialog
kit.hxml          the libraries and flags every project compiles with
kit.css           theme tokens, base styles, scrollbars
kit.config.sh     settings shared by every project
cli.mjs           the entry point your package.json calls into
scripts/          build, project creation, checks, icons, version sync
export-*.sh       the macOS, Linux and Windows distributables
docker/           two Linux builder images
tauri/            the shared desktop host, as a Rust crate
template/         what create-app copies into a new project
web/              the host page and the Lucide icon font
lib/              wisdom, tracker and facile, pinned as submodules
```

## How your code and the kit fit together

Your application lives in `src/app` and can use anything in `kit`. The kit
never reaches back into your code, which is what lets one kit serve many
projects.

To save you importing the same things everywhere, a few values are available
ambiently, anywhere in your code:

| you write | and you get |
|---|---|
| `theme` | the current colours |
| `preferences` | the user's saved settings |
| `chrome` | the state of the frame the kit draws around your app |
| `model` | your own application state |

`chrome` is the one worth a word. It is everything the kit manages on your
behalf around your content: the dialog currently open, whether the settings
popup is open, the short message shown in the status bar, and whether the
window is fullscreen or maximised. Your own state goes in `model`, and the
frame's state lives in `chrome` so your model never has to carry it.

The settings popup is part of the kit, as `kit.ui.SettingsPopup`. It holds the
theme (light, dark or follow the system) and the interface scale, both saved in
`preferences`. The kit opens it on ⌘, (Ctrl+, elsewhere) and closes it on
Escape. A new project mounts it and gives it a button in the title bar, and
that is all it has to do. To add your own settings, put them between its tags:

```haxe
<SettingsPopup>
    <SectionHeader label="Data" />
    <LabeledRow label="Notes" hint="Removes every note on this device">
        <Button label="Clear" variant="danger" onpress=${clearNotes} />
    </LabeledRow>
</SettingsPopup>
```

When the kit needs something only your app can provide, you hand it over at
startup rather than the kit guessing:

```haxe
App.start({ model: new AppModel(), render: () -> ... });
```

`AppModel` is your own, and it extends `kit.model.RootModel` so the kit knows
it will find `preferences` and `chrome` on it. `App.start` takes your model,
your markup, your keyboard shortcuts and an Escape handler. That is the entire
contract between the two sides.

## Reactive state

Your state lives in classes that extend `tracker.Model`. You mark a field, and
anything that reads it during a render re-runs when it changes. You never
subscribe or emit by hand.

```haxe
class AppModel extends RootModel {
    @observe public var count:Int = 0;
}
```

Read `model.count` inside a component's `render()` and that component redraws
whenever `count` changes. That is the whole idea.

The annotations you will use:

| annotation | when to use it |
|---|---|
| `@observe` | reactive state that resets when the app restarts |
| `@serialize` | reactive state that is also saved and restored |
| `@compute` | a value derived from other fields, recomputed on demand |
| `@autorun` | run a side effect whenever the fields it reads change |

Three things surprise people, so they are worth knowing up front.

**Replace arrays, do not push into them.** Tracker notices a change by
comparing the old value with the new one. An array you push into is still the
same array, so nothing happens: no redraw, no save. Give the field a fresh
array instead.

```haxe
model.items = model.items.concat([item]);              // adds one
model.items = [for (i in model.items) if (keep(i)) i]; // removes some
```

If you type the field as `ReadOnlyArray<T>`, the compiler reminds you.

**An `@autorun` that reads and writes the same kind of field can loop.**
Reading a field inside an autorun is what subscribes the autorun to it, so if
the autorun then writes a field it also reads, it wakes itself up forever. When
you hit this, read what you need first, call `Autorun.unobserve()` to stop
subscribing, and only then write. Most autoruns never need it. You will know
when you do, because the app will spin. `kit.model.Theme` uses the pattern if
you want to see it in context.

**Renaming a model class invalidates saved data.** A save records the full
class name of everything in it. If you move `app.model.Preferences` to another
package, an old save still points at the name that no longer exists, and that
field comes back empty on load. The same happens when you add a new sub-model
to an app people already have installed. It does not crash: the load succeeds
and the app falls over later when it reads the missing field, which on the
desktop looks like a blank window. So give your root model a `repair()` that
fills in anything missing, and the kit calls it before the first render:

```haxe
App.start({ model: model, onModelLoaded: () -> model.repair() });
```

One last thing: every `tracker.Model` already has an `id` field that the save
system uses internally, so name your own identifiers something else.

## Building components

Components are small classes with a `render()`. A few conventions keep them
predictable.

Data comes in through `@props` and changes go back out through callbacks, the
way HTML inputs work. Give every prop a default. A primitive like a text field
holds no state of its own. It shows what you pass and tells you when the user
changes it.

```haxe
@props public var label:String = "";
@props public var onChange:(value:String) -> Void = null;
```

Each `render()` returns one root element. A helper method that returns markup
needs to say so with `:VNode`, otherwise Haxe assumes it returns nothing and
the markup silently vanishes.

When a feature only exists on one platform, keep the button and disable it
rather than hiding it. Ask `Platform.can(...)`, disable when the answer is no,
and say why in a tooltip. The markup then looks the same everywhere, which
keeps the virtual DOM stable, and the user sees that the feature exists rather
than wondering where it went.

Watch out for one syntax trap: the markup is a single-quoted Haxe string, so an
apostrophe inside it, even in a comment, ends the string early. The compiler
then complains about something far away. Avoid apostrophes in markup.

## Styling

Styling is Tailwind utility classes. Colours come from the theme tokens
(`bg-t-surface`, `text-t-text-muted`) so they follow the light and dark themes.
A hard-coded colour will be wrong in one of them.

Write class names out in full. Tailwind finds them by scanning your source as
plain text, so a name you build at runtime is invisible to it:

```haxe
class="bg-t-accent"          // found
class=${"bg-t-" + tone}      // never generated
```

Icons take their colour from their parent, so colour the parent, not the icon.
And because the base style turns off text selection (a desktop app should not
let you select its own toolbar), add `select-text` to anything the user should
be able to copy.

## The platform layer

`Platform` is how your code does anything host-specific: opening a file,
reading the clipboard, controlling the window. There are two implementations
behind it, one for Tauri and one for the browser, and only they ever touch
`window.__TAURI__`. Your code calls `Platform` and stays the same everywhere.

Every operation is a callback, error first, and no promise leaks out. If you
add an operation, you add it to both backends, so the compiler will not let you
ship something that quietly does nothing in the browser.

Dialogs are drawn in the app, never with `window.confirm`, which freezes the
page, ignores your theme, and is blocked by some browsers.

## Third party

Bundled into every app built on the kit:

| | licence |
|---|---|
| [Lucide](https://lucide.dev) icons, as a WOFF2 font | ISC, see `web/lucide-font/LICENSE` |
| [wisdom](https://github.com/jeremyfa/wisdom), the virtual DOM and components | MIT |
| [tracker](https://github.com/jeremyfa/tracker), the observable models | MIT |
| [facile](https://github.com/jeremyfa/facile), utilities | MIT |
| [Tauri](https://tauri.app) and its dialog, fs, opener and clipboard plugins | MIT or Apache-2.0 |

Used only while building, so not part of your app's licensing: Haxe, Tailwind
CSS, esbuild, and a [fork of the Tauri CLI](https://github.com/jeremyfa/tauri)
that the Linux AppImage build relies on.

The interface uses whatever font the system provides, so the icon font is the
only one shipped.

## Licence

MIT.
