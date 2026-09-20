// Implicitly imported into every module under kit.*
//
// Guarded with `#if !macro` because js.* does not exist in macro context, and
// these imports pull browser types in transitively.
//
// This file must never import anything from an application package. The kit
// knows nothing about what is built on it, and scripts/check-kit.mjs enforces
// that.

#if !macro
import js.Browser.*;
import kit.App;
import kit.Dialog;
import kit.Keys;
import kit.Shortcuts.*;
import kit.platform.Platform;
import kit.platform.Capability;
import kit.ui.*;
#end
