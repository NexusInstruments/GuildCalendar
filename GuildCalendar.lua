------------------------------------------------------------------------------------------------
--	GuildCalendar ver. @project-version@
--	by Chronosis--Caretaker-US
--	Build @project-hash@
--	Copyright (c) Chronosis. All rights reserved
--
--	https://github.com/chronosis/GuildCalendar
------------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- GuildCalendar Module Definition
-----------------------------------------------------------------------------------------------
local GuildCalendar = {}
local Chronology = {}
local Utils = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local karEventTypes =
{
  Undetermined = 0,
  Meeting = 1,
  Dungeon = 2,
  Raid = 3,
  Other = 4
}

local karLocations =
{
  ["Datascape"] = "20_2",
  ["Genetic Archives"] = "20_1",
}

local karAttendingStates =
{
  ["No"] = 0,
  ["Yes"] = 1,
  ["Maybe"] = 2
}

local tDefaultAttendee =
{
  name = "",
  class = 0,
  path = 0,
  attending = karAttendingStates["No"]
}

local tDefaultEvent =
{
  uuid = "",
  time = {
    from = {
      day = 0,
      month = 0,
      year = 0,
      hour = 0,
      minute = 0
    },
    til = {
      day = 0,
      month = 0,
      year = 0,
      hour = 0,
      minute = 0
    }
  },
  type = karEventTypes.Undetermined,
  subtype = "",
  title = "",
  description = "",
  invitees = {},
  attendees = {},
  flags = {
    allowSignups = true,
    inviteOnly = true,
    viewedInvite = false
  }
}

local tDefaultSettings = {
  enabled = true,
  debug = false,
  shown = false
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function GuildCalendar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here
  o.config = defaultSettings
  o.wndCalendarMonth = {}
  o.weeks = {}
  o.days = {}
  o.hours = {}
  o.tState = {
    isOpen = false
  }

  o.tEvents = {}
  o.tCurrentDisplayedEvents = {}

  o.currentSelection = nil
  o.currentSelectedDay = {
    day = 0,
    month = 0,
    year = 0
  }
    return o
end

function GuildCalendar:Init()
  local bHasConfigureFunction = false
  local strConfigureButtonText = ""
  local tDependencies = {
    -- "UnitOrPackageName",
  }
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- GuildCalendar OnInterfaceMenuListHasLoaded
-----------------------------------------------------------------------------------------------
function GuildCalendar:OnInterfaceMenuListHasLoaded()
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "GuildCalendar", {"Generic_ToggleCalendar", "", "GuildCalendarSprites:CalendarDay"})
end

-----------------------------------------------------------------------------------------------
-- GuildCalendar OnLoad
-----------------------------------------------------------------------------------------------
function GuildCalendar:OnLoad()
  Apollo.LoadSprites("GuildCalendarSprites.xml")
    -- load our form file
  self.xmlDoc = XmlDoc.CreateFromFile("GuildCalendar.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)

  Chronology = Apollo.GetPackage("Chronology-1.0").tPackage
  Utils = Apollo.GetPackage("SimpleUtils-1.0").tPackage

  Apollo.RegisterEventHandler("Generic_ToggleCalendar", "OnToggleCalendar", self)
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- GuildCalendar OnDocLoaded
-----------------------------------------------------------------------------------------------
function GuildCalendar:OnDocLoaded()

  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
      self.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildCalendarForm", nil, self)
    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end

    self.wndMain:Show(false)

    self.wndWeekDays = self.wndMain:FindChild("WeekDays")
    self.wndCalendarMonth = self.wndMain:FindChild("CalendarMonth")
    self.wndSchedule = self.wndMain:FindChild("Schedule")
    self.wndDayHours = self.wndSchedule:FindChild("DayHours")

    -- Create week day labels
    for wd = 1, 7, 1 do
      dayName = Chronology:GetDayOfWeekString(wd, false, nil)
      wndDayLabel = Apollo.LoadForm(self.xmlDoc, "CalendarWeekDay", self.wndWeekDays, self)
      wndDayLabel:SetText(dayName)
      wndDayLabel:SetData(wd)
    end
    self.wndWeekDays:ArrangeChildrenHorz(0)

    -- Create calendar weeks/days
    for wk = 0, 5, 1 do
      local wndWeek = Apollo.LoadForm(self.xmlDoc, "CalendarWeek", self.wndCalendarMonth, self)
      local wndWeekDays = wndWeek:FindChild("CalendarWeekDays")
      for wd = 0, 6, 1 do
        local wndDay = Apollo.LoadForm(self.xmlDoc, "CalendarDay", wndWeekDays, self)
        wndDay:SetData(wd)
        self.days[wd + (wk * 7)] = wndDay
      end
      wndWeekDays:ArrangeChildrenHorz(0)
      wndWeek:SetData(wk)
      self.weeks[wk] = wndWeek
    end
    self.wndCalendarMonth:ArrangeChildrenVert(0)

    -- Create schedule hours
    for hr = 0, 23, 1 do
      local wndHour = Apollo.LoadForm(self.xmlDoc, "ScheduleHour", self.wndDayHours, self)
      wndHour:FindChild("Hour"):SetText(hr)
      wndHour:SetData(hr)
      self.hours[hr] = wndHour
    end
    self.wndDayHours:ArrangeChildrenVert(0)
    self:InitCalendarReferences()
    self:Refresh()
    -- if the xmlDoc is no longer needed, you should set it to nil
    -- self.xmlDoc = nil

    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
    Apollo.RegisterSlashCommand("guildcalendar", "OnSlashCommand", self)
    Apollo.RegisterSlashCommand("gcalendar", "OnSlashCommand", self)
    Apollo.RegisterSlashCommand("calendar", "OnSlashCommand", self)
    Apollo.RegisterSlashCommand("cal", "OnSlashCommand", self)

    self.timer = ApolloTimer.Create(3600.000, true, "OnTimer", self)

    -- Do additional Addon initialization here
  end
end

-----------------------------------------------------------------------------------------------
-- GuildCalendar Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on timer
function GuildCalendar:OnTimer()
  -- Do your timer-related stuff here.
end


-----------------------------------------------------------------------------------------------
-- GuildCalendarForm Functions
-----------------------------------------------------------------------------------------------
function GuildCalendar:OnSlashCommand(sCmd, sInput)
  local s = string.lower(sInput)
  if s == nil or s == "" or s == "help" then
    cprint("GuildCalendar")
    cprint("Usage:  /calendar <command>")
    cprint("============================")
    cprint("   options   Shows the addon options.")
    cprint("   show	     Shows the addon")
    cprint("   enable    Enables the addon (default)")
    cprint("   disable   Disables the addon")
    cprint("   clear     Clears the greeting cache")
    cprint("   reset      Restore default settings")
  elseif s == "show" then
    self.wndMain:Show(true)
  elseif s == "options" then
    self:OnOptions()
  elseif s == "enable" then
    self.config.enabled = true
    self:ApplySettings()
  elseif s == "disable" then
    self.config.enabled = false
    self:ApplySettings()
  elseif s == "reset" then
    self.config = shallowcopy(tDefaultSettings)
    self:ApplySettings()
  end
end

function GuildCalendar:Refresh()
  self:UpdateCalendarReferences()
  self:WipeCalendar()
  self:RedrawCalendar()
  self:UpdateMonthYear()
end

function GuildCalendar:RefreshSchedule()
  self:WipeSchedule()
  self:RedrawSchedule()
end

function GuildCalendar:InitCalendarReferences()
  self.currentDate = GameLib.GetLocalTime()
  self.currentMonth = self.currentDate.nMonth
  self.currentYear = self.currentDate.nYear
  self.currentDay = self.currentDate.nDay
end

function GuildCalendar:UpdateCalendarReferences()
  local day_one = {
    year=self.currentYear,
    month=self.currentMonth,
    day=1,
    hour=0,
    sec=1
  }

  self.firstDayOfMonth = os.time(day_one)
  self.firstDayOfWeek = os.date("%w", self.firstDayOfMonth)
  self.currentDaysOfMonth = Chronology:GetDaysInMonth(self.currentMonth, self.currentYear)
end

function GuildCalendar:WipeCalendar()
  for dy = 0, 41, 1 do
    local day = self.days[dy]
    day:FindChild("Date"):SetText("")
    day:SetBGColor({a = 1,r = 0.2,g = 0.2,b = 0.2})
    day:FindChild("Highlight"):Show(false)
    day:FindChild("Selection"):Show(false)
  end
end

function GuildCalendar:RedrawCalendar()
  for dy = 1, self.currentDaysOfMonth, 1 do
    local day = self.days[dy - 1 + self.firstDayOfWeek]
    day:FindChild("Date"):SetText(dy)
    day:SetBGColor({a = 1,r = 1,g = 1,b = 1})

    -- Show highlight for current day of month
    if self.currentDate.nYear == self.currentYear then
      if self.currentDate.nMonth == self.currentMonth then
        if self.currentDay == dy then
          day:FindChild("Highlight"):Show(true)
        end
      end
    end

    -- Show selection cursor for current select day
    if self.currentSelectedDay.year == self.currentYear then
      if self.currentSelectedDay.month == self.currentMonth then
        if self.currentSelectedDay.day == dy then
          day:FindChild("Selection"):Show(true)
        end
      end
    end

  end
end

function GuildCalendar:WipeSchedule()

end

function GuildCalendar:RedrawSchedule()

end

function GuildCalendar:UpdateMonthYear()
  local wndMonth = self.wndMain:FindChild("Month")
  local wndYear = self.wndMain:FindChild("Year")
  monthName = Chronology:GetMonthString(self.currentMonth, false, nil)
  wndMonth:SetText(monthName)
  wndYear:SetText(self.currentYear)
end

function GuildCalendar:OnToggleCalendar()
  if self.tState.isOpen == true then
    self.tState.isOpen = false
    self.wndMain:Close() -- hide the window
  else
    self.tState.isOpen = true
    self.wndMain:Invoke() -- show the window
  end
end

function GuildCalendar:OnCalendarClose( wndHandler, wndControl, eMouseButton )
  self.tState.isOpen = false
  self.wndMain:Close()
end

function GuildCalendar:OnCalendarClosed( wndHandler, wndControl )
  self.tState.isOpen = false
end

function GuildCalendar:OnPreviousMonth( wndHandler, wndControl, eMouseButton )
  self.currentMonth = self.currentMonth - 1
  if self.currentMonth < 1 then
    self.currentMonth = 12
    self.currentYear = self.currentYear - 1
  end
  self:Refresh()
end

function GuildCalendar:OnNextMonth( wndHandler, wndControl, eMouseButton )
  self.currentMonth = self.currentMonth + 1
  if self.currentMonth > 12 then
    self.currentMonth = 1
    self.currentYear = self.currentYear + 1
  end
  self:Refresh()
end

function GuildCalendar:OnPreviousYear( wndHandler, wndControl, eMouseButton )
  self.currentYear = self.currentYear - 1
  self:Refresh()
end

function GuildCalendar:OnNextYear( wndHandler, wndControl, eMouseButton )
  self.currentYear = self.currentYear + 1
  self:Refresh()
end

---------------------------------------------------------------------------------------------------
-- CalendarDay Functions
---------------------------------------------------------------------------------------------------

function GuildCalendar:OnDaySelected( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
  if self.currentSelection ~= nil then
    self.currentSelection:FindChild("Selection"):Show(false)
    self.currentSelection = nil
  end

  local calDay = wndHandler:FindChild("Date"):GetText()
  if calDay ~= nil and calDay ~= "" then
    self.currentSelectedDay = {
      year = self.currentYear,
      month = self.currentMonth,
      day = tonumber(calDay)
    }
    self.currentSelection = wndHandler
    self.currentSelection:FindChild("Selection"):Show(true)
  else
    self.currentSelectedDay = {
      year = self.currentYear,
      month = self.currentMonth,
      day = self.currentDay
    }
  end
  self:RefreshSchedule()
end

---------------------------------------------------------------------------------------------------
-- AddEventForm Functions
---------------------------------------------------------------------------------------------------

function GuildCalendar:OnEditEventCancel( wndHandler, wndControl, eMouseButton )
  self.wndEventAdd:Show(false)
  self.wndEventAdd:Close()
end

function GuildCalendar:OnEditEventSave( wndHandler, wndControl, eMouseButton )
  self.wndEventAdd:Show(false)
  self.wndEventAdd:Close()
end

function GuildCalendar:OnColorPickerClick( wndHandler, wndControl, eMouseButton )

end

function GuildCalendar:OnInviteAdd( wndHandler, wndControl, eMouseButton )

end

function GuildCalendar:OnScheduleAdd( wndHandler, wndControl, eMouseButton )
  self.wndEventAdd = Apollo.LoadForm(self.xmlDoc, "AddEventForm", nil, self)
  local t_start = self.wndEventAdd:FindChild("StartTime"):FindChild("Data")
  local t_end = self.wndEventAdd:FindChild("EndTime"):FindChild("Data")
  self.wndStart = Apollo.LoadForm(self.xmlDoc, "DatePicker", t_start, self)
  self.wndEnd = Apollo.LoadForm(self.xmlDoc, "DatePicker", t_end, self)
  self.wndEventAdd:Show(true)
  self.wndStart:Show(true)
  self.wndEnd:Show(true)
end


function GuildCalendar:OnEventLocationClick( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
end

function GuildCalendar:OnEventTypeClick( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
end

---------------------------------------------------------------------------------------------------
-- ColorPickerColor Functions
---------------------------------------------------------------------------------------------------

function GuildCalendar:OnColorPickerColorSelected( wndHandler, wndControl, eMouseButton )
end

-----------------------------------------------------------------------------------------------
-- GuildCalendar Instance
-----------------------------------------------------------------------------------------------
local GuildCalendarInst = GuildCalendar:new()
GuildCalendarInst:Init()
