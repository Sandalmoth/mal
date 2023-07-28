const std = @import("std");

const _env = @import("env.zig");

pub const MalTypeType = enum {
    list,
    symbol,
    int,
    // float,
    string,
    nil,
    true,
    false,
    keyword,
    vector,
    dict,
    quote,
    quasiquote,
    unquote,
    splice_unquote,
    deref,
    with_meta,
    intrinsic, // built in functions
    closure, // user defined functions
};
pub const MalType = union(MalTypeType) {
    list: std.ArrayList(MalType),
    symbol: []u8,
    int: i64,
    // float: f64,
    string: []u8,
    nil: void,
    true: void,
    false: void,
    keyword: []u8,
    vector: std.ArrayList(MalType),
    dict: std.ArrayList(MalType), // to preserve order
    quote: void,
    quasiquote: void,
    unquote: void,
    splice_unquote: void,
    deref: void,
    with_meta: void,
    intrinsic: Intrinsic,
    // closure: std.ArrayList(MalType), // first item is the expression, following is the binds
    closure: Closure,
};

pub const Intrinsic = enum {
    plus,
    minus,
    mul,
    div,
    prn,
    list,
    islist,
    isempty,
    count,
    eql,
    lt,
    leq,
    gt,
    geq,
};

pub const Closure = struct {
    closure: std.ArrayList(MalType), // first item is expression, rest are binds
    env: *_env.Environment,
};

pub fn eql(a: MalType, b: MalType) bool {
    // const ta = @enumToInt(a);
    // const tb = @enumToInt(b);

    // if (ta != tb) {
    //     return MalType{ .false = {} };
    // }

    if (a == .list and b == .list) {
        if (a.list.items.len != b.list.items.len) {
            return false;
        }

        var acc = true;
        for (a.list.items, b.list.items) |x, y| {
            acc = acc and eql(x, y);
        }
        return acc;
    }

    return std.meta.eql(a, b);
}
