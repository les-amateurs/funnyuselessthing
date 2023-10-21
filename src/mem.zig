const std = @import("std");
const uefi = std.os.uefi;
const allocator = uefi.pool_allocator;

pub export fn malloc(size: usize) callconv(.C) ?*anyopaque {
    var m = allocator.alloc(u8, size) catch @panic("failed to allocate memory");
    return @ptrCast(m.ptr);
}

pub export fn free(ptr: ?*anyopaque) callconv(.C) void {
    if (ptr) |nonnull| {
        allocator.free(nonnull);
    }
}

pub export fn realloc(ptr: ?*anyopaque, newsize: usize) callconv(.C) ?*anyopaque {
    free(ptr);
    return malloc(newsize);
}

pub export fn calloc(num: usize, size: usize) ?*anyopaque {
    var m = allocator.alloc(u8, num * size) catch @panic("failed to allocate memory");
    @memset(m, 0);
    return @ptrCast(m.ptr);
}
