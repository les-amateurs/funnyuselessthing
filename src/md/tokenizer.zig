const std = @import("std");
const uefi = std.os.uefi;
const term = @import("../term.zig");

const ArrayList = std.ArrayList;
const heap = uefi.pool_allocator;

const Self = @This();
const Stream = @import("stream.zig");
const Tokens = ArrayList([]const u8);

const Type = enum {
    dash,
    hash,
    opening_bracket,
    closing_bracket,
    opening_paren,
    closing_paren,
    fragment,
};

pub const Token = union(Type) {
    dash: void,
    hash: usize,
    opening_bracket: void,
    closing_bracket: void,
    opening_paren: void,
    closing_paren: void,
    fragment: []u8,

    // tag wise comparison only, we do not care about the values
    pub fn cmp(self: Token, other: Token) bool {
        return switch (self) {
            .dash => switch (other) {
                .dash => true,
                else => false,
            },
            .hash => switch (other) {
                .hash => true,
                else => false,
            },
            .opening_bracket => switch (other) {
                .opening_bracket => true,
                else => false,
            },
            .closing_bracket => switch (other) {
                .closing_bracket => true,
                else => false,
            },
            .opening_paren => switch (other) {
                .opening_paren => true,
                else => false,
            },
            .closing_paren => switch (other) {
                .closing_paren => true,
                else => false,
            },
            .fragment => switch (other) {
                .fragment => true,
                else => false,
            },
        };
    }
};

tokens: Tokens,
stream: Stream,
fragment: ArrayList(u8),

pub fn init(data: []const u8) Self {
    return .{
        .tokens = Tokens.init(heap),
        .stream = Stream.init(data),
        .fragment = ArrayList(u8).init(heap),
    };
}

pub fn clone(self: *Self) !Self {
    return .{
        .tokens = try self.tokens.clone(),
        .stream = self.stream.clone(),
        .fragment = try self.fragment.clone(),
    };
}

fn isHash(ch: u8) bool {
    return ch == '#';
}

pub fn skip(self: *Self, count: usize) !void {
    for (0..count) |_| {
        _ = try self.next();
    }
}

pub fn gimme(self: *Self) Token {
    return (self.next() catch @panic("oops")).?;
}

pub fn next(self: *Self) !?Token {
    while (self.stream.next()) |ch| {
        const control = switch (ch) {
            '-', '#' => self.stream.start_of_line,
            '[', ']', '(', ')' => true,
            else => false,
        };

        if (control) {
            if (self.fragment.items.len != 0) {
                self.stream.back();
                defer self.fragment.shrinkAndFree(0);
                return Token{ .fragment = (try self.fragment.clone()).items };
            }

            switch (ch) {
                '-' => return Token.dash,
                '#' => return Token{ .hash = 1 + self.stream.takeWhile(isHash).len },
                '[' => return Token.opening_bracket,
                ']' => return Token.closing_bracket,
                '(' => return Token.opening_paren,
                ')' => return Token.closing_paren,
                else => {},
            }
        }

        try self.fragment.append(ch);
        if (ch == '\n') break;
    }

    if (self.fragment.items.len != 0) {
        defer self.fragment.shrinkAndFree(0);
        return Token{ .fragment = (try self.fragment.clone()).items };
    }
    return null;
}
