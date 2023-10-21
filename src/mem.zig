const std = @import("std");
const uefi = std.uefi;

export fn malloc(amount: usize) callconc(.C) *anyopaque {

}