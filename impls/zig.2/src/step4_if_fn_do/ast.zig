const std = @import("std");

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
    closure: std.ArrayList(MalType), // first item is the expression, following is the binds
};

pub const Intrinsic = enum {
    plus,
    minus,
    mul,
    div,
};
