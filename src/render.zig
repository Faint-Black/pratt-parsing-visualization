const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

pub const screen_width = 800;
pub const screen_height = 450;
pub const frames_per_second = 60;
pub var frame_counter: u64 = 0;

/// renders and returns a readable slice of the textbox contents
pub fn updateTextBox(buffer_ptr: [:0]u8, char_limit: comptime_int) []const u8 {
    const textbox_pos = rl.Vector2{
        .x = 10,
        .y = 10,
    };
    const textbox_rect = rl.Rectangle{
        .x = textbox_pos.x,
        .y = textbox_pos.y,
        .width = screen_width - textbox_pos.x * 2,
        .height = 50,
    };
    _ = rg.textBox(textbox_rect, buffer_ptr, char_limit, true);
    const sentinel_pos = std.mem.indexOfSentinel(u8, 0, buffer_ptr);
    return buffer_ptr[0..sentinel_pos];
}
