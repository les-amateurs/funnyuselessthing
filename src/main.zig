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
<<<<<<< HEAD
const Parser = @import("md/parser.zig");

var heap = uefi.pool_allocator;
=======
const lexbor = @import("lexbor.zig");
const mymem = @import("mem.zig");
const screen = @import("screen.zig");
const font = @import("font.zig");
>>>>>>> 022f6503fb3ece2ab4f4b6e849fb452f00c49564

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

pub fn main() noreturn {
    term.init();
    for (logo) |line| {
        term.printf("{s}\r\n", .{line});
    }

    const boot_services = uefi.system_table.boot_services.?;
<<<<<<< HEAD
    _ = boot_services;

    main_with_error() catch |e| {
        term.printf("ERROR: {s}\r\n", .{@errorName(e)});
        @panic("ERROR");
    };
=======
    const lmao = mymem.malloc(1);
    term.printf("mem: {?}\r\n", .{lmao});
    font.init();
    var fb = screen.init(boot_services);

    fb.clear();
    fb.text(.{ 100, 100 }, font.h1, "Hello World!");
    fb.text(.{ 100, 140 }, font.h2, "Hello World!");
    fb.text(.{ 100, 160 }, font.h3, "Hello World!");
    fb.text(.{ 100, 175 }, font.p, "Hello World!");

    //_ = lexbor.init();
    //const doc = lexbor.Html.docCreate();
    //if (doc == null) {
    //    term.printf("Failed to init document", .{});
    //    arch.hang();
    //}

    //const status = lexbor.Html.docParse(doc.?, "<h1>hello world</h1>", 20);
    //if (status != 0) {
    //    term.printf("Failed to parse html", .{});
    // }
>>>>>>> 022f6503fb3ece2ab4f4b6e849fb452f00c49564

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
