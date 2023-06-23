const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;
const testing = std.testing;
const expect = std.testing.expect;

const jpegdec = @import("jpegdec.zig");

pub fn main() !void {
    const alc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alc);
    defer std.process.argsFree(alc, args);

    if (args.len < 5) {
        std.debug.print("Usage: {s} input_jpeg_file output_i422_file width height\n", .{args[0]});
        std.os.exit(1);
    }
    var infile = try std.fs.cwd().openFile(std.mem.sliceTo(args[1], 0), .{});
    defer infile.close();
    var outfile = try std.fs.cwd().createFile(std.mem.sliceTo(args[2], 0), .{});
    defer outfile.close();
    const width = try std.fmt.parseInt(u32, args[3], 10);
    const height = try std.fmt.parseInt(u32, args[4], 10);

    try decodeMjpeg(alc, infile, outfile, width, height);
}

pub fn decodeMjpeg(alc: std.mem.Allocator, infile: fs.File, outfile: fs.File, width: u32, height: u32) !void {
    var bufsize: usize = 64 * 1024;
    blk: {
        if (builtin.os.tag == .linux) {
            const pip = @import("set_pipe_size.zig");
            if (try pip.isPipe(infile.handle)) {
                const max_size = pip.getPipeMaxSize() catch {
                    break :blk;
                };
                bufsize = max_size;
            }
        }
    }

    var buffer = try alc.alloc(u8, bufsize);
    defer alc.free(buffer);
    var write_buffer = std.ArrayList(u8).init(alc);
    defer write_buffer.deinit();
    var i422_data = try alc.alloc(u8, width * height * 2);
    defer alc.free(i422_data);
    var jp = try jpegdec.JpegDec.init();
    defer jp.deinit();
    var isPipe = false;
    if (builtin.os.tag == .linux) {
        const pip = @import("set_pipe_size.zig");
        if (try pip.isPipe(outfile.handle)) {
            isPipe = true;
            try pip.setPipeMaxSize(outfile.handle);
        }
    }

    const JPEG_START0 = 0xff;
    const JPEG_START1 = 0xd8;
    const JPEG_END0 = 0xff;
    const JPEG_END1 = 0xd9;
    const State = enum {
        st0, // waiting for JPEG_START0
        st1, // waiting for JPEG_START1
        st2, // waiting for JPEG_END0
        st3, // waiting for JPEG_END1
    };
    var state: State = State.st0;

    var running = true;
    while (running) {
        const n = try infile.read(buffer);
        if (n == 0) break;

        for (buffer[0..n]) |v| {
            switch (state) {
                State.st0 => {
                    if (v == JPEG_START0) {
                        state = State.st1;
                    }
                },
                State.st1 => {
                    if (v == JPEG_START1) {
                        try write_buffer.append(JPEG_START0);
                        try write_buffer.append(JPEG_START1);
                        state = State.st2;
                    } else if (v != JPEG_START0) {
                        state = State.st0;
                    }
                },
                State.st2 => {
                    try write_buffer.append(v);
                    if (v == JPEG_END0) {
                        state = State.st3;
                    }
                },
                State.st3 => {
                    try write_buffer.append(v);
                    if (v == JPEG_END1) {
                        state = State.st0;
                        defer write_buffer.clearRetainingCapacity();
                        jp.decodeToI422(write_buffer.items, i422_data, width, height) catch {
                            continue;
                        };
                        if (builtin.os.tag == .linux and isPipe) {
                            @import("vmsplice.zig").vmspliceSingleBuffer(i422_data, outfile.handle) catch |err| {
                                if (err == error.BrokenPipe) {
                                    running = false;
                                    break;
                                } else {
                                    return err;
                                }
                            };
                        } else {
                            outfile.writeAll(i422_data) catch |err| {
                                if (err == error.BrokenPipe) {
                                    running = false;
                                    break;
                                } else {
                                    return err;
                                }
                            };
                        }
                    } else if (v != JPEG_END0) {
                        state = State.st2;
                    }
                },
            }
        }
    }
}
