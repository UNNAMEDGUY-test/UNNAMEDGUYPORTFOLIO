-- xonae

-- dependencies
local Director = require(game.ReplicatedFirst.Director)
local PlayerData = require(game.ReplicatedFirst.PlayerData)
local Network = require(game.ReplicatedFirst.Network)
local Maid=require(game.ReplicatedFirst.Maid)
local Variables =require(game.ReplicatedFirst.Variables)
local Stepper=require(game.ReplicatedFirst.Stepper)
local amby=require(game.ReplicatedFirst.Ambassador)

-- services
local CameraPlane: CameraPlane = { ClassName = script.Name, ClassModule = script }
local mt = { __index = CameraPlane }


local id=0

function check(a,b) return a.X^2+a.Z^2<=b.X^2+b.Z^2 end

local checkid=0
local maplane=nil
amby.HookEvent("YourCameraPlane",function()
	checkid+=1
end)
function CameraPlane:Init()
	local nice=false
	local touching=false
	self.Root.Transparency=1
	if self.Root.Shape==Enum.PartType.Cylinder then
		self.Cylinder=true
		local v1=self.Root:GetAttribute("V1") --Start direction of allowed cone
		local v2=self.Root:GetAttribute("V2") --End direction of allowed cone
		local v3=self.Root:GetAttribute("V3") --FALLBACK TO THIS ALWAYS
		local avg=(v1+v2)/2
		local v0=avg~=Vector3.new() and avg.Unit or avg
		local b=math.acos(v1:Dot(v2))
		id+=1
		self.ID=id
		Stepper.Subscribe("CameraPlane"..self.ID,function()
			if Variables.chr and Variables.hrp and self.Root:IsDescendantOf(game.Workspace) then
				local r=self.Root.Size.Y/2+1
				local y=self.Root.Size.X/2
				local yo=(Variables.hrp.Position-self.Root.Position)
				if self.Root:GetAttribute("Inverse") then yo*=-1 end
				local a=yo*Vector3.new(1,0,1)
				local totouch=false
				if yo.X^2+yo.Z^2<=r^2 and yo.Y^2<=y^2 then totouch=true  end
				local lv=nil
				if totouch then
					if a~=Vector3.new() then
						a=a.Unit
						if touching~=true then
							touching=true
							Variables.camchange=tick()
						end
						if v0==Vector3.new() or math.acos(a:Dot(v0))<=b/2 then
							nice=true
							lv=a
							Variables.quickcam=true
						else
							nice=false
							if check(v1-a,v2-a) then lv=v1 else lv=v2 end
							Variables.quickcam=false
						end
					end
				else
					if touching~=false then
						touching=false
						if v3 then
							lv=v3
						else
							a=a.Unit
							if check(v1-a,v2-a) or nice then lv=v1 else lv=v2 end
						end
						Variables.quickcam=false
					end
				end
				if lv and Variables.camplane~=lv then Variables.camplane=lv end
			end
		end,"Stepped")
	else
		local function do1(ocheckid,lv)
			if maplane==self.Root and checkid==ocheckid then
				if Variables.camplane~=lv then
					Variables.camplane=lv
				end						
			end
		end
		local function do2(ocheckid)
			if maplane==nil and checkid==ocheckid then
				Variables.camplane=Vector3.new(0, 0, -1)			
			end
		end
		self.Maid:Add(self.Root.Touched:Connect(function(hit)
			if Variables.chr and hit.Name=="HumanoidRootPart" and hit.Parent==Variables.chr then
				local lv=self.Root:GetAttribute("Camera") or self.Root:GetAttribute("LookHere") or self.Root.CFrame.LookVector
				maplane=self.Root
				checkid+=1
				local ocheckid=checkid
				if self.Root:GetAttribute("Camera") then
					task.delay(0.5,function()
						do1(ocheckid,lv)
					end)			
				else
					do1(ocheckid,lv)
				end
			end
		end))
		self.Maid:Add(self.Root.TouchEnded:Connect(function(hit)
			if Variables.chr and hit.Name=="HumanoidRootPart" and hit.Parent==Variables.chr then
				if maplane==self.Root then
					maplane=nil
					checkid+=1
					local ocheckid=checkid
					if self.Root:GetAttribute("Camera") then
						task.delay(0.5,function()
							do2(ocheckid)
						end)
					else
						do2(ocheckid)
					end
				end
			end
		end))
	end
end

function CameraPlane:Destroy() 
	if self.Cylinder then Stepper.Unsubscribe("CameraPlane"..self.ID,"Stepped") end
	self.Maid:Clean() -- nothing to clean!
end

local function new(root: PVInstance)
	local self = {
		Root = root,
		Maid = Maid.new(),
		ID=0
	}

	return setmetatable(self, mt)
end

export type CameraPlane = typeof(new(...))

local export = setmetatable({ ["new"] = new :: (root: PVInstance) -> CameraPlane }, mt)
Director.Register(script.Name, { export })

return export
