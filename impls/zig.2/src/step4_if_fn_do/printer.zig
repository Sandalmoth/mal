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
                // .plus => {
                //     try out.writer().print("+", .{});
                // },
                // .minus => {
                //     try out.writer().print("-", .{});
                // },
                // .mul => {
                //     try out.writer().print("*", .{});
                // },
                // .div => {
                //     try out.writer().print("/", .{});
                // },
                else => {
                    try out.writer().print("#<intrinsic>", .{});
                },
            }
        },
        .closure => |closure| {
            _ = closure;
            try out.writer().print("#<function>", .{});
        },
    }
}

pub fn pr_str(alloc: std.mem.Allocator, node: MalType, readably: bool) []u8 {
    // we're just gonna catch unreachable all the errors for simplicity
    // and assume that alloc never fails
    switch (node) {
        .list => |list| {
            var s: []u8 = "";
            for (list.items, 0..) |item, i| {
                if (i > 0) {
                    const ss: [2][]u8 = .{ s, pr_str(alloc, item, readably) };
                    s = std.mem.join(alloc, " ", &ss) catch unreachable;
                } else {
                    s = pr_str(alloc, item, readably);
                }
            }
            return std.fmt.allocPrint(alloc, "({s})", .{s}) catch unreachable;
        },
        .symbol => |symbol| {
            return std.fmt.allocPrint(alloc, "{s}", .{symbol}) catch unreachable;
        },
        .int => |int| {
            return std.fmt.allocPrint(alloc, "{}", .{int}) catch unreachable;
        },
        .string => |string| {
            if (readably) {
                var buf = alloc.alloc(
                    u8,
                    std.mem.replacementSize(u8, string, "\\", "\\"),
                ) catch unreachable;
                _ = std.mem.replace(u8, string, "\\", "\\", buf);
                var buf2 = alloc.alloc(
                    u8,
                    std.mem.replacementSize(u8, buf, "\"", "\\\""),
                ) catch unreachable;
                _ = std.mem.replace(u8, buf, "\"", "\\\"", buf2);
                return std.fmt.allocPrint(alloc, "\"{s}\"", .{buf2}) catch unreachable;
            } else {
                return std.fmt.allocPrint(alloc, "\"{s}\"", .{string}) catch unreachable;
            }
        },
        .nil => {
            return std.fmt.allocPrint(alloc, "nil", .{}) catch unreachable;
        },
        .true => {
            return std.fmt.allocPrint(alloc, "true", .{}) catch unreachable;
        },
        .false => {
            return std.fmt.allocPrint(alloc, "false", .{}) catch unreachable;
        },
        .quote => {
            return std.fmt.allocPrint(alloc, "quote", .{}) catch unreachable;
        },
        .quasiquote => {
            return std.fmt.allocPrint(alloc, "quasiquote", .{}) catch unreachable;
        },
        .unquote => {
            return std.fmt.allocPrint(alloc, "unquote", .{}) catch unreachable;
        },
        .splice_unquote => {
            return std.fmt.allocPrint(alloc, "splice-unquote", .{}) catch unreachable;
        },
        .deref => {
            return std.fmt.allocPrint(alloc, "deref", .{}) catch unreachable;
        },
        .with_meta => {
            return std.fmt.allocPrint(alloc, "with-meta", .{}) catch unreachable;
        },
        .keyword => |keyword| {
            return std.fmt.allocPrint(alloc, "{s}", .{keyword}) catch unreachable;
        },
        .vector => |vector| {
            var s: []u8 = "";
            for (vector.items, 0..) |item, i| {
                if (i > 0) {
                    const ss: [2][]u8 = .{ s, pr_str(alloc, item, readably) };
                    s = std.mem.join(alloc, " ", &ss) catch unreachable;
                } else {
                    s = pr_str(alloc, item, readably);
                }
            }
            return std.fmt.allocPrint(alloc, "[{s}]", .{s}) catch unreachable;
        },
        .dict => |dict| {
            var s: []u8 = "";
            for (dict.items, 0..) |item, i| {
                if (i > 0) {
                    const ss: [2][]u8 = .{ s, pr_str(alloc, item, readably) };
                    s = std.mem.join(alloc, " ", &ss) catch unreachable;
                } else {
                    s = pr_str(alloc, item, readably);
                }
            }
            return std.fmt.allocPrint(alloc, "{{{s}}}", .{s}) catch unreachable;
        },
        .intrinsic => |intrinsic| {
            switch (intrinsic) {
                else => {
                    return std.fmt.allocPrint(alloc, "#<intrinsic>", .{}) catch unreachable;
                },
            }
        },
        .closure => |closure| {
            _ = closure;
            return std.fmt.allocPrint(alloc, "#<function>", .{}) catch unreachable;
        },
    }
}
