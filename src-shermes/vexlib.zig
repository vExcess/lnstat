// vexlib - v0.0.23
//
// ABOUT
//   vexlib is a "standard" library for writing Web Assembly compatible
//   programs in Zig. Unlike Zig's official standard library, vexlib
//   has no issues compiling to freestanding Web Assembly. In addition
//   because most people writing freestanding wasm code will be web
//   developers I have architected the library to be similiar to 
//   JavaScript's built in APIs
// 
// DESIGN NOTES
//   - Because wasm is 32 bit rather than 64 bit like most native code
//     these days, vexlib tends to use u32 instead of usize in order to
//     ensure that the library will function the same in wasm as when
//     running natively
//   - Zig dislikes memory allocations that aren't explicitly done by the
//     programmer using allocators, however my assumption is that most web
//     devs want to worry as little about memory management as possible.
//     Therefore I have made the entire library share a single allocator
//     and objects are managed using a simple .alloc + .dealloc pattern like so:
//     var myString = String.allocFrom("Hello World");
//     defer myString.dealloc();
//   - Because wasm doesn't work with top level functions that return 
//     errors as values vexlib avoids functions returning errors
// 
// When compiling to wasm freestanding instead of native simply set the
// wasmFreestanding boolean below to true
// 

pub const wasmFreestanding: bool = false;

const std = @import("std");
const Prng = std.Random.DefaultPrng;
const http = std.http;

pub var GPA: std.heap.GeneralPurposeAllocator(.{}) = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var prng: std.Random.DefaultPrng = undefined;

pub fn init(gpa_: std.heap.GeneralPurposeAllocator(.{})) void {
    GPA = gpa_;
    allocator = GPA.allocator();
    prng = std.Random.DefaultPrng.init(@intFromPtr(&allocator));
}

var gaussianf32Y2: f32 = 0;
var gaussianf64Y2: f64 = 0;
var gaussianf32Previous = false;
var gaussianf64Previous = false;

inline fn genCastFn(comptime T: type, trunc: bool) fn(anytype) T {
    return struct {
        fn func(num: anytype) T {
            switch (@typeInfo(@TypeOf(num))) {
                .ComptimeInt, .Int => {
                    // input is integer
                    switch (@typeInfo(T)) {
                        .Int => {
                            // output is integer
                            if (trunc) {
                                return @truncate(num);
                            } else {
                                return @intCast(num);
                            }
                        },
                        .Float => {
                            // output is float
                            return @floatFromInt(num);
                        },
                        else => @compileError("Cast only accepts numbers")
                    }
                },
                .ComptimeFloat, .Float => {
                    // input is float
                    switch (@typeInfo(T)) {
                        .Int => {
                            // output is integer
                            if (trunc) {
                                return @truncate(num);
                            } else {
                                return @intFromFloat(num);
                            }
                        },
                        .Float => {
                            // output is float
                            return @floatCast(num);
                        },
                        else => @compileError("Cast only accepts numbers")
                    }
                },
                else => @compileError("Cast only accepts numbers")
            }
        }
    }.func;
}

pub const As = struct {
    pub const @"f16"  = genCastFn(f16, false);
    pub const @"f32"  = genCastFn(f32, false);
    pub const @"f64"  = genCastFn(f64, false);
    pub const @"f80"  = genCastFn(f80, false);
    pub const @"f128" = genCastFn(f128, false);

    pub const @"u8"  = genCastFn(u8, false);
    pub const @"u16" = genCastFn(u16, false);
    pub const @"u32" = genCastFn(u32, false);
    pub const @"u64" = genCastFn(u64, false);

    pub const @"i8"  = genCastFn(i8, false);
    pub const @"i16" = genCastFn(i16, false);
    pub const @"i32" = genCastFn(i32, false);
    pub const @"i64" = genCastFn(i64, false);

    pub const @"u8T"  = genCastFn(u8, true);
    pub const @"u16T" = genCastFn(u16, true);
    pub const @"u32T" = genCastFn(u32, true);
    pub const @"u64T" = genCastFn(u64, true);

    pub const @"i8T"  = genCastFn(i8, true);
    pub const @"i16T" = genCastFn(i16, true);
    pub const @"i32T" = genCastFn(i32, true);
    pub const @"i64T" = genCastFn(i64, true);
};

pub const Math = struct {
    pub const PI: f64 = 3.141592653589793;
    pub const E = 2.71828182845904523536028747135266249775724709369995;

    pub fn abs(x: anytype) @TypeOf(x) {
        switch (@typeInfo(@TypeOf(x))) {
            .ComptimeInt, .Int => {
                return if (x < 0) -x else x;
            },
            .ComptimeFloat, .Float => {
                return if (x < 0.0) -x else x;
            },
            else => @panic("Math.abs only accepts integers and floats")
        }
    }

    pub fn pow(x: anytype, y: anytype) @TypeOf(x, y) {
        return std.math.pow(@TypeOf(x, y), x, y);
    }

    pub fn loge(n: anytype) @TypeOf(n) {
        return std.math.log(@TypeOf(n), Math.E, n);
    }

    pub fn log(base: anytype, n: anytype) @TypeOf(n) {
        return std.math.log(@TypeOf(n), base, n);
    }

    pub fn sqrt(x: anytype) @TypeOf(x) {
        return std.math.sqrt(x);
    }

    pub inline fn round(x: anytype) @TypeOf(x) {
        return @round(x);
    }

    pub inline fn floor(x: anytype) @TypeOf(x) {
        return @floor(x);
    }

    pub inline fn ceil(x: anytype) @TypeOf(x) {
        return @ceil(x);
    }

    pub inline fn cos(x: anytype) @TypeOf(x) {
        return @cos(x);
    }

    pub inline fn sin(x: anytype) @TypeOf(x) {
        return @sin(x);
    }

    pub fn atan2(y: anytype, x: anytype) @TypeOf(y) {
        return std.math.atan2(y, x);
    }

    pub fn factorial(x: anytype) @TypeOf(x) {
        var val = x;
        var i = 2;
        while (i < x) : (i += 1) {
            val *= i;
        }
        return val;
    }

    pub fn min(x: anytype, y: @TypeOf(x)) @TypeOf(x) {
        if (x < y) {
            return x;
        } else {
            return y;
        }
    }

    pub fn constrain(val: anytype, min_: @TypeOf(val), max_: @TypeOf(val)) @TypeOf(val) {
        if (val > max_) {
            return max_;
        } else if (val < min_) {
            return min_;
        } else {
            return val;
        }
    }

    pub fn max(x: anytype, y: anytype) @TypeOf(x, y) {
        if (x > y) {
            return x;
        } else {
            return y;
        }
    }

    pub fn map(value: anytype, istart: @TypeOf(value), istop: @TypeOf(value), ostart: @TypeOf(value), ostop: @TypeOf(value)) @TypeOf(value) {
        return ostart + (ostop - ostart) * ((value - istart) / (istop - istart));
    }

    pub fn lerp(val1: anytype, val2: anytype, amt: anytype) @TypeOf(val1, val2) {
        const valType = @TypeOf(val1, val2);
        switch (@typeInfo(@TypeOf(val1, val2))) {
            .Vector => |vecData| {
                const castedAmt = @as(vecData.child, @floatCast(amt));
                return ((val2 - val2) * @as(valType, @splat(castedAmt))) + val1;
            },
            else => {
                return ((val2 - val2) * @as(valType, @floatCast(amt))) + val1;
            }
        }
    }

    pub fn Infinity(val: type) val {
        const inf_u16: u16 = 0x7C00;
        const inf_u32: u32 = 0x7F800000;
        const inf_u64: u64 = 0x7FF0000000000000;
        const inf_u80: u80 = 0x7FFF8000000000000000;
        const inf_u128: u128 = 0x7FFF0000000000000000000000000000;

        return switch (val) {
            f16 => @as(f16, @bitCast(inf_u16)),
            f32 => @as(f32, @bitCast(inf_u32)),
            f64 => @as(f64, @bitCast(inf_u64)),
            f80 => @as(f80, @bitCast(inf_u80)),
            f128 => @as(f128, @bitCast(inf_u128)),
            else => @panic("Math.Infinity only exists for f16, f32, f64, f80, f128")
        };
    }

    pub fn randomInt(T: type) T {
        return prng.random().int(T);
    }

    pub fn random(T: type, min_: T, max_: T) T {
        const num = prng.random().float(T);
        return num * (max_ - min_) + min_;
    }

    pub fn randomGaussian(T: type) T {
        var y1: T = undefined;
        var x1: T = undefined;
        var x2: T = undefined;
        var w: T = undefined;

        switch (T) {
            f32 => {
                if (gaussianf32Previous) {
                    y1 = gaussianf32Y2;
                    gaussianf32Previous = false;
                } else {
                    x1 = Math.random(T, -1, 1);
                    x2 = Math.random(T, -1, 1);
                    w = x1 * x1 + x2 * x2;
                    while (w >= 1) {
                        x1 = Math.random(T, -1, 1);
                        x2 = Math.random(T, -1, 1);
                        w = x1 * x1 + x2 * x2;
                    }
                    w = Math.sqrt(-2 * Math.loge(w) / w);
                    y1 = x1 * w;
                    gaussianf32Y2 = x2 * w;
                    gaussianf32Previous = true;
                }
            },
            f64 => {
                if (gaussianf64Previous) {
                    y1 = gaussianf64Y2;
                    gaussianf64Previous = false;
                } else {
                    x1 = Math.random(T, -1, 1);
                    x2 = Math.random(T, -1, 1);
                    w = x1 * x1 + x2 * x2;
                    while (w >= 1) {
                        x1 = Math.random(T, -1, 1);
                        x2 = Math.random(T, -1, 1);
                        w = x1 * x1 + x2 * x2;
                    }
                    w = Math.sqrt(-2 * Math.loge(w) / w);
                    y1 = x1 * w;
                    gaussianf64Y2 = x2 * w;
                    gaussianf64Previous = true;
                }
            },
            else => @panic("Math.randomGaussian only accepts f32 or f64")
        }

        return y1;
    }

    // vector maths
    pub fn mag(v: anytype) @TypeOf(v[0]) {
        const sqd = v * v;
        switch (@typeInfo(@TypeOf(v))) {
            .Vector => |vecData| {
                switch (vecData.len) {
                    2 => return Math.sqrt(sqd[0] + sqd[1]),
                    3 => return Math.sqrt(sqd[0] + sqd[1] + sqd[2]),
                    4 => return Math.sqrt(sqd[0] + sqd[1] + sqd[2] + sqd[3]),
                    else => @panic("unsupported vector length")
                }
            },
            else => @panic("Math.mag only accepts vectors")
        }
    }

    pub fn normalize(v: anytype) @TypeOf(v) {
        const m = Math.mag(v);
        if (m > 0.0) {
            return v / @as(@TypeOf(v), @splat(m));
        }
        return v;
    }

    pub fn dot(v1: anytype, v2: anytype) @TypeOf(v1[0]) {
        switch (@typeInfo(@TypeOf(v1, v2))) {
            .Vector => |vecData| {
                switch (vecData.len) {
                    2 => return v1[0] * v2[0] + v1[1] * v2[1],
                    3 => return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2],
                    4 => return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3],
                    else => @panic("unsupported vector length")
                }
            },
            else => @panic("Math.dot only accepts vectors")
        }
    }

    pub fn cross(v1: anytype, v2: anytype) @TypeOf(v1, v2) {
        return .{
            v1[1] * v2[2] - v1[2] * v2[1],
            v1[2] * v2[0] - v1[0] * v2[2],
            v1[0] * v2[1] - v1[1] * v2[0]
        };
    }
};

pub const Time = struct {
    pub const micros = if (wasmFreestanding)
        (struct {
            pub extern fn micros() i64;
        }).micros
    else
        (struct {
            fn micros() i64 {
                return std.time.microTimestamp();
            }
        }).micros;

    pub fn millis() i64 {
        return @divTrunc(Time.micros(), 1000);
    }

    pub fn seconds() f64 {
        return @as(f64, @floatFromInt(Time.millis() / 1000));
    }
};

pub const stdio = if (wasmFreestanding)
    (struct {
        pub extern fn stdio(id: i32, addr: usize, len: u32) void;
    }).stdio
else
    (struct {
        fn stdio(id: i32, addr: usize, len: u32) void {
            const manyPtr: [*]u8 = @ptrFromInt(addr);
            const slice: []u8 = manyPtr[0..len];

            if (id == 1) {
                std.debug.print("{s}\n", .{slice});
            }
        }
    }).stdio;

pub fn fmt(data_: anytype) String {
    if (@TypeOf(data_) == String) {
        return String.allocFrom(data_);
    } else {
        var outString: String = undefined;
        
        switch (@typeInfo(@TypeOf(data_))) {
            .Struct => {
                outString = String.allocFrom(data_);
            },
            .Array, .Pointer => {
                const contentType = std.meta.Elem(@TypeOf(data_));
                if (contentType == u8) {
                    // handle const strings
                    outString = String.allocFrom(data_);
                } else {
                    // handle other slices
                    outString = String.allocFrom("[]");
                    outString.concat(@typeName(contentType));
                    outString.concat("{");
                    var i: usize = 0; while (i < data_.len) : (i += 1) {
                        var temp = fmt(data_[i]);
                        defer temp.dealloc();
                        outString.concat(temp);
                        if (i < data_.len - 1) {
                            outString.concat(", ");
                        }
                    }
                    outString.concat("}");
                }
            },
            .Vector => |vecData| {
                outString = String.allocFrom("@Vector<");
                outString.concat(@typeName(vecData.child));
                outString.concat(">{");
                var i: usize = 0; while (i < vecData.len) : (i += 1) {
                    var numStr = Float.toString(data_[i], 10);
                    defer numStr.dealloc();
                    outString.concat(numStr);
                    if (i < vecData.len - 1) {
                        outString.concat(", ");
                    }
                }
                outString.concat("}");
            },
            else => {
                switch (@TypeOf(data_)) {
                    comptime_int, i8, u8, i16, u16, i32, u32, i64, u64, i128, u128, isize, usize => {
                        outString = Int.toString(data_, 10);
                    },
                    comptime_float, f16, f32, f64, f80, f128 => {
                        outString = Float.toString(data_, 10);
                    },
                    bool => {
                        if (data_) {
                            outString = String.allocFrom("true");
                        } else {
                            outString = String.allocFrom("false");
                        }
                    },
                    @TypeOf(null) => {
                        outString = String.allocFrom("null");
                    },
                    @TypeOf(void) => {
                        outString = String.allocFrom("void");
                    },
                    else => {
                        if (wasmFreestanding) {
                            outString = String.allocFrom("error: unreachable code has been reached");
                        } else {
                            @panic("attempted to print unsupported type of data");
                        }
                    }
                }
            },
        }

        return outString;
    }
}

pub fn print(data_: anytype) void {
    const write = std.debug.print;

    if (@TypeOf(data_) == String and !wasmFreestanding) {
        var temp = data_;
        write("{s}", .{temp.raw()});
    } else {
        var outString: String = fmt(data_);
        defer outString.dealloc();
        if (wasmFreestanding) {
            stdio(1, @intFromPtr(outString.bytes.buffer.ptr), outString.len());
        } else {
            // var temp = Array(u8).using(outString.raw());
            // temp.len = As.u32(outString.raw().len);
            // var temp2 = temp.join(",");
            // defer temp2.dealloc();
            // write("!!!{}!!!", .{temp2});
            write("{s}", .{outString.raw()});
        }
    }              
}
pub fn println(data: anytype) void {
    print(data);
    print("\n");
}

const stdin = std.io.getStdIn().reader();
pub fn readln(maxLen: u32) String {
    var out = String.alloc(maxLen);
    if (try stdin.readUntilDelimiterOrEof(out.bytes.buffer, '\n')) |user_input| {
        return out.slice(0, @as(u32, @intCast(user_input.len)));
    } else {
        return String.alloc(0);
    }
}

pub const HTTPResponse = struct {
    body: []u8 = undefined,
    // headers = .{},
    ok: bool = undefined,
    redirected: bool = undefined,
    status: bool = undefined,
    statusText: []u8 = undefined,
    url: String = undefined,
    
    pub fn text(self: *HTTPResponse) String {
        return String.allocFrom(self.body);
    }

    pub fn dealloc(self: *HTTPResponse) void {
        allocator.free(self.body);
        self.url.dealloc();
    }
};

pub fn fetch(url_: anytype, options: anytype) !HTTPResponse {
    // create String url
    var url: String = undefined;
    switch (@TypeOf(url_)) {
        // String
        String => {
            url = url_.clone();
        },
        // const string
        else => {
            url = String.allocFrom(url_);
        },
    }

    var method = http.Method.GET;
    var hasBody = false;

    const Client = std.http.Client;
    const Value = Client.Request.Headers.Value;
    var headers = Client.Request.Headers{};
    headers.accept_encoding = Value.omit;
    headers.connection = Value.omit;

    inline for (@typeInfo(@TypeOf(options)).Struct.fields) |field| {
        const value = @field(options, field.name);
        if (@typeInfo(@TypeOf(value)) == .Struct) {
            if (std.mem.eql(u8, field.name, "headers")) {
                inline for (@typeInfo(@TypeOf(value)).Struct.fields) |subfield| {
                    const subValue = @field(value, subfield.name);
                    if (std.mem.eql(u8, subfield.name, "content_type")) {
                        headers.content_type = Value{ .override = subValue };
                    }
                }
            }
        } else {
            if (std.mem.eql(u8, field.name, "method")) {
                if (std.mem.eql(u8, value, "POST")) {
                    method = http.Method.POST;
                }
            } else if (std.mem.eql(u8, field.name, "body")) {
                method = http.Method.POST;
                hasBody = true;
            }
        }
    }

    // create http client
    var httpClient = http.Client{ .allocator = allocator };
    defer httpClient.deinit();

    // create uri object
    const uri = try std.Uri.parse(url.raw());
    var server_header_buffer: [16 * 1024]u8 = undefined;

    var req = try httpClient.open(method, uri, .{
        .server_header_buffer = &server_header_buffer,
        .redirect_behavior = .unhandled,
        .headers = headers,
        // .extra_headers = options.extra_headers,
        // .privileged_headers = options.privileged_headers,
        // .keep_alive = options.keep_alive,
    });
    defer req.deinit();
    req.transfer_encoding = Client.RequestTransfer{ .content_length = options.body.len };

    try req.send(); // send headers
    if (hasBody) {
        try req.writeAll(options.body);  
    } 
    try req.finish(); // finish body
    try req.wait(); // wait for response

    const res = try req.reader().readAllAlloc(allocator, 1024);

    return HTTPResponse{
        .body = res,
        // .headers = .{},
        .ok = req.response.status.class() == .success,
        // .redirected = false,
        // .status = 200,
        // .statusText = "",
        // .type = "",
        .url = url,
    };
}

pub const fs_Stat = struct {
    kind: std.fs.Dir.Entry.Kind
};

pub const fs = struct {
    pub fn readDir(path: String) Array(String) {
        var iterable_dir = std.fs.cwd().openDir(path.raw(), .{
            .iterate = true
        }) catch @panic("failed to open dir");
        defer iterable_dir.close();

        var filenames = Array(String).alloc(4);
        var it = iterable_dir.iterate();
        while (it.next() catch @panic("iterater error")) |entry| {
            // need to dupe because entry.name uses an Iterator internal buffer
            const name_duped = allocator.dupe(u8, entry.name) catch @panic("dupe error");
            var buff = Uint8Array.using(name_duped);
            buff.len = As.u32(name_duped.len);
            filenames.append(String.using(buff));
        }

        return filenames;
    }

    pub fn lStat(path_: String) fs_Stat {
        var path = path_;
        const firstSlash = path.indexOf('/');
        var iterable_dir: std.fs.Dir = undefined;
        if (firstSlash == -1) {
            iterable_dir = std.fs.cwd().openDir("./", .{
                .iterate = true
            }) catch @panic("failed to open dir");
        } else {
            iterable_dir = std.fs.cwd().openDir(path.slice(0, As.u32(firstSlash)).raw(), .{
                .iterate = true
            }) catch @panic("failed to open dir");
            path = path.slice(As.u32(firstSlash) + 1, -1);
        }
        defer iterable_dir.close();

        var it = iterable_dir.iterate();
        while (it.next() catch @panic("iterater error")) |entry| {
            if (std.mem.eql(u8, entry.name, path.raw())) {
                return fs_Stat{
                    .kind = entry.kind,
                };
            }
        }

        @panic("link doesn't exist");
    }

    pub fn readFile(path: String) Uint8Array {
        const file = std.fs.cwd().openFile(path.raw(), .{
            .mode = .read_only
        }) catch @panic("failed to open file");
        const len = file.getEndPos() catch @panic("failed to read file length");
        var data = Uint8Array.alloc(As.u32(len));
        const readLen = file.read(data.buffer) catch @panic("failed to read file");
        if (readLen != len) {
            @panic("failed to read whole file");
        }
        data.len = As.u32(len);
        return data;
    }
};

pub fn Array(comptime T: type) type {
    return struct {
        buffer: []T = undefined,
        len: u32 = 0,

        const Self = @This();

        pub fn alloc(capacity_: u32) Self {
            const buffer = allocator.alloc(T, capacity_) catch @panic("memory allocation failed");
            return Self{
                .buffer = buffer
            };
        }

        pub fn new(capacity_: u32) *Self {
            const array = Self.alloc(capacity_);
            const heapArray = allocator.create(Self) catch @panic("memory allocation failed");
            heapArray.* = array;
            return heapArray;
        }

        pub fn dealloc(self: *Self) void {
            allocator.free(self.buffer);
        }

        pub fn free(self: *Self) void {
            self.dealloc();
            allocator.destroy(self);
        }

        pub fn using(buffer: []T) Self {
            return Self{
                .buffer = buffer
            };
        }

        pub fn deallocContents(self: *Self) void {
            var i: u32 = 0; while (i < self.len) : (i += 1) {
                self.get(i).dealloc();
            }
        }

        pub fn capacity(self: *const Self) u32 {
            return As.u32(self.buffer.len);
        }

        pub fn get(self: *const Self, idx: u32) if (@typeInfo(T) == .Struct) *T else T {
            if (@typeInfo(T) == .Struct) {
                return &self.buffer[idx];
            } else {
                return self.buffer[idx];
            }
        }

        pub fn getCopy(self: *const Self, idx: u32) T {
            return self.buffer[idx];
        }

        pub fn set(self: *Self, idx: u32, val: T) void {
            self.buffer[idx] = val;
        }

        fn Array_write8(self: *Self, addr: usize, val: u8) void {
            // use little endian
            self.buffer[addr] = val;
        }
        pub const write8 = switch(T) {
            u8 => Array_write8,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_read8(self: *Self, addr: usize) u8 {
            // use little endian
            return self.buffer[addr];
        }
        pub const read8 = switch(T) {
            u8 => Array_read8,
            else => @panic("Not implemented non u8 Arrays"),
        };
        
        fn Array_write16(self: *Self, addr: usize, val: u16) void {
            // use little endian
            self.buffer[addr] = @as(u8, @intCast(val & 255));
            self.buffer[addr+1] = @as(u8, @intCast(val >> 8));
        }
        pub const write16 = switch(T) {
            u8 => Array_write16,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_read16(self: *Self, addr: usize) u16 {
            // use little endian
            const a = @as(u16, @intCast(self.buffer[addr]));
            const b = @as(u16, @intCast(self.buffer[addr + 1]));
            return b << 8 | a;
        }
        pub const read16 = switch(T) {
            u8 => Array_read16,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_write24(self: *Self, addr: usize, val: u32) void {
            // use little endian
            self.buffer[addr] = @as(u8, @intCast(val & 255));
            self.buffer[addr+1] = @as(u8, @intCast((val >> 8) & 255));
            self.buffer[addr+2] = @as(u8, @intCast(val >> 16));
        }
        pub const write24 = switch(T) {
            u8 => Array_write24,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_read24(self: *Self, addr: usize) u32 {
            // use little endian
            const a = @as(u32, @intCast(self.buffer[addr]));
            const b = @as(u32, @intCast(self.buffer[addr + 1]));
            const c = @as(u32, @intCast(self.buffer[addr + 2]));
            return c << 16 | b << 8 | a;
        }
        pub const read24 = switch(T) {
            u8 => Array_read24,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_write32(self: *Self, addr: usize, val: u32) void {
            // use little endian
            self.buffer[addr] = @as(u8, @intCast(val & 255));
            self.buffer[addr+1] = @as(u8, @intCast((val >> 8) & 255));
            self.buffer[addr+2] = @as(u8, @intCast((val >> 16) & 255));
            self.buffer[addr+3] = @as(u8, @intCast(val >> 24));
        }
        pub const write32 = switch(T) {
            u8 => Array_write32,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_read32(self: *Self, addr: usize) u32 {
            // use little endian
            const a = @as(u32, @intCast(self.buffer[addr]));
            const b = @as(u32, @intCast(self.buffer[addr + 1]));
            const c = @as(u32, @intCast(self.buffer[addr + 2]));
            const d = @as(u32, @intCast(self.buffer[addr + 3]));
            return d << 24 | c << 16 | b << 8 | a;
        }
        pub const read32 = switch(T) {
            u8 => Array_read32,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_write64(self: *Self, addr: usize, val: u64) void {
            // use little endian
            self.buffer[addr  ] = @as(u8, @intCast( val        & 255));
            self.buffer[addr+1] = @as(u8, @intCast((val >>  8) & 255));
            self.buffer[addr+2] = @as(u8, @intCast((val >> 16) & 255));
            self.buffer[addr+3] = @as(u8, @intCast((val >> 24) & 255));
            self.buffer[addr+4] = @as(u8, @intCast((val >> 32) & 255));
            self.buffer[addr+5] = @as(u8, @intCast((val >> 40) & 255));
            self.buffer[addr+6] = @as(u8, @intCast((val >> 48) & 255));
            self.buffer[addr+7] = @as(u8, @intCast((val >> 56) & 255));
        }
        pub const write64 = switch(T) {
            u8 => Array_write64,
            else => @panic("Not implemented non u8 Arrays"),
        };

        fn Array_read64(self: *Self, addr: usize) u64 {
            // use little endian
            const a = @as(u64, @intCast(self.buffer[addr]));
            const b = @as(u64, @intCast(self.buffer[addr + 1]));
            const c = @as(u64, @intCast(self.buffer[addr + 2]));
            const d = @as(u64, @intCast(self.buffer[addr + 3]));
            const e = @as(u64, @intCast(self.buffer[addr + 4]));
            const f = @as(u64, @intCast(self.buffer[addr + 5]));
            const g = @as(u64, @intCast(self.buffer[addr + 6]));
            const h = @as(u64, @intCast(self.buffer[addr + 7]));
            return h << 56 | g << 48 | f << 40 | e << 32 | d << 24 | c << 16 | b << 8 | a;
        }
        pub const read64 = switch(T) {
            u8 => Array_read64,
            else => @panic("Not implemented non u8 Arrays"),
        };

        pub fn fill(self: *Self, val: T, len_: i32) void {
            const len: u32 = if (len_ == -1) @as(u32, @intCast(self.buffer.len)) else @as(u32, @intCast(len_));
            var i: u32 = 0;
            while (i < len) : (i += 1) {
                self.buffer[i] = val;
            }
            self.len = len;
        }

        pub fn resize(self: *Self, newCapacity: u32) void {
            var newBuffer = allocator.alloc(T, newCapacity) catch @panic("memory allocation failed");

            for (self.buffer, 0..) |val, idx| {
                newBuffer[idx] = val;
            }

            allocator.free(self.buffer);
            self.buffer = newBuffer;
        }

        pub fn append(self: *Self, val: T) void {
            const prevLen = self.len;
            const prevCapacity = self.capacity();
            if (prevLen == prevCapacity) {
                if (prevCapacity == 0) {
                    self.resize(2);
                } else {
                    self.resize(prevCapacity * 2);
                }
            }
            self.buffer[prevLen] = val;
            self.len += 1;
        }

        pub fn remove(self: *Self, idx: u32, len: u32) void {
            const buff = self.buffer;
            var i = idx;
            while (i + len < self.len) : (i += 1) {
                buff[i] = buff[i + len];
            }
            self.len -= len;
        }

        pub fn indexOf(self: *const Self, val: T) i32 {
            const buff = self.buffer;
            var i: usize = 0;
            while (i < self.len) : (i += 1) {
                if (buff[i] == val) {
                    return @as(i32, @intCast(i));
                }
            }
            return -1;
        }

        pub fn join(self: *const Self, separator_: anytype) String {
            var stringSeparator: String = undefined;
            var needToFreeSeparator = false;
            if (@TypeOf(separator_) == String) {
                stringSeparator = separator_;
            } else {
                stringSeparator = String.allocFrom(separator_);
                needToFreeSeparator = true;
            }
            defer if (needToFreeSeparator) stringSeparator.dealloc();

            var out = String.alloc(0);

            var i: u32 = 0;
            while (i < self.len) : (i += 1) {
                var item: String = undefined;
                const TypeInfo = @typeInfo(T);
                if (TypeInfo == .Struct or TypeInfo == .Pointer) {
                    item = self.get(i).*.toString();
                } else if (TypeInfo == .Int) {
                    item = Int.toString(self.get(i), 10);
                } else if (TypeInfo == .Float) {
                    item = Float.toString(self.get(i), 10);
                } else if (TypeInfo == .Bool) {
                    item = if (self.get(i)) String.allocFrom("true") else String.allocFrom("false");
                }
                defer item.dealloc();
                out.concat(item);
                if (i < self.len - 1) {
                    out.concat(stringSeparator);
                }
            }

            return out;
        }
    };
}

pub const Uint8Array = Array(u8);
pub const Int8Array = Array(i8);
pub const Uint16Array = Array(u16);
pub const Int16Array = Array(i16);
pub const Uint32Array = Array(u32);
pub const Int32Array = Array(i32);
pub const Uint64Array = Array(u64);
pub const Int64Array = Array(i64);
pub const Float32Array = Array(f32);
pub const Float64Array = Array(f64);

pub const Hash = struct {
    fn FNV1a(key: []const u8) u32 {
        var hash: u32 = 2166136261;
        var i: u32 = 0;
        while (i < key.len) : (i += 1) {
            hash ^= As.u8T(key[i]);
            hash *%= 16777619;
        }
        return hash;
    }
};

pub fn MapIterator(comptime MapEntry: type) type {
    _=MapEntry;
    return struct {
        
    };
}

pub fn Map(comptime KeyType: type, comptime ValueType: type) type {
    return struct {
        pub const Entry = struct {
            key: ?KeyType,
            value: ValueType,
            hash: u32
        };
        
        size: u32 = 0,
        buckets: []Entry = undefined,

        const MAX_LOAD: f64 = 0.66;

        const Self = @This();

        pub fn alloc() Self {
            const buckets = allocator.alloc(Entry, 4) catch @panic("memory allocation failed");
            var i: u32 = 0;
            while (i < buckets.len) : (i += 1) {
                buckets[i] = Entry{
                    .key = null,
                    .value = undefined,
                    .hash = undefined
                };
            }
            return Self{
                .buckets = buckets
            };
        }

        pub fn dealloc(self: *Self) void {
            allocator.free(self.buckets);
        }

        pub fn grow(self: *Self) void {
            const newBuckets = allocator.alloc(Entry, self.buckets.len * 2) catch @panic("memory allocation failed");
            var i: u32 = 0;
            while (i < newBuckets.len) : (i += 1) {
                newBuckets[i] = Entry{
                    .key = null,
                    .value = undefined,
                    .hash = undefined
                };
            }

            const oldBuckets = self.buckets;
            self.buckets = newBuckets;
            i = 0;
            while (i < oldBuckets.len) : (i += 1) {
                const bucket = oldBuckets[i];
                if (bucket.key != null) {
                    self.setPreHashed(bucket.key.?, bucket.hash, bucket.value);
                }
            }
            
            allocator.free(oldBuckets);
        }

        fn keyEql(a: KeyType, b: KeyType) bool {
            return switch (KeyType) {
                String => a.equals(b),
                []const u8 => std.mem.eql(u8, a, b),
                else => a == b
            };
        }

        pub fn setPreHashed(self: *Self, key: KeyType, hash: u32, value: ValueType) void {
            const idx = As.u32(hash & (self.buckets.len - 1));
            var bucket = self.buckets[idx];
            var isEmpty = bucket.key == null;
            if (isEmpty or Self.keyEql(bucket.key.?, key)) {
                // if bucket is empty or is same key, set value
                self.buckets[idx] = Entry{
                    .key = key,
                    .value = value,
                    .hash = hash
                };
                if (!isEmpty) {
                    self.size += 1;
                }
            } else {
                // go to next bucket or wrap around
                var i: u32 = if (idx + 1 == self.buckets.len) 0 else idx + 1;
                while (i < self.buckets.len) {
                    bucket = self.buckets[i];
                    isEmpty = bucket.key == null;
                    if (isEmpty or Self.keyEql(bucket.key.?, key)) {
                        // if bucket is empty or is same key, set value
                        self.buckets[idx] = Entry{
                            .key = key,
                            .value = value,
                            .hash = hash
                        };
                        if (!isEmpty) {
                            self.size += 1;
                        }
                        break;
                    } else {
                        i += 1;
                        if (i == self.buckets.len) {
                            // wrap around to start if out of bounds
                            i = 0;
                        } else if (i == idx) {
                            // if we end up back where we started we are 
                            // todo resize
                            self.grow();
                        }
                    }
                }
            }
        }

        pub fn set(self: *Self, key: KeyType, value: ValueType) void {
            const hash = switch (KeyType) {
                String => Hash.FNV1a(key.raw()),
                else => Hash.FNV1a(key)
            };
            self.setPreHashed(key, hash, value);
        }

        pub fn get(self: *const Self, key: KeyType) ?ValueType {
            const hash = switch (KeyType) {
                String => Hash.FNV1a(key.raw()),
                else => Hash.FNV1a(key)
            };
            const idx = hash & (self.buckets.len - 1);
            if (self.buckets[idx].key != null) {
                return self.buckets[idx].value;
                // var i: u32 = 0;
                // while (i < self.buckets.len) {
                //     if (self.buckets[idx].key) {
                //         break;
                //     } else if (i + 1 < self.buckets.len) {
                //         i += 1;
                //     } else {
                //         i = 0;
                //     }
                // }
            }
            return null;
        }
    };
}

pub const String = struct {
    viewStart: u32 = 0,
    viewEnd: u32 = 0,
    bytes: Uint8Array,
    isSlice: bool = false,

    pub fn alloc(capacity: u32) String {
        const bytes = Uint8Array.alloc(capacity);
        return String{
            .viewStart = 0,
            .viewEnd = 0,
            .bytes = bytes,
            .isSlice = false
        };
    }

    pub fn allocFrom(data_: anytype) String {
        var data = data_;
        if (@TypeOf(data) == String) {
            const temp = data.clone();
            return temp;
        } else if (@typeInfo(@TypeOf(data)) == .Struct) {
            var temp = String.allocFrom(".{\n");
            inline for (@typeInfo(@TypeOf(data)).Struct.fields) |field| {
                const value = @field(data, field.name);
                if (@typeInfo(@TypeOf(value)) == .Struct) {
                    
                } else {
                    temp.concat("    .");
                    temp.concat(field.name);
                    temp.concat(" = ");
                    const formatted = std.fmt.allocPrint(allocator, "{any}", .{ value }) catch @panic("memory allocation failed");
                    defer allocator.free(formatted);
                    temp.concat(formatted);
                    temp.concat(",\n");
                }
            }
            temp.concat("}");
            return temp;
        } else {
            switch (@TypeOf(data)) {
                // char
                comptime_int, i8, u8, i16, u16, i32, u32, i64, u64, i128, u128, isize, usize => {
                    const temp = Int.toString(data, 10);
                    return temp;
                },
                // const string
                else => {
                    const dataLen = @as(u32, @intCast(data.len));
                    var temp = String.alloc(dataLen);
                    temp.viewEnd = dataLen;
                    temp.bytes.len = dataLen;

                    for (data, 0..) |val, idx| {
                        temp.bytes.buffer[idx] = val;
                    }

                    return temp;
                },
            }
        }
        
    }
    
    pub fn new(capacity: u32) *String {
        const str = String.alloc(capacity);
        const heapStr = allocator.create(String) catch @panic("memory allocation failed");
        heapStr.* = str;
        return heapStr;
    }

    pub fn newFrom(data_: anytype) *String {
        const str = String.allocFrom(data_);
        const heapStr = allocator.create(String) catch @panic("memory allocation failed");
        heapStr.* = str;
        return heapStr;
    }

    pub fn dealloc(self: *String) void {
        self.bytes.dealloc();
    }

    pub fn free(self: *String) void {
        self.bytes.dealloc();
        allocator.destroy(self);
    }

    pub fn using(bytes: Uint8Array) String {
        return String{
            .viewStart = 0,
            .viewEnd = bytes.len,
            .bytes = bytes,
            .isSlice = false
        };
    }

    pub fn len(self: *const String) u32 {
        return self.viewEnd - self.viewStart;
    }

    pub fn charAt(self: *const String, idx: u32) u8 {
        return self.bytes.get(self.viewStart + idx);
    }

    pub fn charCodeAt(self: *const String, idx: u32) u8 {
        return self.bytes.get(self.viewStart + idx);
    }

    pub fn setChar(self: *String, idx: u32, val: u8) void {
        self.bytes.set(self.viewStart + idx, val);
    }

    pub fn concat(self: *String, data: anytype) void {
        if (self.isSlice) {
            unreachable;
        }
        switch (@TypeOf(data)) {
            // char
            comptime_int, i8, u8, i16, u16, i32, u32, i64, u64, i128, u128, isize, usize => {
                self.bytes.append(data);
                self.viewEnd = self.bytes.len;
                return;
            },
            // String
            *String, String => {
                var i: u32 = data.viewStart;
                while (i < data.viewEnd) : (i += 1) {
                    self.bytes.append(data.bytes.buffer[i]);
                    self.viewEnd = self.bytes.len;
                }
                return;
            },
            // const string
            else => {
                for (data, 0..) |val, idx| {
                    _ = idx;
                    self.bytes.append(val);
                    self.viewEnd = self.bytes.len;
                }
                return;
            },
        }
    }

    pub fn equals(self: *const String, str: anytype) bool {
        var temp: String = undefined;
        var needsFreeing = false;
        switch (@TypeOf(str)) {
            String => {
                temp = str;
            },
            else => {
                temp = String.allocFrom(str);
                needsFreeing = true;
            }
        }

        var out = true;
        const buf1 = self.bytes.buffer;
        const buf2 = temp.bytes.buffer;
        if (buf1.ptr == buf2.ptr and self.viewStart == temp.viewStart and self.viewEnd == temp.viewEnd) {
            // out is already true so no need to set it
            // out = true;
        } else if (temp.len() != self.len()) {
            out = false;
        } else {
            var i: u32 = 0;
            while (i < self.len()) : (i += 1) {
                if (self.charAt(i) != temp.charAt(i)) {
                    out = false;
                    break;
                }
            }
        }

        defer if (needsFreeing) temp.dealloc();
        
        return out;
    }

    pub fn toSlice(self: *const String, start_: u32, end_: u32) String {
        const start = start_;
        var end = end_;

        if (end == 0) {
            end = self.len();
        }
        var bytes = Uint8Array.alloc(end - start);
        bytes.len = end - start;

        var i: u32 = 0;
        while (i < bytes.len) : (i += 1) {
            bytes.buffer[i] = self.bytes.buffer[start + i];
        }

        return String{
            .viewStart = 0,
            .viewEnd = bytes.len,
            .bytes = bytes,
            .isSlice = false
        };
    }

    pub fn slice(self: *const String, start_: u32, end_: anytype) String {
        const start = start_;
        var end: u32 = undefined;

        if (end_ == -1) {
            end = self.len();
        } else {
            end = As.u32(end_);
        }

        return String{
            .viewStart = self.viewStart + start,
            .viewEnd = self.viewStart + end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn trimStart(self: *const String) String {
        var start = self.viewStart;
        const end = self.viewEnd;
        const buff = self.bytes.buffer;

        // trim start
        while (
            start < end and
            (buff[start] == 9 or 
            buff[start] == 10 or
            buff[start] == 11 or
            buff[start] == 12 or
            buff[start] == 13 or
            buff[start] == 32)
        ) {
            start += 1;
        }

        return String{
            .viewStart = start,
            .viewEnd = end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn trimEnd(self: *const String) String {
        const start = self.viewStart;
        var end = self.viewEnd;
        const buff = self.bytes.buffer;

        // trim end
        var endMinusOne: isize = end - 1;
        while (
            end > start and
            (buff[@as(usize, @bitCast(endMinusOne))] == 9 or 
            buff[@as(usize, @bitCast(endMinusOne))] == 10 or
            buff[@as(usize, @bitCast(endMinusOne))] == 11 or
            buff[@as(usize, @bitCast(endMinusOne))] == 12 or
            buff[@as(usize, @bitCast(endMinusOne))] == 13 or
            buff[@as(usize, @bitCast(endMinusOne))] == 32)
        ) {
            endMinusOne -= 1;
            end -= 1;
        }

        return String{
            .viewStart = start,
            .viewEnd = end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn trim(self: *const String) String {
        var start = self.viewStart;
        var end = self.viewEnd;
        const buff = self.bytes.buffer;

        // trim start
        while (
            start < end and
            (buff[start] == 9 or 
            buff[start] == 10 or
            buff[start] == 11 or
            buff[start] == 12 or
            buff[start] == 13 or
            buff[start] == 32)
        ) {
            start += 1;
        }
        
        // trim end
        var endMinusOne = end - 1;
        while (
            (buff[endMinusOne] == 9 or 
            buff[endMinusOne] == 10 or
            buff[endMinusOne] == 11 or
            buff[endMinusOne] == 12 or
            buff[endMinusOne] == 13 or
            buff[endMinusOne] == 32)
            and end > start
        ) {
            endMinusOne -= 1;
            end -= 1;
        }

        return String{
            .viewStart = start,
            .viewEnd = end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn split(self: *const String, str: anytype) Array(String) {
        var delimiter: String = undefined;
        var needsFreeing = false;
        var out = Array(String).alloc(0);
        switch (@TypeOf(str)) {
            String => {
                delimiter = str;
            },
            else => {
                delimiter = String.allocFrom(str);
                needsFreeing = true;
            }
        }

        var selfCopy = self.*;
        var idx = selfCopy.indexOf(delimiter);
        while (idx != -1) {
            const slc = selfCopy.slice(0, @as(u32, @bitCast(idx)));
            out.append(slc);
            selfCopy = selfCopy.slice(@as(u32, @bitCast(idx)) + delimiter.len(), -1);
            idx = selfCopy.indexOf(delimiter);
        }

        if (selfCopy.len() > 0) {
            out.append(selfCopy);
        }

        defer if (needsFreeing) delimiter.dealloc();
        
        return out;
    }

    pub fn repeat(self: *String, amt: u32) void {
        if (self.isSlice) {
            @panic("cannot repeat a slice");
        }
        var selfClone = self.clone();
        defer selfClone.dealloc();
        var i: u32 = 0;
        while (i < amt - 1) : (i += 1) {
            self.concat(selfClone);
        }
    }

    pub fn padStart(self: *String, width: u32, str: anytype) void {
        if (self.isSlice) {
            @panic("cannot pad a slice");
        }
        const padAmount = width - self.len();
        if (padAmount > 0) {
            var temp = String.alloc(width);
            temp.concat(str);
            temp.repeat(padAmount / temp.len());
            temp.concat(self.*);
            temp = temp.slice(0, width);

            self.dealloc();
            self.bytes = temp.bytes;
            self.viewStart = temp.viewStart;
            self.viewEnd = temp.viewEnd;
        }
    }

    pub fn padEnd(self: *String, width: u32, str: anytype) void {
        if (self.isSlice) {
            @panic("cannot pad a slice");
        }
        const padAmount = width - self.len();
        if (padAmount > 0) {
            var temp = String.alloc(width);
            defer temp.dealloc();
            temp.concat(str);
            temp.repeat(padAmount / temp.len());
            self.concat(temp.slice(0, padAmount));
        }
    }

    pub fn lowerCase(self: *String) void {
        var i: u32 = 0;
        while (i < self.len()) : (i += 1) {
            const c = self.charAt(i);
            if (c >= 'A' and c <= 'Z') {
                self.setChar(i, c + 32);
            }
        }
    }

    pub fn upperCase(self: *String) void {
        var i: u32 = 0;
        while (i < self.len()) : (i += 1) {
            const c = self.charAt(i);
            if (c >= 'a' and c <= 'z') {
                self.setChar(i, c - 32);
            }
        }
    }

    pub fn indexOfPos(self: *const String, str: anytype, pos: u32) i32 {
        var temp: String = undefined;
        var isChar = false;
        var charVal: u8 = 0;
        var needsFreeing = false;
        switch (@TypeOf(str)) {
            comptime_int, u8 => {
                isChar = true;
                charVal = str;
            },
            String => {
                temp = str;
            },
            else => {
                temp = String.allocFrom(str);
                if (temp.len() == 1) {
                    isChar = true;
                    charVal = temp.charAt(0);
                    defer temp.dealloc();
                } else {
                    needsFreeing = true;
                }
            }
        }
        
        if (isChar) {
            var i: u32 = pos;
            while (i < self.len()) : (i += 1) {
                if (self.charAt(i) == charVal) {
                    return @as(i32, @bitCast(i));
                }
            }
        } else {
            var i: u32 = pos;
            while (i < self.len()) : (i += 1) {
                var j: u32 = 0;
                while (j < temp.len()) : (j += 1) {
                    if (self.charAt(i + j) == temp.charAt(j)) {
                        if (j == temp.len() - 1) {
                            defer if (needsFreeing) temp.dealloc();
                            return @as(i32, @bitCast(i));
                        }
                    } else {
                        break;
                    }
                }
            }

            defer if (needsFreeing) temp.dealloc();
        }

        return -1;
    }

    pub fn indexOf(self: *const String, str: anytype) i32 {
        return self.indexOfPos(str, 0);
    }

    pub fn contains(self: *const String, str: anytype) bool {
        return self.indexOf(str) >= 0;
    }

    pub fn startsWith(self: *const String, str: anytype) bool {
        var temp: String = undefined;
        var needsFreeing = false;
        var out = true;
        switch (@TypeOf(str)) {
            String => {
                temp = str;
            },
            else => {
                temp = String.allocFrom(str);
                needsFreeing = true;
            }
        }

        if (temp.len() > self.len()) {
            out = false;
        } else {
            var i: u32 = 0;
            while (i < temp.len()) : (i += 1) {
                if (self.charAt(i) != temp.charAt(i)) {
                    out = false;
                    break;
                }
            }
        }

        defer if (needsFreeing) temp.dealloc();
        
        return out;
    }

    pub fn endsWith(self: *const String, str: anytype) bool {
        var temp: String = undefined;
        var needsFreeing = false;
        var out = true;
        switch (@TypeOf(str)) {
            String => {
                temp = str;
            },
            else => {
                temp = String.allocFrom(str);
                needsFreeing = true;
            }
        }

        if (temp.len() > self.len()) {
            out = false;
        } else {
            var i: u32 = 0;
            const offset = self.len() - temp.len();
            while (i < temp.len()) : (i += 1) {
                if (self.charAt(offset + i) != temp.charAt(i)) {
                    out = false;
                    break;
                }
            }
        }

        defer if (needsFreeing) temp.dealloc();
        
        return out;
    }

    pub fn raw(self: *const String) []u8 {
        return self.bytes.buffer[self.viewStart..self.viewEnd];
    }

    pub fn clone(self: *const String) String {
        return String.allocFrom(self.raw());
    }

    pub const toString = clone;
};

pub const Int = enum {
    var base10 = "0123456789";
    var base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var codeKey = "0123456789abcdefghijklmnopqrstuvwxyz";
    
    pub fn toString(num_: anytype, base: u32) String {
        switch (@typeInfo(@TypeOf(num_))) {
            .Int, .ComptimeInt => {
                const key = if (base == 10) Int.base10 else Int.codeKey;

                // calculate length
                const num = @as(u64, @intCast(Math.abs(num_)));
                var placeValues: u32 = 1;
                while (Math.pow(@as(u64, @intCast(base)), placeValues) < num + 1) {
                    placeValues += 1;
                }

                const negative = num_ < 0;
                var encoded = if (negative) String.alloc(placeValues + 1) else String.alloc(placeValues);
                encoded.bytes.len = encoded.bytes.capacity();
                encoded.viewEnd = encoded.bytes.capacity();
                
                var i = placeValues;
                var strIdx: u32 = 0;

                if (negative) {
                    encoded.setChar(0, '-');
                    strIdx = 1;
                }

                var f64num = @as(f64, @floatFromInt(num));
                while (i > 0) {
                    const factor: f64 = Math.pow(@as(f64, @floatFromInt(base)), @as(f64, @floatFromInt(i - 1)));
                    const digit = Math.floor(f64num / factor);
                    encoded.setChar(strIdx, key[@as(usize, @intFromFloat(digit))]);
                    strIdx += 1;
                    f64num -= digit * factor;
                    i -= 1;
                }

                return encoded;
            },
            else => @panic("Int.toString only accepts integers")
        }
    }

    pub fn parse(data: anytype, base_: u32) i64 {
        var key = if (base_ == 10) String.allocFrom(Int.base10) else String.allocFrom(Int.codeKey);
        defer key.dealloc();
        const base = @as(i64, @intCast(base_));

        var str: String = undefined;
        var createdString = false;
        switch (@TypeOf(data)) {
            // String
            String => {
                str = data;
            },
            // const string
            else => {
                str = String.allocFrom(data);
                createdString = true;
            }
        }
    
        var num: i64 = 0;
        var i = @as(i32, @intCast(str.len() - 1));
        var power: i64 = 0;
        while (i >= 0) : (i -= 1) {
            const ch = str.charAt(@as(u32, @bitCast(i)));
            var idx = key.indexOf(ch);
            if (idx == -1) {
                idx = key.indexOf(ch + 32);
            }
            num += @as(i64, @intCast(idx)) * Math.pow(base, power);
            power += 1;
        }
    
        defer if (createdString) str.dealloc();

        return num;
    }
};

pub const Float = enum {
    var base10 = "0123456789";

    pub fn toString(num_: anytype, base: u32) String {
        if (Float.isNaN(num_)) {
            return String.allocFrom("NaN");
        }

        switch (@typeInfo(@TypeOf(num_))) {
            .Float, .ComptimeFloat => {
                var num: f64 = @as(f64, @floatCast(num_));
                const negative = num < 0;
                num = Math.abs(num);
                const leading = @as(u32, @intFromFloat(num));
                const ten: f64 = 10;
                const six: f64 = 6;
                var f64Trailing = (num - @as(f64, @floatFromInt(leading))) * Math.pow(ten, six);
                var trailing = @as(u32, @intFromFloat(f64Trailing));
                f64Trailing = @as(f64, @floatFromInt(trailing));

                if (trailing > 0) {
                    while ((f64Trailing / 10) - Math.floor(f64Trailing / 10) == 0) {
                        f64Trailing /= 10.0;
                    }
                    trailing = @as(u32, @intFromFloat(f64Trailing));
                }

                var trailStr = Int.toString(trailing, base);
                defer trailStr.dealloc();

                var temp = if (negative) String.allocFrom("-") else String.alloc(0);
                var temp2 = Int.toString(leading, base);
                defer temp2.dealloc();
                temp.concat(temp2);
                temp.concat('.');
                temp.concat(trailStr);
                return temp;
            },
            else => @panic("Float.toString only accepts floats")
        }
    }

    pub fn toFixed(num: anytype, digits: u32) String {
        var out = Float.toString(num, 10);
        const dotIdx = out.indexOf(".");
        const digitCount = out.len - dotIdx;
        if (digitCount >= digits) {
            return out.slice(dotIdx, dotIdx + digits);
        } else {
            out.padEnd(digits, "0");
            return out;
        }
    }
    
    pub fn parse(data_: anytype, base: u32) f64 {
        var str: String = undefined;
        var createdString = false;
        switch (@TypeOf(data_)) {
            // String
            String => {
                str = data_;
            },
            // const string
            else => {
                str = String.allocFrom(data_);
                createdString = true;
            }
        }
    
        const dotIdx = @as(u32, @bitCast(str.indexOf('.')));
        const front = str.slice(0, dotIdx);
        var back = str.slice(dotIdx + 1, -1);
        const frontNum = @as(f64, @floatFromInt(Int.parse(front, base)));
        const backNum = @as(f64, @floatFromInt(Int.parse(back, base)));
        const floatLen = @as(f64, @floatFromInt(back.len()));
        const divider = Math.pow(@as(f64, 10.0), floatLen);

        defer if (createdString) str.dealloc();

        return frontNum + (backNum / divider);
    }

    pub fn NaN(val: type) val {
        return std.math.nan(val);
    }

    pub fn isNaN(val: anytype) bool {
        return std.math.isNan(val);
    }
};
