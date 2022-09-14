-- System wide default modules that get loaded
-- This is referecend by LMOD_SYSTEM_DEFAULT_MODULES

function chomp(s)
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

local uid, status = chomp(capture("/usr/bin/id -u"))

if uid == "0" then
  load("shared", "cmd", "cluster-tools", "{{ lmod_slurm_module_rel_path }}")
else
  load("shared", "{{ lmod_slurm_module_rel_path }}") -- DEFAULT_MODULES_OTHER
end
