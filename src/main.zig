const std = @import("std");
const Io = std.Io;

const log = std.log.scoped(.winkbm);

const cfg: Configuration = .{
    .hotkeys = &.{
        .{
            .command = &.{},
            .binding = .{
                .mods = .{ .ctrl = true, .alt = true },
                .key = .f9,
            },
        },
        .{
            .command = &.{},
            .binding = .{
                .mods = .{ .ctrl = true, .alt = true },
                .key = .f10,
            },
        },
    },
};

pub fn main(init: std.process.Init) void {
    _ = init;

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
        .key = .q,
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

            // TODO: Execute hotkey.command
            const hotkey = config.hotkeys[hotkey_index];
            log.info("pressed hotkey: {f}", .{hotkey.binding});
        }
    }
    comptime unreachable;
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
        q = 0x51,
        f9 = 0x78,
        f10 = 0x79,
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

    pub const GetLastError = _w.GetLastError;

    const _w = std.os.windows;
};
