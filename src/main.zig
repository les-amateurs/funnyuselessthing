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

    const boot_services = uefi.system_table.boot_services.?;

    for (logo) |line| {
        term.printf("{s}\r\n", .{line});
    }

    var http_service_binding: *HttpServiceBinding = undefined;
    if (Status.Success != boot_services.locateProtocol(&HttpServiceBinding.guid, null, @ptrCast(&http_service_binding))) {
        @panic("failed to find http service binding");
    }
    term.printf("[+] found http service binding\r\n", .{});

    var http: ?*Http = null;
    var handle: ?uefi.Handle = null;
    if (Status.Success != http_service_binding.createChild(&handle)) {
        @panic("failed to create http service");
    }
    term.printf("[+] created http service\r\n", .{});

    if (Status.Success != boot_services.handleProtocol(handle.?, &Http.guid, @ptrCast(&http))) {
        @panic("failed to bind http service");
    }
    term.printf("[+] http service bound\r\n", .{});

    var access_point = Http.Ipv4AccessPoint{
        .use_default_address = true,
        .local_address = [_]u8{ 0, 0, 0, 0 },
        .local_subnet = [_]u8{ 0, 0, 0, 0 },
        .local_port = 0,
    };
    var config = Http.Config{
        .version = Http.Version.Http11,
        .timeout_millis = 0,
        .is_ipv6 = false,
        .access_point = .{ .ipv4 = &access_point },
    };
    if (Status.Success != http.?.configure(&config)) {
        @panic("failed to configure http");
    }
    term.printf("[+] http configured\r\n", .{});
    term.printf("[+] provided config: \r\n{any}\r\n", .{config});
    config.timeout_millis = 1337;
    config.is_ipv6 = true;
    if (Status.Success != http.?.getModeData(&config)) {
        @panic("failed to get mode data");
    }
    term.printf("[+] confirm config: \r\n{any}\r\n", .{config});

    var req = Http.Request{
        .method = Http.Method.Get,
        .url = L("http://example.com"),
    };
    var header = Http.Header{
        .name = "Host",
        .value = "example.com",
    };
    var message = Http.Message{
        .data = .{ .req = &req },
        .header_count = 1,
        .headers = &header,
        .body_length = 0,
        .body = null,
    };
    var token = Http.Token{
        .event = undefined,
        .status = Status.Success,
        .message = &message,
    };
    if (Status.Success != boot_services.createEvent(uefi.tables.BootServices.event_notify_signal, uefi.tables.BootServices.tpl_callback, &callback, null, &token.event)) {
        @panic("failed to create http callback event");
    }

    var status: Status = undefined;
    while (true) {
        status = http.?.request(&token);
        switch (status) {
            Status.Success => break,
            Status.NoMapping => term.printf("[-] no mapping\r\n", .{}),
            else => {
                term.printf("[!] status: {any}\r\n", .{status});
                @panic("failed to send http request");
            },
        }
    }

    term.printf("poll: {any}\r\n", .{http.?.poll()});

    term.printf("[+] all done\r\n", .{});
    arch.hang();
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
