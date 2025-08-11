local socket = require "cosock.socket"
local cosock = require "cosock"
local log = require "log"
local binary = require "nabto/binary"
local protocol = require "nabto/protocol"
local ModelAdapter = require "nabto/model_adapter"

-- Helper function to convert a string to a hex representation for logging
local function to_hex_string(str)
    if str == nil then return "<nil>" end
    return (string.gsub(str, ".", function(c)
        return string.format("%02x ", string.byte(c))
    end))
end


-- Constants
local SOCKET_TIMEOUT = 1 -- seconds
local SOCKET_MAXSIZE = 1024
local CONNECTION_TIMEOUT = 15 -- seconds


local GenvexConnection = {}
GenvexConnection.__index = GenvexConnection

function GenvexConnection.new(driver, authorized_email)
    local self = setmetatable({}, GenvexConnection)
    log.info("Starting GenvexNabto in Lua")

    self.driver = driver
    self.authorized_email = authorized_email or ""

    -- Generate a random 4-byte client ID
    self.client_id = binary.pack_u32_be(math.random(0, 0xFFFFFFFF))
    self.server_id = string.char(0, 0, 0, 0)

    self.refresh_callback = function() end
    self.connected_callback = function() end
    self.model_set_callback = function() end

    self.device_id = nil
    self.device_ip = nil
    self.device_port = protocol.DEVICE_DEFAULT_PORT

    self.model_adapter = nil
    self.is_running = false
    self.last_response = 0
    self.last_data_update = 0
    self.last_setpoint_update = 0

    self.sock = nil
    self.discovered_devices = {}

    return self
end

function GenvexConnection:start()
    if self.is_running then
        return
    end
    self.is_running = false

    self.sock = socket.udp()
    if not self.sock then
        log.error("Failed to create UDP socket")
        return
    end

    ok, err = self.sock:settimeout(SOCKET_TIMEOUT)
    if not ok then
        log.error("Failed to set socket timeout: ", err or "unknown error")
        self.sock:close()
        return
    end


    -- Bind to a random port
    ok, err = self.sock:setsockname("0.0.0.0", 0)
    if not ok then
        log.error("Failed to bind socket: ", err)
        self.sock:close()
        return
    end

    ok, err = self.sock:setoption('broadcast', true)
    if not ok then
        log.error("Failed to set broadcast option: ", err)
        self.sock:close()
        return
    end

    log.info("Start the main coroutine for listening")
    cosock.spawn(function() self:_receive_loop() end, "receive_loop")

    self.is_running = true
end

function GenvexConnection:stop()
    self.is_running = false
    if self.sock then
        self.sock:close()
        self.sock = nil
    end
    log.info("Genvex connection stopped.")
end

function GenvexConnection:set_device(device_id)
    self.device_id = device_id
    if self.discovered_devices[device_id] then
        self.device_ip, self.device_port = self.discovered_devices[device_id][1], self.discovered_devices[device_id][2]
        log.info(string.format("Using cached IP for %s -> %s:%d", device_id, self.device_ip, self.device_port))
        self:_connect_to_device()
    else
        log.info(string.format("Device %s not found in cache, sending discovery...", device_id))
        self:send_discovery(device_id)
    end
end

function GenvexConnection:set_manual_ip(ip, port)
    self.device_ip = ip
    self.device_port = port or protocol.DEVICE_DEFAULT_PORT
    self.device_id = ip:gsub("%.", "")
    self.discovered_devices[self.device_id] = { ip, self.device_port }
    self:_connect_to_device()
end

function GenvexConnection:send_discovery(specific_device)
    if not self.sock then
        return
    end
    log.info("Broadcasting for device discovery...")
    local discover_packet = protocol.GenvexDiscovery.build_packet(specific_device)
    local ok, err = self.sock:sendto(discover_packet, protocol.BROADCAST_ADDRESS, protocol.DISCOVERY_PORT)
    if not ok then
        log.error("Failed to send discovery packet: ", err or "unknown error", " Packet: ".. to_hex_string(discover_packet))
    else
        log.info("Discovery packet sent successfully: " .. to_hex_string(discover_packet))
    end
end


function GenvexConnection:_connect_to_device()
    if not self.sock or not self.device_ip then
        log.warn("Cannot connect: socket or device IP is not ready.")
        return
    end

    -- Create the necessary payloads for the connection packet
    local IPXPayload = protocol.GenvexPayloadIPX:new()
    local CP_IDPayload = protocol.GenvexPayloadCP_ID:new(self.authorized_email)

    -- Build the full connection packet using the protocol definition
    local packet = protocol.GenvexPacket.build_packet(
            self.client_id,
            self.server_id,
            protocol.PacketType.U_CONNECT,
            0, -- Sequence ID for connect is typically 0
            { IPXPayload, CP_IDPayload }
    )

    log.info(string.format("Sending connect packet to %s:%d", self.device_ip, self.device_port))
    local ok, err = self.sock:sendto(packet, self.device_ip, self.device_port)
    if not ok then
        log.error("Failed to send connect packet: ", err or "unknown error", " Packet: ".. to_hex_string(packet))
    else
        log.info("Connect packet sent successfully: " .. to_hex_string(packet))
    end
end

--- Main loop for receiving data from the socket
function GenvexConnection:_receive_loop()
    while self.is_running do
        local data, err_or_ip, port = self.sock:receivefrom(SOCKET_MAXSIZE)
        if data then
            log.info("loop got data: "..data)
            local ok, err = pcall(function()
                self:_process_received_message(data, { err_or_ip, port })
            end)
            if not ok then
                log.error("Error processing received message: " .. tostring(err))
            end
        else
            -- Check the error message returned as the second value
            local err = err_or_ip
            if err ~= "timeout" then
                -- If the error is not a timeout (e.g., "closed"), log it and break the loop.
                log.error("Socket error in receive loop, exiting:", err)
                self.is_running = false
                break
            end
            -- If it was a timeout, we simply continue the loop to wait for the next message.
        end
    end
end

--- Loop for handling periodic tasks like polling and keep-alives
--[[function GenvexConnection:periodic_tasks_loop()
    if self.is_running then
        local current_time = os.time()
        if self.is_connected then
            -- Request datapoint update
            if current_time - self.last_data_update > DATAPOINT_UPDATEINTERVAL then
                log.debug("Requesting datapoint update...")
                self:_send_data_state_request(100)
            end

            -- Request setpoint update
            if current_time - self.last_setpoint_update > SETPOINT_UPDATEINTERVAL then
                log.debug("Requesting setpoint update...")
                self:_send_setpoint_state_request(200)
            end

            -- Check for connection timeout and reconnect if needed
            if current_time - self.last_response > SECONDS_UNTILRECONNECT then
                log.warn("Connection timed out. Reconnecting...")
                self.is_connected = false
                self:_connect_to_device()
            end
        end
    end
end]]

function GenvexConnection:_should_reconnect()
    local current_time = os.time()
    return current_time - self.last_response > CONNECTION_TIMEOUT
end


function GenvexConnection:refresh()
    if not self.is_running then
        log.warn("Cannot refresh: connection is not active or not running")
        return
    end

    local callback = function()
        self:_send_data_state_request(100)
        self:_send_setpoint_state_request(200)
    end

    if self:_should_reconnect() then
        log.warn("Connection timed out. Reconnecting...")
        self.refresh_callback = callback
        self:_connect_to_device()
    else
        callback()
    end
end


function GenvexConnection:_process_received_message(message, address)
    -- Check for Discovery Response first
    if string.sub(message, 1, 4) == string.char(0x00, 0x80, 0x00, 0x01) then
        log.debug("Processing a discovery response packet.")
        -- Response structure: 19 bytes header, then null-terminated device ID string
        local discovery_response = string.sub(message, 20)

        -- Find the end of the device ID string (null terminator)
        local device_id_end = string.find(discovery_response, "\0", 1, true)
        if not device_id_end then
            log.warn("Could not find null terminator in discovery response.")
            return
        end

        local device_id = string.sub(discovery_response, 1, device_id_end - 1)

        -- Check if it's a valid Genvex device response
        if string.find(device_id, "remote.lscontrol.dk", 1, true) then
            log.info(string.format("Discovered device '%s' at %s:%d", device_id, address[1], address[2]))
            -- Add the device to our list if not seen before
            if not self.discovered_devices[device_id] then
                self.discovered_devices[device_id] = { address[1], address[2] }
            end

            -- If this is the device we were specifically looking for, store its IP
            if self.device_id and device_id == self.device_id then
                self.device_ip, self.device_port = address[1], address[2]
            end
        end
        return
    end

    -- If not a discovery packet, check if it's a regular packet intended for us
    if string.sub(message, 1, 4) ~= self.client_id then
        log.debug("Received packet not intended for this client.")
        return -- Not for us
    end

    self.last_response = os.time()

    if #message < 9 then
        log.error("Message too short, expected at least 9 bytes")
        return
    end

    local packet_type = string.sub(message, 9, 9)
    log.info(string.format("Received packet type: ".. to_hex_string(packet_type)))

    if packet_type == protocol.PacketType.U_CONNECT then
        log.debug("U_CONNECT response received")
        -- Check for successful connection (status code == 1)
        if string.sub(message, 21, 24) == binary.pack_u32_be(1) then
            self.server_id = string.sub(message, 25, 28)
            if not self.model_adapter then
                log.info("Successfully connected to device. Pinging to get model info.")
                self:_send_ping()
            else
                self.refresh_callback()
                self.refresh_callback = function()  end
                self.connected_callback()
                self.connected_callback = function()  end
            end
        else
            log.error("Authentication failed. Check authorized email.")
            if self.on_error then
                -- Corresponds to GenvexNabtoConnectionErrorType.AUTHENTICATION_ERROR
                self.on_error("authentication_error")
            end
        end

    elseif packet_type == protocol.PacketType.DATA then
        -- We only care about data packets with crypt payloads (type 0x36)
        if string.byte(message, 17) == 54 then -- 54 is 0x36
            log.debug("Data packet with crypt payload received.")
            local length = binary.unpack_u16_be(message, 19)
            local payload = string.sub(message, 23, 22 + length)
            local sequence_id = binary.unpack_u16_be(message, 13)

            log.debug(string.format("Got payload with sequence ID: %d", sequence_id))

            if sequence_id == 50 then
                -- This is a response to a Ping
                self:_process_ping_payload(payload)
            else
                if self.model_adapter then
                    self.model_adapter:parseDataResponse(sequence_id, payload)
                    if sequence_id == 100 then
                        self.last_data_update = os.time()
                    end
                    if sequence_id == 200 then
                        self.last_setpoint_update = os.time()
                    end
                end
            end
        else
            log.debug("Received data packet, but not a crypt payload. Ignoring.")
        end
    else
        log.debug("Unknown packet type received. Ignoring.")
    end
end

function GenvexConnection:_process_ping_payload(payload)
    -- Extract device information from payload using big-endian byte order
    local device_number = binary.unpack_u32_be(payload, 5)      -- payload[4:8] in Python
    local device_model = binary.unpack_u32_be(payload, 9)       -- payload[8:12] in Python
    local slavedevice_number = binary.unpack_u32_be(payload, 17) -- payload[16:20] in Python
    local slavedevice_model = binary.unpack_u32_be(payload, 21)  -- payload[20:24] in Python

    log.debug(string.format("Got model: %d with device number: %d, slavedevice number: %d and slavedevice model: %d",
            device_model, device_number, slavedevice_number, slavedevice_model))

    -- Check if the model is supported
    if ModelAdapter.providesModel(device_model, device_number, slavedevice_number, slavedevice_model) then

        -- Create the model adapter with proper error handling
        local success, result = pcall(ModelAdapter.new, device_model, device_number, slavedevice_number, slavedevice_model)
        if success and result then
            self.model_adapter = result

            self.model_set_callback()
            self.model_set_callback = function()  end
            self.refresh_callback()
            self.refresh_callback = function()  end
            self.connected_callback()
            self.connected_callback = function()  end

            local model_name = self.model_adapter:getModelName() or "Unknown"
            log.debug(string.format("Loaded model for %s", model_name))

        else
            log.error("Failed to initialize model adapter: " .. tostring(result or "Unknown error"))
            self.model_adapter = nil
            if self.on_error then
                self.on_error("model_initialization_failed")
            end
        end
    else
        log.error(string.format("No model adapter available for model: %d with device number: %d, slavedevice number: %d and slavedevice model: %d",
                device_model, device_number, slavedevice_number, slavedevice_model))
        if self.on_error then
            -- Corresponds to GenvexNabtoConnectionErrorType.UNSUPPORTED_MODEL
            self.on_error("unsupported_model")
        end
    end
end


-- Methods for sending commands
function GenvexConnection:_send_ping()
    if not self.sock or not self.device_ip then
        log.warn("Cannot send ping: socket or device IP is not ready.")
        return
    end

    local ping_cmd = protocol.GenvexCommandPing:new()
    local payload = protocol.GenvexPayloadCrypt:new()
    payload:setData(ping_cmd:buildCommand())

    local packet = protocol.GenvexPacket.build_packet(
            self.client_id,
            self.server_id,
            protocol.PacketType.DATA,
            50,
            { payload }
    )

    local ok, err = self.sock:sendto(packet, self.device_ip, self.device_port)
    if not ok then
        log.error("Failed to send ping packet: ", err or "unknown error")
    else
        log.info("Ping packet sent successfully")
    end
end



function GenvexConnection:_send_data_state_request(sequence_id)
    if not self.model_adapter then
        return
    end
    local datalist = self.model_adapter:getDatapointRequestList(sequence_id)
    if not datalist then
        log.warn("No datapoint list for sequence ID: ", sequence_id)
        return
    end
    local payload = protocol.GenvexPayloadCrypt:new()
    local command = protocol.GenvexCommandDatapointReadList:new(datalist)
    payload:setData(command:buildCommand())
    local packet = protocol.GenvexPacket.build_packet(self.client_id, self.server_id, protocol.PacketType.DATA, sequence_id, { payload })
    self.sock:sendto(packet, self.device_ip, self.device_port)
end

function GenvexConnection:_send_setpoint_state_request(sequence_id)
    if not self.model_adapter then
        return
    end
    local datalist = self.model_adapter:getSetpointRequestList(sequence_id)
    if not datalist then
        log.warn("No setpoint list for sequence ID: ", sequence_id)
        return
    end
    local payload = protocol.GenvexPayloadCrypt:new()
    local command = protocol.GenvexCommandSetpointReadList:new(datalist)
    payload:setData(command:buildCommand())
    local packet = protocol.GenvexPacket.build_packet(self.client_id, self.server_id, protocol.PacketType.DATA, sequence_id, { payload })
    self.sock:sendto(packet, self.device_ip, self.device_port)
end


function GenvexConnection:set_setpoint(setpointKey, newValue)
    if not self.model_adapter then
        log.debug("Cannot set setpoint: model adapter not initialized")
        return false
    end

    if not self.model_adapter:providesValue(setpointKey) then
        log.debug("Model adapter does not provide value for key: " .. setpointKey)
        return false
    end

    -- Get the setpoint data from the model adapter
    local setpointData = self.model_adapter._loadedModel._setpoints[setpointKey]
    if not setpointData then
        log.debug("No setpoint data found for key: " .. setpointKey)
        return false
    end

    -- Convert the new value using the setpoint's scaling factors
    newValue = math.floor((newValue * setpointData.divider) - setpointData.offset)

    -- Check if the value is within the valid range
    if newValue < setpointData.min or newValue > setpointData.max then
        log.debug("Value " .. newValue .. " is outside valid range (" .. setpointData.min .. "-" .. setpointData.max .. ")")
        return false
    end

    -- Create the payload and send the command
    local payload = protocol.GenvexPayloadCrypt:new()
    local command = protocol.GenvexCommandSetpointWriteList:new({
        {
            obj = setpointData.write_obj,
            address = setpointData.write_address,
            value = newValue
        }
    })
    payload:setData(command:buildCommand())

    local packet = protocol.GenvexPacket.build_packet(
            self.client_id,
            self.server_id,
            protocol.PacketType.DATA,
            3,
            { payload }
    )

    local callback = function()
        local ok, err = self.sock:sendto(packet, self.device_ip, self.device_port)
        if not ok then
            log.error("Failed to send setpoint packet: ", err or "unknown error")
            return false
        end
    end

    if self:_should_reconnect() then
        log.warn("Connection timed out. Reconnecting...")
        self.connected_callback = callback
        self:_connect_to_device()
    else
        callback()
    end

    return true
end

-- Getter functions to be called by the driver
function GenvexConnection:get_value(key)
    if self.model_adapter then
        return self.model_adapter:getValue(key)
    end
    return nil
end

function GenvexConnection:register_update_handler(key, handler)
    if self.model_adapter then
        self.model_adapter:registerUpdateHandler(key, handler)
    else
        log.warn("Cannot register handler: model adapter not initialized.")
    end
end

function GenvexConnection:clear_update_handlers()
    if self.model_adapter then
        self.model_adapter._update_handlers = {}
    else
        log.warn("Cannot clear handlers")
    end
end

return GenvexConnection
