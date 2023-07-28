const std = @import("std");

const _ast = @import("ast.zig");
const MalType = _ast.MalType;

const _printer = @import("printer.zig");

pub const Environment = struct {
    alloc: std.mem.Allocator,
    symbol_table: std.StringHashMap(MalType), // probably a useful abstraction for the future?
    out: std.fs.File, // awkward, but oh well we need print

    outer: ?*Environment,

    pub fn init(alloc: std.mem.Allocator, out: std.fs.File) !Environment {
        var env = Environment{
            .alloc = alloc,
            .symbol_table = std.StringHashMap(MalType).init(alloc),
            .outer = null,
            .out = out,
        };

        // we could also use set, but whatever
        return env;
    }

    pub fn set(env: *Environment, key: MalType, value: MalType) void {
        // add to symbol tabble
        // std.debug.print("{} kv {}\n", .{ key, value });
        switch (key) {
            .symbol => |symbol| {
                env.symbol_table.put(env.alloc.dupe(u8, symbol) catch unreachable, value) catch unreachable;
            },
            else => {
                @panic("only symbols can be symbols");
            },
        }
    }

    pub fn get(env: *Environment, key: MalType) !MalType {
        // get the value for a key in the environment

        switch (key) {
            .symbol => |symbol| {
                // well this doesn't work, the symbol table needs to hold maltypes
                // and then maltypes need to be able to be .intrinsic?
                if (env.find(symbol)) |e| {
                    return e.symbol_table.get(symbol).?;
                }
            },
            else => {
                return error.NotASymbol;
            },
        }

        if (key == .symbol) {
            std.debug.print("{s} ", .{key.symbol});
        }
        return error.NotFound;
    }

    pub fn find(env: *Environment, key: []const u8) ?*Environment {
        // find the environment a key is in
        // by walking out recursively

        // std.debug.print("FIND {?*}\n", .{env});
        // std.debug.print("{}\n", .{env.*});
        if (env.symbol_table.contains(key)) {
            return env;
        }

        if (env.outer) |parent| {
            // std.debug.print("PARENT {?*}\n", .{env.outer});
            return parent.find(key);
        }
        return null;
    }

    pub fn eval(env: *Environment, root: MalType, arena: std.mem.Allocator) anyerror!MalType {
        // {
        // var kvit = env.symbol_table.iterator();
        // std.debug.print("{}\n", .{root});
        // if (root == .list) {
        // for (root.list.items) |item| {
        // std.debug.print("  {}\n", .{item});
        // }
        // }
        // try _printer.print(env.out, root);
        // std.debug.print("\n", .{});
        // std.debug.print("{*} {*}\n", .{ env, env.outer });
        // std.debug.print("{{\n", .{});
        // while (kvit.next()) |kv| {
        // std.debug.print("  {s}: {},\n", .{ kv.key_ptr.*, kv.value_ptr.* });
        // }
        // std.debug.print("}}\n", .{});
        // }
        switch (root) {
            .list => |list| {
                if (list.items.len == 0) {
                    return root;
                }

                // special forms
                if (list.items[0] == .symbol and std.mem.eql(u8, list.items[0].symbol, "def!")) {
                    // const val = try env.eval_ast(list.items[2], arena); // eval or eval_ast?
                    const val = try env.eval(list.items[2], arena); // eval or eval_ast?
                    env.set(list.items[1], val);
                    return val; // NOTE is this the expected behaviour?
                }
                if (list.items[0] == .symbol and std.mem.eql(u8, list.items[0].symbol, "let*")) {
                    var new_env = Environment{
                        .alloc = env.alloc,
                        .symbol_table = std.StringHashMap(MalType).init(env.alloc),
                        .outer = env,
                        .out = env.out,
                    };
                    if (list.items[1] == .list) {
                        std.debug.assert(list.items[1].list.items.len % 2 == 0);
                        var i: usize = 0;
                        while (i < list.items[1].list.items.len) : (i += 2) {
                            new_env.set(
                                list.items[1].list.items[i],
                                try new_env.eval(list.items[1].list.items[i + 1], arena),
                            );
                        }
                        return try new_env.eval(list.items[2], arena);
                    } else if (list.items[1] == .vector) {
                        std.debug.assert(list.items[1].vector.items.len % 2 == 0);
                        var i: usize = 0;
                        while (i < list.items[1].vector.items.len) : (i += 2) {
                            new_env.set(
                                list.items[1].vector.items[i],
                                try new_env.eval(list.items[1].vector.items[i + 1], arena),
                            );
                        }
                        return try new_env.eval(list.items[2], arena);
                    } else {
                        return error.BadLet;
                    }
                }
                if (list.items[0] == .symbol and std.mem.eql(u8, list.items[0].symbol, "do")) {
                    // NOTE guide says to use eval_ast, but eval produces expected output...
                    for (list.items[1..], 2..) |item, i| {
                        if (i < list.items.len) {
                            _ = try env.eval(item, arena);
                        } else {
                            return try env.eval(item, arena);
                        }
                    }
                }
                if (list.items[0] == .symbol and std.mem.eql(u8, list.items[0].symbol, "if")) {
                    const cond = try env.eval(list.items[1], arena);
                    if (cond == .false or cond == .nil) {
                        if (list.items.len < 4) {
                            return MalType{ .nil = {} };
                        } else {
                            return try env.eval(list.items[3], arena);
                        }
                    } else {
                        return try env.eval(list.items[2], arena);
                    }
                }
                if (list.items[0] == .symbol and std.mem.eql(u8, list.items[0].symbol, "fn*")) {
                    // var closure = try env.alloc.create(MalType);
                    // var closure.* = MalType{
                    var closure = MalType{
                        .closure = _ast.Closure{
                            .closure = std.ArrayList(MalType).init(arena),
                            .env = env,
                        },
                    };
                    try closure.closure.closure.append(list.items[2]); // hell yeah closure!!!
                    if (list.items[1] == .list) {
                        for (list.items[1].list.items) |item| {
                            try closure.closure.closure.append(item);
                        }
                        // std.debug.print("MADE A CLOSURE {}\n", .{closure.closure.env});
                        return closure; //.*;
                    }
                    return error.BadFunctionDef;
                }

                // function!
                const new_list = try env.eval_ast(root, arena);
                // const new_list = list;
                // wow this turned awful fast huh
                if (new_list == MalType.list) {
                    switch (new_list.list.items[0]) {
                        .symbol => |symbol| {
                            if (env.symbol_table.get(symbol)) |val| {
                                switch (val) {
                                    .intrinsic => {},
                                    else => {
                                        return error.SymbolNotComputable;
                                    },
                                }
                                return error.wat;
                            } else {
                                return error.UnknownSymbol;
                            }
                        },
                        .intrinsic => |intrinsic| {
                            if (intrinsic == .plus) {
                                var acc: i64 = 0;
                                for (new_list.list.items[1..]) |item| {
                                    if (item == MalType.int) {
                                        acc += item.int;
                                    } else {
                                        return error.OperatorTyping;
                                    }
                                }
                                return MalType{ .int = acc };
                            } else if (intrinsic == .minus) {
                                var acc: i64 = undefined;
                                for (new_list.list.items[1..], 0..) |item, i| {
                                    if (item == MalType.int) {
                                        if (i == 0) {
                                            acc = item.int;
                                        } else {
                                            acc -= item.int;
                                        }
                                    } else {
                                        return error.OperatorTyping;
                                    }
                                }
                                return MalType{ .int = acc };
                            } else if (intrinsic == .mul) {
                                var acc: i64 = 1;
                                for (new_list.list.items[1..]) |item| {
                                    if (item == MalType.int) {
                                        acc *= item.int;
                                    } else {
                                        return error.OperatorTyping;
                                    }
                                }
                                return MalType{ .int = acc };
                            } else if (intrinsic == .div) {
                                var acc: i64 = undefined;
                                for (new_list.list.items[1..], 0..) |item, i| {
                                    if (item == MalType.int) {
                                        if (i == 0) {
                                            acc = item.int;
                                        } else {
                                            acc = @divTrunc(acc, item.int);
                                        }
                                    } else {
                                        // std.debug.print("{}\n", .{item});
                                        return error.OperatorTyping;
                                    }
                                }
                                return MalType{ .int = acc };
                            } else if (intrinsic == .prn) {
                                if (new_list.list.items.len > 1) {
                                    try _printer.print(env.out, new_list.list.items[1]);
                                }
                                try env.out.writer().print("\n", .{});
                                return MalType{ .nil = {} };
                            } else if (intrinsic == .list) {
                                var result = MalType{
                                    .list = std.ArrayList(MalType).init(env.alloc),
                                };
                                for (new_list.list.items[1..]) |item| {
                                    try result.list.append(item);
                                }
                                return result;
                            } else if (intrinsic == .islist) {
                                if (new_list.list.items[1] == .list) {
                                    return MalType{ .true = {} };
                                } else {
                                    return MalType{ .false = {} };
                                }
                            } else if (intrinsic == .isempty) {
                                if (new_list.list.items[1] == .list) {
                                    if (new_list.list.items[1].list.items.len > 0) {
                                        return MalType{ .false = {} };
                                    } else {
                                        return MalType{ .true = {} };
                                    }
                                } else {
                                    return MalType{ .nil = {} };
                                }
                            } else if (intrinsic == .count) {
                                if (new_list.list.items[1] == .list) {
                                    return MalType{ .int = @intCast(i64, new_list.list.items[1].list.items.len) };
                                } else {
                                    return MalType{ .int = 0 };
                                }
                            } else if (intrinsic == .eql) {
                                const result = _ast.eql(
                                    new_list.list.items[1],
                                    new_list.list.items[2],
                                );
                                if (result) {
                                    return MalType{ .true = {} };
                                } else {
                                    return MalType{ .false = {} };
                                }
                            } else if (intrinsic == .lt) {
                                if (new_list.list.items[1] != .int or new_list.list.items[2] != .int) {
                                    return error.BadOperatorTyping;
                                } else if (new_list.list.items[1].int < new_list.list.items[2].int) {
                                    return MalType{ .true = {} };
                                } else {
                                    return MalType{ .false = {} };
                                }
                            } else if (intrinsic == .leq) {
                                if (new_list.list.items[1] != .int or new_list.list.items[2] != .int) {
                                    return error.BadOperatorTyping;
                                } else if (new_list.list.items[1].int <= new_list.list.items[2].int) {
                                    return MalType{ .true = {} };
                                } else {
                                    return MalType{ .false = {} };
                                }
                            } else if (intrinsic == .gt) {
                                if (new_list.list.items[1] != .int or new_list.list.items[2] != .int) {
                                    return error.BadOperatorTyping;
                                } else if (new_list.list.items[1].int > new_list.list.items[2].int) {
                                    return MalType{ .true = {} };
                                } else {
                                    return MalType{ .false = {} };
                                }
                            } else if (intrinsic == .geq) {
                                if (new_list.list.items[1] != .int or new_list.list.items[2] != .int) {
                                    return error.BadOperatorTyping;
                                } else if (new_list.list.items[1].int >= new_list.list.items[2].int) {
                                    return MalType{ .true = {} };
                                } else {
                                    return MalType{ .false = {} };
                                }
                            } else {
                                return error.UnimplementedIntrinsic;
                            }
                        },
                        .closure => |closure| {
                            // std.debug.print("CLOSURE\n", .{});
                            // aww dammit there should be a compiler warning for returning locals...
                            var new_env = try env.alloc.create(Environment);
                            new_env.* = Environment{
                                .alloc = env.alloc,
                                .symbol_table = std.StringHashMap(MalType).init(env.alloc),
                                .outer = closure.env,
                                .out = env.out,
                            };
                            // std.debug.print("{*} {*} {*}\n", .{ &new_env, new_env.outer, closure.env });
                            // std.debug.print("{}\n", .{new_env});
                            // std.debug.print("{}\n", .{new_env.outer.?});
                            // for (closure.items[1..], new_list.list.items[1..]) |bind, item| {
                            // new_env.set(bind, item);
                            // }
                            // ((
                            // (fn* (a) (fn* (b) (+ a b)))
                            // 5) 7)
                            var i: usize = 1;
                            var j: usize = 1;
                            while (i < closure.closure.items.len and j < new_list.list.items.len) {
                                if (closure.closure.items[i] == .symbol and std.mem.eql(u8, closure.closure.items[i].symbol, "&")) {
                                    i += 1;
                                    // variadic argument
                                    var varlist = MalType{ .list = std.ArrayList(MalType).init(env.alloc) };
                                    for (new_list.list.items[j..]) |item| {
                                        try varlist.list.append(item);
                                        j += 1;
                                    }
                                    new_env.set(closure.closure.items[i], varlist);
                                } else {
                                    new_env.set(closure.closure.items[i], new_list.list.items[j]);
                                    i += 1;
                                    j += 1;
                                }
                            }
                            // std.debug.print("evaluating in new env\n", .{});
                            // try _printer.print(env.out, closure.closure.items[0]);
                            // std.debug.print("\n", .{});
                            return try new_env.eval(closure.closure.items[0], arena);
                        },
                        else => {
                            std.debug.print("{}\n", .{new_list.list.items[0]});
                            @panic("yeah...");
                        },
                    }
                    return root;
                } else {
                    @panic("wtf?");
                }
            },
            else => {
                return env.eval_ast(root, arena);
            },
        }
    }

    pub fn eval_ast(env: *Environment, root: MalType, arena: std.mem.Allocator) !MalType {
        // std.debug.print("EVAL_AST\n", .{});
        // try _printer.print(env.out, root);
        // std.debug.print("\n{*} {*}\n", .{ env, env.outer });
        switch (root) {
            .symbol => |symbol| {
                _ = symbol;
                // if (env.symbol_table.get(symbol)) |val| {
                const val = try env.get(root);
                return val;
                // if (val == .intrinsic) {
                // return root;
                // }
                // @panic("we cant get here right?");
                // }
                // return error.UnknownSymbol;
            },
            .list => |list| {
                var new_list = MalType{
                    .list = std.ArrayList(MalType).init(arena),
                };
                for (list.items) |item| {
                    try new_list.list.append(try env.eval(item, arena));
                }
                return new_list;
            },
            .vector => |vector| {
                var new_vector = MalType{
                    .vector = std.ArrayList(MalType).init(arena),
                };
                for (vector.items) |item| {
                    try new_vector.vector.append(try env.eval(item, arena));
                }
                return new_vector;
            },
            .dict => |dict| {
                var new_dict = MalType{
                    .dict = std.ArrayList(MalType).init(arena),
                };
                var i: u32 = 0;
                for (dict.items) |item| {
                    // for a dict, only eval values, not keys
                    if (i % 2 == 1) {
                        try new_dict.dict.append(try env.eval(item, arena));
                    } else {
                        try new_dict.dict.append(item);
                    }
                    i += 1;
                }
                return new_dict;
            },
            else => {
                return root;
            },
        }

        return root;
    }
};
