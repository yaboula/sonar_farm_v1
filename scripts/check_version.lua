-- Release contract check. Runs in CI without FiveM dependencies.

local function read(path)
    local file = assert(io.open(path, 'rb'))
    local value = file:read('*a')
    file:close()
    return value
end

local version = read('VERSION'):match('^%s*(.-)%s*$')
assert(version:match('^%d+%.%d+%.%d+[%w%.%-]*$'), 'VERSION must be SemVer-compatible')

local manifest = read('fxmanifest.lua')
local manifestVersion
for line in manifest:gmatch('[^\r\n]+') do
    manifestVersion = manifestVersion or line:match("^version%s+'([^']+)'")
end
assert(manifestVersion == version, ('fxmanifest version %s does not match VERSION %s')
    :format(tostring(manifestVersion), version))

local changelog = read('CHANGELOG.md')
assert(changelog:find('## [' .. version .. ']', 1, true),
    ('CHANGELOG.md must contain a ## [%s] release section'):format(version))

print(('Release version contract valid: %s'):format(version))
