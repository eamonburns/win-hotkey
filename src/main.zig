const std = @import("std");
const Io = std.Io;

comptime {
    // This program is dedicated to Windows, and uses OS APIs
    std.debug.assert(@import("builtin").os.tag == .windows);
}

const log = std.log.scoped(.winkbm);

const cfg: Configuration = .{
    .hotkeys = &.{
        .{
            // Open Windows Terminal on Ctrl+Alt+T
            .command = &.{"wt.exe"},
            .binding = .{
                .mods = .{ .ctrl = true, .shift = true },
                .key = .@"1",
            },
        },
    },
};

pub fn main(init: std.process.Init) void {
    const io = init.io;

    log.debug("Hotkey listener started.", .{});

    // TODO: Read ZON file
    const config: Configuration = cfg;

    const num_registered = for (config.hotkeys, 0..) |hk, i| {
        if (win.RegisterHotKey(
            null,
            @intCast(i),
            @backingInt(hk.binding.mods),
            @backingInt(hk.binding.key),
        ) == .FALSE) {
            log.err("Failed to register hotkey {d} ({f}).", .{ i, hk.binding });
            break i;
        }
        log.info("Registered hotkey {d} ({f}).", .{ i, hk.binding });
    } else config.hotkeys.len;
    defer for (0..num_registered) |i| {
        log.debug("Unregistering hotkey {d}", .{i});
        _ = win.UnregisterHotKey(null, @intCast(i));
    };

    if (num_registered != config.hotkeys.len) {
        // FIXME: How can I exit with a non-zero exit code while also allowing the `defer`s to run?
        log.err("Only {d}/{d} hotkeys were registered", .{ num_registered, config.hotkeys.len });
        return;
    }

    // TODO: Don't use this
    const quit_binding: Hotkey.Binding = .{
        .mods = .{ .windows = true, .ctrl = true, .alt = true, .shift = true },
        .key = .Q,
    };
    const quit_binding_id = config.hotkeys.len;
    if (win.RegisterHotKey(
        null,
        @intCast(quit_binding_id),
        @backingInt(quit_binding.mods),
        @backingInt(quit_binding.key),
    ) == .FALSE) {}
    log.info("Registered quit hotkey: {f}", .{quit_binding});

    log.debug("Hotkeys registered successfully.", .{});

    var msg: win.MSG = undefined;
    while (true) {
        const result = win.GetMessageW(&msg, null, 0, 0);
        if (result == .FALSE) return;
        if (@backingInt(result) == -1) {
            log.err("Error getting message: {t}", .{win.GetLastError()});
            return;
        }

        if (msg.message == win.WM_HOTKEY) {
            if (msg.wParam == quit_binding_id) {
                log.info("pressed quit hotkey: {f} (exiting)", .{quit_binding});
                return;
            }

            const hotkey_index = msg.wParam;
            if (hotkey_index >= config.hotkeys.len) {
                log.warn("ignoring invalid hotkey ID {d} (there are only {d} hotkeys)", .{ hotkey_index, config.hotkeys.len });
                continue;
            }

            const hotkey = config.hotkeys[hotkey_index];
            log.info("pressed hotkey: {f}", .{hotkey.binding});

            if (hotkey.command.len == 0) {
                log.warn("no command", .{});
                continue;
            }

            const command = hotkey.command;

            log.info("spawning command: {f}", .{std.fmt.Alt([]const []const u8, fmtCommand){ .data = command }});

            const child = std.process.spawn(io, .{
                .argv = command,
            }) catch |err| switch (err) {
                error.Canceled => return,
                else => {
                    log.err("unable to spawn command process: {t}", .{err});
                    continue;
                },
            };
            if (child.id) |process_handle| {
                log.info("spawned command process: {d}", .{win.GetProcessId(process_handle)});
            } else {
                log.info("spawned command process but it has already exited", .{});
            }
        }
    }
    comptime unreachable;
}

fn fmtCommand(command: []const []const u8, writer: *Io.Writer) Io.Writer.Error!void {
    for (command, 0..) |arg, i| {
        if (i != 0) try writer.writeByte(' ');
        // TODO: Escape?
        try writer.writeAll(arg);
    }
}

const Configuration = struct {
    hotkeys: []const Hotkey,
};

const Hotkey = struct {
    binding: Binding,
    command: []const []const u8,

    pub const Binding = struct {
        key: Key,
        mods: Mods,

        pub fn format(
            self: Binding,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            // I'm making up the order...
            var have_printed = false;
            if (self.mods.windows) {
                have_printed = true;
                try writer.writeAll("Win");
            }
            if (self.mods.ctrl) {
                if (have_printed) try writer.writeByte('+');
                have_printed = true;
                try writer.writeAll("Ctrl");
            }
            if (self.mods.alt) {
                if (have_printed) try writer.writeByte('+');
                have_printed = true;
                try writer.writeAll("Alt");
            }
            if (self.mods.shift) {
                if (have_printed) try writer.writeByte('+');
                have_printed = true;
                try writer.writeAll("Shift");
            }
            if (have_printed) try writer.writeByte('+');
            try writer.print("{t}", .{self.key});
        }
    };

    pub const Key = enum(win.UINT) {
        // Numbers

        ///0 key
        @"0" = 0x30,
        ///1 key
        @"1" = 0x31,
        ///2 key
        @"2" = 0x32,
        ///3 key
        @"3" = 0x33,
        ///4 key
        @"4" = 0x34,
        ///5 key
        @"5" = 0x35,
        ///6 key
        @"6" = 0x36,
        ///7 key
        @"7" = 0x37,
        ///8 key
        @"8" = 0x38,
        ///9 key
        @"9" = 0x39,

        // Letters

        ///A key
        A = 0x41,
        ///B key
        B = 0x42,
        ///C key
        C = 0x43,
        ///D key
        D = 0x44,
        ///E key
        E = 0x45,
        ///F key
        F = 0x46,
        ///G key
        G = 0x47,
        ///H key
        H = 0x48,
        ///I key
        I = 0x49,
        ///J key
        J = 0x4A,
        ///K key
        K = 0x4B,
        ///L key
        L = 0x4C,
        ///M key
        M = 0x4D,
        ///N key
        N = 0x4E,
        ///O key
        O = 0x4F,
        ///P key
        P = 0x50,
        ///Q key
        Q = 0x51,
        ///R key
        R = 0x52,
        ///S key
        S = 0x53,
        ///T key
        T = 0x54,
        ///U key
        U = 0x55,
        ///V key
        V = 0x56,
        ///W key
        W = 0x57,
        ///X key
        X = 0x58,
        ///Y key
        Y = 0x59,
        ///Z key
        Z = 0x5A,

        // NOTE: I think that is good for now. We can add more later.
    };

    pub const Mods = packed struct(win.UINT) {
        alt: bool = false,
        ctrl: bool = false,
        shift: bool = false,
        windows: bool = false,
        _padding: u28 = 0,
    };
};

// Windows bindings

const win = struct {
    pub const DWORD = _w.DWORD;
    pub const UINT = _w.UINT;
    pub const BOOL = _w.BOOL;
    pub const HANDLE = _w.HANDLE;
    pub const HWND = _w.HWND;

    pub const MOD_ALT: UINT = 0x0001;
    pub const MOD_CONTROL: UINT = 0x0002;

    pub const VK_F9: UINT = 0x78;
    pub const VK_F10: UINT = 0x79;

    pub const WM_HOTKEY: UINT = 0x0312;

    pub const GENERIC_WRITE: DWORD = 0x40000000;
    pub const FILE_SHARE_READ: DWORD = 0x00000001;
    pub const OPEN_ALWAYS: DWORD = 4;
    pub const FILE_ATTRIBUTE_NORMAL: DWORD = 0x00000080;
    pub const FILE_APPEND_DATA: DWORD = 0x00000004;

    pub const MSG = extern struct {
        hwnd: HWND,
        message: UINT,
        wParam: usize,
        lParam: isize,
        time: DWORD,
        pt: extern struct {
            x: i32,
            y: i32,
        },
        lPrivate: DWORD,
    };

    pub extern "user32" fn RegisterHotKey(
        hwnd: ?HWND,
        id: i32,
        modifiers: UINT,
        vk: UINT,
    ) callconv(.winapi) BOOL;

    pub extern "user32" fn UnregisterHotKey(
        hwnd: ?HWND,
        id: i32,
    ) callconv(.winapi) BOOL;

    pub extern "user32" fn GetMessageW(
        msg: *MSG,
        hwnd: ?HWND,
        min: UINT,
        max: UINT,
    ) callconv(.winapi) BOOL;

    pub extern "user32" fn GetProcessId(
        process: HANDLE,
    ) callconv(.winapi) DWORD;

    pub const GetLastError = _w.GetLastError;

    const _w = std.os.windows;
};
