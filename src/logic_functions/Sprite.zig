const rl = @import("raylib");
const std = @import("std");

pub const Sprite = struct {
    texture: rl.Image,
    position: rl.Vector2,
    size: usize,

    pub fn init(texture_path: [:0]const u8, position: rl.Vector2, size: usize) !Sprite {
        var texture = try rl.loadImage(texture_path);
        rl.imageFormat(&texture, .uncompressed_r8g8b8a8);
        return .{ .size = size, .position = position, .texture = texture };
    }

    pub fn deinit(self: Sprite) void {
        rl.unloadImage(self.texture);
    }
};
