const std = @import("std");
const LmdbError = @import("lmdb_sup.zig").LmdbError;

const Allocator = @import("std").mem.Allocator;

pub var global_config = GlobalConfiguration{};
pub const original_language = "en";
pub const CombinedError = LmdbError || error{ OutOfMemory, AllocationFailed };

pub const GlobalConfiguration = struct {
    translation_api: []const u8 = &.{},
    database_spanish_conjugation_fix: []const u8 = &.{},
    output_with_colors: bool = true,
};

pub const ReplaceAndSize = struct {
    replacements: usize,
    size: usize,
};

pub const Replacement = struct {
    original: []const u8,
    replacement: []const u8,
};

pub const automated_translation_warning = "Please review your work prior making a pull request to TLDR. Let's have translations with good quality for your language.";

pub const no_replacements = [_]Replacement{};

/// function signature applied after a translation depending on the language
pub const PostProcess = *const fn (allocator: Allocator, line: []const u8) CombinedError![]const u8;

pub fn identityFn(allocator: Allocator, line: []const u8) CombinedError![]const u8 {
    return allocator.dupe(u8, line);
}

pub const LangReplacement = struct {
    process_replacement: []const Replacement,
    summary_replacement: []const Replacement,
    fixPostTranslation: PostProcess = &identityFn,
};

pub const l_default: LangReplacement = .{ .summary_replacement = no_replacements[0..], .process_replacement = no_replacements[0..] };

pub const supported_default_languages = [_][]const u8{
    "fr",
    "ar",
    "bn",
    "ar",
    "ca",
    "cs",
    "da",
    "de",
    "fa",
    "fi",
    "hi",
    "id",
    "it",
    "ja",
    "ko",
    "nl",
    "pl",
    "pt_BR",
    "pt_PT",
    "ro",
    "ru",
    "sv",
    "th",
    "tr",
    "uk",
    "zh",
    "zh_TW",
};

pub fn logErr(
    comptime format: []const u8,
    args: anytype,
) void {
    std.log.err("\u{001b}[91;5;31m*\u{001b}[m: " ++ format, args);
}

pub fn replaceMany(original: []const u8, replacements: []const Replacement, output: []u8) ReplaceAndSize {
    var found: usize = 0;
    var total: usize = 0;
    var len = original.len;
    var buffer2: [2000]u8 = undefined;

    if (replacements.len == 0) {
        std.mem.copyForwards(u8, output, original);
        return ReplaceAndSize{ .replacements = 0, .size = original.len };
    }
    @memcpy(buffer2[0..original.len], original);
    for (replacements) |replacepair| {
        found = std.mem.replace(u8, buffer2[0..len], replacepair.original, replacepair.replacement, output);
        if (found == 0) {
            continue;
        }
        total += found;
        if (replacepair.replacement.len > replacepair.original.len) {
            len = len + found * (replacepair.replacement.len - replacepair.original.len);
        } else {
            len = len - found * (replacepair.original.len - replacepair.replacement.len);
        }
        @memcpy(buffer2[0..len], output[0..len]);
    }
    return ReplaceAndSize{ .replacements = total, .size = len };
}

test "replaceMany" {
    const process_replacements = [_]Replacement{
        Replacement{ .original = "path/to/file_or_directory", .replacement = "ruta/al/archivo_o_directorio" },
        Replacement{ .original = "path/to/target/directory", .replacement = "ruta/al/directorio/destino" },
        Replacement{ .original = "path/to/directory", .replacement = "ruta/al/directorio" },
        Replacement{ .original = "path/to/file", .replacement = "ruta/al/archivo" },
        Replacement{ .original = "path/to/binary", .replacement = "ruta/al/binario" },
        Replacement{ .original = "{{file}}", .replacement = "{{archivo}}" },
        Replacement{ .original = "{{pattern}}", .replacement = "{{patrón}}" },
        Replacement{ .original = "{{directory}}", .replacement = "{{directorio}}" },
    };

    const initial_string = "path/to/file_or_directory_1 path/to/file_or_directory_2";
    const expected_result = "ruta/al/archivo_o_directorio_1 ruta/al/archivo_o_directorio_2";
    const allocator = std.testing.allocator;
    const output = try allocator.alloc(u8, 200);
    defer allocator.free(output);
    const result1 = replaceMany(initial_string, &process_replacements, output);
    try std.testing.expectEqualStrings(expected_result, output[0..result1.size]);
    try std.testing.expectEqual(2, result1.replacements);
    try std.testing.expectEqual(expected_result.len, result1.size);

    const mixed_replacement = "{{file}} {{directory}} {{other_thing}} {{pattern}}";
    const expected = "{{archivo}} {{directorio}} {{other_thing}} {{patrón}}";
    const resultm = replaceMany(mixed_replacement, &process_replacements, output);
    try std.testing.expectEqualStrings(expected, output[0..resultm.size]);
    try std.testing.expectEqual(3, resultm.replacements);
    try std.testing.expectEqual(expected.len, resultm.size);

    const not_replaced = "este texto no se reemplaza";
    const result2 = replaceMany(not_replaced, &process_replacements, output);
    try std.testing.expectEqualStrings(not_replaced, output[0..result2.size]);
    try std.testing.expectEqual(0, result2.replacements);
    try std.testing.expectEqual(not_replaced.len, result2.size);

    const empty_replacement = "";
    const result3 = replaceMany(empty_replacement, &process_replacements, output);
    try std.testing.expectEqualStrings(empty_replacement, output[0..result3.size]);
    try std.testing.expectEqual(0, result3.replacements);
    try std.testing.expectEqual(empty_replacement.len, result3.size);
}
