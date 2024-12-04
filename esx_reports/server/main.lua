local ESX = exports["es_extended"]:getSharedObject()
local reports = {}
local nextReportId = 1
local adminGroups = Config.AdminGroups or {
    ['admin'] = true,
    ['superadmin'] = true,
    ['mod'] = true
}

-- Cache online admins
local onlineAdmins = {}

-- Update online admins cache
local function updateOnlineAdmins()
    local xPlayers = ESX.GetPlayers()
    onlineAdmins = {}
    for _, playerId in ipairs(xPlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and adminGroups[xPlayer.getGroup()] then
            onlineAdmins[playerId] = true
        end
    end
end

-- Clean old reports periodically
local function cleanOldReports()
    local threshold = os.time() - (24 * 60 * 60) -- 24 hours
    local cleanedCount = 0
    
    for id, report in pairs(reports) do
        if report.status == 'resolved' and os.time(os.date('*t', report.timestamp)) < threshold then
            reports[id] = nil
            cleanedCount = cleanedCount + 1
        end
    end
    
    if cleanedCount > 0 then
        print(('[esx_reports] Cleaned %s old resolved reports'):format(cleanedCount))
    end
end

-- Initialize
CreateThread(function()
    updateOnlineAdmins()
    -- Update admin cache every 5 minutes
    while true do
        Wait(300000)
        updateOnlineAdmins()
    end
end)

-- Clean reports every hour
CreateThread(function()
    while true do
        Wait(3600000)
        cleanOldReports()
    end
end)

-- Submit new report
RegisterServerEvent('esx_reports:submitReport')
AddEventHandler('esx_reports:submitReport', function(reason, description)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    -- Basic input validation
    if not reason or not description or
       type(reason) ~= 'string' or type(description) ~= 'string' or
       #reason < 1 or #description < 1 or #description > Config.MaxReportLength then
        return
    end
    
    local report = {
        id = nextReportId,
        reporterId = source,
        reporterName = GetPlayerName(source),
        reason = reason,
        description = description,
        status = 'pending',
        assignedTo = nil,
        timestamp = os.time(),
        createdAt = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    reports[nextReportId] = report
    nextReportId = nextReportId + 1
    
    -- Only notify online admins once
    for adminId in pairs(onlineAdmins) do
        TriggerClientEvent('esx_reports:newReport', adminId, report)
    end
    
    TriggerClientEvent('esx:showNotification', source, 'Report submitted successfully')
end)

-- Update report status
RegisterServerEvent('esx_reports:updateStatus')
AddEventHandler('esx_reports:updateStatus', function(reportId, newStatus)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or not adminGroups[xPlayer.getGroup()] then 
        return 
    end
    
    local report = reports[reportId]
    if report then
        report.status = newStatus
        report.assignedTo = source
        
        -- Notify all admins about the status update
        for adminId in pairs(onlineAdmins) do
            TriggerClientEvent('esx_reports:statusUpdated', adminId, reportId, newStatus)
        end
        
        -- Only notify the reporter if they're online
        if report.reporterId and report.reporterId ~= source then
            local reporter = ESX.GetPlayerFromId(report.reporterId)
            if reporter then
                TriggerClientEvent('esx:showNotification', report.reporterId, 'Your report status has been updated to: ' .. newStatus)
            end
        end
    end
end)

-- Get reports (optimized to send only necessary data)
ESX.RegisterServerCallback('esx_reports:getReports', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or not adminGroups[xPlayer.getGroup()] then
        cb({})
        return
    end
    
    local reportsList = {}
    for id, report in pairs(reports) do
        reportsList[#reportsList + 1] = {
            id = report.id,
            reporterId = report.reporterId,
            reporterName = report.reporterName,
            reason = report.reason,
            description = report.description,
            status = report.status,
            createdAt = report.createdAt
        }
    end
    
    cb(reportsList)
end)

-- Delete report
RegisterServerEvent('esx_reports:deleteReport')
AddEventHandler('esx_reports:deleteReport', function(reportId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or not adminGroups[xPlayer.getGroup()] then 
        return 
    end
    
    if reports[reportId] then
        reports[reportId] = nil
        
        -- Notify all admins about the deletion
        for adminId in pairs(onlineAdmins) do
            TriggerClientEvent('esx_reports:reportDeleted', adminId, reportId)
        end
        
        TriggerClientEvent('esx:showNotification', source, 'Report deleted successfully')
    end
end)

-- Check admin permission
ESX.RegisterServerCallback('esx_reports:checkPermission', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and adminGroups[xPlayer.getGroup()] then
        cb(true)
    else
        cb(false)
    end
end)
