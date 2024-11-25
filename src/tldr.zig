const std = @import("std");
const tldr_base = @import("tldr-base.zig");
const lang_es = @import("lang_es.zig");
const escapeJsonString = @import("extern.zig").escapeJsonString;

const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Child = std.process.Child;
const logErr = tldr_base.logErr;
const fs = std.fs;
const http = std.http;

const Replacement = tldr_base.Replacement;
const ReplaceAndSize = tldr_base.ReplaceAndSize;
const LangReplacement = tldr_base.LangReplacement;
const identityFn = tldr_base.identityFn;
const PostProcess = tldr_base.PostProcess;
const conjugateToThird = lang_es.conjugateToThird;
const original_language = tldr_base.original_language;
const replaceMany = tldr_base.replaceMany;

const translation_api = &tldr_base.global_config.translation_api;

pub const ArgosApiError = error{LangNotFound};

/// Translates a TLDR file to the specified language using the replacements for the language
/// Writes the result to the corresponding file in the TLDR tree hierarchy if not dry run.
pub fn processFile(
    allocator: Allocator,
    /// Source file
    filename: []const u8,
    /// The pairs of replacements for a given language
    replacements: LangReplacement,
    /// The language to translate to
    language: []const u8,
    /// if true does not write the file, just shown in stdout
    dryrun: bool,
) !void {
    const file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    const ipages = std.mem.indexOf(u8, filename, "pages") orelse {
        logErr("Make sure the path includes the tldr root, target and pagename: pages/common/tar.md", .{});
        return;
    };
    const filename_language = try std.fmt.allocPrint(allocator, "{s}.{s}{s}", .{ filename[0 .. ipages + 5], language, filename[ipages + 5 ..] });
    defer allocator.free(filename_language);
    var file_out: fs.File = undefined;
    if (dryrun) {
        file_out = std.io.getStdOut();
    } else {
        file_out = fs.cwd().createFile(filename_language, .{}) catch |err| {
            logErr("Make sure the target path exists {s}\n{}", .{ filename_language, err });
            return;
        };
        errdefer file.close();
    }
    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = ArrayList(u8).init(allocator);
    defer line.deinit();

    const writer = line.writer();
    var line_no: usize = 0;
    var buf = std.io.bufferedWriter(file_out.writer());
    var buf_w = buf.writer();

    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        // Clear the line so we can reuse it.
        defer line.clearRetainingCapacity();
        line_no += 1;
        if (line.items.len < 3) {
            try buf_w.print("{s}\n", .{line.items});
            continue;
        }
        switch (line.items[0]) {
            '>' => {
                try processSummary(allocator, line.items, replacements.summary_replacement, language, replacements.fixPostTranslation, buf_w);
            },
            '-' => {
                try processDescription(allocator, line.items, language, replacements.fixPostTranslation, buf_w);
            },
            '`' => {
                try processExecution(line.items, replacements.process_replacement, buf_w);
            },
            else => {
                try buf_w.print("{s}\n", .{line.items});
            },
        }
    } else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                line_no += 1;
            }
        },
        else => return err, // Propagate error
    }
    try buf.flush();
    if (!dryrun) {
        file_out.close();
    }
}

/// The summary starts with `> ` the contents are translated and there are common replacements
/// for the common ones, as More information. The result is written to the writer and includes
/// a newline at the end
fn processSummary(
    /// The allocations are self contained in this function
    allocator: Allocator,
    /// We receive the line complete, including the >
    source_string: []const u8,
    /// Pair of replacements allowed for Summary
    summary_replacements: []const Replacement,
    /// Language to translate to
    language: []const u8,
    /// Post process function to make adjustments to the translation
    postFn: PostProcess,
    /// a handle to write the translation to
    writer: anytype,
) !void {
    var buffer: [1024]u8 = undefined;
    const result: ReplaceAndSize = replaceMany(source_string[0..], summary_replacements, buffer[0..]);
    if (result.replacements > 0) {
        try writer.print("{s}", .{buffer[0..result.size]});
        if (buffer[result.size - 1] != '\n') {
            _ = try writer.write("\n");
        }
    } else {
        try translateLine(allocator, source_string, language, postFn, writer);
    }
}

/// The execution starts with  ```, no translation is made, just the replacements are applied
/// the result is written to `writer` with a newline at the end.
fn processExecution(
    /// The line is received complete with the special characters and
    source_string: []const u8,
    /// Pairs of possible replacements to be used
    replacements: []const Replacement,
    /// a handle to write the sentence with the replacements applied
    writer: anytype,
) !void {
    var buffer: [1024]u8 = undefined;
    const result = replaceMany(source_string, replacements, buffer[0..]);
    try writer.print("{s}", .{buffer[0..result.size]});
    if (buffer[result.size - 1] != '\n') {
        _ = try writer.write("\n");
    }
}

/// The description starts with `- `.  Translates `source_string` to `language` and postprocess the result with `postFn`, the
/// result is written to writer with a newline at the end.
const processDescription = translateLine;

/// translates `source_string` to `language` and postprocess the result with `postFn`, the
/// result is written to writer with a newline at the end
fn translateLine(
    /// The allocations are self contained in this function
    allocator: Allocator,
    /// string to be translated
    source_string: []const u8,
    /// target translation language
    language: []const u8,
    /// A function to apply to the translated sentence
    postFn: PostProcess,
    /// A handle to write the result of the translation and post process function
    writer: anytype,
) !void {
    var sentence: []u8 = undefined;
    sentence = try translateLineApi(allocator, source_string[2..], language);
    defer allocator.free(sentence);

    const post_processed_line = postFn(allocator, sentence) catch |err| {
        return err;
    };
    defer allocator.free(post_processed_line);

    const last_char_idx = post_processed_line.len - 1;
    if (post_processed_line[last_char_idx] == '\n') {
        try writer.print("{s}{s}", .{ source_string[0..2], post_processed_line });
    } else {
        try writer.print("{s}{s}\n", .{ source_string[0..2], post_processed_line });
    }
}

/// Invokes API Argos Translator with the `source_string` to be translated to `language`
/// and returns the translation as a string.  Allocates memory that you must release. Expects the
/// original language to be `en`. If it's not able to reach the API, offers instructions
/// and propagates the error to finish the program.
fn translateLineApi(
    /// Allocator to return a new string with the translation
    allocator: Allocator,
    /// text to be translated
    source_string: []const u8,
    /// Target language
    language: []const u8,
) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();
    const uri = try std.Uri.parse(translation_api.*);
    const escaped_for_json = try escapeJsonString(source_string, allocator);
    defer allocator.free(escaped_for_json);
    const payload = try std.fmt.allocPrint(allocator, "{{\"text\": \"{s}\", \"from_lang\": \"{s}\", \"to_lang\": \"{s}\"}}", .{
        escaped_for_json,
        original_language,
        language[0..2],
    });
    defer allocator.free(payload);

    var buf: [1024]u8 = undefined;
    var req = client.open(.POST, uri, .{ .server_header_buffer = &buf }) catch |err| {
        if (err == std.posix.ConnectError.ConnectionRefused) {
            logErr("{s}{s}.\n {s}{s} {s}", .{
                "Make sure you have an API Argos Translate Running in ",
                translation_api.*,
                "Follow instructions from ",
                "to install and make it run in another window. It takes a few seconds to be available.",
                "https://github.com/Jaro-c/Argos-API",
            });
        }
        return err;
    };
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = payload.len };
    try req.send();
    var wtr = req.writer();
    try wtr.writeAll(payload);
    try req.finish();
    try req.wait();

    var rdr = req.reader();
    const body = try rdr.readAllAlloc(allocator, 1024 * 1024 * 4);
    defer allocator.free(body);

    if (req.response.status != .ok) {
        logErr("Make sure you have language `{s}` installed, if your API has it installed, check the next.\n Status:{d}\nPayload:{s}\nResponse:{s}", .{
            language,
            req.response.status,
            payload,
            body,
        });
        return ArgosApiError.LangNotFound;
    }

    const Translated_text = struct { translated_text: []u8 };
    const parsed = try std.json.parseFromSlice(Translated_text, allocator, body, .{});
    defer parsed.deinit();

    const json_res = parsed.value;

    return allocator.dupe(u8, json_res.translated_text);
}
