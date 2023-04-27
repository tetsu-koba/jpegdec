const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const testing = std.testing;
const expect = std.testing.expect;

const jpegdec = @import("jpegdec.zig");

test "decodeJpegToI422" {
    const allocator = std.heap.page_allocator;

    const input_jpeg_path = "testfiles/test001.jpeg";
    const expected_output_path = "testfiles/test001.i422";

    var file1 = try std.fs.cwd().openFile(input_jpeg_path, .{});
    defer file1.close();
    const jpeg_data = try file1.readToEndAlloc(allocator, 4 * 1024 * 1024);
    defer allocator.free(jpeg_data);

    var file2 = try std.fs.cwd().openFile(expected_output_path, .{});
    defer file2.close();
    const expected_i422_data = try file2.readToEndAlloc(allocator, 4 * 1024 * 1024);
    defer allocator.free(expected_i422_data);

    // Test decoding
    const width: u32 = 160;
    const height: u32 = 90;
    var i422_data_buf: [width * height * 2]u8 = undefined;
    try jpegdec.decodeJpegToI422(jpeg_data, &i422_data_buf, width, height);

    try expect(mem.eql(u8, expected_i422_data, i422_data_buf[0..]));
}
