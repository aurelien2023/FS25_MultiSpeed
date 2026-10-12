--[[
    Mod name: FS25 MultiSpeed
    Version: 1.0.0.0 (FS25)
]]

local _modDirectory = g_currentModDirectory

if g_specializationManager:getSpecializationByName("multiSpeed") == nil then
    g_specializationManager:addSpecialization('multiSpeed', 'multiSpeed', Utils.getFilename('multiSpeed.lua', g_currentModDirectory), nil)
end

for vehicleTypeName, vehicleType in pairs(g_vehicleTypeManager.types) do 
    if vehicleType == nil then
    elseif SpecializationUtil.hasSpecialization(multiSpeed, vehicleType.specializations) then
    elseif SpecializationUtil.hasSpecialization(Locomotive, vehicleType.specializations) then
    elseif vehicleTypeName == 'trainTimberTrailer' then
    elseif vehicleTypeName == 'trainTrailer' then
    elseif vehicleTypeName == 'pallet' then
    elseif vehicleTypeName == 'horse' then
    else
        g_vehicleTypeManager:addSpecialization(vehicleTypeName, 'multiSpeed')
    end 
end

local function addNewStoreConfig(manager, superFunc, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
    local configurations, defaultConfigurationIds = superFunc(manager, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
    
    local hasSpeedLimit = false
    local isMotorized = false
    if storeItem ~= nil then
        if xmlFile:hasProperty("vehicle.base.speedLimit#value") then
            local speedLimit = xmlFile:getValue("vehicle.base.speedLimit#value")
            if speedLimit > 0.5 then
                hasSpeedLimit = true
            end
        end
        if xmlFile:hasProperty("vehicle.motorized") then
            isMotorized = true
        end
    end
    
    local integrateConfig = false
    if storeItem == nil then
    elseif (hasSpeedLimit == false and isMotorized == false) then
    elseif configurations ~= nil and configurations["multiSpeed"] ~= nil then
    else
        integrateConfig = true
    end
    
    if integrateConfig == true then
        if configurations == nil then
            configurations = {}
        end
        
        local configurationFile = XMLFile.load("multiSpeedXML", _modDirectory .. "multiSpeedConfigurations.xml", xmlFile.schema)
        if configurationFile then
            local configurationDescs = manager:getConfigurations()
            local configurationDesc = configurationDescs["multiSpeed"]
            
            if configurationDesc ~= nil then
                configurations["multiSpeed"] = {}
                local counter = 0
                local maxConfigCount = isMotorized and 2 or nil
                
                while true do
                    if maxConfigCount ~= nil and counter >= maxConfigCount then
                        break
                    end
                    local configKey = string.format(configurationDesc.configurationKey .."(%d)", counter)
                    if not configurationFile:hasProperty(configKey) then
                        break
                    end
                    counter = counter + 1
                    local configItem = configurationDesc.itemClass.new("multiSpeed")
                    configItem:setIndex(counter)
                    if configItem:loadFromXML(configurationFile, configurationDesc.configurationsKey, configKey, baseDir, customEnvironment) then
                        configurations["multiSpeed"][counter] = configItem
                    end
                end
                
                if #configurations["multiSpeed"] > 0 then
                    local kph = " " .. g_i18n:getText("CONFIG_KPH")
                    
                    for i = 1, #configurations["multiSpeed"] do
                        if i == 1 then
                            configurations["multiSpeed"][i].name = g_i18n:getText("CONFIG_OFF")
                        elseif i == 2 then
                            configurations["multiSpeed"][i].name = g_i18n:getText("CONFIG_NO_LIMIT")
                        else
                            local speedValue = SPEEDS[i]
                            if g_gameSettings.useMiles == false then
                                configurations["multiSpeed"][i].name = tostring(speedValue) .. kph
                            else
                                local mphValue = math.floor(speedValue / 1.609344 * 10) / 10
                                configurations["multiSpeed"][i].name = tostring(mphValue) .. " mph"
                            end
                        end
                    end
                    
                    if defaultConfigurationIds ~= nil then
                        defaultConfigurationIds["multiSpeed"] = ConfigurationUtil.getDefaultConfigIdFromItems(configurations["multiSpeed"])
                    end
                    
                    multiSpeedReg.i = multiSpeedReg.i + 1
                    multiSpeedReg.xmls[multiSpeedReg.i] = storeItem.xmlFilename
                else
                    configurations["multiSpeed"] = nil
                    print("Error: No configuration property found")
                end
            end
            configurationFile:delete()
        else
            print("Error: File not found: 'multiSpeedConfigurations.xml'")
        end
    end
    
    return configurations, defaultConfigurationIds
end

if g_vehicleConfigurationManager.configurations["multiSpeed"] == nil then
    g_vehicleConfigurationManager:addConfigurationType("multiSpeed", g_i18n:getText("CONFIG_TITLE"), "multiSpeed", VehicleConfigurationItem)
    ConfigurationUtil.getConfigurationsFromXML = Utils.overwrittenFunction(ConfigurationUtil.getConfigurationsFromXML, addNewStoreConfig)
end

SPEEDS = { nil, 999, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 30, 35, 40, 45, 50 }

multiSpeedReg = {}
multiSpeedReg.xmls = {}
multiSpeedReg.i = 0

function multiSpeedReg:update(dt)
    if multiSpeedReg.miles ~= g_gameSettings.useMiles then
        multiSpeedReg.miles = g_gameSettings.useMiles
        
        for ii = 1, multiSpeedReg.i do
            local storeItem = g_storeManager:getItemByXMLFilename(multiSpeedReg.xmls[ii])
            if storeItem ~= nil and storeItem.configurations ~= nil then
                if storeItem.configurations["multiSpeed"] ~= nil then
                    local kph = " " .. g_i18n:getText("CONFIG_KPH")
                    for i = 1, #storeItem.configurations["multiSpeed"] do
                        if i == 1 then
                            storeItem.configurations["multiSpeed"][i].name = g_i18n:getText("CONFIG_OFF")
                        elseif i == 2 then
                            storeItem.configurations["multiSpeed"][i].name = g_i18n:getText("CONFIG_NO_LIMIT")
                        else
                            local speedValue = SPEEDS[i]
                            if g_gameSettings.useMiles == false then
                                storeItem.configurations["multiSpeed"][i].name = tostring(speedValue) .. kph
                            else
                                local mphValue = math.floor(speedValue / 1.609344 * 10) / 10
                                storeItem.configurations["multiSpeed"][i].name = tostring(mphValue) .. " mph"
                            end
                        end
                    end
                end
            end
        end
    end
end

if multiSpeedReg.active == nil then
    multiSpeedReg.active = true
    multiSpeedReg.miles = g_gameSettings.useMiles
    addModEventListener(multiSpeedReg)
end
