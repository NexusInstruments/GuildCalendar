local S_MAJOR, S_MINOR = "SimpleUtils-1.0", 1
local S_Pkg = Apollo.GetPackage(S_MAJOR)
if S_Pkg and (S_Pkg.nVersion or 0) >= S_MINOR then
	return -- no upgrade needed
end

-- Set a reference to the actual package or create an empty table
local SimpleUtils = S_Pkg and S_Pkg.tPackage or {}

function SimpleUtils:new(args)
   local new = { }

   if args then
      for key, val in pairs(args) do
         new[key] = val
      end
   end

   return setmetatable(new, SimpleUtils)
end

function string:split(inSplitPattern, outResults)
   if not outResults then
      outResults = { }
   end
   local theStart = 1
   local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
   while theSplitStart do
      table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
      theStart = theSplitEnd + 1
      theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
   end
   table.insert( outResults, string.sub( self, theStart ) )
   return outResults
end

function string:tohexstring(spacer)
	return (
		string.gsub(self,"(.)",
			function (c)
				return string.format("%02X%s",string.byte(c), spacer or "")
			end
		)
	)
end

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function cprint(string)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, string, "")
end

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      cprint(formatting)
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      cprint(formatting .. tostring(v))      
    else
      cprint(formatting .. v)
    end
  end
end

Apollo.RegisterPackage(SimpleUtils, S_MAJOR, S_MINOR, {})
