--- Helper module for packing and unpacking binary data, specifically big-endian integers.
local binary = {}

--- Packs a 32-bit unsigned integer into a 4-byte big-endian string.
-- @param n (number) The integer to pack.
-- @return (string) A 4-byte string.
function binary.pack_u32_be(n)
    local b1 = (n >> 24) & 0xFF
    local b2 = (n >> 16) & 0xFF
    local b3 = (n >> 8) & 0xFF
    local b4 = n & 0xFF
    return string.char(b1, b2, b3, b4)
end

--- Packs a 16-bit unsigned integer into a 2-byte big-endian string.
-- @param n (number) The integer to pack.
-- @return (string) A 2-byte string.
function binary.pack_u16_be(n)
    local b1 = (n >> 8) & 0xFF
    local b2 = n & 0xFF
    return string.char(b1, b2)
end

--- Unpacks a 32-bit unsigned integer from a 4-byte big-endian string.
-- @param s (string) The 4-byte string.
-- @param offset (number, optional) The starting position (default 1).
-- @return (number) The unpacked integer.
function binary.unpack_u32_be(s, offset)
    offset = offset or 1
    local b1, b2, b3, b4 = string.byte(s, offset, offset + 3)
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
end

--- Unpacks a 16-bit unsigned integer from a 2-byte big-endian string.
-- @param s (string) The 2-byte string.
-- @param offset (number, optional) The starting position (default 1).
-- @return (number) The unpacked integer.
function binary.unpack_u16_be(s, offset)
    offset = offset or 1
    local b1, b2 = string.byte(s, offset, offset + 1)
    return (b1 << 8) | b2
end

return binary