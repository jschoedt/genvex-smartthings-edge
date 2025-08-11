--- Manages device model selection, state, and data parsing.
---
--- Defines the data models for different Genvex devices.
--- This module contains the specific datapoint and setpoint IDs for each supported model.
---
local log = require "log"
local binary = require("nabto.binary")

-- Forward declaration of the main table
local ModelAdapter = {}
ModelAdapter.__index = ModelAdapter

--- "Static" function to select the correct model constructor.
-- @return (function|nil) The .new function of the model, or nil.
local function translateToModel(model, deviceNumber, slaveDeviceNumber, slaveDeviceModel)
    if model == 2010 then
        if deviceNumber == 79265 then
            return require("nabto.optima270")
        end
    elseif model == 1040 then
        if slaveDeviceNumber == 79250 then
            if slaveDeviceModel == 8 then
                return require("nabto.optima251")
            elseif slaveDeviceModel == 1 then
                return require("nabto.optima250")
            end
        end
    end
    return nil
end

--- "Static" function to check if a model is supported.
function ModelAdapter.providesModel(model, deviceNumber, slaveDeviceNumber, slaveDeviceModel)
    return translateToModel(model, deviceNumber, slaveDeviceNumber, slaveDeviceModel) ~= nil
end

--- Constructor for the ModelAdapter instance.
function ModelAdapter.new(model, deviceNumber, slaveDeviceNumber, slaveDeviceModel)
    local self = setmetatable({}, ModelAdapter)

    local modelToLoad = translateToModel(model, deviceNumber, slaveDeviceNumber, slaveDeviceModel)
    if not modelToLoad then
        log.error(string.format("Invalid model configuration - model: %d, device: %d, slave device: %d, slave model: %d",
                model or 0, deviceNumber or 0, slaveDeviceNumber or 0, slaveDeviceModel or 0))
        error("Invalid model")
    end

    -- Create model instance
    self._loadedModel = modelToLoad:new(slaveDeviceModel)
    log.info("Model type: " .. type(self._loadedModel or "undefined"))
    log.info(string.format("Loaded model: %s (manufacturer: %s)", self._loadedModel:getModelName(), self._loadedModel:getManufacturer()))

    -- Call device quirks and finish loading if methods exist
    if type(self._loadedModel.addDeviceQuirks) == "function" then
        self._loadedModel:addDeviceQuirks()
    end

    if type(self._loadedModel.finishLoading) == "function" then
        self._loadedModel:finishLoading()
    end

    -- Initialize request lists and handlers
    self._currentDatapointList = { [100] = self._loadedModel:getDefaultDatapointRequest() }
    self._currentSetpointList = { [200] = self._loadedModel:getDefaultSetpointRequest() }
    self._values = {}
    self._update_handlers = {}

    return self
end

--- Get the model name
function ModelAdapter:getModelName()
    return self._loadedModel:getModelName()
end

--- Get the manufacturer name
function ModelAdapter:getManufacturer()
    return self._loadedModel:getManufacturer()
end

--- Check if the model provides a specific value key
function ModelAdapter:providesValue(key)
    return self._loadedModel:modelProvidesDatapoint(key) or self._loadedModel:modelProvidesSetpoint(key)
end

--- Check if a value is currently stored for the given key
function ModelAdapter:hasValue(key)
    return self._values[key] ~= nil
end

--- Get the current value for a given key
function ModelAdapter:getValue(key)
    return self._values[key]
end

--- Get the minimum value for a setpoint key
function ModelAdapter:getMinValue(key)
    if self._loadedModel:modelProvidesSetpoint(key) then
        local sp = self._loadedModel._setpoints[key]
        return (sp.min + sp.offset) / sp.divider
    end
    return false
end

--- Get the maximum value for a setpoint key
function ModelAdapter:getMaxValue(key)
    if self._loadedModel:modelProvidesSetpoint(key) then
        local sp = self._loadedModel._setpoints[key]
        return (sp.max + sp.offset) / sp.divider
    end
    return false
end

--- Get the step value for a setpoint key
function ModelAdapter:getSetpointStep(key)
    if self._loadedModel:modelProvidesSetpoint(key) then
        return self._loadedModel._setpoints[key].step
    end
    return nil
end

--- Register an update handler for a specific key
function ModelAdapter:registerUpdateHandler(key, updateMethod)
    if not self._update_handlers[key] then
        self._update_handlers[key] = {}
    end
    table.insert(self._update_handlers[key], updateMethod)
end



--- Notify all update handlers for values that have changed
function ModelAdapter:notifyAllUpdateHandlers()
    for key, handlers in pairs(self._update_handlers) do
        if self:hasValue(key) then
            for _, method in ipairs(handlers) do
                method(-1, self._values[key])
            end
        end
    end
end

--- Get the datapoint request list for a given sequence ID
function ModelAdapter:getDatapointRequestList(sequenceId)
    if not self._currentDatapointList[sequenceId] then
        return false
    end

    local request_list = {}
    for _, key in ipairs(self._currentDatapointList[sequenceId]) do
        table.insert(request_list, self._loadedModel._datapoints[key])
    end
    return request_list
end

--- Get the setpoint request list for a given sequence ID
function ModelAdapter:getSetpointRequestList(sequenceId)
    if not self._currentSetpointList[sequenceId] then
        return false
    end

    local request_list = {}
    for _, key in ipairs(self._currentSetpointList[sequenceId]) do
        table.insert(request_list, self._loadedModel._setpoints[key])
    end
    return request_list
end

--- Parse a data response based on sequence ID and payload
function ModelAdapter:parseDataResponse(responseSeq, responsePayload)
    log.debug(string.format("Got dataresponse with sequence id: %d", responseSeq))

    if self._currentDatapointList[responseSeq] then
        log.debug("Is a datapoint response")
        return self:parseDatapointResponse(responseSeq, responsePayload)
    elseif self._currentSetpointList[responseSeq] then
        log.debug("Is a setpoint response")
        return self:parseSetpointResponse(responseSeq, responsePayload)
    end
end

--- Parse a datapoint response
function ModelAdapter:parseDatapointResponse(responseSeq, responsePayload)
    if not self._currentDatapointList[responseSeq] then
        log.error(string.format("No datapoint list found for sequence ID: %d", responseSeq))
        return false
    end

    local decodingKeys = self._currentDatapointList[responseSeq]
    log.debug("decodingKeys: " .. tostring(decodingKeys))

    local responseLength = binary.unpack_u16_be(string.sub(responsePayload, 1, 2))

    for position = 0, responseLength - 1 do
        local valueKey = decodingKeys[position + 1] -- Lua is 1-indexed
        local payloadSlice = string.sub(responsePayload, 3 + position * 2, 4 + position * 2)

        -- Calculate the new value based on the payload and the datapoint configuration
        local raw_value = binary.unpack_u16_be(payloadSlice)
        local newValue = raw_value + self._loadedModel._datapoints[valueKey].offset

        if self._loadedModel._datapoints[valueKey].divider > 1 then
            newValue = newValue / self._loadedModel._datapoints[valueKey].divider
        end



        -- Check if the value has changed, if so notify update handlers for that key
        local oldValue = self._values[valueKey]
        log.debug(string.format("Value comparison - Key: %s, Old: %s, New: %s",
                tostring(valueKey), tostring(oldValue), tostring(newValue)))

        if newValue ~= oldValue then
            if self._update_handlers[valueKey] then
                local handlerCount = #self._update_handlers[valueKey]
                log.debug(string.format("Calling %d update handlers for key %s", handlerCount, tostring(valueKey)))
                for _, method in ipairs(self._update_handlers[valueKey]) do
                    -- Pass the old value (which could be nil) and the new value to the handler
                    method(oldValue, newValue)
                end
            end
        end


        self._values[valueKey] = newValue
    end
end

--- Parse a setpoint response
function ModelAdapter:parseSetpointResponse(responseSeq, responsePayload)
    if not self._currentSetpointList[responseSeq] then
        log.error(string.format("No setpoint list found for sequence ID: %d", responseSeq))
        return false
    end

    local decodingKeys = self._currentSetpointList[responseSeq]
    log.debug("decodingKeys: " .. tostring(decodingKeys))

    local responseLength = binary.unpack_u16_be(string.sub(responsePayload, 2, 3))

    for position = 0, responseLength - 1 do
        local valueKey = decodingKeys[position + 1] -- Lua is 1-indexed
        local payloadSlice = string.sub(responsePayload, 4 + position * 2, 5 + position * 2)

        -- Calculate the new value based on the payload and the setpoint configuration
        local raw_value = binary.unpack_u16_be(payloadSlice)
        local newValue = raw_value + self._loadedModel._setpoints[valueKey].offset

        if self._loadedModel._setpoints[valueKey].divider > 1 then
            newValue = newValue / self._loadedModel._setpoints[valueKey].divider
        end

        -- Check if the value has changed, if so notify update handlers for that key
        local oldValue = self._values[valueKey]
        log.debug(string.format("Value comparison - Key: %s, Old: %s, New: %s",
                tostring(valueKey), tostring(oldValue), tostring(newValue)))
        if newValue ~= oldValue then
            if self._update_handlers[valueKey] then
                local handlerCount = #self._update_handlers[valueKey]
                log.debug(string.format("Calling %d update handlers for key %s", handlerCount, tostring(valueKey)))
                for _, method in ipairs(self._update_handlers[valueKey]) do
                    -- Pass the old value (which could be nil) and the new value to the handler
                    method(oldValue, newValue)
                end
            end
        end

        self._values[valueKey] = newValue
    end
end

return ModelAdapter
