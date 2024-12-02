const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

/// Escapes an string to be sent to an API that receives json
/// New memory must be freed by the caller
pub fn escapeJsonString(input: []const u8, allocator: Allocator) ![]u8 {
    var result = try allocator.alloc(u8, input.len * 2);
    var index: usize = 0;
    for (input) |c| {
        switch (c) {
            '\"' => {
                result[index] = '\\';
                result[index + 1] = c;
                index += 2;
            },
            '\\' => {
                result[index] = '\\';
                result[index + 1] = c;
                index += 2;
            },
            '\n' => {
                result[index] = '\\';
                result[index + 1] = 'n';
                index += 2;
            },
            '\r' => {
                result[index] = '\\';
                result[index + 1] = 'r';
                index += 2;
            },
            '\t' => {
                result[index] = '\\';
                result[index + 1] = 't';
                index += 2;
            },
            else => {
                result[index] = c;
                index += 1;
            },
        }
    }
    return result[0..index]; // Return the escaped string
}

// Original version from https://github.com:jiripospisil/drtl
pub fn writeHighlighted(allocator: Allocator, stdout: File, content: []const u8) !void {
    const tty_conf = std.io.tty.detectConfig(std.io.getStdErr());
    var stdout_bw = std.io.bufferedWriter(stdout.writer());
    const stdout_w = stdout_bw.writer();

    try stdout_w.writeAll("\n");

    var it = std.mem.tokenizeScalar(u8, content, '\n');

    while (it.next()) |s| {
        if (std.mem.eql(u8, s, "")) {
            try stdout_w.writeAll("\n");
        } else if (std.mem.startsWith(u8, s, "#")) {
            try tty_conf.setColor(stdout_w, .bold);
            try stdout_w.print("{s}\n\n", .{s[2..]});
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, ">")) {
            try highlightBackTick(s[2..], stdout_w, tty_conf, .magenta, .yellow);
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, "-")) {
            try highlightBackTick(s[0..], stdout_w, tty_conf, .green, .yellow);
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, "`")) {
            const ss = s[1..(s.len - 1)];
            const output = try allocator.alloc(u8, ss.len);
            defer allocator.free(output);

            _ = std.mem.replace(u8, ss, "}}", "{{", output);

            try stdout_w.writeAll("    ");
            try tty_conf.setColor(stdout_w, .red);

            var itt = std.mem.tokenizeSequence(u8, output, "{{");
            var flip = false;
            while (itt.next()) |sss| {
                if (flip) {
                    try tty_conf.setColor(stdout_w, .blue);
                } else {
                    try tty_conf.setColor(stdout_w, .red);
                }
                flip = !flip;
                try stdout_w.writeAll(sss);
            }
            try stdout_w.writeAll("\n\n");
        }
    }

    try tty_conf.setColor(stdout_w, .reset);
    try stdout_bw.flush();
}

fn highlightBackTick(content: []const u8, stdout_w: anytype, tty_conf: std.io.tty.Config, color1: std.io.tty.Color, color2: std.io.tty.Color) !void {
    var itt = std.mem.tokenizeScalar(u8, content, '`');
    var flip = content[0] != '`';
    while (itt.next()) |sss| {
        if (flip) {
            try tty_conf.setColor(stdout_w, color1);
        } else {
            try tty_conf.setColor(stdout_w, color2);
        }
        flip = !flip;
        try stdout_w.writeAll(sss);
    }
    try stdout_w.writeAll("\n\n");
}
