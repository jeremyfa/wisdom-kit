package kit.macros;

/**
 * Bakes package.json's version into the compiled app.
 *
 * package.json is the single source of truth for the version. The
 * sync-version script pushes it into tauri.conf.json and Cargo.toml, and this
 * macro brings it into the Haxe side, so all four can never disagree.
 *
 * Requires the compiler's working directory to be the project root, which is
 * how every npm script invokes it.
 */
class VersionMacro {

    public static macro function get():haxe.macro.Expr {

        #if macro
        final raw = sys.io.File.getContent('package.json');
        final version:String = haxe.Json.parse(raw).version;
        if (version == null || version == '') {
            haxe.macro.Context.error('No "version" in package.json', haxe.macro.Context.currentPos());
        }
        return macro $v{version};
        #else
        return macro '0.0.0';
        #end

    }

}
