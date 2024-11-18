const Allocator = @import("std").mem.Allocator;
const Mdb_Err = @import("lmdb-zig").Mdb_Err;

pub const original_language = "en";
pub const CombinedError = Mdb_Err || error{ OutOfMemory, AllocationFailed };

pub const ReplaceAndSize = struct {
    replacements: usize,
    size: usize,
};

pub const Replacement = struct {
    original: []const u8,
    replacement: []const u8,
};

pub const no_replacements = [_]Replacement{};

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
    "pl",
    "pt_BR",
    "pt_PT",
    "ro",
    "ru",
    "sv",
    "th",
    "uk",
    "zh",
    "zh_TW",
};
