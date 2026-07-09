-- LibStub is a simple versioned library registry.
-- This embedded copy is intentionally tiny and compatible with the common LibStub API.
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2
local LibStub = _G[LIBSTUB_MAJOR]

if not LibStub or not LibStub.minor or LibStub.minor < LIBSTUB_MINOR then
    LibStub = LibStub or { libs = {}, minors = {} }
    LibStub.libs = LibStub.libs or {}
    LibStub.minors = LibStub.minors or {}
    LibStub.minor = LIBSTUB_MINOR

    function LibStub:NewLibrary(major, minor)
        assert(type(major) == "string", "Bad argument #2 to LibStub:NewLibrary (string expected)")
        minor = assert(tonumber(minor), "Bad argument #3 to LibStub:NewLibrary (number expected)")
        local oldminor = self.minors[major]
        if oldminor and oldminor >= minor then
            return nil, oldminor
        end
        self.minors[major] = minor
        self.libs[major] = self.libs[major] or {}
        return self.libs[major], oldminor
    end

    function LibStub:GetLibrary(major, silent)
        if not self.libs[major] and not silent then
            error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
        end
        return self.libs[major], self.minors[major]
    end

    function LibStub:IterateLibraries()
        return pairs(self.libs)
    end

    setmetatable(LibStub, {
        __call = function(self, major, silent)
            return self:GetLibrary(major, silent)
        end,
    })

    _G[LIBSTUB_MAJOR] = LibStub
end
