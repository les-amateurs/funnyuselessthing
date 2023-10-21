const std = @import("std");

const Self = @This();

buffer: []const u8,
position: usize,
start_of_line: bool,

pub fn init(data: []const u8) Self {
    return .{
        .buffer = data,
        .position = 0,
        .start_of_line = false,
    };
}

pub fn clone(self: *Self) Self {
    return .{
        .buffer = self.buffer,
        .position = self.position,
        .start_of_line = self.start_of_line,
    };
}

pub fn peek(self: *Self) ?u8 {
    defer self.start_of_line = (self.prev() orelse '\n') == '\n';
    if (0 <= self.position and self.position < self.buffer.len) {
        return self.buffer[self.position];
    }
    return null;
}

pub fn back(self: *Self) void {
    self.position -= 1;
    defer self.start_of_line = (self.prev() orelse '\n') == '\n';
}

pub fn next(self: *Self) ?u8 {
    defer self.position += 1;
    return self.peek();
}

pub fn prev(self: *Self) ?u8 {
    if (self.position >= 1) {
        return self.buffer[self.position - 1];
    }
    return null;
}

pub fn skip(self: *Self, count: usize) void {
    self.position += count;
}

pub fn takeWhile(self: *Self, cond: *const fn (u8) bool) []const u8 {
    const start = self.position;
    var end = start;
    while (self.next()) |ch| {
        if (cond(ch)) {
            end += 1;
        } else {
            self.back();
            break;
        }
    }
    return self.buffer[start..end];
}
