const std = @import("std");
const builtin = std.builtin;
const arch = @import("arch.zig");
const term = @import("term.zig");
const uefi = std.os.uefi;
const cc = uefi.cc;
const mem = std.mem;
const fmt = std.fmt;
const ArrayList = std.ArrayList;

const Http = @import("http.zig").Http;
const HttpServiceBinding = @import("http_service_binding.zig").HttpServiceBinding;
const Status = uefi.Status;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
const Parser = @import("md/parser.zig");
const screen = @import("screen.zig");
const font = @import("font.zig");

var heap = uefi.pool_allocator;

// MSFROG OS ascii art
const logo = [_][]const u8{
    \\ __  __  _____ ______ _____   ____   _____    ____   _____ 
    ,
    \\|  \/  |/ ____|  ____|  __ \ / __ \ / ____|  / __ \ / ____|
    ,
    \\| |\/| |\___ \|  __| |  _  /| |  | | | |_ | | |  | |\___ \ 
    ,
    \\| |  | |____) | |    | | \ \| |__| | |__| | | |__| |____) |
    ,
    \\|_|  |_|_____/|_|    |_|  \_\\____/ \_____|  \____/|_____/ 
    ,
    \\===========================================================
    ,
    "\r\n",
};

fn callback(event: uefi.Event, ctx: ?*anyopaque) callconv(cc) void {
    _ = ctx;
    _ = event;
    term.printf("[!] callback!\r\n", .{});
}

const Mode = enum { edit, visual };

var mode = Mode.edit;
var file: ArrayList(ArrayList(u8)) = undefined;
var line: u32 = 0;
var col: u32 = 0;

fn addLine() void {
    file.insert(line, ArrayList(u8).init(heap)) catch @panic("OOM");
    line += 1;
}

const Dir = enum { up, down, left, right };

fn typeChar(char: u8) void {
    file.items[line].insert(col, char) catch @panic("OOM");
    col += 1;
}

fn moveCursor(dir: Dir) void {
    switch (dir) {
        .up => line = @min(0, line - 1),
        .down => line = @max(line + 1, file.items.len),
        .left => col = @min(0, col - 1),
        .right => col = @max(file.items[line].len, col + 1),
    }
}

fn switchMode() void {
    switch (mode) {
        .edit => mode = .visual,
        .visual => mode = .edit,
    }
}

pub fn main() noreturn {
    term.init();
    const boot_services = uefi.system_table.boot_services.?;

    // main_with_error() catch |e| {
    //     term.printf("error: {s}\r\n", .{@errorName(e)});
    // };
    //
    file = ArrayList(ArrayList(u8)).init(heap);
    var fb = screen.init(boot_services);
    addLine();
    line -= 1;
    term.printf("{any}", .{file.items});
    typeChar('#');
    typeChar(' ');
    typeChar('H');
    col = 0;
    fb.clear();
    font.init();
    fb.edit(file, line, col);

    arch.hang();
}

fn main_with_error() !void {
    var data = "#### LMFAO\n- item";
    var parser = Parser.init(data);

    while (try parser.next()) |node| {
        term.printf("node: {any}\r\n", .{node});
    }

    term.printf("wtf this worked???\n", .{});
}

// must provide a panic implementation, similar to how Rust forces you to define
// a panic function to handle errors when using #[no_std]
pub fn panic(message: []const u8, stack_trace: ?*builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = stack_trace;
    _ = ret_addr;

    // see terminal colors here: https://uefi.org/specs/UEFI/2.10/12_Protocols_Console_Support.html#efi-simple-text-output-protocol-setattribute
    _ = term.stdout.setAttribute(0x0C);
    term.printf("[-] ERROR: {s}\r\nRESTART to try again\r\n", .{message});

    arch.hang();
}
