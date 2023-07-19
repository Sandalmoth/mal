const std = @import("std");

const _ast = @import("ast.zig");
const MalType = _ast.MalType;

pub fn print(out: std.fs.File, node: MalType) !void {
    switch (node) {
        .list => |list| {
            try out.writer().print("(", .{});
            for (list.items, 0..) |item, i| {
                try print(out, item);
                if (i + 1 < list.items.len) {
                    try out.writer().print(" ", .{});
                }
            }
            try out.writer().print(")", .{});
        },
        .symbol => |symbol| {
            try out.writer().print("{s}", .{symbol});
        },
        .int => |int| {
            try out.writer().print("{}", .{int});
        },
        .string => |string| {
            try out.writer().print("\"{s}\"", .{string});
        },
        .nil => {
            try out.writer().print("nil", .{});
        },
        .true => {
            try out.writer().print("true", .{});
        },
        .false => {
            try out.writer().print("false", .{});
        },
    }
}
