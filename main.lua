getgenv().Dump = Dump or loadstring(game:HttpGet("http://apidump.glitch.me/"))()

local Default = {}

local Tags = {"ReadOnly", "Deprecated", "Hidden", "NotScriptable"}

local Ignored = {
	Classes = {},
	Global = {
		"Parent",
		"BrickColor",
		"CollisionGroup",
		"AssemblyLinearVelocity"
	}
}

local function FindClassEntry(Class)
	local Found
	
	for Index, Value in Dump.Classes do
		if Value.Name == Class then
			Found = Dump.Classes[Index]
			break
		end
	end

	return Found
end

function GetClassAncestry(Class)
	local Ancestors = {FindClassEntry(Class)}

	while Ancestors[#Ancestors].Superclass ~= "<<<ROOT>>>" do
		table.insert(Ancestors, FindClassEntry(Ancestors[#Ancestors].Superclass))
	end

	return Ancestors
end

function GetIgnoredPropertyNames(Class)
	local Ancestry = GetClassAncestry(Class)
	
	local IgnoredProperties = {}

	for _, Ancestor in Ancestry do
		local IgnoreList = Ignored.Classes[Ancestor.Name]

		if IgnoreList then
			table.insert(IgnoredProperties, IgnoreList)
		end
	end

	for _, Property in ipairs(Ignored.Global) do
		table.insert(IgnoredProperties, Property)
	end

	return IgnoredProperties
end

function GetPropertyList(Class)
	local Ancestry = GetClassAncestry(Class)
	
	local IgnoredProperties = GetIgnoredPropertyNames(Class)
	
	local Properties = {}

	for _, Ancestor in Ancestry do
		local Members = {}
		
		for Index, Member in next, Ancestor.Members do
			if Member.MemberType ~= "Property" then
				continue
			end
			
			if Member.Security.Read ~= "None" or Member.Security.Write ~= "None" then
				continue
			end
			
			if Member.Tags then
				local Tagged = false
				
				for _, Tag in Member.Tags do
					if table.find(Tags, Tag) then
						Tagged = true
					end
				end
				
				if Tagged then
					continue
				end
			end
			
			table.insert(Members, Member)
		end
		
		for _, Property in ipairs(Members) do
			if table.find(IgnoredProperties, Property.Name) then
				continue
			end

			table.insert(Properties, Property.Name)
		end
	end
		
	return Properties
end

function GetDefaultProperties(Class)
	if not Default[Class] then
		local DefaultProperties = {}
		
		local Properties = GetPropertyList(Class)

		local DefaultInstance
    
	    local Source, Error = pcall(function()
	        DefaultInstance = Instance.new(Class)
		end)
	    
	    if not Source then
	        return nil
	    end
    
		for _, Property in next, Properties do
			DefaultProperties[Property] = DefaultInstance[Property]
		end
		
		DefaultInstance:Destroy()
		
		Default[Class] = DefaultProperties
	end
	
	return Default[Class]
end

local keywords = {["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true,
["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true, ["function"]=true,
["if"]=true, ["in"]=true, ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true, ["until"]=true, ["while"]=true}
 
local function isLuaIdentifier(str)
	if type(str) ~= "string" then return false end
	if str:len() == 0 then return false end
	if str:find("[^%d%a_]") then return false end
	if tonumber(str:sub(1, 1)) then return false end
	if keywords[str] then return false end
	return true
end
 
local function properFullName(object, usePeriod)
	if object == nil or object == game then return "" end
	
	local s = object.Name
	local usePeriod = true
	if not isLuaIdentifier(s) then
		s = ("[%q]"):format(s)
		usePeriod = false
	end
	
	if not object.Parent or object.Parent == game then
		return s
	else
		return properFullName(object.Parent) .. (usePeriod and "." or "") .. s 
	end
end

local function FormatProperty(Value)
	if type(Value) == "string" then
		return ("%q"):format(Value)
	elseif type(Value) == "number" then
		if v == math.huge then return "math.huge" end
		if v == -math.huge then return "-math.huge" end
		return tonumber(Value)
	elseif type(Value) == "boolean" then
		return tostring(Value)
	elseif type(Value) == "nil" then
		return "nil"
	elseif typeof then
		if typeof(Value) == "Instance" then
			return  properFullName(Value)
		elseif typeof(Value) == "Axes" then
			local s = {}
			if Value.X then table.insert(s, FormatProperty(Enum.Axis.X)) end
			if Value.Y then table.insert(s, FormatProperty(Enum.Axis.Y)) end
			if Value.Z then table.insert(s, FormatProperty(Enum.Axis.Z)) end
			return ("Axes.new(%s)"):format(table.concat(s, ", "))
		elseif typeof(Value) == "BrickColor" then
			return ("BrickColor.new(%q)"):format(Value.Name)
		elseif typeof(Value) == "CFrame" then
			return ("CFrame.new(%s)"):format(table.concat({Value:GetComponents()}, ", "))
		elseif typeof(Value) == "Color3" then
			return ("Color3.fromRGB(%d, %d, %d)"):format(Value.r * 255, Value.g * 255, Value.b * 255)
		elseif typeof(Value) == "ColorSequence" then
			if #Value.Keypoints > 2 then
				return ("ColorSequence.new(%s)"):format(FormatProperty(Value.Keypoints))
			else
				if Value.Keypoints[1].Value == Value.Keypoints[2].Value then
					return ("ColorSequence.new(%s)"):format(FormatProperty(Value.Keypoints[1].Value))
				else
					return ("ColorSequence.new(%s, %s)"):format(
						FormatProperty(Value.Keypoints[1].Value),
						FormatProperty(Value.Keypoints[2].Value)
					)
				end
			end
		elseif typeof(Value) == "ColorSequenceKeypoint" then
			return ("ColorSequenceKeypoint.new(%d, %s)"):format(Value.Time, FormatProperty(Value.Value))
		elseif typeof(Value) == "DockWidgetPluginGuiInfo" then
			return ("DockWidgetPluginGuiInfo.new(%s, %s, %s, %s, %s, %s, %s)"):format(
				FormatProperty(Value.InitialDockState),
				FormatProperty(Value.InitialEnabled),
				FormatProperty(Value.InitialEnabledShouldOverrideRestore),
				FormatProperty(Value.FloatingXSize),
				FormatProperty(Value.FloatingYSize),
				FormatProperty(Value.MinWidth),
				FormatProperty(Value.MinHeight)
			)
		elseif typeof(Value) == "Enums" then
			return "Enums"
		elseif typeof(Value) == "Enum" then
			return ("Enum.%s"):format(tostring(Value))
		elseif typeof(Value) == "EnumItem" then
			return ("Enum.%s.%s"):format(tostring(Value.EnumType), Value.Name)
		elseif typeof(Value) == "Faces" then
			local s = {}
			for _, enumItem in pairs(Enum.NormalId:GetEnumItems()) do
				if v[enumItem.Name] then
					table.insert(s, FormatProperty(enumItem))
				end
			end
			return ("Faces.new(%s)"):format(table.concat(s, ", "))
		elseif typeof(Value) == "NumberRange" then
			if Value.Min == Value.Max then
				return ("NumberRange.new(%d)"):format(Value.Min)
			else
				return ("NumberRange.new(%d, %d)"):format(Value.Min, Value.Max)
			end
		elseif typeof(Value) == "NumberSequence" then
			if #Value.Keypoints > 2 then
				return ("NumberSequence.new(%s)"):format(FormatProperty(Value.Keypoints))
			else
				if Value.Keypoints[1].Value == Value.Keypoints[2].Value then
					return ("NumberSequence.new(%d)"):format(Value.Keypoints[1].Value)
				else
					return ("NumberSequence.new(%d, %d)"):format(Value.Keypoints[1].Value, Value.Keypoints[2].Value)
				end
			end
		elseif typeof(Value) == "NumberSequenceKeypoint" then
			if Value.Envelope ~= 0 then
				return ("NumberSequenceKeypoint.new(%d, %d, %d)"):format(Value.Time, Value.Value, Value.Envelope)
			else
				return ("NumberSequenceKeypoint.new(%d, %d)"):format(Value.Time, Value.Value)
			end
		elseif typeof(Value) == "PathWaypoint" then
			return ("PathWaypoint.new(%s, %s)"):format(
				FormatProperty(Value.Position),
				FormatProperty(Value.Action)
			)
		elseif typeof(Value) == "PhysicalProperties" then
			return ("PhysicalProperties.new(%d, %d, %d, %d, %d)"):format(
				Value.Density, Value.Friction, Value.Elasticity, Value.FrictionWeight, Value.ElasticityWeight
			)
		elseif typeof(Value) == "Ray" then
			return ("Ray.new(%s, %s)"):format(
				FormatProperty(Value.Origin),
				FormatProperty(Value.Direction)
			)
		elseif typeof(Value) == "Rect" then
			return ("Rect.new(%d, %d, %d, %d)"):format(
				Value.Min.X, Value.Min.Y, Value.Max.X, Value.Max.Y
			)
		elseif typeof(Value) == "Region3" then
			local min = Value.CFrame.p + Value.Size * -.5
			local max = Value.CFrame.p + Value.Size * .5
			return ("Region3.new(%s, %s)"):format(
				FormatProperty(min),
				FormatProperty(max)
			)
		elseif typeof(Value) == "Region3int16" then
			return ("Region3int16.new(%s, %s)"):format(
				FormatProperty(Value.Min),
				FormatProperty(Value.Max)
			)
		elseif typeof(Value) == "TweenInfo" then
			return ("TweenInfo.new(%d, %s, %s, %d, %s, %d)"):format(
				Value.Time, FormatProperty(Value.EasingStyle), FormatProperty(Value.EasingDirection),
				Value.RepeatCount, FormatProperty(Value.Reverses), Value.DelayTime
			)
		elseif typeof(Value) == "UDim" then
			return ("UDim.new(%d, %d)"):format(
				Value.Scale, Value.Offset
			)
		elseif typeof(Value) == "UDim2" then
			return ("UDim2.new(%d, %d, %d, %d)"):format(
				Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset
			)
		elseif typeof(Value) == "Vector2" then
			return ("Vector2.new(%d, %d)"):format(Value.X, Value.Y)
		elseif typeof(Value) == "Vector2int16" then
			return ("Vector2int16.new(%d, %d)"):format(Value.X, Value.Y)
		elseif typeof(Value) == "Vector3" then
			return ("Vector3.new(%d, %d, %d)"):format(Value.X, Value.Y, Value.Z)
		elseif typeof(Value) == "Vector3int16" then
			return ("Vector3int16.new(%d, %d, %d)"):format(Value.X, Value.Y, Value.Z)
		elseif typeof(Value) == "DateTime" then
			return ("DateTime.fromIsoDate(%q)"):format(Value:ToIsoDate())
    elseif typeof(Value) == "Font" then
      return "Font.new(\"" .. string.match(tostring(Value), "Family = (.+)\.json") .. ".json\")"
		end
	end
	
	return ""
end

local function Clutterify(Object, Indent, Comma)
	local Indent = Indent or 0
	local Data = {string.rep("\t", Indent), Object.ClassName, " ", "{", "\n"}
	
	local DefaultProperties = GetDefaultProperties(Object.ClassName)
	local PropertyCount = 0
	
	if DefaultProperties == nil then return "" end
	
	for Property, Default in DefaultProperties do
		if Object[Property] ~= Default then
			table.insert(Data, string.rep("\t", Indent + 1))
			table.insert(Data, Property)
			table.insert(Data, " = ")
			table.insert(Data, FormatProperty(Object[Property]))
			table.insert(Data, ",\n")
			
			PropertyCount = PropertyCount + 1
		end
	end
	
	local Children = Object:GetChildren()
	
	for Index, Child in Children do
		table.insert(Data, Clutterify(Child, Indent + 1, #Children ~= Index))
	end
	
	if PropertyCount == 0 and #Children == 0 then
		table.remove(Data, #Data)
	end
	
	if #Children == 0 and PropertyCount > 0 then
		table.remove(Data, #Data)
	end
	
	if PropertyCount ~= 0 and #Children ~= 0 then
		table.insert(Data, "\n" .. string.rep("\t", Indent))	
	end
	
	table.insert(Data, "}")
	
	if Comma then
		table.insert(Data, ",\n")
	end
	
	return table.concat(Data)
end

return Clutterify
