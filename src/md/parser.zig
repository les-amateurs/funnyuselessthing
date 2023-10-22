const std = @import("std");
const mem = std.mem;
const uefi = std.os.uefi;
const ArrayList = std.ArrayList;

const term = @import("../term.zig");

const Self = @This();
const Tokenizer = @import("tokenizer.zig");
const Token = Tokenizer.Token;
pub const Nodes = ArrayList(*Node);
const Lines = ArrayList([]const u8);

const heap = uefi.pool_allocator;

const Type = enum {
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
    children: Nodes = Nodes.init(heap),
    raw: []const u8 = undefined,

    pub fn clone(self: Node) *Node {
        var new = heap.create(Node) catch @panic("OOM");
        new.type = self.type;
        new.children = self.children.clone() catch @panic("OOM");
        new.raw = self.raw;
        return new;
    }
};

tokenizer: Tokenizer,

pub fn init(data: []const u8) Self {
    return .{
        .tokenizer = Tokenizer.init(data),
    };
}

pub fn matches(self: *Self, expected: []const Token) !bool {
    var new = try self.tokenizer.clone();
    for (expected) |expect| {
        const token = (new.next() catch return false) orelse return false;
        if (!expect.cmp(token)) {
            return false;
        }
    }
    return true;
}

pub fn consumeLine(self: *Self) anyerror!Nodes {
    var nodes = Nodes.init(heap);
    while (try self.next()) |node| {
        term.printf("node: {s}\r\n", .{@tagName(node.type)});
        try nodes.append(node.clone());
        if (node.type == Type.text) {
            if (mem.endsWith(u8, node.raw, "\n")) {
                break;
            }
        }
    }
    return nodes;
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
            // return Node{
            //     .type = .listitem,
            //     .children = try self.consumeLine(),
            // };
            try fragment.append('-');
        }

        // if (token.cmp(Token.opening_bracket) and try self.matches(&[_]Token{
        //     Token{ .fragment = undefined },
        //     Token.closing_bracket,
        //     Token.opening_paren,
        //     Token{ .fragment = undefined },
        //     Token.closing_paren,
        // })) {
        //     var children = Nodes.init(heap);
        //     try children.append((Node{ .type = .text, .raw = self.tokenizer.gimme().fragment }).clone());
        //     try self.tokenizer.skip(2);
        //     try children.append((Node{ .type = .text, .raw = self.tokenizer.gimme().fragment }).clone());
        //     try self.tokenizer.skip(1);
        //     return Node{
        //         .type = .link,
        //         .children = children,
        //     };
        // }

        if (token.cmp(Token{ .fragment = undefined })) {
            try fragment.appendSlice(token.fragment);
            if (mem.endsWith(u8, fragment.items, "\n")) {
                return Node{ .type = .text, .raw = fragment.items };
            }
        }

        if (token.cmp(Token.opening_bracket)) {
            try fragment.append('[');
        }

        if (token.cmp(Token.closing_bracket)) {
            try fragment.append(']');
        }

        if (token.cmp(Token.opening_paren)) {
            try fragment.append('(');
        }

        if (token.cmp(Token.closing_paren)) {
            try fragment.append(')');
        }
    }

    if (fragment.items.len != 0) {
        return Node{ .type = .text, .raw = fragment.items };
    }

    return null;
}
