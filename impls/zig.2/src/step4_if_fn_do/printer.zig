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
        .quote => {
            try out.writer().print("quote", .{});
        },
        .quasiquote => {
            try out.writer().print("quasiquote", .{});
        },
        .unquote => {
            try out.writer().print("unquote", .{});
        },
        .splice_unquote => {
            try out.writer().print("splice-unquote", .{});
        },
        .deref => {
            try out.writer().print("deref", .{});
        },
        .with_meta => {
            try out.writer().print("with-meta", .{});
        },
        .keyword => |keyword| {
            try out.writer().print("{s}", .{keyword});
        },
        .vector => |vector| {
            try out.writer().print("[", .{});
            for (vector.items, 0..) |item, i| {
                try print(out, item);
                if (i + 1 < vector.items.len) {
                    try out.writer().print(" ", .{});
                }
            }
            try out.writer().print("]", .{});
        },
        .dict => |dict| {
            try out.writer().print("{{", .{});
            for (dict.items, 0..) |item, i| {
                try print(out, item);
                if (i + 1 < dict.items.len) {
                    try out.writer().print(" ", .{});
                }
            }
            try out.writer().print("}}", .{});
        },
        .intrinsic => |intrinsic| {
            switch (intrinsic) {
                .plus => {
                    try out.writer().print("+", .{});
                },
                .minus => {
                    try out.writer().print("-", .{});
                },
                .mul => {
                    try out.writer().print("*", .{});
                },
                .div => {
                    try out.writer().print("/", .{});
                },
            }
        },
        .closure => |closure| {
            _ = closure;
            try out.writer().print("#<function>", .{});
        },
    }
}
