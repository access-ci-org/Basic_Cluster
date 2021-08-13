--------------------------------------------------------------------------
-- load_hook(): Here we record the any modules loaded.

local hook    = require("Hook")
local uname   = require("posix").uname
local cosmic  = require("Cosmic"):singleton()
local syshost = cosmic:value("LMOD_SYSHOST")

local s_msgA = {}

local function load_hook(t)
   -- the arg t is a table:
   --     t.modFullName:  the module full name: (i.e: gcc/4.7.2)
   --     t.fn:           The file name: (i.e /apps/modulefiles/Core/gcc/4.7.2.lua)


   -- use syshost from configuration if set
   -- otherwise extract 2nd name from hostname: i.e. login1.stampede2.tacc.utexas.edu
   local host        = syshost
   if (not host) then
      local i,j, first
      i,j, first, host = uname("%n"):find("([^.]*)%.([^.]*)%.")
   end


   if (mode() ~= "load") then return end
   local msg         = string.format("user=%s module=%s path=%s host=%s time=%f",
                                     os.getenv("USER"), t.modFullName, t.fn, uname("%n"),
                                     epoch())
   local a           = s_msgA
   a[#a+1]           = msg
end

hook.register("load", load_hook)

local function report_loads()
   local a = s_msgA
   for i = 1,#a do
      local msg = a[i]
      lmod_system_execute("logger -t ModuleUsageTracking -p local0.info " .. msg)
   end
end

ExitHookA.register(report_loads)
