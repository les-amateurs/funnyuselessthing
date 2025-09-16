const std = @import("std");
const arch = @import("arch.zig");
const term = @import("term.zig");
const font = @import("font.zig");
const Parser = @import("md/parser.zig");

const ArrayList = std.ArrayList;
const uefi = std.os.uefi;

pub const BootServices = uefi.tables.BootServices;
pub const GraphicsOutput = uefi.protocols.GraphicsOutputProtocol;

pub var graphics: *GraphicsOutput = undefined;

pub fn init(boot_services: *BootServices) FrameBuffer {
    if (boot_services.locateProtocol(&uefi.protocols.GraphicsOutputProtocol.guid, null, @ptrCast(&graphics)) != uefi.Status.Success) {
        @panic("HSAHHAHAHA");
    }

    const num_pixels = graphics.mode.info.vertical_resolution * graphics.mode.info.horizontal_resolution;
    std.debug.assert(graphics.mode.frame_buffer_size == num_pixels);
    return FrameBuffer{ .height = graphics.mode.info.vertical_resolution, .width = graphics.mode.info.horizontal_resolution, .buf = @as([*]u32, @ptrFromInt(graphics.mode.frame_buffer_base))[0..@as(usize, num_pixels)] };
}

pub const Vec2 = std.meta.Tuple(&[_]type{ u32, u32 });

pub const FrameBuffer = struct {
    const Self = @This();
    height: u32,
    width: u32,
    buf: []u32,

    pub fn clear(self: *Self) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.buf[y * self.width + x] = 0xffffffff;
            }
        }
    }

    pub fn rect(self: *Self, p1: Vec2, p2: Vec2, col: u32) void {
        for (p1[1]..p2[1]) |y| {
            for (p1[0]..p2[0]) |x| {
                self.buf[y * self.width + x] = col;
            }
        }
    }

    pub fn invertRect(self: *Self, line: u32, col: u32) void {
        const p1 = .{ 16 + col * font.p.max_w, 16 + line * (font.p.max_h + 2) };
        const p2 = .{ 16 + (col + 1) * font.p.max_w, 16 + (line + 1) * (font.p.max_h + 2) };
        for (p1[1]..p2[1]) |y| {
            for (p1[0]..p2[0]) |x| {
                const ogColor = self.buf[y * self.width + x];
                self.buf[y * self.width + x] = ~ogColor;
            }
        }
    }

    pub fn char(self: *Self, bl: Vec2, glyph: font.Glyph) void {
        var i: u32 = 0;
        for (bl[1] - glyph.height..bl[1]) |y| {
            for (bl[0]..bl[0] + glyph.width) |x| {
                var data = 255 - glyph.data[i];
                const color = 0xff000000 + @as(u32, data) * 0x010101;
                self.buf[y * self.width + x] = color;
                i += 1;
            }
        }
    }

    pub fn text(self: *Self, bl: Vec2, set: font.GlyphSet, str: []const u8) void {
        var left: u32 = 0;
        for (str) |c| {
            if (std.mem.indexOfScalar(u8, "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`~!@#$%^&*()-_=+[]{}\\|.>,</?;:'\" ", c)) |_| {
                self.char(.{ bl[0] + left, bl[1] }, set.get(c));
                left += set.max_w;
            }
        }
    }

    pub fn edit(self: *Self, file: ArrayList(ArrayList(u8)), line: u32, col: u32) void {
        var scroll: u32 = 16;
        for (file.items) |lineList| {
            self.text(.{ 16, scroll + font.p.max_h }, font.p, lineList.items);
            scroll += font.p.max_h + 2;
        }
        self.invertRect(line, col);
    }

    pub fn markdown(self: *Self, md: Parser.Nodes, scroll: *u32, inheritedFont: ?font.GlyphSet) void {
        for (md.items) |node| {
            switch (node.type) {
                .h1, .h2, .h3, .h4, .h5, .h6 => {
                    const glyphSet = font.enumToGlyphSet(node.type);
                    self.markdown(node.children, scroll, glyphSet);
                },
                .text => {
                    var textFont: font.GlyphSet = undefined;
                    if (inheritedFont) |f| {
                        textFont = f;
                    } else {
                        textFont = font.p;
                    }
                    self.text(.{ 16, scroll.* + textFont.max_h }, textFont, node.raw);
                    scroll.* += textFont.max_h;
                },
                else => @panic("\"OOM\""),
            }
        }
    }
};
