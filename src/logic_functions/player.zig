const rl = @import("raylib");

pub const Player = struct {
    position: rl.Vector2,
    Angle: f32,
    FOV: f32,
    speed: f32,
    rotation_speed: f32,
};
