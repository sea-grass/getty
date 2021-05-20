const std = @import("std");

pub fn serialize(serializer: anytype, v: anytype) @typeInfo(@TypeOf(serializer)).Pointer.child.Error!@typeInfo(@TypeOf(serializer)).Pointer.child.Ok {
    const s = serializer.serializer();

    return switch (@typeInfo(@TypeOf(v))) {
        .Array => try s.serialize_bytes(v),
        .Bool => try s.serialize_bool(v),
        .Float => try s.serialize_float(v),
        .ComptimeInt => {
            if (v >= 0 and v <= std.math.maxInt(u21) and std.unicode.utf8ValidCodepoint(v)) {
                try s.serialize_char(v);
            } else {
                try s.serialize_int(v);
            }
        },
        .Int => try s.serialize_int(v),
        .Pointer => try s.serialize_str(v),
        else => @compileError("unsupported serialize value " ++ @typeName(@TypeOf(v))),
    };
}

/// A data format that can serialize any data structure supported by Getty.
///
/// The interface defines the serialization half of the [Getty data model],
/// which is a way to categorize every Zig data structure into one of TODO
/// possible types. Each method of the `Serializer` interface corresponds to
/// one of the types of the data model.
///
/// Implementations of `Serialize` map themselves into this data model by
/// invoking exactly one of the `Serializer` methods.
///
/// The types that make up the Getty data model are:
///
///  - Primitives
///    - bool
///    - iN (where N is any supported signed integer bit-width)
///    - uN (where N is any supported unsigned integer bit-width)
///    - fN (where N is any supported floating-point bit-width)
pub fn Serializer(
    comptime Context: type,
    comptime O: type,
    comptime E: type,
    comptime boolFn: fn (context: Context, value: bool) E!O,
    comptime charFn: fn (context: Context, value: comptime_int) E!O,
    comptime intFn: fn (context: Context, value: anytype) E!O,
    comptime floatFn: fn (context: Context, value: anytype) E!O,
    comptime strFn: fn (context: Context, value: anytype) E!O,
    comptime bytesFn: fn (context: Context, value: anytype) E!O,
    comptime seqFn: fn (context: Context, length: usize) E!O,
    comptime elementFn: fn (context: Context, value: anytype) E!O,
) type {
    return struct {
        const Self = @This();

        pub const Ok = O;
        pub const Error = E;

        context: Context,

        /// Serialize a boolean value.
        pub fn serialize_bool(self: Self, value: bool) Error!Ok {
            try boolFn(self.context, value);
        }

        /// Serialize a Unicode code point.
        pub fn serialize_char(self: Self, comptime value: comptime_int) Error!Ok {
            return try charFn(self.context, value);
        }

        /// Serialize an integer value.
        pub fn serialize_int(self: Self, value: anytype) Error!Ok {
            return try intFn(self.context, value);
        }

        /// Serialize a float value.
        pub fn serialize_float(self: Self, value: anytype) Error!Ok {
            try floatFn(self.context, value);
        }

        /// Serialize a Zig string.
        pub fn serialize_str(self: Self, value: anytype) Error!Ok {
            if (!comptime std.meta.trait.isZigString(@TypeOf(value))) {
                @compileError("expected string, found " ++ @typeName(@TypeOf(value)));
            }

            try strFn(self.context, value);
        }

        /// Serialize a chunk of raw byte data.
        ///
        /// Enables serializers to serialize byte slices more compactly or more
        /// efficiently than other types of slices. If no efficient implementation
        /// is available, a reasonable implementation would be to forward to
        /// `serialize_seq`.
        pub fn serialize_bytes(self: Self, value: anytype) Error!Ok {
            if (std.meta.Child(@TypeOf(value)) != u8) {
                @compileError("expected byte array, found " ++ @typeName(@TypeOf(value)));
            }

            try bytesFn(self.context, value);
        }

        /// Begin to serialize a variably sized sequence. This call must be
        /// followed by zero or more calls to `serialize_element`, then a call to
        /// `end`.
        ///
        /// The argument is the number of elements in the sequence, which may or may
        /// not be computable before the sequence is iterated. Some serializers only
        /// support sequences whose length is known up front.
        pub fn serialize_seq(self: Self, length: usize) Error!Ok {
            try seqFn(self.context, length);
        }

        pub fn serialize_element(self: Self, value: anytype) Error!Ok {
            try elementFn(self.context, value);
        }
    };
}

const json = @import("json.zig");

const eql = std.mem.eql;
const expect = std.testing.expect;
const testing_allocator = std.testing.allocator;

test "Serialize - bool" {
    var t = try json.toArrayList(testing_allocator, true);
    defer t.deinit();
    var f = try json.toArrayList(testing_allocator, false);
    defer f.deinit();

    try expect(eql(u8, t.items, "true"));
    try expect(eql(u8, f.items, "false"));
}

test "Serialize - integer" {
    const types = [_]type{
        i8, i16, i32, i64,
        u8, u16, u32, u64,
    };

    inline for (types) |T| {
        const max = std.math.maxInt(T);
        const min = std.math.minInt(T);

        var max_buf: [20]u8 = undefined;
        var min_buf: [20]u8 = undefined;
        const max_expected = std.fmt.bufPrint(&max_buf, "{}", .{max}) catch unreachable;
        const min_expected = std.fmt.bufPrint(&min_buf, "{}", .{min}) catch unreachable;

        const max_encoded = try json.toArrayList(testing_allocator, @as(T, max));
        defer max_encoded.deinit();
        const min_encoded = try json.toArrayList(testing_allocator, @as(T, min));
        defer min_encoded.deinit();

        try expect(eql(u8, max_encoded.items, max_expected));
        try expect(eql(u8, min_encoded.items, min_expected));
    }
}
