const std = @import("std");
const tldr_base = @import("tldr-base.zig");
const tldr = @import("tldr.zig");
const lang_es = @import("lang_es.zig");
const l_es = lang_es.l_es;
const processFile = tldr.processFile;

const LangReplacement = tldr_base.LangReplacement;
const l_default = tldr_base.l_default;
const supported_langs = tldr_base.supported_default_languages;

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const print = std.debug.print;
const logerr = std.log.err;
const Writer = std.fs.File.Writer;

const global_config = &tldr_base.global_config;
const getSysTmpDir = @import("extern.zig").getSysTmpDir;

// Improve memory management, reuse the allocator in the invocation of processFile
// Add cli options to show supported languges, set APIPORT APIURL DBPATH
// Show help on how to use this with languages
// TBD TLDR_ES_DB_PATH
// TBD TLDR_ARGOS_API_PORT
// TBD TLDR_ARGOS_API_URLBASE
// TBD Add sample file and explanation on how to add another language

/// The language is found following these rules:
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

fn setupTranslationApi(allocator: Allocator) !void {
    var tldr_api_port: []const u8 = undefined;
    if (std.process.getEnvVarOwned(allocator, "TLDR_ARGOS_API_PORT")) |value| {
        tldr_api_port = value;
    } else |err| {
        if (err != std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            return err;
        }
        tldr_api_port = "8000";
    }
    var tldr_api_urlbase: []const u8 = undefined;
    if (std.process.getEnvVarOwned(allocator, "TLDR_ARGOS_API_URLBASE")) |value| {
        tldr_api_urlbase = value;
    } else |err| {
        if (err != std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            return err;
        }
        tldr_api_urlbase = "localhost";
    }
    const api = try std.fmt.allocPrint(allocator, "http://{s}:{s}/translate", .{ tldr_api_urlbase, tldr_api_port });
    global_config.translation_api = api;
}

fn setupSpanishConjugationDbPath(allocator: Allocator) !void {
    var local_spanish_database: []const u8 = undefined;
    if (std.process.getEnvVarOwned(allocator, "TLDR_ES_DB_PATH")) |value| {
        local_spanish_database = value;
    } else |err| {
        if (err != std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            return err;
        }
        local_spanish_database = try getSysTmpDir(allocator);
    }
    const dbpath = try std.fs.path.join(allocator, &[_][]const u8{ local_spanish_database, "tldr_translation.db" });
    global_config.database_spanish_conjugation_fix = dbpath;
}

pub fn show_supported_langs(writer: Writer) !void {
    try writer.print("We do support atm:\n", .{});
    for (supported_langs) |lang| {
        try writer.print("  * {s}\n", .{lang});
    }
    try writer.print("  * {s}\n", .{"es"});
}

pub fn show_env_vars_and_defaults(allocator: Allocator, writer: Writer) !void {
    try writer.print("\nYou can set the following ENV_VARS to change the default configurations:\n{s}\n{s}\n{s}\n{s}{s}\n\n", .{
        "  TLDR_LANG: defaults to spanish",
        "  TLDR_ARGOS_API_URLBASE: defaults to localhost",
        "  TLDR_ARGOS_API_PORT: Defaults to 8000",
        "  TLDR_ES_DB_PATH: Defaults to ",
        try std.fs.path.join(allocator, &[_][]const u8{ try getSysTmpDir(allocator), "tldr_translation.db" }),
    });
}

pub fn show_usage(progname: []const u8, writer: Writer) !void {
    try writer.print("\n{s} is here to help you translate tldr pages. Visit https://tldr.sh/ to learn more about the project\n{s}\n{s}\n{s}\n", .{
        progname,
        "\nReceives as parameter the tldr page to be translated, i.e. pages/common/tar.md",
        "\nIt will put the translation to the language you are translating to.  Set your `TLDR_LANG` to your needes, \nit will try your LOCALE first, if it's not english you would be ok, if there is no possible \nconfiguration, it will translate to es (Spanish).\n",
        "The translated file will go to pages.es/common/tar.md as the example, change accordingly.",
    });
}

pub fn main() !u8 {
    var language: []u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) {
        logerr("Make sure the path includes the tldr root, target and pagename: i.e.\n\n   {s} pages/common/tar.md", .{args[0]});
        try show_usage(args[0], std.io.getStdOut().writer());
        try show_env_vars_and_defaults(allocator, std.io.getStdOut().writer());
        return 1;
    }

    try setupTranslationApi(allocator);
    defer allocator.free(global_config.translation_api);
    try setupSpanishConjugationDbPath(allocator);
    defer allocator.free(global_config.database_spanish_conjugation_fix);
    language = try setupLanguage(allocator);
    defer allocator.free(language);

    var replacements = std.StringHashMap(LangReplacement).init(
        allocator,
    );
    defer replacements.deinit();
    try replacements.put("es", l_es);
    for (supported_langs) |lang| {
        try replacements.put(lang[0..], l_default);
    }

    if (!replacements.contains(language)) {
        logerr("We do not support language `{s}` yet.", .{language});
        try show_supported_langs(std.io.getStdErr().writer());
        return 1;
    }

    const lang_replacement = replacements.get(language).?;
    processFile(allocator, args[1], lang_replacement, language) catch |err| {
        if (err == std.posix.OpenError.FileNotFound) {
            logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md\nCulprit was {s}", .{args[1]});
        }
        return err;
    };

    return 0;
}
