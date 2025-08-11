--- Base model for all Genvex devices in Lua
--- This module provides the base functionality and constants for Genvex Nabto models

local BaseModel = {}

-- Define data point and setpoint keys, similar to the Python library's classes
local GenvexNabtoDatapointKey = {
    -- Temperature of the air to supplied to the house
    TEMP_SUPPLY = "temp_supply",
    -- Temperature of the air passing through the heater
    TEMP_SUPPLY_AFTER_HEATER = "temp_supply_after_heater",
    -- Temperature of the air outside the house, being pulled into the system
    TEMP_OUTSIDE = "temp_outside",
    -- Temperature of the air being exhausted from the system to the outside
    TEMP_EXHAUST = "temp_exhaust",
    -- Temperature of the air being extracted from the house into the system
    TEMP_EXTRACT = "temp_extract",
    -- Temperature of the condenser in the heatpump
    TEMP_CONDENSER = "temp_condenser",
    -- Temperature of the evaporator in the heatpump
    TEMP_EVAPORATOR = "temp_evaporator",
    -- Temperature of the room sensor
    TEMP_ROOM = "temp_room",
    -- Temperature of the heater
    TEMP_HEATER = "temp_heater",
    HUMIDITY = "humidity",
    -- The current fan level from 0 to 4
    FAN_LEVEL_SUPPLY = "fan_level_supply",
    FAN_LEVEL_EXTRACT = "fan_level_extract",
    -- The current dutycycle of the supply and extract fans from 0 to 100
    DUTYCYCLE_SUPPLY = "fan_speed_supply",
    DUTYCYCLE_EXTRACT = "fan_speed_extract",
    -- The current RPM of the supply and extract fans from 0 to their max RPM
    RPM_SUPPLY = "fan_rpm_supply",
    RPM_EXTRACT = "fan_rpm_extract",
    -- The current m3/h of the supply and extract fans from 0 to their max m3/h
    M3H_SUPPLY = "fan_m3h_supply",
    M3H_EXTRACT = "fan_m3h_extract",
    -- The current PWM of the heating elements from 0 to 100
    PREHEAT_PWM = "preheat_pwm",
    REHEAT_PWM = "reheat_pwm",
    -- The current RPM of the rotor from 0 to its max RPM
    ROTOR_SPEED = "rotor_speed",
    -- Indicates if the bypass currently is active (Opened)
    BYPASS_ACTIVE = "bypass_active",
    -- The temperature of the hot water in the tank in the top
    HOTWATER_TOP = "hotwater_top",
    -- The temperature of the hot water in the tank in the bottom
    HOTWATER_BOTTOM = "hotwater_bottom",
    -- Indicates if the summer mode is active
    SUMMER_MODE = "summer_mode",
    -- Indicates if the sacrificial anode has a problem. 0 = OK, 1 = Problem
    SACRIFICIAL_ANODE = "sacrificial_anode",
    -- The current CO2 level in the house
    CO2_LEVEL = "co2_level",
    -- The current days left before planned filter change
    FILTER_DAYS_LEFT = "filter_days_left",
    -- Indicates if the defrost is currently active
    DEFROST_ACTIVE = "defrost_active",
    -- The time since the last defrost
    DEFORST_TIMESINCELAST = "defrost_timesincelast",
    CONTROLSTATE_602 = "controlstate_602",
    ALARM_OPTIMA270 = "alarm_optima270",
    ALARM_CTS602NO1 = "alarm_cts602no1",
    ALARM_CTS602NO2 = "alarm_cts602no2",
    ALARM_CTS602NO3 = "alarm_cts602no3",
    ALARM_CTS400CRITICAL = "alarm_cts400critical",
    ALARM_CTS400WARNING = "alarn_cts400warning",
    ALARM_CTS400INFO = "alarm_cts400info",

    -- CTS 602 Compact P
    HPS_CAPACITY_ACTUAL = "hps_capacity_actual",
    HPS_OPERATION_STATE = "hps_operation_state",
    HPS_HEATPUMP_ACTIVE = "hps_heatpump_active",
    HPS_HEATER_ACTIVE = "hps_heater_active",
    HPS_TEMP_AFTER_CONDENSER = "hps_temp_after_condenser", -- Heatpump equiped T17
    HPS_TEMP_BEFORE_CONDENSER = "hps_temp_before_condenser", -- Heatpump equiped T16
    HPS_TEMP_BUFFERTANK = "hps_temp_buffertank", -- Heatpump equiped T18
    HPS_TEMP_HEATPUMP_OUTDOOR = "hps_temp_heatpump_outdoor", -- Heatpump equiped T20
    HPS_TEMP_PRESSURE_PIPE = "hps_temp_pressure_pipe", -- Heatpump equiped T19

    CENTRALHEAT_TEMP_SUPPLY = "centralheat_temp_supply",
    CENTRALHEAT_TEMP_RETURN = "centralheat_temp_return",
}

local GenvexNabtoSetpointKey = {
    FAN_SPEED = "fan_speed",
    TEMP_SETPOINT = "temp_setpoint",
    BYPASS_OPENOFFSET = "bypass_openoffset", -- EE1
    REHEATING = "reheating", -- A1
    PREHEATING = "preheating", -- A1
    HUMIDITY_CONTROL = "humidity_control", -- A2
    BOOST_ENABLE = "boost_enable",
    BOOST_TIME = "boost_time", -- A3
    FILTER_DAYS = "filter_days",
    FILTER_HOURS = "filter_hours",
    FILTER_RESET = "filter_reset",
    FILTER_MONTHS_SETTING = "filter_months_setting",
    FILTER_DAYS_SETTING = "filter_days_setting",
    SUPPLY_AIR_LEVEL1 = "supply_air_level1",
    SUPPLY_AIR_LEVEL2 = "supply_air_level2",
    SUPPLY_AIR_LEVEL3 = "supply_air_level3",
    SUPPLY_AIR_LEVEL4 = "supply_air_level4",
    EXTRACT_AIR_LEVEL1 = "extract_air_level1",
    EXTRACT_AIR_LEVEL2 = "extract_air_level2",
    EXTRACT_AIR_LEVEL3 = "extract_air_level3",
    EXTRACT_AIR_LEVEL4 = "extract_air_level4",
    HOTWATER_TEMP = "hotwater_temp",
    HOTWATER_BOOSTTEMP = "hotwater_boosttemp",
    ANTILEGIONELLA_DAY = "antilegionella_day",
    SUPPLYAIR_MIN_TEMP_SUMMER = "supplyair_min_temp_summer",
    SUPPLYAIR_MAX_TEMP_SUMMER = "supplyair_max_temp_summer",
    COOLING_PRIORITY = "cooling_priority",
    COOLING_ENABLE = "cooling_enable",
    COOLING_TEMPERATURE = "cooling_temperature",
    COOLING_OFFSET = "cooling_offset",
    VENTILATION_ENABLE = "ventilation_enable",
    CENTRALHEAT_SUPPLY_MIN = "centralheat_supply_min",
    CENTRALHEAT_SUPPLY_MAX = "centralheat_supply_max",
    CENTRALHEAT_PUMP_MODE = "centralheat_pump_mode",
    CENTRALHEAT_TYPE = "centralheat_type",
    CENTRALHEAT_SELECT = "centralheat_select",
}

---
--- Creates a new GenvexNabtoDatapoint configuration
--- @param address number The address of the datapoint
--- @param obj number|nil The object ID (default 0)
--- @param divider number|nil The divider value (default 1)
--- @param offset number|nil The offset value (default 0)
--- @return table The datapoint configuration
---
local function createGenvexNabtoDatapoint(address, obj, divider, offset)
    return {
        obj = obj or 0,
        address = address,
        divider = divider or 1,
        offset = offset or 0
    }
end

---
--- Creates a new GenvexNabtoSetpoint configuration
--- @param read_address number The read address of the setpoint
--- @param write_address number The write address of the setpoint
--- @param min number The minimum value
--- @param max number The maximum value
--- @param read_obj number|nil The read object ID (default 0)
--- @param write_obj number|nil The write object ID (default 0)
--- @param divider number|nil The divider value (default 1)
--- @param offset number|nil The offset value (default 0)
--- @param step number|nil The step value (default 1.0)
--- @return table The setpoint configuration
---
local function createGenvexNabtoSetpoint(read_address, write_address, min, max, read_obj, write_obj, divider, offset, step)
    return {
        read_obj = read_obj or 0,
        read_address = read_address,
        write_obj = write_obj or 0,
        write_address = write_address,
        divider = divider or 1,
        offset = offset or 0,
        min = min,
        max = max,
        step = step or 1.0
    }
end

---
--- Base model "class" for all Genvex devices.
--- This serves as the prototype for all device models.
---
local GenvexNabtoBaseModel = {}
GenvexNabtoBaseModel.__index = GenvexNabtoBaseModel

---
--- Constructor for GenvexNabtoBaseModel
--- @param slaveDeviceModel string The slave device model identifier
--- @return table The new base model instance
---
function GenvexNabtoBaseModel:new(slaveDeviceModel)
    local instance = {
        _datapoints = {},
        _setpoints = {},
        _quirks = {},
        _defaultDatapointRequest = {},
        _defaultSetpointRequest = {},
        _slaveDeviceModel = slaveDeviceModel
    }
    setmetatable(instance, self)
    return instance
end

---
--- Get the model name (to be overridden by subclasses)
--- @return string The model name
---
function GenvexNabtoBaseModel:getModelName()
    return "Basemodel"
end

---
--- Get the manufacturer name (to be overridden by subclasses)
--- @return string The manufacturer name
---
function GenvexNabtoBaseModel:getManufacturer()
    return ""
end

---
--- Check if the model provides a specific datapoint
--- @param datapoint string The datapoint key
--- @return boolean True if the model provides the datapoint
---
function GenvexNabtoBaseModel:modelProvidesDatapoint(datapoint)
    return self._datapoints[datapoint] ~= nil
end

---
--- Get the default datapoint request list
--- @return table List of default datapoint keys
---
function GenvexNabtoBaseModel:getDefaultDatapointRequest()
    return self._defaultDatapointRequest
end

---
--- Check if the model provides a specific setpoint
--- @param setpoint string The setpoint key
--- @return boolean True if the model provides the setpoint
---
function GenvexNabtoBaseModel:modelProvidesSetpoint(setpoint)
    return self._setpoints[setpoint] ~= nil
end

---
--- Get the default setpoint request list
--- @return table List of default setpoint keys
---
function GenvexNabtoBaseModel:getDefaultSetpointRequest()
    return self._defaultSetpointRequest
end

---
--- Check if a device has a specific quirk
--- @param quirk string The quirk name
--- @param device number The device identifier
--- @return boolean True if the device has the quirk
---
function GenvexNabtoBaseModel:deviceHasQuirk(quirk, device)
    if not self._quirks[quirk] then
        return false
    end
    for _, dev in ipairs(self._quirks[quirk]) do
        if dev == device then
            return true
        end
    end
    return false
end

---
--- Add device quirks (to be overridden by subclasses)
---
function GenvexNabtoBaseModel:addDeviceQuirks()
    -- Override in subclasses
end

---
--- Finish loading the model by setting default values
--- This method is called by subclasses to add default values to datapoints and setpoints
---
function GenvexNabtoBaseModel:finishLoading()
    -- Add default values to datapoints
    for key, datapoint in pairs(self._datapoints) do
        if datapoint.obj == nil then
            datapoint.obj = 0
        end
        if datapoint.divider == nil then
            datapoint.divider = 1
        end
        if datapoint.offset == nil then
            datapoint.offset = 0
        end
    end

    -- Add default values to setpoints
    for key, setpoint in pairs(self._setpoints) do
        if setpoint.read_obj == nil then
            setpoint.read_obj = 0
        end
        if setpoint.write_obj == nil then
            setpoint.write_obj = 0
        end
        if setpoint.divider == nil then
            setpoint.divider = 1
        end
        if setpoint.offset == nil then
            setpoint.offset = 0
        end
        if setpoint.step == nil then
            setpoint.step = 1.0
        end
    end
end

-- Export the module
BaseModel.GenvexNabtoDatapointKey = GenvexNabtoDatapointKey
BaseModel.GenvexNabtoSetpointKey = GenvexNabtoSetpointKey
BaseModel.createGenvexNabtoDatapoint = createGenvexNabtoDatapoint
BaseModel.createGenvexNabtoSetpoint = createGenvexNabtoSetpoint
BaseModel.GenvexNabtoBaseModel = GenvexNabtoBaseModel

return BaseModel