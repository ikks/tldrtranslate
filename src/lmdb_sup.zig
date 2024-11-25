const std = @import("std");

const Allocator = @import("std").mem.Allocator;
const c = @import("lmdb");

pub fn getwordordefault(
    /// Reserve memory, free when not needed
    allocator: Allocator,
    /// Name of the database holding the data
    db_name: []const u8,
    /// key to be fetched
    key_name: []const u8,
) ![]u8 {
    const env = try ret(c.mdb_env_create, .{});
    try result(c.mdb_env_open(env, db_name.ptr, 0, 0o400));
    const txn = try ret(c.mdb_txn_begin, .{ env, null, 0 });
    const myDb = try ret(c.mdb_dbi_open, .{ txn, null, 0x40000 });

    var key = val(key_name);
    const get_value: c.MDB_val = try ret(c.mdb_get, .{ txn, myDb, &key });

    return allocator.dupe(u8, fromVal(get_value));
}

pub fn ret(constructor: anytype, args: anytype) LmdbError!TypeToCreate(constructor) {
    const Intermediate = IntermediateType(constructor);
    var maybe: IntermediateType(constructor) = switch (@typeInfo(Intermediate)) {
        .Optional => null,
        .Int => 0,
        else => undefined,
    };
    try result(@call(.auto, constructor, args ++ .{&maybe}));
    return switch (@typeInfo(Intermediate)) {
        .Optional => maybe.?,
        else => maybe,
    };
}

pub fn val(bytes: []const u8) c.MDB_val {
    return .{
        .mv_size = bytes.len,
        .mv_data = @constCast(@ptrCast(bytes.ptr)),
    };
}

pub fn fromVal(value: c.MDB_val) []const u8 {
    const ptr: [*c]u8 = @ptrCast(value.mv_data);
    return ptr[0..value.mv_size];
}

fn TypeToCreate(function: anytype) type {
    const InnerType = IntermediateType(function);
    return switch (@typeInfo(InnerType)) {
        .Optional => |o| o.child,
        else => InnerType,
    };
}

fn IntermediateType(function: anytype) type {
    const params = @typeInfo(@TypeOf(function)).Fn.params;
    return @typeInfo(params[params.len - 1].type.?).Pointer.child;
}

pub fn result(int: isize) LmdbError!void {
    const e = switch (int) {
        0 => {},
        -30799 => error.MDB_KEYEXIST,
        -30798 => error.MDB_NOTFOUND,
        -30797 => error.MDB_PAGE_NOTFOUND,
        -30796 => error.MDB_CORRUPTED,
        -30795 => error.MDB_PANIC,
        -30794 => error.MDB_VERSION_MISMATCH,
        -30793 => error.MDB_INVALID,
        -30792 => error.MDB_MAP_FULL,
        -30791 => error.MDB_DBS_FULL,
        -30790 => error.MDB_READERS_FULL,
        -30789 => error.MDB_TLS_FULL,
        -30788 => error.MDB_TXN_FULL,
        -30787 => error.MDB_CURSOR_FULL,
        -30786 => error.MDB_PAGE_FULL,
        -30785 => error.MDB_MAP_RESIZED,
        -30784 => error.MDB_INCOMPATIBLE,
        -30783 => error.MDB_BAD_RSLOT,
        -30782 => error.MDB_BAD_TXN,
        -30781 => error.MDB_BAD_VALSIZE,
        -30780 => error.MDB_BAD_DBI,
        -30779 => error.MDB_PROBLEM,
        1 => error.EPERM,
        2 => error.ENOENT,
        3 => error.ESRCH,
        4 => error.EINTR,
        5 => error.EIO,
        6 => error.ENXIO,
        7 => error.E2BIG,
        8 => error.ENOEXEC,
        9 => error.EBADF,
        10 => error.ECHILD,
        11 => error.EAGAIN,
        12 => error.ENOMEM,
        13 => error.EACCES,
        14 => error.EFAULT,
        15 => error.ENOTBLK,
        16 => error.EBUSY,
        17 => error.EEXIST,
        18 => error.EXDEV,
        19 => error.ENODEV,
        20 => error.ENOTDIR,
        21 => error.EISDIR,
        22 => error.EINVAL,
        23 => error.ENFILE,
        24 => error.EMFILE,
        25 => error.ENOTTY,
        26 => error.ETXTBSY,
        27 => error.EFBIG,
        28 => error.ENOSPC,
        29 => error.ESPIPE,
        30 => error.EROFS,
        31 => error.EMLINK,
        32 => error.EPIPE,
        33 => error.EDOM,
        34 => error.ERANGE,
        else => error.UnspecifiedErrorCode,
    };
    return e catch |ee| {
        @import("std").debug.print("{}", .{ee});
        return ee;
    };
}

pub const LmdbError = error{
    ////////////////////////////////////////////////////////
    /// lmdb-specific errors
    ////

    /// Successful result
    MDB_SUCCESS,
    /// key/data pair already exists
    MDB_KEYEXIST,
    /// key/data pair not found (EOF)
    MDB_NOTFOUND,
    /// Requested page not found - this usually indicates corruption
    MDB_PAGE_NOTFOUND,
    /// Located page was wrong type
    MDB_CORRUPTED,
    /// Update of meta page failed or environment had fatal error
    MDB_PANIC,
    /// Environment version mismatch
    MDB_VERSION_MISMATCH,
    /// File is not a valid LMDB file
    MDB_INVALID,
    /// Environment mapsize reached
    MDB_MAP_FULL,
    /// Environment maxdbs reached
    MDB_DBS_FULL,
    /// Environment maxreaders reached
    MDB_READERS_FULL,
    /// Too many TLS keys in use - Windows only
    MDB_TLS_FULL,
    /// Txn has too many dirty pages
    MDB_TXN_FULL,
    /// Cursor stack too deep - internal error
    MDB_CURSOR_FULL,
    /// Page has not enough space - internal error
    MDB_PAGE_FULL,
    /// Database contents grew beyond environment mapsize
    MDB_MAP_RESIZED,
    /// Operation and DB incompatible, or DB type changed. This can mean:
    /// The operation expects an #MDB_DUPSORT / #MDB_DUPFIXED database.
    /// Opening a named DB when the unnamed DB has #MDB_DUPSORT / #MDB_INTEGERKEY.
    /// Accessing a data record as a database, or vice versa.
    /// The database was dropped and recreated with different flags.
    MDB_INCOMPATIBLE,
    /// Invalid reuse of reader locktable slot
    MDB_BAD_RSLOT,
    /// Transaction must abort, has a child, or is invalid
    MDB_BAD_TXN,
    /// Unsupported size of key/DB name/data, or wrong DUPFIXED size
    MDB_BAD_VALSIZE,
    /// The specified DBI was changed unexpectedly
    MDB_BAD_DBI,
    /// Unexpected problem - txn should abort
    MDB_PROBLEM,

    ////////////////////////////////////////////////////////
    /// asm-generic errors - may be thrown by lmdb
    ////

    /// Operation not permitted
    EPERM,
    /// No such file or directory
    ENOENT,
    /// No such process
    ESRCH,
    /// Interrupted system call
    EINTR,
    /// I/O error
    EIO,
    /// No such device or address
    ENXIO,
    /// Argument list too long
    E2BIG,
    /// Exec format error
    ENOEXEC,
    /// Bad file number
    EBADF,
    /// No child processes
    ECHILD,
    /// Try again
    EAGAIN,
    /// Out of memory
    ENOMEM,
    /// Permission denied
    EACCES,
    /// Bad address
    EFAULT,
    /// Block device required
    ENOTBLK,
    /// Device or resource busy
    EBUSY,
    /// File exists
    EEXIST,
    /// Cross-device link
    EXDEV,
    /// No such device
    ENODEV,
    /// Not a directory
    ENOTDIR,
    /// Is a directory
    EISDIR,
    /// Invalid argument
    EINVAL,
    /// File table overflow
    ENFILE,
    /// Too many open files
    EMFILE,
    /// Not a typewriter
    ENOTTY,
    /// Text file busy
    ETXTBSY,
    /// File too large
    EFBIG,
    /// No space left on device
    ENOSPC,
    /// Illegal seek
    ESPIPE,
    /// Read-only file system
    EROFS,
    /// Too many links
    EMLINK,
    /// Broken pipe
    EPIPE,
    /// Math argument out of domain of func
    EDOM,
    /// Math result not representable
    ERANGE,

    ////////////////////////////////////////////////////////
    /// errors interfacing with Lmdb
    ////

    /// Got a return value that is not specified in LMDB's header files
    UnspecifiedErrorCode,
};
