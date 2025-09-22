const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

pub var screen_width: i32 = 800;
pub var screen_height: i32 = 450;
pub const frames_per_second = 60;
pub var frame_counter: u64 = 0;

/// buffer[0] -> previous state
/// buffer[1] -> new state
var textbox_internal_buffers: [2][512]u8 = std.mem.zeroes([2][512]u8);

/// renders and returns a readable slice of the textbox contents
/// returns null if the textbox contents have not changed
pub fn updateTextBox() ?[]const u8 {
    const raw_pointer_0: [:0]u8 = @ptrCast(&textbox_internal_buffers[0]);
    const raw_pointer_1: [:0]u8 = @ptrCast(&textbox_internal_buffers[1]);
    const textbox_pos_x = 10;
    const textbox_pos_y = 10;
    const textbox_rect = rl.Rectangle{
        .x = textbox_pos_x,
        .y = textbox_pos_y,
        .width = @floatFromInt(screen_width - textbox_pos_x * 2),
        .height = 50,
    };
    @memcpy(textbox_internal_buffers[0][0..], textbox_internal_buffers[1][0..]);
    _ = rg.textBox(textbox_rect, raw_pointer_1, textbox_internal_buffers[0].len - 1, true);
    const sentinel_pos_0 = std.mem.indexOfSentinel(u8, 0, raw_pointer_0);
    const sentinel_pos_1 = std.mem.indexOfSentinel(u8, 0, raw_pointer_1);
    if (std.mem.eql(
        u8,
        textbox_internal_buffers[0][0..sentinel_pos_0],
        textbox_internal_buffers[1][0..sentinel_pos_1],
    )) {
        return null;
    } else {
        return textbox_internal_buffers[1][0..sentinel_pos_1];
    }
}
