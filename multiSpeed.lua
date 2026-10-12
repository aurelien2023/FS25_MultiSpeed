--[[
    Mod name: FS25 MultiSpeed
    Version: 1.0.0.0 (FS25)
]]

multiSpeed = {}

function multiSpeed.prerequisitesPresent(specializations)
    return true
end

function multiSpeed.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", multiSpeed)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", multiSpeed)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", multiSpeed)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", multiSpeed)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", multiSpeed)
    if SpecializationUtil.hasSpecialization(AttacherJoints, vehicleType.specializations) then
        SpecializationUtil.registerEventListener(vehicleType, "onPreDetachImplement", multiSpeed)
    end
end

function multiSpeed:onPostLoad(savegame)
    local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
    
    if storeItem ~= nil and storeItem.configurations ~= nil then
        if storeItem.configurations["multiSpeed"] ~= nil then
            local configId = Utils.getNoNil(self.configurations["multiSpeed"], 0)
            
            if configId > 0.5 then
                local motor = self.spec_motorized and self.spec_motorized.motor or nil
                self.spec_multiSpeedTemporary.available = motor ~= nil or (self.speedLimit ~= nil and self.speedLimit > 0.5)
                
                if motor ~= nil then
                    -- Vehicule motorise : OFF (1) = rien, Sans Limite (2) = retire le bridage logiciel
                    if configId == 2 then
                        local bigSpeed = 999 / 3.6
                        motor.maxForwardSpeed = bigSpeed
                        motor.maxBackwardSpeed = bigSpeed
                        motor.maxForwardSpeedOrigin = bigSpeed
                        motor.maxBackwardSpeedOrigin = bigSpeed
                    end
                else
                    local speedValue = SPEEDS[configId]
                
                    if speedValue == nil or speedValue == 0 then
                        -- OFF: keep the vehicle's original speed limit
                    elseif self.speedLimit ~= nil and self.speedLimit > 0.5 then
                        self.speedLimit = math.max(speedValue, 1)
                    end
                end
            end
        end
    end
end

function multiSpeed.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setMultiSpeedTemporaryNoLimit", multiSpeed.setMultiSpeedTemporaryNoLimit)
    SpecializationUtil.registerFunction(vehicleType, "setMultiSpeedEnsembleNoLimit", multiSpeed.setMultiSpeedEnsembleNoLimit)
end

function multiSpeed:onLoad(savegame)
    self.spec_multiSpeedTemporary = {
        available = false,
        active = false,
        ensembleActive = false,
        actionEvents = {},
        restore = nil
    }
end

function multiSpeed:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_multiSpeedTemporary
        self:clearActionEventsTable(spec.actionEvents)
        spec.actionEventId = nil

        if self == self:getRootVehicle() and isActiveForInputIgnoreSelection and #multiSpeed.getTemporaryNoLimitObjects(self) > 0 then
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.MULTISPEED_TEMP_NO_LIMIT, self, multiSpeed.actionEventTemporaryNoLimit, false, true, false, true, nil)
            spec.actionEventId = actionEventId
            g_inputBinding:setActionEventTextVisibility(actionEventId, true)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            multiSpeed.updateTemporaryActionText(self)
        end
    end
end

function multiSpeed.updateTemporaryActionText(self)
    local spec = self.spec_multiSpeedTemporary
    if self.isClient and spec.actionEventId ~= nil then
        local key = spec.ensembleActive and "MULTISPEED_RESTORE_STORE" or "MULTISPEED_ENABLE_NO_LIMIT"
        g_inputBinding:setActionEventText(spec.actionEventId, g_i18n:getText(key))
    end
end

function multiSpeed.actionEventTemporaryNoLimit(self, actionName, inputValue, callbackState, isAnalog)
    if self == self:getRootVehicle() and self:getIsActiveForInput(true) then
        self:setMultiSpeedEnsembleNoLimit(not self.spec_multiSpeedTemporary.ensembleActive)
    end
end


function multiSpeed.getTemporaryNoLimitObjects(self)
    local objects = {}
    local visited = {}
    local function collect(object)
        if object == nil or visited[object] then
            return
        end
        visited[object] = true
        if object.spec_multiSpeedTemporary ~= nil and object.spec_multiSpeedTemporary.available then
            table.insert(objects, object)
        end
        if object.getAttachedImplements ~= nil then
            for _, implement in ipairs(object:getAttachedImplements()) do
                collect(implement.object)
            end
        end
    end
    collect(self)
    return objects
end

function multiSpeed:setMultiSpeedEnsembleNoLimit(active, noEventSend)
    local spec = self.spec_multiSpeedTemporary
    if spec == nil then
        return
    end

    for _, object in ipairs(multiSpeed.getTemporaryNoLimitObjects(self)) do
        object:setMultiSpeedTemporaryNoLimit(active, true)
    end
    spec.ensembleActive = active
    multiSpeed.updateTemporaryActionText(self)
    multiSpeedTemporaryNoLimitEvent.sendEvent(self, active, noEventSend, true)
end

function multiSpeed:onPreDetachImplement(implement)
    if self.isServer and implement.object ~= nil then
        local object = implement.object
        if object.setMultiSpeedEnsembleNoLimit ~= nil then
            object:setMultiSpeedEnsembleNoLimit(false)
        else
            for _, child in ipairs(multiSpeed.getTemporaryNoLimitObjects(object)) do
                child:setMultiSpeedTemporaryNoLimit(false)
            end
        end
    end
end

function multiSpeed:setMultiSpeedTemporaryNoLimit(active, noEventSend)
    local spec = self.spec_multiSpeedTemporary
    if spec == nil or not spec.available or spec.active == active then
        return
    end

    local motor = self.spec_motorized and self.spec_motorized.motor or nil
    if active then
        if motor ~= nil then
            spec.restore = {
                maxForwardSpeed = motor.maxForwardSpeed,
                maxBackwardSpeed = motor.maxBackwardSpeed,
                maxForwardSpeedOrigin = motor.maxForwardSpeedOrigin,
                maxBackwardSpeedOrigin = motor.maxBackwardSpeedOrigin,
                transmissionDirection = motor.transmissionDirection
            }
            local bigSpeed = 999 / 3.6
            motor.maxForwardSpeed = bigSpeed
            motor.maxBackwardSpeed = bigSpeed
            motor.maxForwardSpeedOrigin = bigSpeed
            motor.maxBackwardSpeedOrigin = bigSpeed
        else
            spec.restore = { speedLimit = self.speedLimit }
            self.speedLimit = 999
        end
    else
        local restore = spec.restore
        if restore == nil then
            return
        end

        if motor ~= nil then
            motor.maxForwardSpeedOrigin = restore.maxForwardSpeedOrigin
            motor.maxBackwardSpeedOrigin = restore.maxBackwardSpeedOrigin
            local reversedBefore = (restore.transmissionDirection or 1) < 0
            local reversedNow = (motor.transmissionDirection or 1) < 0
            if reversedBefore == reversedNow then
                motor.maxForwardSpeed = restore.maxForwardSpeed
                motor.maxBackwardSpeed = restore.maxBackwardSpeed
            else
                motor.maxForwardSpeed = restore.maxBackwardSpeed
                motor.maxBackwardSpeed = restore.maxForwardSpeed
            end
        else
            self.speedLimit = restore.speedLimit
        end
        spec.restore = nil
    end

    spec.active = active
    multiSpeed.updateTemporaryActionText(self)
    multiSpeedTemporaryNoLimitEvent.sendEvent(self, active, noEventSend)
end

function multiSpeed:onReadStream(streamId, connection)
    if connection:getIsServer() then
        self:setMultiSpeedTemporaryNoLimit(streamReadBool(streamId), true)
        self.spec_multiSpeedTemporary.ensembleActive = streamReadBool(streamId)
        multiSpeed.updateTemporaryActionText(self)
    end
end

function multiSpeed:onWriteStream(streamId, connection)
    if not connection:getIsServer() then
        streamWriteBool(streamId, self.spec_multiSpeedTemporary.active)
        streamWriteBool(streamId, self.spec_multiSpeedTemporary.ensembleActive)
    end
end

multiSpeedTemporaryNoLimitEvent = {}
local multiSpeedTemporaryNoLimitEvent_mt = Class(multiSpeedTemporaryNoLimitEvent, Event)
InitEventClass(multiSpeedTemporaryNoLimitEvent, "multiSpeedTemporaryNoLimitEvent")

function multiSpeedTemporaryNoLimitEvent.emptyNew()
    return Event.new(multiSpeedTemporaryNoLimitEvent_mt)
end

function multiSpeedTemporaryNoLimitEvent.new(vehicle, active, isEnsemble)
    local self = multiSpeedTemporaryNoLimitEvent.emptyNew()
    self.vehicle = vehicle
    self.active = active
    self.isEnsemble = isEnsemble == true
    return self
end

function multiSpeedTemporaryNoLimitEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.active = streamReadBool(streamId)
    self.isEnsemble = streamReadBool(streamId)
    self:run(connection)
end

function multiSpeedTemporaryNoLimitEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.active)
    streamWriteBool(streamId, self.isEnsemble)
end

function multiSpeedTemporaryNoLimitEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle.setMultiSpeedTemporaryNoLimit ~= nil then
        if self.isEnsemble then
            self.vehicle:setMultiSpeedEnsembleNoLimit(self.active, true)
        else
            self.vehicle:setMultiSpeedTemporaryNoLimit(self.active, true)
        end
        if not connection:getIsServer() then
            g_server:broadcastEvent(multiSpeedTemporaryNoLimitEvent.new(self.vehicle, self.active, self.isEnsemble), nil, connection, self.vehicle)
        end
    end
end

function multiSpeedTemporaryNoLimitEvent.sendEvent(vehicle, active, noEventSend, isEnsemble)
    if not noEventSend then
        if g_server ~= nil then
            g_server:broadcastEvent(multiSpeedTemporaryNoLimitEvent.new(vehicle, active, isEnsemble), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(multiSpeedTemporaryNoLimitEvent.new(vehicle, active, isEnsemble))
        end
    end
end
