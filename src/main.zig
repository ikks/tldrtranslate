const std = @import("std");
const tldr_base = @import("tldr-base.zig");
const tldr = @import("tldr.zig");
const lang_es = @import("lang_es.zig");
const clap = @import("clap");

// Importing Language replacements
const l_es = lang_es.l_es; // Spanish replacements import

const processFile = tldr.processFile;

const LangReplacement = tldr_base.LangReplacement;
const l_default = tldr_base.l_default;
const supported_langs = tldr_base.supported_default_languages;

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const print = std.debug.print;
const logErr = tldr_base.logErr;
const Writer = std.fs.File.Writer;

const global_config = &tldr_base.global_config;

/// Set replacements for languages
fn lang_with_replacements(replacements: anytype) !void {

    // Add your language replacements below this line, better alphabetically

    try replacements.put("es", l_es); // Spanish replacements usage
}

const help_args =
    \\  -h, --help                   Display this help and exit
    \\  -L, --languages              Show the list of supported languages
    \\  -y, --dryrun                 Outputs to stdout instead of writing the file
    \\  -l, --lang <str>             Target translation language
    \\  -p, --port <usize>           Port of Argos Translate API, defaults to 8000
    \\  -u, --url <str>              URL of the Argos Translate API, defaults to localhost
    \\  <str> pages/common/sample.md Path to a file to be translated
;

// Improve memory management, reuse the allocator in the invocation of processFile
// TBD Add sample file and explanation on how to add another language

/// The language is selected following these rules:
/// * tries to use the LANG envvar in case it's not english
/// * if the TLDR_LANG is set, takes that value
/// * else defaults to es
/// It's able to manage pt and zh correctly
fn setupLanguage(allocator: Allocator) ![]u8 {
    if (std.process.getEnvVarOwned(allocator, "TLDR_LANG")) |value| {
        defer allocator.free(value);
        return allocator.dupe(u8, value);
    } else |err| {
        if (err == std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            const env_lang = try std.process.getEnvVarOwned(allocator, "LANG");
            defer allocator.free(env_lang);
            if (!std.mem.eql(u8, env_lang[0..2], "en")) {
                if (std.mem.eql(u8, env_lang[0..2], "pt") or std.mem.eql(u8, env_lang[0..5], "zh_TW")) {
                    return allocator.dupe(u8, env_lang[0..5]);
                } else {
                    return allocator.dupe(u8, env_lang[0..2]);
                }
            } else {
                return allocator.dupe(u8, "es");
            }
        } else {
            return err;
        }
    }
}

fn setupTranslationApi(allocator: Allocator, host: []const u8, port: usize) !void {
    var tldr_api_port: []const u8 = undefined;
    if (port == 0) {
        if (std.process.getEnvVarOwned(allocator, "TLDR_ARGOS_API_PORT")) |value| {
            tldr_api_port = value;
        } else |err| {
            if (err != std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
                return err;
            }
            tldr_api_port = "8000";
        }
    } else {
        tldr_api_port = try std.fmt.allocPrint(allocator, "{}", .{port});
    }
    var tldr_api_urlbase: []const u8 = undefined;
    if (host.len == 0) {
        if (std.process.getEnvVarOwned(allocator, "TLDR_ARGOS_API_URLBASE")) |value| {
            tldr_api_urlbase = value;
        } else |err| {
            if (err != std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
                return err;
            }
            tldr_api_urlbase = "localhost";
        }
    } else {
        tldr_api_urlbase = host[0..];
    }
    const api = try std.fmt.allocPrint(allocator, "http://{s}:{s}/translate", .{ tldr_api_urlbase, tldr_api_port });
    global_config.translation_api = api;
    if (port != 0)
        allocator.free(tldr_api_port);
}

pub fn showSupportedLangs(writer: Writer) !void {
    try writer.print("\nSupported languages:\n", .{});
    for (supported_langs) |lang| {
        try writer.print("  * {s}\n", .{lang});
    }
    try writer.print("  * {s}\n", .{"es"});
}

pub fn showEnvVarsAndDefaults(writer: Writer) !void {
    try writer.print("\nYou can set the following ENV_VARS to change the default configurations:\n{s}\n{s}\n{s}\n\n", .{
        "  TLDR_LANG: defaults to es (spanish)",
        "  TLDR_ARGOS_API_URLBASE: defaults to localhost",
        "  TLDR_ARGOS_API_PORT: Defaults to 8000",
    });
}

pub fn usage(progname: []const u8, writer: Writer) !void {
    try writer.print("\n{s} helps you translate tldr pages.\nVisit https://tldr.sh/ to learn more about the project\n\n{s}\n\n{s}\n\n", .{
        progname,
        help_args,
        "The translated file will go to the proper place, pages.es/common/sample.md.",
    });
}

pub fn main() !u8 {
    var language: []u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const params = comptime clap.parseParamsComptime(help_args);
    var diag = clap.Diagnostic{};
    var dryrun: bool = false;

    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try usage(args[0], std.io.getStdOut().writer());
        try showEnvVarsAndDefaults(std.io.getStdOut().writer());
        return 0;
    }
    if (res.args.dryrun != 0) {
        dryrun = true;
    }
    if (res.args.languages != 0) {
        try std.io.getStdOut().writer().print("\n{s}: Starts a tldr translation for you to review\n", .{args[0]});
        try showSupportedLangs(std.io.getStdOut().writer());
        return 0;
    }

    if (res.positionals.len != 1) {
        logErr("Make sure the path includes the tldr root, target and pagename: i.e.\n\n   {s} pages/common/tar.md", .{args[0]});
        try usage(args[0], std.io.getStdOut().writer());
        try showEnvVarsAndDefaults(std.io.getStdOut().writer());
        return 1;
    }

    if (res.args.lang) |s| {
        language = try allocator.dupe(u8, s);
        errdefer allocator.free(language);
    } else {
        language = try setupLanguage(allocator);
        errdefer allocator.free(language);
    }

    var port: usize = 0;
    if (res.args.port) |n| {
        port = n;
    }

    var host: []const u8 = "";

    if (res.args.url) |s| {
        host = s[0..];
    }
    try setupTranslationApi(allocator, host, port);
    errdefer allocator.free(global_config.translation_api);

    var replacements = std.StringHashMap(LangReplacement).init(
        allocator,
    );
    defer replacements.deinit();

    for (supported_langs) |lang| {
        try replacements.put(lang[0..], l_default);
    }
    try lang_with_replacements(&replacements);

    if (!replacements.contains(language)) {
        logErr("We do not support language `{s}` yet.", .{language});
        try showSupportedLangs(std.io.getStdErr().writer());
        return 1;
    }

    const lang_replacement = replacements.get(language).?;
    processFile(allocator, res.positionals[0], lang_replacement, language, dryrun) catch |err| {
        if (err == std.posix.OpenError.FileNotFound) {
            logErr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md\nCulprit was {s}", .{args[1]});
        }
        return err;
    };

    return 0;
}
