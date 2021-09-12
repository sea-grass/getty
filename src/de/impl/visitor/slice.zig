const std = @import("std");
const interface = @import("../../interface.zig");

pub fn Visitor(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Implements `getty.de.Visitor`.
        pub usingnamespace interface.Visitor(
            *Self,
            Value,
            visitBool,
            visitEnum,
            visitFloat,
            visitInt,
            visitMap,
            visitNull,
            visitSequence,
            visitSlice,
            visitSome,
            visitVoid,
        );

        const Value = T;

        fn visitBool(self: *Self, comptime Error: type, input: bool) Error!Value {
            _ = self;
            _ = input;

            @panic("Unsupported");
        }

        fn visitEnum(self: *Self, comptime Error: type, input: anytype) Error!Value {
            _ = self;
            _ = input;

            @panic("Unsupported");
        }

        fn visitFloat(self: *Self, comptime Error: type, input: anytype) Error!Value {
            _ = self;
            _ = input;

            @panic("Unsupported");
        }

        fn visitInt(self: *Self, comptime Error: type, input: anytype) Error!Value {
            _ = self;
            _ = input;

            @panic("Unsupported");
        }

        fn visitMap(self: *Self, allocator: ?*std.mem.Allocator, mapAccess: anytype) @TypeOf(mapAccess).Error!Value {
            _ = self;
            _ = allocator;

            @panic("Unsupported");
        }

        fn visitNull(self: *Self, comptime Error: type) Error!Value {
            _ = self;

            @panic("Unsupported");
        }

        fn visitSequence(self: *Self, allocator: ?*std.mem.Allocator, seqAccess: anytype) @TypeOf(seqAccess).Error!Value {
            _ = self;

            var list = std.ArrayList(std.meta.Child(Value)).init(allocator.?);
            errdefer list.deinit();

            while (try seqAccess.nextElement(std.meta.Child(Value))) |elem| {
                // TODO: change unreachable
                list.append(elem) catch unreachable;
            }

            return list.toOwnedSlice();
        }

        fn visitSlice(self: *Self, allocator: *std.mem.Allocator, comptime Error: type, input: anytype) Error!Value {
            _ = self;

            return allocator.dupe(std.meta.Child(Value), input) catch unreachable;
        }

        fn visitSome(self: *Self, allocator: ?*std.mem.Allocator, deserializer: anytype) @TypeOf(deserializer).Error!Value {
            _ = self;
            _ = allocator;

            @panic("Unsupported");
        }

        fn visitVoid(self: *Self, comptime Error: type) Error!Value {
            _ = self;

            @panic("Unsupported");
        }
    };
}
