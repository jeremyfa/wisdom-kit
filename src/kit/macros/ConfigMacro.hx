package kit.macros;

/**
 * Reads a value from project.config.sh into the compiled app.
 *
 * project.config.sh is regex-parsable by design (`KEY="value"` lines only),
 * and this reads it with the same pattern as scripts/config.mjs and the shell
 * scripts, so all of them agree on what it says.
 *
 * The file is registered as a dependency of the calling module, so changing
 * it recompiles instead of keeping a stale value.
 *
 * Requires the compiler's working directory to be the project root, which is
 * how every npm script invokes it.
 */
class ConfigMacro {

    public static macro function get(key:String, fallback:String):haxe.macro.Expr {
        #if macro
        final file = 'project.config.sh';
        var value:String = null;
        if (sys.FileSystem.exists(file)) {
            haxe.macro.Context.registerModuleDependency(haxe.macro.Context.getLocalModule(), file);
            final pattern = new EReg('^' + key + '="(.*)"\\s*$', '');
            for (line in sys.io.File.getContent(file).split('\n')) {
                if (pattern.match(line)) value = pattern.matched(1);
            }
        }
        return macro $v{value != null && value != '' ? value : fallback};
        #else
        return macro $v{fallback};
        #end
    }

}
