-- transition.lua
--
-- Copyright 2013 Lance Ulmer.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in the
-- Software without restriction, including without limitation the rights to use, copy,
-- modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
-- and to permit persons to whom the Software is furnished to do so, subject to the
-- following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies
-- or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
----------------------------------------------------------------------------------------------------

local cachedTransition     = _G.transition
local anonymousPaused      = {}
local namespacePaused      = {}
local namespaceTransitions = {}
local anonymousTransitions = {}
local previousSystemTime   = 0

local _advance,_loop,_generateHandle,_checkDisplayObject,to,from,restart,cancel,pause,resume,cancelAll,pauseAll,resumeAll

_advance = function(handle, t, deltaT)
    local lastFrame = t.frame
    t.frame   = t.frame + deltaT

    local currentFrame   = t.frame
    local delayFrame     = t.ease.delay
    local animationFrame = currentFrame - delayFrame
    local endFrame       = t.ease.time

    if animationFrame >= endFrame then
        animationFrame = endFrame
        if handle.namespace then
            local group = namespaceTransitions[handle.namespace]
            group[handle] = nil
        else
            anonymousTransitions[handle] = nil
        end
    end

    -- if the animation has started (beyond the delay)
    if animationFrame > 0 then
        -- if the last frame was during the delay or it was 0
        if lastFrame - delayFrame < 0 or lastFrame == 0 then
            -- fire onStart
            if t.ease.onStart then
                t.ease.onStart(t.object)
            end
        end

        -- if this frame is the last
        if currentFrame - delayFrame >= endFrame then
            -- fire onComplete
            if t.ease.onComplete then
                t.ease.onComplete(t.object)
            end
            -- set the values exactly
            for key,value in pairs(t.finish) do
                t.object[key] = t.finish[key]
            end
        else
            -- use the easing function
            for key,value in pairs(t.finish) do
                t.object[key] = t.ease.transition( animationFrame, endFrame, t.start[key], t.finish[key] - t.start[key] )
            end
        end
    end
end

_loop = function()
    local currentSystemTime = system.getTimer();
    local deltaT = currentSystemTime - previousSystemTime;
    previousSystemTime = currentSystemTime;

    for handle,t in pairs(anonymousTransitions) do

        if not t.paused then
            _advance(handle, t, deltaT)
        end

    end

    for ns,group in pairs(namespaceTransitions) do
        for handle,t in pairs(group) do

            if not t.paused then
                _advance(handle, t, deltaT)
            end

        end
    end

end

_generateHandle = function(object, params, namespace, to)
    local ease   = {}
    local start  = {}
    local finish = {}

    if params.time and type(params.time) == 'number' and params.time > 0 then
        ease.time = params.time
    else
        ease.time = 500
    end

    if params.transition and type(params.transition) == 'function' then
        if params.transition == easing.inExpo then
            ease.transition = params.transition
        elseif params.transition == easing.inOutExpo then
            ease.transition = params.transition
        elseif params.transition == easing.inOutQuad then
            ease.transition = params.transition
        elseif params.transition == easing.inQuad then
            ease.transition = params.transition
        elseif params.transition == easing.outExpo then
            ease.transition = params.transition
        elseif params.transition == easing.outQuad then
            ease.transition = params.transition
        else
            ease.transition = easing.linear
        end
    else
        ease.transition = easing.linear
    end

    if params.delay and type(params.delay) == 'number' and params.delay > 0 then
        ease.delay = params.delay
    else
        ease.delay = 0
    end

    if params.delay and type(params.delay) == 'number' and params.delay > 0 then
        ease.delay = params.delay
    else
        ease.delay = 0
    end

    if params.delta then
        ease.delta = true
    else
        ease.delta = false
    end

    if params.onStart and type(params.onStart) == 'function' then
        ease.onStart = params.onStart
    end

    if params.onComplete and type(params.onComplete) == 'function' then
        ease.onComplete = params.onComplete
    end

    params.time       = nil
    params.transition = nil
    params.delay      = nil
    params.delta      = nil
    params.onStart    = nil
    params.onComplete = nil


    for k,v in pairs(params) do
        if object[k] and type(object[k]) == 'number' and type(v) == 'number' then
            start[k]  = object[k]
            finish[k] = v
            -- if delta is true, add the final value to the start value
            if ease.delta then
                finish[k] = start[k] + finish[k]
            end

            -- swap the values when using 'for' instead of 'to'
            if not to then
                local startValue  = finish[k]
                local finishValue = start[k]
                start[k]  = startValue
                finish[k] = finishValue
            end

            -- prevent alpha 'valid range' errors
            if k == 'alpha' then
                if start[k] < 0 then
                    start[k] = 0
                elseif start[k] > 1 then
                    start[k] = 1
                end

                if finish[k] < 0 then
                    finish[k] = 0
                elseif finish[k] > 1 then
                    finish[k] = 1
                end
            end
        end
    end

    local handle = {object=object, ease=ease, start=start, finish=finish}
    if namespace and type(namespace) == 'string' then
        handle.namespace = namespace
        if not namespaceTransitions[namespace] then
            namespaceTransitions[namespace] = {}
        end
    end

    return {handle=handle, paused=false, frame=0, object=object, ease=ease, start=start, finish=finish}
end

_checkDisplayObject = function(object)
    if type(object) == 'table' and type(object._proxy) == 'userdata' then
        return true
    end
    return false
end

to = function(namespace, object, params)
    if _checkDisplayObject(namespace) then
        params, object, namespace = object, namespace, nil
    elseif not _checkDisplayObject(object) then
        return
    end

    local transitionObject = _generateHandle(object, params, namespace, true)
    local handle           = transitionObject.handle

    if handle.namespace then
        local group = namespaceTransitions[handle.namespace]
        group[handle] = transitionObject
    else
        anonymousTransitions[handle] = transitionObject
    end

    for k,v in pairs(transitionObject.start) do
        object[k] = v
    end

    return handle
end

from = function(namespace, object, params)
    if _checkDisplayObject(namespace) then
        params, object, namespace = object, namespace, nil
    elseif not _checkDisplayObject(object) then
        return
    end

    local transitionObject = _generateHandle(object, params, namespace, false)
    local handle           = transitionObject.handle

    if handle.namespace then
        local group = namespaceTransitions[handle.namespace]
        group[handle] = transitionObject
    else
        anonymousTransitions[handle] = transitionObject
    end

    for k,v in pairs(transitionObject.start) do
        object[k] = v
    end

    return handle
end

restart = function(handle, reverse)
    if handle and handle.object and handle.ease and handle.start and handle.finish then
        cancel(handle)

        local transitionObject = {handle=handle, paused=false, frame=0, object=handle.object, ease=handle.ease, start=handle.start, finish=handle.finish}
        if reverse then
            local start             = handle.finish
            local finish            = handle.start
            handle.start            = start
            handle.finish           = finish
            transitionObject.start  = start
            transitionObject.finish = finish
        end

        if handle.namespace then
            local group = namespaceTransitions[handle.namespace]
            group[handle] = transitionObject
        else
            anonymousTransitions[handle] = transitionObject
        end

        for k,v in pairs(transitionObject.start) do
            handle.object[k] = v
        end
    end

    return handle
end

cancel = function(handle)
    if type(handle) == 'string' and namespaceTransitions[handle] then
        namespaceTransitions[handle] = nil
        namespacePaused[handle] = nil
    elseif handle and handle.namespace and namespaceTransitions[handle.namespace] then
        local group = namespaceTransitions[handle.namespace]
        group[handle] = nil
    elseif anonymousTransitions[handle] then
        anonymousTransitions[handle] = nil
    -- this is to cancel dissolve transitions
    elseif handle and handle._transition then
        cachedTransition.cancel(handle)
    end
end

pause = function(handle)
    if type(handle) == 'string' and namespaceTransitions[handle] then
        local group = namespaceTransitions[handle]
        for handle,t in pairs(group) do
            pause(handle)
        end
    elseif handle and handle.namespace and namespaceTransitions[handle.namespace] then
        local group = namespaceTransitions[handle.namespace]
        group[handle].paused = true

        if not namespacePaused[handle.namespace] then
            namespacePaused[handle.namespace] = {}
        end
        namespacePaused[handle.namespace][handle] = group[handle]
    elseif anonymousTransitions[handle] then
        anonymousTransitions[handle].paused = true
        anonymousPaused[handle] = anonymousTransitions[handle]
    end
end

resume = function(handle)
    if type(handle) == 'string' and namespacePaused[handle] then
        local group = namespacePaused[handle]
        for handle,t in pairs(group) do
            resume(handle)
        end
    elseif handle and handle.namespace and namespaceTransitions[handle.namespace] then
        local group = namespacePaused[handle.namespace]
        group[handle].paused = false
        group[handle] = nil

        keysLeft = false
        for k,v in pairs(group) do
            keysLeft = true
            break
        end
        if not keysLeft then
            namespacePaused[handle.namespace] = nil
        end
    elseif anonymousTransitions[handle] then
        anonymousPaused[handle].paused = false
        anonymousPaused[handle] = nil
    end
end

cancelAll = function()
    anonymousPaused      = {}
    namespacePaused      = {}
    namespaceTransitions = {}
    anonymousTransitions = {}
end

pauseAll = function()
    for handle,t in pairs(anonymousTransitions) do
        pause(handle)
    end
    for ns,group in pairs(namespaceTransitions) do
        pause(ns)
    end
end

resumeAll = function()
    for handle,t in pairs(anonymousPaused) do
        resume(handle)
    end
    for ns,group in pairs(namespacePaused) do
        resume(ns)
    end
end

Runtime:addEventListener('enterFrame', _loop)

local transition = {to=to,from=from,restart=restart,cancel=cancel,pause=pause,resume=resume,cancelAll=cancelAll,pauseAll=pauseAll,resumeAll=resumeAll,legacy=cachedTransition}
for k,v in pairs(cachedTransition) do
    if not transition[k] then
        transition[k] = v
    end
end
return transition
