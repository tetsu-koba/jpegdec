const std = @import("std");
const fs = std.fs;
const os = std.os;
const posix = std.posix;
const c = @cImport({
    @cDefine("_GNU_SOURCE", "");
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
});

// Check if the given file descriptor is a pipe
pub fn isPipe(fd: posix.fd_t) !bool {
    const stat = try posix.fstat(fd);
    return (stat.mode & os.linux.S.IFMT) == os.linux.S.IFIFO;
}

// Get the maximum size for pipe buffer
pub fn getPipeMaxSize() !usize {
    // Read the maximum pipe size
    var pipe_max_size_file = try fs.cwd().openFile("/proc/sys/fs/pipe-max-size", .{});
    defer pipe_max_size_file.close();

    var reader = pipe_max_size_file.reader();
    var buffer: [128]u8 = undefined;
    const max_size_str = std.mem.trimRight(u8, buffer[0..(try reader.readAll(&buffer))], &std.ascii.whitespace);
    const max_size = std.fmt.parseInt(usize, max_size_str, 10) catch |err| {
        std.debug.print("Failed to parse /proc/sys/fs/pipe-max-size: {}\n", .{err});
        return err;
    };
    return max_size;
}

// Set the size of the given pipe file descriptor to the maximum size
pub fn setPipeMaxSize(fd: posix.fd_t) !void {
    const max_size = @as(c_int, @intCast(try getPipeMaxSize()));
    // If the current size is less than the maximum size, set the pipe size to the maximum size
    const current_size = c.fcntl(fd, c.F_GETPIPE_SZ);
    if (current_size < max_size) {
        if (max_size != c.fcntl(fd, c.F_SETPIPE_SZ, max_size)) {
            return error.FaiedToSetPipeSize;
        }
    }
}
