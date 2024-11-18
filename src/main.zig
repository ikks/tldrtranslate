const std = @import("std");
const tldr_base = @import("tldr-base.zig");
const tldr = @import("tldr.zig");
const lang_es = @import("lang_es.zig");
const l_es = lang_es.l_es;
const processFile = tldr.processFile;

const LangReplacement = tldr_base.LangReplacement;
const l_default = tldr_base.l_default;

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const print = std.debug.print;
const logerr = std.log.err;

// Improve memory management, reuse the allocator in the invocation of what?
// Add cli options to show supported languges
// Show help on how to use this with languages

/// The language is established by:
/// * tries to use the LANG envvar in case it's not english
/// * if the TLDR_LANG is set takes that value
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
    try replacements.put("fr", l_default);
    try replacements.put("ar", l_default);
    try replacements.put("bn", l_default);
    try replacements.put("ar", l_default);
    try replacements.put("ca", l_default);
    try replacements.put("cs", l_default);
    try replacements.put("da", l_default);
    try replacements.put("de", l_default);
    try replacements.put("fa", l_default);
    try replacements.put("fi", l_default);
    try replacements.put("hi", l_default);
    try replacements.put("id", l_default);
    try replacements.put("it", l_default);
    try replacements.put("ja", l_default);
    try replacements.put("ko", l_default);
    try replacements.put("pl", l_default);
    try replacements.put("pt_BR", l_default);
    try replacements.put("pt_PT", l_default);
    try replacements.put("ro", l_default);
    try replacements.put("ru", l_default);
    try replacements.put("sv", l_default);
    try replacements.put("th", l_default);
    try replacements.put("tr", l_default);
    try replacements.put("uk", l_default);
    try replacements.put("zh", l_default);
    try replacements.put("zh_TW", l_default);

    if (!replacements.contains(language)) {
        logerr("We do not support language {s} yet.", .{language});
        return 1;
    }

    const lang_replacement = replacements.get(language).?;
    processFile(allocator, args[1], lang_replacement, language) catch |err| {
        if (err == std.posix.OpenError.FileNotFound) {
            logerr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md\nCulprit was {s}", .{args[1]});
            return err; // Return to signify the end
        } else {
            return err; // Propagate any other errors up the call stack
        }
    };

    return 0;
}
