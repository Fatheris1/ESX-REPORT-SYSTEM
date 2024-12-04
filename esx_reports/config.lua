Config = {}

-- Admin groups that can manage reports
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true,
    ['mod'] = true
}

-- Report settings
Config.ReportCooldown = 60        -- Time in seconds between reports
Config.MaxReportLength = 1000     -- Maximum characters in report
Config.EnableSounds = true        -- Enable notification sounds
