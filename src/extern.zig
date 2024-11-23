const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

//Taken from https://github.com/liyu1981/tmpfile.zig/blob/master/src/tmpfile.zig
pub fn getSysTmpDir(a: std.mem.Allocator) ![]const u8 {
    const Impl = switch (builtin.os.tag) {
        .linux, .macos, .freebsd, .openbsd, .netbsd => struct {
            pub fn get(allocator: std.mem.Allocator) ![]const u8 {
                // cpp17's temp_directory_path gives good reference
                // https://en.cppreference.com/w/cpp/filesystem/temp_directory_path
                // POSIX standard, https://en.wikipedia.org/wiki/TMPDIR
                return std.process.getEnvVarOwned(allocator, "TMPDIR") catch {
                    return std.process.getEnvVarOwned(allocator, "TMP") catch {
                        return std.process.getEnvVarOwned(allocator, "TEMP") catch {
                            return std.process.getEnvVarOwned(allocator, "TEMPDIR") catch {
                                return try allocator.dupe(u8, "/tmp");
                            };
                        };
                    };
                };
            }
        },
        .windows => struct {
            const DWORD = std.os.windows.DWORD;
            const LPWSTR = std.os.windows.LPWSTR;
            const MAX_PATH = std.os.windows.MAX_PATH;
            const WCHAR = std.os.windows.WCHAR;

            pub extern "C" fn GetTempPath2W(BufferLength: DWORD, Buffer: LPWSTR) DWORD;

            pub fn get(allocator: std.mem.Allocator) ![]const u8 {
                // use GetTempPathW2, https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-gettemppathw
                var wchar_buf: [MAX_PATH + 2:0]WCHAR = undefined;
                wchar_buf[MAX_PATH + 1] = 0;
                const ret = GetTempPath2W(MAX_PATH + 1, &wchar_buf);
                if (ret != 0) {
                    const path = wchar_buf[0..ret];
                    return std.unicode.utf16leToUtf8Alloc(allocator, path);
                } else {
                    return error.GetTempPath2WFailed;
                }
            }
        },
        else => {
            @panic("Not support, os=" ++ @tagName(std.builtin.os.tag));
        },
    };

    return Impl.get(a);
}

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
