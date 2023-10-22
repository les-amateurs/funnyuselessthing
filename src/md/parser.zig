const std = @import("std");
const mem = std.mem;
const uefi = std.os.uefi;
const ArrayList = std.ArrayList;

const Self = @This();
const Tokenizer = @import("tokenizer.zig");
const Token = Tokenizer.Token;
pub const Nodes = ArrayList(*Node);
const Lines = ArrayList([]const u8);

const heap = uefi.pool_allocator;

pub const Type = enum {
    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    link,
    image,
    code,
    listitem,
    text,
};

pub const Node = struct {
    type: Type,
    children: Nodes,
    raw: []const u8 = undefined,
};

tokenizer: Tokenizer,

pub fn init(data: []const u8) Self {
    return .{
        .tokenizer = Tokenizer.init(data),
    };
}

pub fn matches(self: *Self, expected: []Token) bool {
    var new = self.tokenizer.clone();
    for (expected) |expect| {
        const token = (new.next() catch return false) orelse return false;
        if (!expect.cmp(token)) {
            return false;
        }
    }
}

pub fn next(self: *Self) !?Node {
    var fragment = ArrayList(u8).init(heap);

    while (try self.tokenizer.next()) |token| {
        if (token.cmp(Token{ .hash = 0 })) {
            return Node{
                .type = switch (token.hash) {
                    1 => .h1,
                    2 => .h2,
                    3 => .h3,
                    4 => .h4,
                    5 => .h5,
                    else => .h6,
                },
                .children = try self.consumeLine(),
            };
        }

        if (token.cmp(Token.dash)) {
            return Node{
                .type = .listitem,
                .children = try self.consumeLine(),
            };
        }

        if (token.cmp(Token.opening_bracket) and self.matches([_]Token{
            Token.fragment,
            Token.closing_bracket,
            Token.opening_paren,
            Token.fragment,
            Token.closing_paren,
        })) {
            var children = Nodes.init(heap);
            try children.append(self.tokenizer.gimme());
            try self.tokenizer.skip(2);
            try children.append(self.tokenizer.gimme());
            try self.tokenizer.skip(1);
            return Node{
                .type = .link,
                .children = children,
            };
        }

        if (token.cmp(Token.fragment)) {
            try fragment.appendSlice(token.fragment);
            if (mem.endsWith(fragment.items, '\n')) {
                return Node{ .text = fragment.items };
            }
        }
    }
}
