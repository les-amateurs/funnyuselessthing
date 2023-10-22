const std = @import("std");
const builtin = std.builtin;
const arch = @import("arch.zig");
const term = @import("term.zig");
const uefi = std.os.uefi;
const cc = uefi.cc;
const mem = std.mem;
const fmt = std.fmt;

const Http = @import("http.zig").Http;
const HttpServiceBinding = @import("http_service_binding.zig").HttpServiceBinding;
const Status = uefi.Status;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
const Parser = @import("md/parser.zig");
const screen = @import("screen.zig");
const font = @import("font.zig");

var heap = uefi.pool_allocator;

pub fn main() noreturn {
    term.init();

    const boot_services = uefi.system_table.boot_services.?;
    _ = boot_services.setWatchdogTimer(0, 0, 0, null);

    var fb = screen.init(boot_services);
    _ = fb;

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
