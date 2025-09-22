const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

pub var screen_width: i32 = 800;
pub var screen_height: i32 = 450;
pub const frames_per_second = 60;
pub var frame_counter: u64 = 0;

var textbox_internal_buffer: [512]u8 = std.mem.zeroes([512]u8);

/// renders and returns a readable slice of the textbox contents
pub fn updateTextBox() []const u8 {
    const raw_pointer: [:0]u8 = @ptrCast(&textbox_internal_buffer);
    const textbox_pos_x = 10;
    const textbox_pos_y = 10;
    const textbox_rect = rl.Rectangle{
        .x = textbox_pos_x,
        .y = textbox_pos_y,
        .width = @floatFromInt(screen_width - textbox_pos_x * 2),
        .height = 50,
    };
    _ = rg.textBox(textbox_rect, raw_pointer, textbox_internal_buffer.len - 1, true);
    const sentinel_pos = std.mem.indexOfSentinel(u8, 0, raw_pointer);
    return textbox_internal_buffer[0..sentinel_pos];
}
