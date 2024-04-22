const std = @import("std");
const fs = std.fs;
const posix = std.posix;
const c = @cImport({
    @cDefine("_GNU_SOURCE", "");
    @cInclude("fcntl.h");
    @cInclude("sys/uio.h");
    @cInclude("errno.h");
});

fn getErrno() c_int {
    return c.__errno_location().*;
}

pub fn vmspliceSingleBuffer(buf: []const u8, fd: posix.fd_t) !void {
    var iov: c.struct_iovec = .{
        .iov_base = @as(?*anyopaque, @ptrCast(@constCast(buf.ptr))),
        .iov_len = buf.len,
    };
    var n: isize = undefined;
    while (true) {
        n = c.vmsplice(fd, &iov, 1, @as(c_uint, @bitCast(c.SPLICE_F_GIFT)));
        if (n < 0) {
            const errno = getErrno();
            switch (errno) {
                c.EINTR => {
                    continue;
                },
                c.EPIPE => {
                    return error.BrokenPipe;
                },
                else => {
                    std.log.err("vmsplice: errno={d}", .{errno});
                },
            }
        } else if (@as(usize, @bitCast(n)) == iov.iov_len) {
            return;
        } else if (n != 0) {
            //std.log.info("vmsplice: return value mismatch: n={d}, iov_len={d}", .{ n, iov.iov_len });
            const un = @as(usize, @bitCast(n));
            iov.iov_len -= un;
            iov.iov_base = @as(?*anyopaque, @ptrFromInt(@intFromPtr(iov.iov_base) + un));
            continue;
        }
        return error.vmsplice;
    }
    unreachable;
}
