const std = @import("std");
const vexlib = @import("vexlib.zig");
const Array = vexlib.Array;
const Uint8Array = vexlib.Uint8Array;
const String = vexlib.String;
const fs = vexlib.fs;

var buffers: Array(Uint8Array) = undefined;

export fn init() void {
    const generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    vexlib.init(generalPurposeAllocator);

    // create empty array of buffers
    buffers = Array(Uint8Array).alloc(10);
}

export fn createBuffer(capacity: u32) u32 {
    buffers.append(Uint8Array.alloc(capacity));
    return buffers.len - 1;
}

export fn getBufferLen(buffIdx: u32) u32 {
    return buffers.get(buffIdx).len;
}

export fn setBufferLen(buffIdx: u32, len: u32) void {
    buffers.get(buffIdx).len = len;
}

export fn getBufferByte(buffIdx: u32, idx: u32) u8 {
    return buffers.get(buffIdx).get(idx);
}

export fn setBufferByte(buffIdx: u32, idx: u32, val: u8) void {
    buffers.get(buffIdx).set(idx, val);
}

export fn readDir(buffIdx: u32) u32 {
    const items = fs.readDir(String.using(buffers.get(buffIdx).*));
    const rangeStart = buffers.len;
    var i: u32 = 0; while (i < items.len) : (i += 1) {
        buffers.append(items.get(i).bytes);
    }
    const rangeEnd = buffers.len;
    return (rangeStart << 16) | rangeEnd;
}

export fn lStat(buffIdx: u32) u32 {
    const stat = fs.lStat(String.using(buffers.get(buffIdx).*));
    return switch (stat.kind) {
        .directory => 1,
        .file => 2,
        else => 0
    };
}

export fn readFile(buffIdx: u32) u32 {
    const content = fs.readFile(String.using(buffers.get(buffIdx).*));
    buffers.append(content);
    return buffers.len - 1;
}

// I'll just let the OS cleanup the leaked memory from buffers