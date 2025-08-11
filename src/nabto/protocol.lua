--- Module to define the Genvex Nabto protocol constants and packet builders.
-- You must port your Python packet building logic into the functions here.

local binary = require('nabto/binary')

local protocol = {}

protocol.PacketType = {
    U_CONNECT = string.char(0x83),
    DATA = string.char(0x16)
}


-- Converted from Python GenvexPayloadType
protocol.PayloadType = {
    U_IPX = string.char(0x35),
    U_CRYPT = string.char(0x36),
    U_CP_ID = string.char(0x3F)
}

-- Converted from Python GenvexCommandType
protocol.CommandType = {
    DATAPOINT_READLIST = string.char(0x2d),
    SETPOINT_READLIST = string.char(0x2a),
    SETPOINT_WRITELIST = string.char(0x2b),
    KEEP_ALIVE = string.char(0x02),
    PING = string.char(0x11)
}


protocol.BROADCAST_ADDRESS = '255.255.255.255'
protocol.DISCOVERY_PORT = 5570
protocol.DEVICE_DEFAULT_PORT = 5570

-- Placeholder for the discovery packet builder
protocol.GenvexDiscovery = {
    build_packet = function(specific_device)
        local device_id = specific_device or "*"
        return table.concat({
            string.char(0, 0, 0, 1), -- So called "Legacy header"
            string.char(0, 0, 0, 0, 0, 0, 0, 0), -- Seems like unused space in header?
            device_id,
            string.char(0) -- Zero terminator for string
        })
    end
}

protocol.GenvexPacket = {
    build_packet = function(client_id, server_id, packet_type, sequence_id, payloads)
        payloads = payloads or {}

        local payload_bundle = ""
        local checksum_required = false

        for _, payload in ipairs(payloads) do
            payload_bundle = payload_bundle .. payload:buildPayload()
            if payload.requiresChecksum then
                checksum_required = true
            end
        end

        local packet_length = string.len(payload_bundle) + 16
        if checksum_required then
            packet_length = packet_length + 2
        end

        local packet = table.concat({
            client_id,
            server_id,
            packet_type,
            string.char(0x02), -- Version
            string.char(0x00), -- Retransmission count
            string.char(0x00), -- Flags
            binary.pack_u16_be(sequence_id),
            binary.pack_u16_be(packet_length),
            payload_bundle
        })

        if checksum_required then
            -- Calculate the checksum. It is simply a sum of all bytes.
            local sum = 0
            for i = 1, string.len(packet) do
                sum = sum + string.byte(packet, i)
            end
            -- The sum is masked to 16 bits to prevent overflow
            packet = packet .. binary.pack_u16_be(sum % 65536)
        end

        return packet
    end
}


---
--- Payload Definitions
---

-- Base Payload "class"
local GenvexPayload = {}
GenvexPayload.__index = GenvexPayload
GenvexPayload.requiresChecksum = false
GenvexPayload.payloadType = nil -- To be overridden by child "classes"
GenvexPayload.payloadFlags = string.char(0x00)

function GenvexPayload:new()
    -- This is a basic constructor for subclasses to inherit
    return setmetatable({}, self)
end

function GenvexPayload:buildPayload()
    -- This function is intended to be overridden by child "classes"
    error("buildPayload() must be overridden in subclasses")
end

-- Make the base payload available for other modules to inherit from
protocol.GenvexPayload = GenvexPayload


-- IPX Payload (converted from Python)
protocol.GenvexPayloadIPX = setmetatable({}, GenvexPayload)
protocol.GenvexPayloadIPX.__index = protocol.GenvexPayloadIPX
protocol.GenvexPayloadIPX.requiresChecksum = false
protocol.GenvexPayloadIPX.payloadType = protocol.PayloadType.U_IPX

function protocol.GenvexPayloadIPX:new()
    return setmetatable({}, self)
end

function protocol.GenvexPayloadIPX:buildPayload()
    return table.concat({
        self.payloadType,
        self.payloadFlags,
        string.char(0x00, 0x11), -- Fixed payload length of 17
        string.char(0x00, 0x00, 0x00, 0x00), -- NOT NEEDED Private Network IP
        string.char(0x00, 0x00), -- NOT NEEDED Private Network Port
        string.char(0x00, 0x00, 0x00, 0x00), -- NOT NEEDED Public IP
        string.char(0x00, 0x00), -- NOT NEEDED Public Port
        string.char(0x80) -- disable rendez-vous
    })
end


-- CP_ID Payload (Authorized Email)
protocol.GenvexPayloadCP_ID = setmetatable({}, GenvexPayload)
protocol.GenvexPayloadCP_ID.__index = protocol.GenvexPayloadCP_ID
protocol.GenvexPayloadCP_ID.requiresChecksum = false
protocol.GenvexPayloadCP_ID.payloadType = protocol.PayloadType.U_CP_ID

function protocol.GenvexPayloadCP_ID:new(email)
    local obj = setmetatable({}, self)
    obj.email = email or ""
    return obj
end

function protocol.GenvexPayloadCP_ID:setEmail(email)
    self.email = email
end

function protocol.GenvexPayloadCP_ID:buildPayload()
    local length = 5 + string.len(self.email)
    return table.concat({
        self.payloadType,
        self.payloadFlags,
        binary.pack_u16_be(length),
        string.char(0x01), -- ID type email
        self.email -- Lua strings are already byte strings
    })
end


-- Abstract Command Payload
local GenvexPayloadWithCommand = setmetatable({}, GenvexPayload)
GenvexPayloadWithCommand.__index = GenvexPayloadWithCommand
function GenvexPayloadWithCommand:new(command)
    local o = setmetatable({}, self)
    o.command = command
    return o
end
function GenvexPayloadWithCommand:buildPayload()
    local command_data = self.command:buildCommand()
    local payload_length = #command_data
    return table.concat({
        binary.pack_u16_be(self.payloadType),
        binary.pack_u16_be(payload_length),
        command_data
    })
end

-- CMD Payload
protocol.GenvexPayloadCMD = setmetatable({ payloadType = 52 }, GenvexPayloadWithCommand) -- 0x34
protocol.GenvexPayloadCMD.__index = protocol.GenvexPayloadCMD

-- CRYPT Payload
protocol.GenvexPayloadCRYPT = setmetatable({ payloadType = 54 }, GenvexPayloadWithCommand) -- 0x36
protocol.GenvexPayloadCRYPT.__index = protocol.GenvexPayloadCRYPT


---
--- Command Definitions
---

-- Base Command "class"
local GenvexCommand = {}
GenvexCommand.__index = GenvexCommand
function GenvexCommand:buildCommand()
    error("buildCommand() must be overridden in subclasses")
end

-- Ping Command (converted from Python)
protocol.GenvexCommandPing = setmetatable({}, GenvexCommand)
protocol.GenvexCommandPing.__index = protocol.GenvexCommandPing

function protocol.GenvexCommandPing:new()
    return setmetatable({}, self)
end

function protocol.GenvexCommandPing:buildCommand()
    return table.concat({
        string.char(0x00, 0x00, 0x00), -- Three null bytes
        protocol.CommandType.PING,     -- PING command type (0x11)
        string.char(0x70, 0x69, 0x6e, 0x67) -- "ping" in ASCII
    })
end

-- CRYPT Payload (converted from Python)
protocol.GenvexPayloadCrypt = setmetatable({}, GenvexPayload)
protocol.GenvexPayloadCrypt.__index = protocol.GenvexPayloadCrypt
protocol.GenvexPayloadCrypt.requiresChecksum = true
protocol.GenvexPayloadCrypt.payloadType = protocol.PayloadType.U_CRYPT

function protocol.GenvexPayloadCrypt:new()
    local obj = setmetatable({}, self)
    obj.data = ""
    return obj
end

function protocol.GenvexPayloadCrypt:setData(data)
    self.data = data
end

function protocol.GenvexPayloadCrypt:buildPayload()
    local length = 6 + string.len(self.data) + 3 -- Header + Crypto code + data length + padding and checksum
    return table.concat({
        self.payloadType,
        self.payloadFlags,
        binary.pack_u16_be(length),
        string.char(0x00, 0x0a), -- Crypto code for the payload
        self.data,
        string.char(0x02) -- Padding??
    })
end



-- Datapoint Read List Command
protocol.GenvexCommandDatapointReadList = setmetatable({}, GenvexCommand)
protocol.GenvexCommandDatapointReadList.__index = protocol.GenvexCommandDatapointReadList

function protocol.GenvexCommandDatapointReadList:new(datapoints)
    local o = setmetatable({}, self)
    -- datapoints is a table of tables, where each inner table has 'obj' and 'address' keys.
    o.datapoints = datapoints or {}
    return o
end

function protocol.GenvexCommandDatapointReadList:buildCommand()
    local request_parts = {}
    for _, datapoint in ipairs(self.datapoints) do
        table.insert(request_parts, string.char(datapoint.obj))
        table.insert(request_parts, binary.pack_u32_be(datapoint.address))
    end

    return table.concat({
        string.char(0, 0, 0),
        protocol.CommandType.DATAPOINT_READLIST,
        binary.pack_u16_be(#self.datapoints),
        table.concat(request_parts),
        string.char(1) -- Terminator
    })
end

-- Setpoint Read List Command
protocol.GenvexCommandSetpointReadList = setmetatable({}, GenvexCommand)
protocol.GenvexCommandSetpointReadList.__index = protocol.GenvexCommandSetpointReadList

function protocol.GenvexCommandSetpointReadList:new(setpoints)
    local o = setmetatable({}, self)
    o.setpoints = setpoints or {}
    return o
end

function protocol.GenvexCommandSetpointReadList:buildCommand()
    local request_parts = {}
    for _, setpoint in ipairs(self.setpoints) do
        table.insert(request_parts, string.char(setpoint.read_obj))
        table.insert(request_parts, binary.pack_u16_be(setpoint.read_address))
    end

    return table.concat({
        string.char(0, 0, 0),
        protocol.CommandType.SETPOINT_READLIST,
        binary.pack_u16_be(#self.setpoints),
        table.concat(request_parts),
        string.char(1) -- Terminator
    })
end

-- Setpoint Write List Command
protocol.GenvexCommandSetpointWriteList = setmetatable({}, GenvexCommand)
protocol.GenvexCommandSetpointWriteList.__index = protocol.GenvexCommandSetpointWriteList

function protocol.GenvexCommandSetpointWriteList:new(setpoints)
    local o = setmetatable({}, self)
    -- setpoints is a table of tables, where each inner table has 'obj', 'address', and 'value' keys.
    o.setpoints = setpoints or {}
    return o
end

function protocol.GenvexCommandSetpointWriteList:buildCommand()
    local request_parts = {}
    for _, setpoint in ipairs(self.setpoints) do
        table.insert(request_parts, string.char(setpoint.obj))
        table.insert(request_parts, binary.pack_u32_be(setpoint.address))
        table.insert(request_parts, binary.pack_u16_be(setpoint.value))
    end

    return table.concat({
        string.char(0, 0, 0),
        protocol.CommandType.SETPOINT_WRITELIST,
        binary.pack_u16_be(#self.setpoints),
        table.concat(request_parts),
        string.char(1) -- Terminator
    })
end

return protocol