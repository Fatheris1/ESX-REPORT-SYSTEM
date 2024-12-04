local ESX = exports["es_extended"]:getSharedObject()
local isReportMenuOpen = false
local lastReportTime = 0
local reportCooldown = Config.ReportCooldown
local maxReportLength = Config.MaxReportLength

-- Simple notification sound
local function playNotificationSound()
    if Config.EnableSounds then
        PlaySoundFrontend(-1, "Menu_Accept", "Phone_SoundSet_Default", false)
    end
end

-- Register key command
RegisterCommand('report', function()
    if not isReportMenuOpen then
        OpenReportMenu()
    end
end)

RegisterKeyMapping('report', 'Open Report Menu', 'keyboard', 'F3')

function OpenReportMenu()
    if GetGameTimer() - lastReportTime < (reportCooldown * 1000) then
        local remainingTime = math.ceil((reportCooldown - (GetGameTimer() - lastReportTime) / 1000))
        ESX.ShowNotification(('Please wait %d seconds before sending another report'):format(remainingTime))
        return
    end
    
    isReportMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "openReportMenu",
        maxLength = maxReportLength
    })
end

-- Admin command to view reports
RegisterCommand('reports', function()
    if not isReportMenuOpen then
        ESX.TriggerServerCallback('esx_reports:checkPermission', function(hasPermission)
            if hasPermission then
                ESX.TriggerServerCallback('esx_reports:getReports', function(reports)
                    if reports then
                        SendNUIMessage({
                            type = "showReportsList",
                            reports = reports
                        })
                        SetNuiFocus(true, true)
                        isReportMenuOpen = true
                    end
                end)
            else
                ESX.ShowNotification('You do not have permission to view reports')
            end
        end)
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    isReportMenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('submitReport', function(data, cb)
    if not data.reason or not data.description then
        cb({ success = false, message = 'Please fill in all fields' })
        return
    end

    if #data.description > maxReportLength then
        cb({ success = false, message = 'Report description is too long' })
        return
    end

    TriggerServerEvent('esx_reports:submitReport', data.reason, data.description)
    lastReportTime = GetGameTimer()
    isReportMenuOpen = false
    SetNuiFocus(false, false)
    cb({ success = true })
end)

-- Event handlers with debouncing
local lastNotificationTime = 0
RegisterNetEvent('esx_reports:newReport')
AddEventHandler('esx_reports:newReport', function(report)
    if GetGameTimer() - lastNotificationTime > 1000 then
        ESX.ShowNotification('New report received from ' .. report.reporterName)
        playNotificationSound()
        SendNUIMessage({
            type = 'newReport',
            report = report
        })
        lastNotificationTime = GetGameTimer()
    end
end)

-- Receive new reports (admin only)
RegisterNetEvent('esx_reports:receiveReport')
AddEventHandler('esx_reports:receiveReport', function(reportData)
    ESX.TriggerServerCallback('esx_reports:checkPermission', function(hasPermission)
        if hasPermission then
            TriggerEvent('esx_reports:newReport', reportData)
        end
    end)
end)

-- Handle report status updates
RegisterNetEvent('esx_reports:statusUpdated')
AddEventHandler('esx_reports:statusUpdated', function(reportId, newStatus)
    SendNUIMessage({
        type = "statusUpdated",
        reportId = reportId,
        status = newStatus
    })
end)

-- NUI Callback for status updates
RegisterNUICallback('updateStatus', function(data, cb)
    if not data.reportId or not data.status then
        cb({ success = false })
        return
    end

    ESX.TriggerServerCallback('esx_reports:checkPermission', function(hasPermission)
        if hasPermission then
            TriggerServerEvent('esx_reports:updateStatus', data.reportId, data.status)
            cb({ success = true })
        else
            cb({ success = false })
            ESX.ShowNotification('You do not have permission to update reports')
            playNotificationSound()
        end
    end)
end)
