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
var fb: screen.FrameBuffer = undefined;

fn addLine() void {
    file.insert(line, ArrayList(u8).init(heap)) catch @panic("OOM");
    line += 1;
}

const Dir = enum(u16) { up = 1, down = 2, left = 3, right = 4 };

fn typeChar(char: u8) void {
    file.items[line].insert(col, char) catch @panic("OOM");
    col += 1;
}

fn moveCursor(dir: Dir) void {
    switch (dir) {
        .up => line = @min(0, line - 1),
        .down => line = @max(line + 1, @as(u32, @truncate(file.items.len))),
        .left => col = @min(0, col - 1),
        .right => col = @max(@as(u32, @truncate(file.items[line].items.len)), col + 1),
    }
}

fn switchMode() void {
    switch (mode) {
        .edit => {
            var string: []const u8 = "";
            for (file.items) |row| {
                string = mem.concat(heap, u8, &[_][]const u8{ string, "\n", row.items }) catch @panic("OOM");
            }
            mode = .visual;
            var p = Parser.init(string);
            var nodes = Parser.Nodes.init(heap);
            while (p.next() catch @panic("oops node failed")) |node| {
                nodes.append(node.clone()) catch @panic("OOM");
            }
            var scroll: u32 = 16;
            fb.markdown(nodes, &scroll, null);
        },
        .visual => {
            mode = .edit;
            fb.edit(file, line, col);
        },
    }
}

pub fn main() noreturn {
    term.init();
    const boot_services = uefi.system_table.boot_services.?;

    // main_with_error() catch |e| {
    //     term.printf("error: {s}\r\n", .{@errorName(e)});
    // };
    //
    fb = screen.init(boot_services);
    file = ArrayList(ArrayList(u8)).init(heap);
    main_with_error() catch |e| {
        term.printf("error: {s}\r\n", .{@errorName(e)});
    };

    addLine();
    line -= 1;
    typeChar('#');
    typeChar(' ');
    typeChar('H');
    col = 0;
    fb.clear();
    font.init();
    fb.edit(file, line, col);

    // ESC is scan code 17
    // otherwise it returns the character
    // and respects the shift key
    while (true) {
        if (term.poll()) |key| {
            fb.clear();
            if (key.scan_code == 17) {
                switchMode();
                continue;
            } else if (key.scan_code < 5 and mode == .edit) {
                moveCursor(@enumFromInt(key.scan_code));
                term.printf("{any}", .{key.scan_code});
                fb.edit(file, line, col);
                continue;
            } else if (key.scan_code == 0) {
                addLine();
            }

            switch(mode) {
                .edit => {
                   if (key.unicode_char > 0) {
                        typeChar(@as(u8, @truncate(key.unicode_char)));
                        fb.edit(file, line, col);
                    } 
                },
                .visual => {}
            }

            // term.printf("ch: {x}\r\n", .{key.unicode_char});
            // term.printf("sc: {x}\r\n", .{key.scan_code});
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
