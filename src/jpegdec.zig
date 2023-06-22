const std = @import("std");

// Import the TurboJPEG library.
const tj = @cImport({
    @cInclude("turbojpeg.h");
});

pub fn decodeJpegToI422(jpeg_data: []const u8, i422_data: []u8, width: u32, height: u32) !void {
    std.debug.assert(i422_data.len >= width * height * 2);
    // Create a TurboJPEG decompressor instance.
    const tj_instance = tj.tjInitDecompress();
    if (tj_instance == null) {
        return error.TurboJpegInitDecompressFailed;
    }
    defer _ = tj.tjDestroy(tj_instance);

    // Get the JPEG image dimensions and pixel format.
    var jpeg_width: c_int = 0;
    var jpeg_height: c_int = 0;
    var jpeg_subsamp: c_int = 0;
    var jpeg_colorspace: c_int = 0;
    if (tj.tjDecompressHeader3(tj_instance, &jpeg_data[0], jpeg_data.len, &jpeg_width, &jpeg_height, &jpeg_subsamp, &jpeg_colorspace) != 0) {
        std.log.err("tjDecompressHeader3: {s}", .{std.mem.sliceTo(tj.tjGetErrorStr2(tj_instance), 0)});
        return error.TurboJpegDecompressHeaderFailed;
    }

    // Check if the given width and height match the JPEG header information.
    if (jpeg_width != width or jpeg_height != height) {
        return error.ImageDimensionsMismatch;
    }

    // Check if the pixel format is YUV422.
    if (jpeg_subsamp != tj.TJSAMP_422) {
        return error.InvalidPixelFormat;
    }

    // Decompress the JPEG image data to the I422 format.
    if (tj.tjDecompressToYUV2(tj_instance, &jpeg_data[0], jpeg_data.len, &i422_data[0], jpeg_width, 1, jpeg_height, 0) != 0) {
        // JPEG data is frequently corrupted in MJPEG
        std.log.info("tjDecompressToYUV2: {s}", .{std.mem.sliceTo(tj.tjGetErrorStr2(tj_instance), 0)});
        return error.TurboJpegDecompressToYUV2Failed;
    }
}

pub const JpegDec = struct {
    instance: tj.tjhandle,

    const Self = @This();

    pub fn init() !JpegDec {
        const instance = tj.tjInitDecompress();
        if (instance == null) {
            return error.TurboJpegInitDecompressFailed;
        }
        return JpegDec{ .instance = instance };
    }

    pub fn deinit(self: *Self) void {
        _ = tj.tjDestroy(self.instance);
    }

    pub fn decodeToI422(self: *Self, jpeg_data: []const u8, i422_data: []u8, width: u32, height: u32) !void {
        // Get the JPEG image dimensions and pixel format.
        var jpeg_width: c_int = 0;
        var jpeg_height: c_int = 0;
        var jpeg_subsamp: c_int = 0;
        var jpeg_colorspace: c_int = 0;
        if (tj.tjDecompressHeader3(self.instance, &jpeg_data[0], jpeg_data.len, &jpeg_width, &jpeg_height, &jpeg_subsamp, &jpeg_colorspace) != 0) {
            std.log.err("tjDecompressHeader3: {s}", .{std.mem.sliceTo(tj.tjGetErrorStr2(self.instance), 0)});
            return error.TurboJpegDecompressHeaderFailed;
        }

        // Check if the given width and height match the JPEG header information.
        if (jpeg_width != width or jpeg_height != height) {
            return error.ImageDimensionsMismatch;
        }

        // Check if the pixel format is YUV422.
        if (jpeg_subsamp != tj.TJSAMP_422) {
            return error.InvalidPixelFormat;
        }

        // Decompress the JPEG image data to the I422 format.
        if (tj.tjDecompressToYUV2(self.instance, &jpeg_data[0], jpeg_data.len, &i422_data[0], jpeg_width, 1, jpeg_height, 0) != 0) {
            // JPEG data is frequently corrupted in MJPEG
            std.log.info("tjDecompressToYUV2: {s}", .{std.mem.sliceTo(tj.tjGetErrorStr2(self.instance), 0)});
            return error.TurboJpegDecompressToYUV2Failed;
        }
    }
};
