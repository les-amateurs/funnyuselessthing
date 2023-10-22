const h1_f = @embedFile("font/rast/jb-h1.txt");
const h2_f = @embedFile("font/rast/jb-h2.txt");
const h3_f = @embedFile("font/rast/jb-h3.txt");
const p_f = @embedFile("font/rast/jb-p.txt");
const term = @import("term.zig");
const Parser = @import("md/parser.zig");

pub const Glyph = struct {
    width: u8,
    height: u8,
    left: u8,
    top: u8,
    data: []const u8,
};
pub const GlyphSet = struct {
    const Self = @This();
    glyphs: [0x7F - 0x20]Glyph,
    max_w: u32,
    max_h: u32,

    fn init(self: *Self, file: []const u8) void {
        var offset: usize = 0;
        var i: u8 = 0;
        while (offset < file.len) : (i += 1) {
            const width = consume(file, &offset);
            const height = consume(file, &offset);
            const left = consume(file, &offset);
            const top = consume(file, &offset);
            const data = file[offset .. offset + (@as(usize, width) * @as(usize, height))];
            offset += @as(u32, width) * @as(u32, height);
            self.max_w = @max(width, self.max_w);
            self.max_h = @max(height, self.max_h);
            self.glyphs[i] = Glyph{
                .width = width,
                .height = height,
                .left = left,
                .top = top,
                .data = data,
            };
        }
    }

    pub fn get(self: Self, char: u8) Glyph {
        return self.glyphs[char - 0x20];
    }
};

pub var h1: GlyphSet = undefined;
pub var h2: GlyphSet = undefined;
pub var h3: GlyphSet = undefined;
pub var p: GlyphSet = undefined;

pub fn enumToGlyphSet(header: Parser.Type) GlyphSet {
    return switch (header) {
        .h1 => h1,
        .h2 => h2,
        .h3 => h3,
        .text => p,
        else => h3,
    };
}

pub fn init() void {
    h1.init(h1_f);
    h2.init(h2_f);
    h3.init(h3_f);
    p.init(p_f);
}

fn consume(file: []const u8, offset: *usize) u8 {
    defer offset.* += 1;
    return file[offset.*];
}
