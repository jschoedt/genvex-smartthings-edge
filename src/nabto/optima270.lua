--- Genvex Optima 270 Model Definition in Lua
--- This module defines the specific datapoints and setpoints for the Optima 270 model

local BaseModel = require("nabto.basemodel")

-- Create the subclass
local GenvexNabtoOptima270 = {}
GenvexNabtoOptima270.__index = GenvexNabtoOptima270

-- Set up inheritance properly
setmetatable(GenvexNabtoOptima270, {__index = BaseModel.GenvexNabtoBaseModel})

---
--- Constructor for GenvexNabtoOptima270
--- @param slaveDeviceModel string The slave device model identifier
--- @return table The new Optima270 model instance
---
function GenvexNabtoOptima270:new(slaveDeviceModel)
    -- Call the parent constructor with the correct syntax
    local instance = BaseModel.GenvexNabtoBaseModel:new(slaveDeviceModel)
    
    -- Set up the metatable for this specific instance
    setmetatable(instance, self)

    -- Define datapoints specific to Optima 270
    instance._datapoints = {
        [BaseModel.GenvexNabtoDatapointKey.TEMP_SUPPLY] = BaseModel.createGenvexNabtoDatapoint(20, 0, 10, -300),
        [BaseModel.GenvexNabtoDatapointKey.TEMP_OUTSIDE] = BaseModel.createGenvexNabtoDatapoint(21, 0, 10, -300),
        [BaseModel.GenvexNabtoDatapointKey.TEMP_EXHAUST] = BaseModel.createGenvexNabtoDatapoint(22, 0, 10, -300),
        [BaseModel.GenvexNabtoDatapointKey.TEMP_EXTRACT] = BaseModel.createGenvexNabtoDatapoint(23, 0, 10, -300),
        [BaseModel.GenvexNabtoDatapointKey.HUMIDITY] = BaseModel.createGenvexNabtoDatapoint(26, 0, 1, 0),
        [BaseModel.GenvexNabtoDatapointKey.DUTYCYCLE_SUPPLY] = BaseModel.createGenvexNabtoDatapoint(18, 0, 100, 0),
        [BaseModel.GenvexNabtoDatapointKey.DUTYCYCLE_EXTRACT] = BaseModel.createGenvexNabtoDatapoint(19, 0, 100, 0),
        [BaseModel.GenvexNabtoDatapointKey.RPM_SUPPLY] = BaseModel.createGenvexNabtoDatapoint(35, 0, 1, 0),
        [BaseModel.GenvexNabtoDatapointKey.RPM_EXTRACT] = BaseModel.createGenvexNabtoDatapoint(36, 0, 1, 0),
        [BaseModel.GenvexNabtoDatapointKey.PREHEAT_PWM] = BaseModel.createGenvexNabtoDatapoint(41, 0, 100, 0),
        [BaseModel.GenvexNabtoDatapointKey.REHEAT_PWM] = BaseModel.createGenvexNabtoDatapoint(42, 0, 100, 0),
        [BaseModel.GenvexNabtoDatapointKey.BYPASS_ACTIVE] = BaseModel.createGenvexNabtoDatapoint(53, 0, 1, 0),
        [BaseModel.GenvexNabtoDatapointKey.ALARM_OPTIMA270] = BaseModel.createGenvexNabtoDatapoint(38, 0, 1, 0),
        [BaseModel.GenvexNabtoDatapointKey.ROTOR_SPEED] = BaseModel.createGenvexNabtoDatapoint(50, 0, 1, 0)
    }

    -- Define setpoints specific to Optima 270
    instance._setpoints = {
        [BaseModel.GenvexNabtoSetpointKey.FAN_SPEED] = BaseModel.createGenvexNabtoSetpoint(7, 24, 0, 4, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.TEMP_SETPOINT] = BaseModel.createGenvexNabtoSetpoint(1, 12, 0, 200, 0, 0, 10, 100, 0.5),
        [BaseModel.GenvexNabtoSetpointKey.BYPASS_OPENOFFSET] = BaseModel.createGenvexNabtoSetpoint(21, 52, 10, 100, 0, 0, 10, 0, 0.1),
        [BaseModel.GenvexNabtoSetpointKey.REHEATING] = BaseModel.createGenvexNabtoSetpoint(3, 16, 0, 1, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.HUMIDITY_CONTROL] = BaseModel.createGenvexNabtoSetpoint(6, 22, 0, 1, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.BOOST_ENABLE] = BaseModel.createGenvexNabtoSetpoint(30, 70, 0, 1, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.BOOST_TIME] = BaseModel.createGenvexNabtoSetpoint(70, 150, 1, 120, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.FILTER_DAYS] = BaseModel.createGenvexNabtoSetpoint(100, 210, 0, 65535, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.FILTER_RESET] = BaseModel.createGenvexNabtoSetpoint(50, 110, 0, 2, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL1] = BaseModel.createGenvexNabtoSetpoint(10, 30, 0, 100, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL2] = BaseModel.createGenvexNabtoSetpoint(11, 32, 0, 100, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL3] = BaseModel.createGenvexNabtoSetpoint(12, 34, 0, 100, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL4] = BaseModel.createGenvexNabtoSetpoint(8, 26, 0, 100, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL1] = BaseModel.createGenvexNabtoSetpoint(13, 36, 0, 100, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL2] = BaseModel.createGenvexNabtoSetpoint(14, 38, 0, 100, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL3] = BaseModel.createGenvexNabtoSetpoint(15, 40, 0, 100, 0, 0, 1, 0, 1.0),
        [BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL4] = BaseModel.createGenvexNabtoSetpoint(9, 28, 0, 100, 0, 0, 1, 0, 1.0)
    }

    -- Define default datapoint request
    instance._defaultDatapointRequest = {
        BaseModel.GenvexNabtoDatapointKey.TEMP_SUPPLY,
        BaseModel.GenvexNabtoDatapointKey.TEMP_OUTSIDE,
        BaseModel.GenvexNabtoDatapointKey.TEMP_EXHAUST,
        BaseModel.GenvexNabtoDatapointKey.TEMP_EXTRACT,
        BaseModel.GenvexNabtoDatapointKey.HUMIDITY,
        BaseModel.GenvexNabtoDatapointKey.DUTYCYCLE_SUPPLY,
        BaseModel.GenvexNabtoDatapointKey.DUTYCYCLE_EXTRACT,
        BaseModel.GenvexNabtoDatapointKey.RPM_SUPPLY,
        BaseModel.GenvexNabtoDatapointKey.RPM_EXTRACT,
        BaseModel.GenvexNabtoDatapointKey.PREHEAT_PWM,
        BaseModel.GenvexNabtoDatapointKey.REHEAT_PWM,
        BaseModel.GenvexNabtoDatapointKey.BYPASS_ACTIVE,
        BaseModel.GenvexNabtoDatapointKey.ALARM_OPTIMA270,
        BaseModel.GenvexNabtoDatapointKey.ROTOR_SPEED
    }

    -- Define default setpoint request
    instance._defaultSetpointRequest = {
        BaseModel.GenvexNabtoSetpointKey.FAN_SPEED,
        BaseModel.GenvexNabtoSetpointKey.TEMP_SETPOINT,
        BaseModel.GenvexNabtoSetpointKey.BYPASS_OPENOFFSET,
        BaseModel.GenvexNabtoSetpointKey.REHEATING,
        BaseModel.GenvexNabtoSetpointKey.HUMIDITY_CONTROL,
        BaseModel.GenvexNabtoSetpointKey.BOOST_ENABLE,
        BaseModel.GenvexNabtoSetpointKey.BOOST_TIME,
        BaseModel.GenvexNabtoSetpointKey.FILTER_DAYS,
        BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL1,
        BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL2,
        BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL3,
        BaseModel.GenvexNabtoSetpointKey.SUPPLY_AIR_LEVEL4,
        BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL1,
        BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL2,
        BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL3,
        BaseModel.GenvexNabtoSetpointKey.EXTRACT_AIR_LEVEL4
    }

    return instance
end

-- Override methods from the base class
function GenvexNabtoOptima270:getModelName()
    return "Optima 270"
end

function GenvexNabtoOptima270:getManufacturer()
    return "Genvex"
end

-- Return the class for module loading
return GenvexNabtoOptima270