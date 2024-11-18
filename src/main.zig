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

// Improve memory management, reuse the allocator in the invocation of what?
// Add cli options to show supported languges
// Show help on how to use this with languages

/// The language is found following these rules:
/// * tries to use the LANG envvar in case it's not english
/// * if the TLDR_LANG is set, takes that value
/// * else defaults to es
/// It's able to manage pt and zh correctly
fn managelang(allocator: Allocator) ![]u8 {
    var language: []u8 = try allocator.alloc(u8, 8);
    const tldr_lang = std.process.getEnvVarOwned(allocator, "TLDR_LANG") catch |err| {
        if (err == std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            const other_value = try std.process.getEnvVarOwned(allocator, "LANG");
            defer allocator.free(other_value);
            if (!std.mem.eql(u8, other_value[0..2], "en")) {
                if (std.mem.eql(u8, other_value[0..2], "pt") or std.mem.eql(u8, other_value[0..2], "zh")) {
                    std.mem.copyForwards(u8, language, other_value[0..5]);
                } else {
                    defer allocator.free(language);
                    return allocator.dupe(u8, other_value[0..2]);
                }
                return language;
            } else {
                std.mem.copyForwards(u8, language, "es");
                return language;
            }
        } else {
            return err;
        }
    };
    var max_size: usize = 5;
    if (tldr_lang.len < 5) {
        max_size = tldr_lang.len;
    }
    std.mem.copyForwards(u8, language[0..max_size], tldr_lang[0..max_size]);
    language[max_size] = 0;
    defer allocator.free(tldr_lang);
    defer allocator.free(language);
    return allocator.dupe(u8, tldr_lang[0..max_size]);
}

pub fn show_supported_langs(writer: Writer) !void {
    try writer.print("We do support atm:\n", .{});
    for (supported_langs) |lang| {
        try writer.print("  * {s}\n", .{lang});
    }
    try writer.print("  * {s}\n", .{"es"});
}

pub fn main() !u8 {
    var language: []u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) {
        logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
        return 1;
    }

    language = try managelang(allocator);
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
