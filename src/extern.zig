const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

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

//github.com:jiripospisil/drtl
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
            try tty_conf.setColor(stdout_w, .dim);
            try stdout_w.print("{s}\n\n", .{s[2..]});
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, "-")) {
            try tty_conf.setColor(stdout_w, .green);
            try stdout_w.print("{s}\n", .{s});
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, "`")) {
            const ss = s[1..(s.len - 1)];
            const output = try allocator.alloc(u8, ss.len);

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
