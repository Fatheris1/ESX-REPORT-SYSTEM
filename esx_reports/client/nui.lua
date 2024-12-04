local ESX = exports["es_extended"]:getSharedObject()

-- NUI Callbacks
RegisterNUICallback('updateStatus', function(data, cb)
    if not data.reportId or not data.status then
        cb({ success = false, message = 'Invalid data' })
        return
    end

    TriggerServerEvent('esx_reports:updateStatus', data.reportId, data.status)
    cb({ success = true })
end)

RegisterNUICallback('closeAdminMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('deleteReport', function(data, cb)
    if not data.reportId then
        cb({ success = false, message = 'Invalid report ID' })
        return
    end

    TriggerServerEvent('esx_reports:deleteReport', data.reportId)
    cb({ success = true })
end)

-- Show notifications for report updates
RegisterNetEvent('esx_reports:statusUpdated')
AddEventHandler('esx_reports:statusUpdated', function(reportId, newStatus)
    SendNUIMessage({
        type = 'updateReportStatus',
        reportId = reportId,
        status = newStatus
    })
end)

-- Notification sound for new reports (admin only)
RegisterNetEvent('esx_reports:playNotificationSound')
AddEventHandler('esx_reports:playNotificationSound', function()
    PlaySoundFrontend(-1, "Menu_Accept", "Phone_SoundSet_Default", 1)
end)

RegisterNetEvent('esx_reports:reportDeleted')
AddEventHandler('esx_reports:reportDeleted', function(reportId)
    SendNUIMessage({
        type = 'reportDeleted',
        reportId = reportId
    })
end)
