import std.stdio : writeln, File, write;
import std.file : thisExePath, readText, getcwd;
import std.path;
import std.array;
import std.process;
import std.string;
import std.json;
import std.algorithm.iteration;
import std.range;
import std.typecons;
import asdf.serialization;
import darg;
import std.conv;
import std.regex : replaceFirst, regex;
import mustache;

private struct Options {
    @Option("help", "h")
    @Help("Prints this help.")
    OptionFlag help;

    @Option("preload")
    @Help("Insert loaded lua scripts inline to support interpreters without the load function.")
    OptionFlag preload;

    @Option("interpreter", "i")
    @Help("Path to the lua executable to use.")
    string interpreter;

    @Argument("entrypoint", Multiplicity.optional)
    string entrypoint;
}
// Generate the usage and help string at compile time.
private immutable help = helpString!Options;
private immutable usage = usageString!Options("%s");
private immutable intercept_script = import("intercept.lua");
struct Literal {
    string value;
}
auto toLua(T, U)(T[U] array) {
    return '{' ~ array.byKeyValue.map!(pair
    => `[` ~ toLua(pair.key) ~ `]=` ~ toLua(pair.value)).join(`,`) ~ `}`;
}
auto toLua(string s) {
    return "%s".format([s])[1 .. $ - 1];
}
auto toLua(Literal l) {
    return l.value;
}
auto toLua(bool b) {
    return "%s".format(b);
}
auto toLua(T)(T[] a) {
    return "{n=" ~ a.length.to!string ~ ',' ~ a.map!toLua.join(`,`) ~ '}';
}
auto platform(string s) {
    version(Windows)
      return replaceFirst(replace("C:\\oho\\nein\\wat", "\\", "/"), regex(r"([A-Z]):/"), "/$1/");
    return s;
}
int main(string[] args) {
    alias MustacheEngine!string Mustache;
    Mustache mus;
    immutable usage = usage.format(thisExePath.baseName);
    Options options;

    try options = parseArgs!Options(args[1 .. $]);
	  catch (ArgParseError issue) {
        writeln(usage);
        write(issue.msg);
        return 1;
    } catch (ArgParseHelp _) {
        writeln(usage);
        write(help);
        return 0;
    }
    if (!options.entrypoint) options.entrypoint = "init.lua";
    if (!options.interpreter) options.interpreter = "lua";
    string output;
    foreach (ref line; pipeProcess([
        options.interpreter,
        "-e", "arg = {[0]=" ~ toLua(options.entrypoint) ~ "}",
        "-e", intercept_script
      ], Redirect.stderrToStdout | Redirect.stdout)
      .stdout
      .byLineCopy) {
          writeln(output);
          output = line;
      }
    struct Results {
        // bool hasLoad;
        string[] loadfile;
        string[] ioopen;
    }
    immutable results = output.deserialize!Results;

    auto files = results.ioopen.map!(path => tuple(path.absolutePath.platform, path.readText));
    auto scripts = results.loadfile.map!(path => tuple(path.absolutePath.platform, path.readText));
    // writeln(toLua(scripts));
    // Literal(`function(_ENV,loadfile,io) return function(...)` ~ path.readText ~ `end end`)
    auto context = new mus.Context;
    context["cwd"] = toLua(getcwd);
    context["scripts"] = false;
    context["files"] = toLua(chain(files, scripts).map!(tup => tuple(tup[0], [tup[1]])).assocArray);
    context["entrypoint"] = toLua(options.entrypoint);
    version(Windows) context["normalizeplatform"] = `
      P = gsub(gsub(P, "\\", "/"), "^(%a):/", "/%1/")
    `;
    if (options.preload) context["scripts"] = scripts
      .map!(tup =>
        tuple(tup[0],
          Literal(`function(_ENV,loadfile,io) return function(...)`
                ~ tup[1]
                ~ `end end`))).assocArray.toLua;
    File(options.entrypoint.withExtension(".bundle.lua"), "w").write(mus.renderString(import("scoped_template.lua"), context));
    
    return 0;
}