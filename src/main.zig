const std = @import("std");
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

    const jpeg_data = try infile.readToEndAlloc(alc, 4 * 1024 * 1024);
    defer alc.free(jpeg_data);
    var i422_data = try alc.alloc(u8, width * height * 2);
    defer alc.free(i422_data);
    try jpegdec.decodeJpegToI422(jpeg_data, i422_data, width, height);
    try outfile.writeAll(i422_data);
}
