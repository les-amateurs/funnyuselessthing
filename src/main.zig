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
    main_with_error() catch |e| {
        term.printf("error: {s}\r\n", .{@errorName(e)});
    };

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
    var example_tree = Parser.Nodes.init(heap);
    var hchildren = Parser.Nodes.init(heap);
    var text_frag = Parser.Node{
        .type = .text,
        .children = undefined,
        .raw = "LMAO",
    };
    hchildren.append(&text_frag) catch @panic("OOM");
    var header = Parser.Node{
        .type = .h1,
        .children = hchildren,
    };
    example_tree.append(&header) catch @panic("OOM");

    var scroll: u32 = 16;
    fb.markdown(example_tree, &scroll, null);

    // ESC is scan code 17
    // otherwise it returns the character
    // and respects the shift key
    while (true) {
        if (term.poll()) |key| {
            term.printf("ch: {x}\r\n", .{key.unicode_char});
            term.printf("sc: {x}\r\n", .{key.scan_code});
        }
    }

    arch.hang();
}

fn main_with_error() !void {
    var data =
        \\#    HEADER 1
        \\##   HEADER 2
        \\###  HEADER 3
        \\- LIST ITEM 1
        \\- LIST ITEM 2
        \\THIS IS SOME TEXT
        \\[URL](wow)
        \\
    ;
    var parser = Parser.init(data);

    while (try parser.next()) |node| {
        term.printf("type: {s}\r\n", .{@tagName(node.type)});
        switch (node.type) {
            .h1, .h2, .h3 => {
                term.printf("header: {s}\r\n", .{node.children.items[0].raw});
            },
            .listitem => {
                term.printf("list: {s}\r\n", .{node.children.items[0].raw});
            },
            .link => {
                term.printf("url: {s} {s}\r\n", .{ node.children.items[0].raw, node.children.items[1].raw });
            },
            .text => {
                term.printf("text: {s}\r\n", .{node.raw});
            },
            else => {},
        }
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
