local RS=game.ReplicatedStorage
local RF=game.ReplicatedFirst
local TS=game:GetService("TweenService")

local amby=require(RF.Ambassador)
local net=require(RF.Network)
local stepper=require(RF.Stepper)
local vars=require(RF.Variables)
local soundmod=require(RS.Modules.Sound)
local shucky=require(RS.Modules.Shucky)
local BP=require(RS.Modules.BP)
local data= require(RF.PlayerData)
local mathlib = require(game.ReplicatedStorage.Modules.Mathlib)
local Spring = require(script.Parent.Viewmodel.Spring)

local r8pull=0.5
local hu2s = 0.08
local accuracy_sd,spdm = 0.0007,1
local numShots,spread,moveInaccuracy=0,0,0
local recoilx,recoily,recoilx2,recoily2,docam,ftick=0,0,0,0,0,0
local Spring = require(script.Parent.Viewmodel.Spring)
local mathlib = require(game.ReplicatedStorage.Modules.Mathlib)

vars.gunRecoilSpring2 = Spring.new(Vector3.new())
vars.gunRecoilSpring2.s = 20
vars.gunRecoilSpring2.d = 1/2

vars.camRecoilSpring = Spring.new(Vector3.new())
vars.camRecoilSpring.s = 40
vars.camRecoilSpring.d = 1

local cam=game.Workspace.CurrentCamera
local weps=RS.Weapons
local player=game.Players.LocalPlayer
local PrivateCommands = RS.PrivateCommands

local slots={}
local lastequipped=0
local reloading=false
local equipped=nil
local lastequip="3"
local equipid=0
local currentspread=0

function hasSpd()
	if vars.chr and vars.chr:FindFirstChild("Buffs") and vars.chr.Buffs:FindFirstChild("SpeedBoost") then return true end
	return false
end

local adr={}
for i,v in script:GetChildren() do
	local bruh=v:Clone()
	bruh.Parent=game.Lighting
	table.insert(adr,bruh)
end

function GI(slot) return slot and slots[slot] and weps[slots[slot].Weapon] end --GunInfo
function updtcam() vars.camRecoilSpring.t = Vector3.new(recoilx+recoilx2,recoily+recoily2,0) end
function shuffle(t) local j, temp; for i = #t, 1, -1 do j = math.random(i);temp = t[i];t[i] = t[j];t[j] = temp end; return t end

function decayshake(v,fExp,fLin,dT)
	fExp*=dT;fLin*=dT;v *= math.exp(-fExp)
	local fMag = (v.X^2+v.Y^2)^(1/2)
	if fMag>fLin then v*=1-fLin/fMag else v=Vector3.new() end
	return v.X,v.Y
end


function Lerp(a,b,t) t=math.clamp(t,0,1); return a+(b-a)*(1-t) end
local revert=CFrame.new()

net.HookEvent("GetWeaponLoadout",function(data, buy, bought)
	vars.loadout = data
	amby.Fire("BuyMenuUpdate")
	if equipped then  amby.Fire("SlotUp", buy, bought) end
end)

amby.HookEvent("SlotUp",function(buy,bought)
	table.clear(slots)
	if not vars.loadout then repeat task.wait() until vars.loadout end
	
	for i,v in vars.loadout do
		if v.GunName then
			local a=RS.Weapons:FindFirstChild(v.GunName)
			if a then slots[tostring(i)]={Weapon=a.Name,Ammo=v.Ammo,StoredAmmo=v.StoredAmmo,AltMode=v.AltMode} end
		else
			if typeof(v)=="table" then
				for c,d in v do
					local a=RS.Weapons:FindFirstChild(d.GunName)
					if a then slots[tostring(i).."_"..c]={Weapon=a.Name,Ammo=d.Ammo,StoredAmmo=d.StoredAmmo} end
				end
			end
		end
	end
	
	local yeabro=false
	if bought and slots[buy] then
		yeabro=true
		amby.Fire("EquipWeapon"); amby.Fire("EquipWeapon",buy)
	end
	
	if buy then
		local yea=true
		if vars.gunname and buy and string.sub(buy,1,1)=="4" then
			if equipped and string.sub(equipped,1,1)=="4" and vars.grenade~="thrown" then
				for i,v in slots do
					if string.sub(i,1,1)=="4" and slots[i] and slots[i].Weapon==vars.gunname then
						cheugie(i)
						return
					end
				end
			end
		end
		if equipped==buy and not yeabro then 
			if slots[buy] then
				amby.Fire("EquipWeapon"); amby.Fire("EquipWeapon",buy)
			else
				yea=false
			end
		end
		amby.Fire("InvUp",slots,equipped)
		if yea then return end
	end
	
	amby.Fire("AutoSwap")
end)

amby.HookEvent("AutoSwap",function()
	if slots["5"] then
		amby.Fire("EquipWeapon"); amby.Fire("EquipWeapon","5")
		return
	end
	if slots["1"] then
		amby.Fire("EquipWeapon"); amby.Fire("EquipWeapon","1")
		return
	end
	if slots["2"] then
		amby.Fire("EquipWeapon"); amby.Fire("EquipWeapon","2")
		return
	end

	if not slots["1"] and not slots["2"] then 
		amby.Fire("EquipWeapon"); amby.Fire("EquipWeapon","3")
	else
		amby.Fire("InvUp",slots,equipped)
	end
end)

function canequip(slot)
	if slot and slots[slot] and slots[slot].Weapon and weps:FindFirstChild(slots[slot].Weapon) then return true end
	return false
end

function notdoingit(wtv)
	local info=GI(equipped)
	local fr=info and tick()-(slots[equipped].lastfired or 0)>=0 and true or false
	local eq=tick()-lastequipped>=0 and true or false
	local whatrel=slots[equipped] and slots[equipped].Reloading and tick()-slots[equipped].Reloading or 0
	local rel=whatrel>=0 and true or false
	return not vars.pulling and not vars.silencing and not vars.planting and not vars.defusing and info and fr and eq and rel and (info:GetAttribute("SReload") or not reloading) and (wtv or not game.ReplicatedStorage:GetAttribute("Preparation"))
end

function nullplant()
	vars.planting=nil
	if vars.plantsound then vars.plantsound:Destroy() end
end

local alt=false

local function updateHUDText(text)
	if cam and cam:FindFirstChild("Arms") and cam.Arms:FindFirstChild("HUD") then
		cam.Arms.HUD.SurfaceGui.TextLabel.Text = text
	end
end

function unpull()
	if vars.pulling then
		advanceid()
		local info=GI(equipped)
		amby.Fire("VStop","pull",r8pull)
		vars.pulling=nil
		amby.Fire("UpdateSpeed")
		if info and info:FindFirstChild("Model") and info.Model:FindFirstChild("unpull") then soundmod.playsound(info.Model.unpull,cam) end
	end
end

function CalcSpread(bul,special,i,spreads)
	local info=GI(equipped)
	if not info then return CFrame.new() end
	local auto=info:GetAttribute("Auto")
	if (info:GetAttribute("Bullets") or 1)>1 then auto=false end
	local radius = math.max(0, spread+moveInaccuracy)
	local bruh=table.unpack({info,slots[equipped].AltMode})
	if special and info:GetAttribute("Pulling") then radius+=25 end--hardcode haha
	radius*=accuracy_sd

	local zamn=1/2
	--if info:GetAttribute("WeaponType")~="Sniper" then zamn=(1/4) end
	local a,b = (math.random() * math.pi * 2), radius * (math.random())^(zamn)

	local cos,sin=math.cos(a),math.sin(a)
	local x,y = b*cos,b*sin
	local Spread = CFrame.Angles(y, x, 0)
	if info:GetAttribute("RecoilY") and i==1 then
		spread+=(info:GetAttribute("FireSpread") or 0)*(vars.scoped and 0.5 or 1)*(vars.fullycrouched and 0.5 or 1)
		local fov=0.7*cam.FieldOfView/700
		local valx,valy=info:GetAttribute("RecoilX") or 0,info:GetAttribute("RecoilY") or 0
		recoilx+=cos*valx*fov;recoily+=(0.8+math.abs(0.2*sin))*valy*fov; docam=tick()

		--local visceral=0.001*(1-vars.adsmodifier)
		--recoilx2+=recoilx*visceral;recoily2+=recoily*visceral
		
		updtcam()
		vars.camRecoilSpring.p = vars.camRecoilSpring.t
	end
	return Spread
end

amby.HookEvent("TrySpread",function(dmg)
	local info=GI(equipped)
	if info and info:GetAttribute("Scoped") and dmg and dmg>0 then
		spread+=math.clamp(dmg*2,10,50)
	end
end)

function firebullet(special)
	if notdoingit()==false or player:GetAttribute("Team") == "Spectator" then return end
	if equipped and slots[equipped] then
		local info=GI(equipped)
		if not info then return end
		if info:GetAttribute("UsingM2")~=nil then
			if special and info:GetAttribute("UsingM2")==false then
				info:SetAttribute("UsingM2",true)
				for i,v in info.AltFire:GetAttributes() do 
					if v=="nil" then v=nil end
					info:SetAttribute(i,v) 
				end
			elseif not special and info:GetAttribute("UsingM2")==true then
				info:SetAttribute("UsingM2",false)
				for i,v in info.NormalFire:GetAttributes() do 
					if v=="nil" then v=nil end
					info:SetAttribute(i,v) 
				end
			end
		end
		
		if info:GetAttribute("Resurrect") or info:GetAttribute("Heal") or info:GetAttribute("SpeedB") or info:GetAttribute("Teleport") then
			if special then return end
			local stone=nil
			if info:GetAttribute("Resurrect") then
				stone=game.Workspace.Debris:GetChildren()
				local closest=10^2
				for i,v in stone do
					if v.Name=="Headstone" then
						local bro=game.Players:FindFirstChild(v:GetAttribute("Owner"))
						if bro and bro.Name~=player.Name and bro:GetAttribute("Team")==player:GetAttribute("Team") then
							local m=(v.Position-cam.CFrame.Position)
							if m.Unit:Dot(cam.CFrame.LookVector)>=0.9 then
								m=m.X^2+m.Y^2+m.Z^2
								if m<=closest then
									closest=m
									stone=v
								end
							end
						end
					end
				end
				if stone and typeof(stone)=="Instance" then else return end
			end
			local spd=hasSpd() and 2 or 1
			vars.grenade="thrown"
			amby.Fire("VPlay","fire",nil,nil,nil,spd)
			amby.Fire("WPlay","Fire",nil,nil,(spd)*(info:GetAttribute("AnimBoost") or 1))
			local sc=info:FindFirstChild("Model") and info.Model:FindFirstChild("eat")
			if sc then 
				soundmod.playsound(sc,cam)
				game.ReplicatedStorage.Events.RepSound:FireServer(sc)
			end
			local fr=(info and info:GetAttribute("FireTime") or 0)/spd
			slots[equipped].lastfired=tick()+fr
			advanceid()
			local curid=equipid
			if info:GetAttribute("Teleport") then
				game.ReplicatedStorage.Events.Heal:FireServer(equipped)
			end
			task.wait(fr)
			if equipid==curid then
				if info:GetAttribute("Resurrect") then
					if stone and typeof(stone)=="Instance" then game.ReplicatedStorage.Events.Defib:FireServer(equipped,stone) end
				elseif info:GetAttribute("Heal") or info:GetAttribute("SpeedB") then
					game.ReplicatedStorage.Events.Heal:FireServer(equipped)
				end
			end
			return
		end
		
		if info and info:GetAttribute("WeaponType")=="Throwable" then
			if special then return end
			local special=vars.grenade=="m2" and true
			if vars.grenade=="thrown" or (not vars.grenade and info and not info:GetAttribute("ThrowAnyway")) then return end
			local sc=info.Model:FindFirstChild("throw"); if sc then soundmod.playsound(sc,cam) end
			amby.Fire("VPlay","throw")
			amby.Fire("WPlay","Throw")
			vars.grenade="thrown"
			local vec=cam.CFrame.LookVector
			local horiz=(vec.X^2+vec.Z^2)^(1/2)
			local ang=math.deg(math.atan(vec.Y/horiz))
			RS.Events.Throwable:FireServer(equipped, cam.CFrame, ang)
			return
		end
		
		if equipped == "5" then
			local planting = shucky.canplant(player)
			if planting and not vars.jumping then
				local spd=hasSpd() and 2 or 1
				local sc=info.Model:FindFirstChild("plantinglocal")
				if sc then vars.plantsound=soundmod.playsound(sc,cam) end
				vars.planting=true
				game.ReplicatedStorage.Events.StartPlanting:FireServer()
				amby.Fire("VPlay","fire",nil,nil,nil,spd)
				local veloc=vars.hrp.AssemblyLinearVelocity
				amby.Fire("WPlay","Fire",nil,nil,spd)
				amby.Fire("UpdateSpeed")
			end
			return
		end
		local function empty() return equipped and slots[equipped] and slots[equipped].Ammo and slots[equipped].Ammo==0 end

		if not vars.pulling and not special and info:GetAttribute("Pulling") and not empty() then
			if vars.jumping then return end
			amby.Fire("VPlay","pull",nil,nil,nil,0.65)
			vars.pulling=true
			amby.Fire("UpdateSpeed")
			if info and info:FindFirstChild("Model") and info.Model:FindFirstChild("pull") then soundmod.playsound(info.Model.pull,cam) end
			local curid=equipid
			task.wait(r8pull)
			if curid==equipid then
				vars.pulling=nil
				amby.Fire("UpdateSpeed")
			else
				return
			end
		end	
		unpull()
		local deplete=(info:GetAttribute("UseAmmo") or 1)
		if typeof(deplete)~="number" or deplete~=deplete or deplete<1 then deplete=1 end
		if (slots[equipped].Ammo and slots[equipped].Ammo+1-deplete>0 or not slots[equipped].Ammo) then else amby.Fire("ReloadWeapon") return end
		if special and info:GetAttribute("UsingM2")==nil then return end
		reloading=false
		vars.silencing=nil
		local auto=info:GetAttribute("Auto")
		local autozoom,doublezoom=false,vars.doublezoom
		if not auto and not info:GetAttribute("NoBolt") and info:GetAttribute("Scoped") and vars.scoped then 
			autozoom=true
			task.delay(0.05,function() amby.Fire("Scope",false) end)
		end
		
		local Basa=(info and info:GetAttribute("Burst") and 3 or 1)-- and slots[equipped].AltMode
		
		local fr=vars.scoped and info:GetAttribute("ScopedFireRate") or Basa>1 and info:GetAttribute("Cooldown") or info:GetAttribute("FireRate")
		slots[equipped].lastfired=tick()+fr
		advanceid()
		
		local curid=equipid
		local st=tick()
		
		for BN=1,Basa do
			if equipped and slots[equipped].Ammo then 
				slots[equipped].Ammo-=deplete 
				game.ReplicatedStorage.Events.HandleShots:FireServer(equipped,"Shoot")
				if slots[equipped].Ammo<=(info and info:GetAttribute("Ammo") or 0)*0.2+1 then
					local sc=game.ReplicatedStorage.Sounds:FindFirstChild("Lowammo")
					if sc then soundmod.playsound(sc,cam) end
				end
			end	
			if curid~=equipid then break end
			local stp=cam.CFrame.p
			local what=not alt and cam.Arms:FindFirstChild("2Flash") and cam.Arms["2Flash"].Position
			local sp=what or cam:FindFirstChild("Arms") and cam.Arms:FindFirstChild("Flash") and cam.Arms.Flash.Position or stp
			local result=nil
			
			shucky.shootsound(shucky.GetWep(info.Name).Model,cam,slots[equipped].AltMode)
			local rng=math.random(1,2)
			if rng==1 then rng="" else rng=tostring(rng) end
			alt=not alt
			
			if info and info:GetAttribute("Melee") then amby.Fire("WStop","Fire"); amby.Fire("WStop","2Fire") end
			local veloc=vars.hrp.AssemblyLinearVelocity
			local default=vars.scoped and "AimFire" or alt and (string.sub(info and info:GetAttribute("AnimType") or "",1,4)=="Dual" or info and info:GetAttribute("Melee")) and "2Fire" or "Fire"
			if special and info:GetAttribute("Melee") then amby.Fire("VPlay","stab");amby.Fire("WPlay","Stab") else amby.Fire("VPlay",special and "sfire" or vars.scoped and "aimfire" or alt and "2fire" or "fire"..rng,"fire"); amby.Fire("WPlay",default,"Fire") end

			amby.Fire("Muzzle",alt,slots[equipped].AltMode)
			if info:GetAttribute("RecoveryTime") then
				local add=auto and 1.5 or 1.1
				ftick = tick()+math.min(0.275,info:GetAttribute("FireRate")*add)
				numShots += 1
			end
			amby.Fire("UpdateAmmo",slots[equipped])
			
			local Params2,Tabl=vars.params,{}
			
			result={}
			local iHit=false
			local t=nil
			while tick()-st<=0.3 do
				if curid~=equipid then break end
				local bul=(info:GetAttribute("Bullets") or 1)
				for i=1,bul do
					local Spread=CalcSpread(bul,special,i)
					if info:GetAttribute("Penetration") then
						Params2=RaycastParams.new()
						Params2.FilterType=Enum.RaycastFilterType.Exclude
						table.clear(Tabl)
						for i,v in vars.params.FilterDescendantsInstances do table.insert(Tabl,v) end
						Params2.FilterDescendantsInstances=Tabl
					end
					
					
					local hit,pos
					local shotCFrame=cam.CFrame
					local ep=(shotCFrame*Spread).LookVector*(info:GetAttribute("Range")/8 or 1000)
					local Raycast=workspace:Raycast(stp,ep,Params2)
					if info:GetAttribute("Melee") then
						if Raycast and Raycast.Instance then else Raycast=workspace:Spherecast(stp,1,ep,Params2) end
					end
					
					--bullet penetration
					local tries=0
					local penetrated=0
					local BangPlayer=0
					local Power=BP.getPower(info)
					local PParams=nil
					local Wallbang=nil
					while true do
						tries+=1 if tries>=4 then break end -- was previously 32
						if Raycast then hit,pos=Raycast.Instance,Raycast.Position else hit,pos=nil,stp+ep end
						if hit then iHit=true end
						local damageHit=hit and hit.Parent and hit.Parent:FindFirstChild("Humanoid")
						t={Hit=hit,hS=(hit and hit.Size and hit.Size.Magnitude),hP=(hit and hit.Position),cCF=(damageHit and shotCFrame),Position=pos,Normal=Raycast and Raycast.Normal or Vector3.new(0,1,0)} --- this is where the base result is stored btw
						if Wallbang then t.Wallbang=true end
						if (info:GetAttribute("Scoped") or info:GetAttribute("Aiming")) and vars.adsmodifier<=0 then t.Noscope=true end
						if t.Hit then table.insert(result,t) end
						if not Power then break end
						local What=hit
						local Endposition,Endnormal
						if What then
							local PeneDistance=0
							Wallbang=true
							local ishum=hit and hit.Parent and (hit.Parent:FindFirstChild("Humanoid") or hit.Parent:GetAttribute("Streak"))
							if ishum then
								What=hit.Parent
								BangPlayer+=1
							else
								local StartPos,Dir=t.Position + (ep.Unit * 10),ep.unit * -20
								PParams=RaycastParams.new()
								PParams.FilterType=Enum.RaycastFilterType.Include
								PParams.FilterDescendantsInstances={hit}
								local t2=workspace:Raycast(StartPos,Dir,PParams)
								local fakehit=t2 and t2.Instance
								Endposition,Endnormal=t2 and t2.Position,t2 and t2.Normal
								PeneDistance=1
								if fakehit then PeneDistance=(Endposition - t.Position).magnitude end
								local mod=BP.getModifier(hit)
								if BP.isHardStop(hit) then penetrated=Power end
								PeneDistance*=mod
							end
							table.insert(Tabl,What)
							Params2=RaycastParams.new()
							Params2.FilterType=Enum.RaycastFilterType.Exclude
							Params2.FilterDescendantsInstances=Tabl
							Raycast=workspace:Raycast(stp,ep,Params2)
							if penetrated>0 and ishum then t.Ratio=1-penetrated/Power end
							penetrated+=PeneDistance
						end
						if not hit or BangPlayer>=1 or penetrated>=Power then break end
						if Endposition and Endnormal then
							t.Endposition=Endposition
							t.Endnormal=Endnormal
						end
					end
					--bullet penetration end
					
					if info:GetAttribute("Backstab") and hit and hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
						local v1=CFrame.new(hit.Parent.PrimaryPart.Position*Vector3.new(1,0,1),vars.hrp.Position*Vector3.new(1,0,1)).LookVector
						local v2=hit.Parent.PrimaryPart.CFrame.LookVector
						if vars.chr and vars.blastjump  or v1:Dot(v2)<=0 then t.Backstab=true end
					end
				end
				
				if not info:GetAttribute("Melee") or curid~=equipid or iHit then break end
				task.wait()
				stp=cam.CFrame.p
			end
			if not iHit then table.insert(result,t) end
			
			if result then shucky.activateresult(result,info,sp,special,alt,slots[equipped].AltMode) end
			if Basa and Basa>1 then task.wait(info:GetAttribute("Burst") or 0.002) end
			if empty() then break end
		end
		
		
		if not auto then vars.mouse1=false end
		task.wait(math.max(0,fr-(tick()-st)))
		local nice=empty()
		local canaltfire=info:GetAttribute("UsingM2")~=nil
		if curid==equipid then
			if not auto and not info:GetAttribute("NoBolt") and info:GetAttribute("Scoped") and autozoom then 
				vars.doublezoom=doublezoom
				amby.Fire("Scope",true) 
			end
			if (vars.mouse1 or canaltfire and vars.mouse2 or nice) then 
				local dospecial=false
				if canaltfire and vars.mouse2 and (not vars.mouse1 or vars.mouse1 and vars.lastinput=="mouse2") then dospecial=true end
				firebullet(dospecial)
			end
		end
		
	end
	
	if slots[equipped] and slots[equipped].Ammo and not vars.scoped then
		local og = RS.Weapons[slots[equipped].Weapon]:GetAttribute("Ammo")
		if data.Cache.Settings.AutoReload and ((slots[equipped].Ammo / og) * 100) <= 0 then
			amby.Fire("ReloadWeapon")
		end
	end
end

function advanceid() equipid+=1;if equipid>=100000 then equipid=0 end end

amby.HookEvent("CheckAutoReload", function ()
	if data.Cache.Settings.AutoReload and slots[equipped] and slots[equipped].Ammo then
		local og = RS.Weapons[slots[equipped].Weapon]:GetAttribute("Ammo")
		if ((slots[equipped].Ammo / og) * 100) <= data.Cache.Settings.AutoReloadThreshold then
			amby.Fire("ReloadWeapon")
		end
	end
end)

amby.HookEvent("InspectWeapon",function()
	if  vars.grenade then return end
	if notdoingit(true)==false or reloading==true or vars.scoped or player:GetAttribute("Team") == "Spectator" or not player:GetAttribute("Alive") then return end
	local info=GI(equipped)
	--[[if equipped and slots[equipped] and slots[equipped].Ammo and slots[equipped].Ammo<=0 then 
		amby.Fire("VPlay","einspect","inspect",info)
	else ]]
	local rng=math.random(1,10)
	amby.Fire("VPlay",rng==1 and "rinspect" or "inspect","inspect",info) 
	--end
end)

amby.HookEvent("ReloadWeapon",function()
	if notdoingit()==false or reloading==true or player:GetAttribute("Team") == "Spectator" or not player:GetAttribute("Alive") then return end
	local info=GI(equipped)
	if not info then return end
	
	local shotgun=info:GetAttribute("SReload")

	local ammoneeded=info:GetAttribute("Ammo")
	if equipped and slots[equipped] and (ammoneeded and slots[equipped].Ammo and slots[equipped].Ammo<ammoneeded and (not slots[equipped].StoredAmmo or slots[equipped].StoredAmmo and slots[equipped].StoredAmmo>0)) then else return end
	
	local empty=false
	if equipped and not shotgun and slots[equipped].Ammo and slots[equipped].Ammo<=0 then empty=true end
	
	reloading=true
	unpull()
	amby.Fire("Scope",false)
	
	local curid=equipid
	local required=1
	local spd=hasSpd() and 2 or 1
	if shotgun then 
		required=ammoneeded-slots[equipped].Ammo
		amby.Fire("VPlay","1reload",nil,nil,nil,spd);amby.Fire("WPlay","1Reload")
		task.wait(info:GetAttribute("SReload")/spd) 
	end
	local reloadsc=info.Model:FindFirstChild("Reload")
	for i=1,required do
		if equipped and slots[equipped] and slots[equipped].StoredAmmo and slots[equipped].StoredAmmo<=0 then break end
		if equipid==curid then
			if reloadsc and vars.vm then vars.reloadsc=soundmod.playsound(reloadsc,vars.vm) end
			local reloadtime=info:GetAttribute("ReloadTime")
			local l=info.Viewmodel.reload:GetAttribute("Length")
			amby.Fire("VPlay",(empty==true and "ereload" or "reload"),"reload",nil,nil,(l and (l/reloadtime) or 1)*spd);amby.Fire("WPlay","Reload")
			local addtime=not shotgun and (info:GetAttribute("ClipRefill") and info:GetAttribute("ReloadTime")-info:GetAttribute("ClipRefill") or info:GetAttribute("EquipTime")) or 0
			task.wait((reloadtime-addtime)/spd)
			if equipped and equipid==curid and slots[equipped] then --Add to ammo count
				if not shotgun then slots[equipped].Reloading=tick()+addtime/spd end
				game.ReplicatedStorage.Events.HandleShots:FireServer(equipped,"Reload")
				if not shotgun then
					if slots[equipped].StoredAmmo then slots[equipped].StoredAmmo+=slots[equipped].Ammo end
					slots[equipped].Ammo=0 
				end 
				local diff=shotgun and 1 or ammoneeded
				if slots[equipped].StoredAmmo then
					diff=math.min(slots[equipped].StoredAmmo,diff)
					slots[equipped].StoredAmmo-=diff
				end
				slots[equipped].Ammo+=diff
				amby.Fire("UpdateAmmo",slots[equipped])	
				local ar=info:GetAttribute("AReload")
				if ar then task.wait(ar) end
				if addtime>0 then task.wait(addtime/spd) end
			end
		end
	end
	
	if equipid==curid then
		reloading=false
		if shotgun then amby.Fire("VPlay","2reload",nil,nil,nil,spd); amby.Fire("WPlay","2Reload") end
		if vars.mouse1 then firebullet() elseif vars.mouse2 then firebullet(true) end
	end
end)

amby.HookEvent("ToggleScope",function()
	if notdoingit(true)==false then return end
	if vars.spectator then return end
	local info=GI(equipped) 
	
	if info and info:GetAttribute("Scoped") then amby.Fire("Scope", nil, info:GetAttribute("SingleZoom") and true or false,info.Name) end
end)

amby.HookEvent("StopReload", function () -- stop it!
	advanceid()
	reloading=false
end)

local oldspeed=nil
local dela=0.3
local menu=game.Players.LocalPlayer.PlayerGui:WaitForChild("Menu"):WaitForChild("Menew")
amby.HookEvent("UpdateSpeed",function()
	local jumpheight=4
	local fs=game.ReplicatedStorage:GetAttribute("Gamemode")=="Flying Snipers" and true or false
	if fs then jumpheight*=4 end
	local info=GI(equipped)
	local basespd=(info and info:GetAttribute("Speed") or 250)
	local wk=basespd*hu2s
	local scope=info and info:GetAttribute("Scoped")
	if scope then scope=scope*hu2s/wk end
	local crouched=vars.crouchspd
	if crouched then 
		wk*=0.3
	else
		if vars.walking then wk*=0.5 end
	end
	
	local accl=1
	local bIsSlowSniperScoped = info and info.Name=="AWP" and true or false --the csgo dev actually did this
	if not crouched and not vars.walking or (vars.walking or crouched) and bIsSlowSniperScoped then accl*=basespd/250 end
	if crouched then
		if not bIsSlowSniperScoped then accl*=0.34 end
	else
		if vars.walking==true and not bIsSlowSniperScoped then accl*=0.52 end
	end
	vars.chr:SetAttribute("Accl",accl)
	
	if vars.scoped then wk*=(scope or 0.5) end
	
	local mult=1
	local cruds=vars.hum:GetChildren()
	for i,v in cruds do 
		if v.Name=="Tagged" then 
			mult*=v.Value
		end 
	end
	mult=math.clamp(mult,0.4,1)
	wk*=mult
	if hasSpd() then
		if mult>=1 then wk*=vars.chr.Buffs.SpeedBoost.Value end
		if adr and adr[1] and adr[1].Enabled==false then
			for i,v in adr do
				v.Enabled=true
			end
		end
	else
		if adr and adr[1] and adr[1].Enabled==true then
			for i,v in adr do
				v.Enabled=false
			end
		end
	end
	if vars.pulling then wk*=0.8 end
	if menu.Enabled or game.ReplicatedStorage:GetAttribute("Preparation") or vars.defusing or vars.planting or vars.buying or vars.chr and vars.chr:FindFirstChild("Buffs") and vars.chr.Buffs:FindFirstChild("Immovable") then wk=0 end
	
	local normal=wk
	
	vars.hum.JumpHeight=jumpheight
	vars.hum.MaxSlopeAngle=60
	if vars.jumping then
		unpull()
		if tick()-vars.landing>=dela then
			wk*=1.1
		else
			wk*=0.6 --Slower jump boost for spamming jump
		end
		if vars.push then wk=vars.push; oldspeed=nil end
	else
		if tick()-vars.landing<dela then 
			wk*=0.6
			task.delay(dela,function() amby.Fire("UpdateSpeed") end)
		end --Punish them for landing I guess so it doesn't feel jarring
	end

	if vars.jumping then
		if oldspeed==nil then oldspeed=wk end
		vars.hum.WalkSpeed=oldspeed
		--vars.chr:SetAttribute("Speed",oldspeed)
	else
		if oldspeed then oldspeed=nil end
		vars.hum.WalkSpeed=wk
		--vars.chr:SetAttribute("Speed",wk)
	end
end)

local function scrollSlot(direction: string)
	local count = vars.equipped
	if vars.equipped:find("_") then
		count = vars.equipped:split("_")[1]
	end
	count = tonumber(count) - (direction == "Up" and 1 or -1)

	if count > 5 then count = 1 end
	if count < 0 then count = 5 end

	local checked = {}
	while (not vars.loadout[tostring(count)] or (not vars.loadout[tostring(count)].GunName and not vars.loadout[tostring(count)]["1"])) and task.wait() and #checked < 6 do
		count -= direction == "Up" and 1 or -1

		if count > 5 then count = 1 end
		if count < 0 then count = 5 end

		if not table.find(checked, count) then
			table.insert(checked, count)
		end
	end
	
	if tostring(count) == "3" or tostring(count) == "4" then
		local maxSlots = 0

		for _,v in vars.loadout[tostring(count)] do
			maxSlots += 1
		end
		
		count = count.."_" .. (direction == "Up" and maxSlots or 1)
	end
	
	return count
end

local function scrollSub(direction: string)
	local slot, sub = table.unpack(vars.equipped:split("_"))
	local count = tonumber(sub) - (direction == "Up" and 1 or -1)

	if count > 4 then count = 1 end
	if count < 1 then count = 4 end

	local checked = {}
	while not vars.loadout[tostring(slot)][tostring(count)] and task.wait() and #checked < 4 do
		count -= direction == "Up" and 1 or -1

		if count > 4 then count = 1 end
		if count < 1 then count = 4 end

		if not table.find(checked, count) then
			table.insert(checked, count)
		end
	end

	return slot.."_"..count
end

amby.HookEvent("QuickSwitch",function(direction)
	if vars.noswitching then return end 
	if player.PlayerGui.HUD.Buymenu.Enabled then return end
	
	vars.switchdeb=tick()
	if direction and vars.equipped then
		local count = tostring(vars.equipped)
		local firstnum="4"; if vars.equipped:find("3_") then firstnum="3" end
		if vars.equipped:find(firstnum.."_") then
			local maxSlots = 0
			
			for _,v in vars.loadout[firstnum] do
				maxSlots += 1
			end
			
			local slot, sub = table.unpack(vars.equipped:split("_"))
			sub = tonumber(sub)
			
			if sub >= maxSlots and direction == "Down" or sub <= 1 and direction == "Up" then
				count = scrollSlot(direction)
			else
				count = scrollSub(direction)
			end
		else
			count = scrollSlot(direction)
		end
		
		lastequip = tostring(count)
	end
	
	if lastequip then amby.Fire("EquipWeapon",lastequip) end 
end)

amby.HookEvent("DropWeapon",function() 
	net.FireServer("DropWeapon",equipped)
end)

function cheugie(slot)
	if slot and (lastequip==slot or not slots[lastequip]) then --the loser failsafe
		if slot=="3" then
			lastequip="1"
		else
			lastequip="3"
		end
	end
	equipped=slot
	vars.equipped = tostring(slot)
	amby.Fire("InvUp",slots,equipped)
	amby.Fire("UpdateAmmo",slots[equipped])
	task.spawn(function() net.FireServer("ApplyGun",GI(slot),vars.equipped) end)
end

amby.HookEvent("EquipWeapon",function(slot)
	if slot==nil then
		if equipped then
			equipped=nil
			amby.Invoke("CreateViewmodel")
			return
		end
	end
	
	if slot=="3" or slot=="4" then
		local firstnum=string.sub(slot,1,1)
		local what=firstnum.."_1"
		local curnum=equipped and string.sub(equipped,1,1)==slot and tonumber(string.sub(equipped,3))
		if curnum then 
			curnum=firstnum.."_"..(curnum+1)
			if slots[curnum] then what=curnum end
		end
		slot=what
	end

	if slot and not slots[slot] then 
		if slots["2"] then
			slot="2"
		else
			slot="3" 
		end
	end
	
	if shucky.isalive()==false then return end
	if not canequip(slot) then return end
	if equipped==slot then return end
	--last equipped for quickswitching
	if equipped and slot and lastequip~=equipped and slot~=equipped then lastequip=equipped end
	unpull()
	vars.grenade=nil
	if vars.planting then nullplant() end
	local gun=slots[slot]
	
	spread=0
	numShots=0
	cheugie(slot)
	local info=GI(slot)
	local spd=hasSpd() and 2 or 1
	local etime=(info and info:GetAttribute("EquipTime") or 1)/spd
	lastequipped=tick()+etime
	
	local gunname=gun.Weapon or ""
	vars.gunname=gunname
	amby.Fire("UpdateSpeed")
	amby.Invoke("CreateViewmodel",gun.Weapon,gun.AltMode)
	amby.Fire("InitWM",RS.WMAnims[(info:GetAttribute("AnimType") or info:GetAttribute("WeaponType"))])
	amby.Fire("WPlay","Idle"); amby.Fire("VPlay","idle")

	amby.Fire("VPlay","equip",nil,nil,nil,spd)
	local eqp=shucky.GetWep(info.Name).Model:FindFirstChild("equip")
	if eqp then soundmod.playsound(eqp,cam) end
	amby.Fire("WPlay","Equip")
	vars.silencing=nil
	reloading=false
	advanceid()
	local curid=equipid
	vars.nocrosshair=info and (info:GetAttribute("WeaponType")=="Sniper" or info:GetAttribute("NoCrosshair")) and true or nil
	amby.Fire("Scope",false)
	task.wait(etime)
	local leftover=slots[equipped] and slots[equipped].Reloading
	if leftover then task.wait(leftover-tick()) end
	if equipid==curid then
		vars.grenade=nil
		if equipped and slots[equipped] and (slots[equipped].Ammo and slots[equipped].Ammo<=0) then amby.Fire("ReloadWeapon") end
		
		if slots[equipped] and slots[equipped].Ammo then
			local og = RS.Weapons[slots[equipped].Weapon]:GetAttribute("Ammo")
			if data.Cache.Settings.AutoReload and ((slots[equipped].Ammo / og) * 100) <= 0 then
				amby.Fire("ReloadWeapon")
			end
		end
		if vars.mouse1 and info and info:GetAttribute("WeaponType")=="Throwable" then cook("throw") return end
		if vars.mouse1 then firebullet() elseif vars.mouse2 then firebullet(true) end
	end
end)

function scopeloop()
	vars.spread = spread+moveInaccuracy
	if vars.scoped then
		local spreadToUse = vars.spread
		if vars.trackthis then spreadToUse=vars.fpsspread end
		local scopescale=math.clamp((spreadToUse)/25,0,1)
		local scope=vars.scopehair
		local desired=0.8*scopescale
		if scope and scope.Parent and scope.Parent.Visible then
			if scope.Scope.ImageTransparency~=scopescale then
				scope.Scope.ImageTransparency=scopescale
				scope.Scope.Blur.ImageTransparency=1-0.05*scopescale
				scope.Scope.Blur.Blur.ImageTransparency=1-0.15*scopescale
			end
		end
	end
end

local preview=script.Parent.preview:Clone()
amby.HookEvent("UpdateTPPreview",function()
	local info=GI(equipped)
	if info and info.Name=="Teleporter" and vars.chr and vars.chr:GetAttribute("Destination") then
		local pos=vars.chr:GetAttribute("Destination")-Vector3.new(0,0.45,0)
		if preview.Parent~=game.Workspace.CurrentCamera then
			preview.Parent=game.Workspace.CurrentCamera
			amby.Fire("MarkLocation",preview,"TP","infinite","TP",Color3.fromRGB(0,210,0))
		end
		preview.CFrame=CFrame.new(pos)
	else
		if preview.Parent~=nil then preview.Parent=nil end
	end
end)

local lastUpdate = tick()
local curspdm=0
stepper.Subscribe("SpreadAdjust",function(dt)
	--[[
	if tick() - lastUpdate >= 0.1 and workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Clips") and workspace.Map.Clips:FindFirstChild("Locations") then
		lastUpdate = tick()
		
		for _,v in workspace.Map.Clips.Locations:GetChildren() do
			local Region = v.CFrame:PointToObjectSpace(cam.CFrame.Position)
			if (math.abs(Region.X) <= v.Size.X / 2) and (math.abs(Region.Z) <= v.Size.Z / 2) then
				player.PlayerGui.HUD.Bottom.Location.Location.Text = v.Name
				
				break
			end
		end
	end]]
	
	local finalCamOffset = vars.camRecoilSpring.p
	local cameracframe=CFrame.Angles(0,finalCamOffset.X, 0) * CFrame.Angles(finalCamOffset.Y, 0, 0)
	cam.CFrame *= revert * cameracframe
	revert = cameracframe:Inverse()
	
	if vars.jumping then 
		local yvel=vars.hrp.AssemblyLinearVelocity.Y
		if yvel and vars.ymaxvel and yvel<vars.ymaxvel then vars.ymaxvel=yvel end
	end	
	if vars.hum and vars.hum:GetState()==Enum.HumanoidStateType.Climbing then
		if not vars.climbing then vars.climbing=true end
	else
		if vars.climbing then vars.climbing=nil; vars.lastclimbed=tick() end
	end
	
	local yeah=false
	if equipped and slots[equipped] then
		yeah=true
		local info=GI(equipped)
		local recvry=info:GetAttribute("RecoveryTime")
		local isgun=false
		if recvry then
			isgun=true
			if vars.fullycrouched then recvry=info:GetAttribute("CrouchRecoveryTime") end
			if vars.jumping==true then recvry*=2 end
		else
			recvry=3
		end

		if (docam==nil or tick()-docam>=1/60) and (recoilx>0 or recoily>0 or recoily2>0 or recoilx2>0) then
			local decayratio=1
			local limit=math.rad(3.4)
			recoilx2,recoily2=decayshake(Vector3.new(recoilx2,recoily2,0), 18*decayratio, limit, dt)--visceral feel???

			local smt=4.5*decayratio
			recoilx,recoily=decayshake(Vector3.new(recoilx,recoily,0),smt,limit,dt)
		end	

		local nspread=0
		moveInaccuracy=0
		if isgun then
			nspread=info:GetAttribute("Spread")
			nspread+=(vars.fullycrouched and info:GetAttribute("CrouchSpread") or info:GetAttribute("StandSpread"))

			if info:GetAttribute("Scoped") then nspread*=(1-vars.adsmodifier) end
			if info:GetAttribute("Spammer") and numShots>=6 then nspread=0 end

			if vars.jumping then nspread+=info:GetAttribute("JumpSpread")*spdm end
			
			if vars.climbing then nspread+=info:GetAttribute("LadderSpread")*spdm end
			if tick()-(vars.justspawned or 0)<=2 then vars.ymaxvel=nil end
			if tick()-vars.landing<=0.25 and vars.ymaxvel then spread+=(info:GetAttribute("LandSpread")*spdm*-vars.ymaxvel*hu2s); amby.Fire("LandAnim",-vars.ymaxvel) end

			local fdiff=tick()-ftick
			if fdiff>0 and numShots>0 then
				local fDecayFactor = math.log(10)*2
				numShots = Lerp(numShots, 0,math.exp( dt * -fDecayFactor ))
				if numShots<=0.001 then numShots=0 end
			end

			--if slots[equipped].AltMode and info:GetAttribute("Burst") then nspread=(nspread+5)*1.5 end
			
			local ms=info:GetAttribute("RunSpread")
			local fs=game.ReplicatedStorage:GetAttribute("Gamemode")=="Flying Snipers" and true or false
			if fs then ms=nil end

			if vars.hrp and ms then
				local val=vars.hrp.AssemblyLinearVelocity
				val=vars.hum and vars.hum.Sit and 0 or (val.X^2+val.Z^2)^(1/2)
				curspdm=stepper.flerp(curspdm,val,4,dt)
			
				
				if (not vars.fullycrouched or vars.jumping) and not vars.climbing then
					local curspd=(info:GetAttribute("Speed") or 250)*hu2s
					local min=(curspd*0.3)
					local max=(curspd*0.9)
					local movescale = mathlib.RemapValClamped(curspdm, min, max,0,1)
					if not vars.walking and not vars.fullycrouched then movescale^=0.25 end
					moveInaccuracy+=ms*spdm*movescale
				end
				
			end
		else
			nspread=0
		end

		if nspread>spread then 
			spread=nspread
		else
			local fDecayFactor=math.log(10)/recvry
			spread=Lerp(spread,nspread,math.exp(dt*-fDecayFactor))
		end
		
		updtcam()	
	end
	scopeloop()
	local ok=yeah and spread+moveInaccuracy
	if vars.trackthis then ok=vars.fpsspread end
	if ok then 
		vars.chspread=ok*accuracy_sd*2
		amby.Fire("UpdateCrosshair")
	end
	
end,"RenderStepped",1/60)

function cook(what)
	if notdoingit()==false then return end
	if vars.grenade=="thrown" then return end
	local info=GI(equipped)
	if info and info:GetAttribute("WeaponType")=="Throwable" then
		if what=="throw" then
			if vars.grenade==nil then cook("m1") return end
			firebullet()
		else
			if info:GetAttribute("ThrowAnyway") then firebullet() return end
			if vars.grenade~=what then
				amby.Fire("VPlay",what)
				if vars.grenade==nil then 
					--amby.Fire("WPlay","Pull")
					amby.Fire("VPlay","pin"..what) 
					local sc=info.Model:FindFirstChild("Pin"); if sc then soundmod.playsound(sc,cam) end
				end
				amby.Fire("VStop",what=="m1" and "m2" or "m1")
				vars.grenade=what
			end
		end
	end
end

amby.HookEvent("CheckMouse1",function(down)
	if vars.freemouse then return end
	local info=GI(equipped)
	if down then
		if info and info:GetAttribute("WeaponType")=="Throwable" then cook("m1") return end
		firebullet() 
	else
		unpull()
		if vars.planting then
			nullplant()
			amby.Fire("VStop","fire")
			amby.Fire("WStop","Fire")
			amby.Fire("UpdateSpeed")
			local displayText = string.rep("*", 7)
			if vars.vm and vars.vm:FindFirstChild("HUD") then vars.vm.HUD.SurfaceGui.TextLabel.Text = displayText end
		end
		if vars.grenade then cook("throw") end
	end
end)

vars.marking=tick()
amby.HookEvent("CheckMouse2",function(down)
	if vars.freemouse then return end
	local info=GI(equipped)
	if down then
		if info and info:GetAttribute("Teleport") then
			if tick()-vars.marking<=0.5 then return end
			amby.Fire("VPlay","mark")
			vars.marking=tick()
			game.ReplicatedStorage.Events.HandleShots:FireServer(equipped,"TP")
			return
		end
		if info and info:GetAttribute("ApplyTime") then
			if vars.silencing or reloading then return end
			local t=info:GetAttribute("ApplyTime")
			local applying=false
			local curid=equipid
			if slots[equipped] and not slots[equipped].AltMode then 
				t=info:GetAttribute("RemoveTime") 
				amby.Fire("VPlay","sremove")
			else
				task.delay(0.1,function()
					if curid==equipid and vars.vm then shucky.handlemodel(vars.vm,false) end
				end)
				amby.Fire("VPlay","sapply")
				applying=true
			end
			vars.silencing=true
			task.wait(t)
			if curid==equipid then
				if not applying then shucky.handlemodel(vars.vm,true) end
				if slots[equipped] and slots[equipped].AltMode~=nil then
					slots[equipped].AltMode=not slots[equipped].AltMode
					game.ReplicatedStorage.Events.HandleShots:FireServer(equipped,"Alt")
				end
				vars.silencing=nil
			end
		end
		firebullet(true) 
	end
end)

while task.wait(0.3) do
	if shucky.isalive() then
		if vars.vm and vars.vm:IsDescendantOf(cam) then
		else
			amby.Fire("AutoSwap")
		end
	end
	local info=GI(equipped)
	if vars.chr and info and shucky.isalive() and vars.chr:GetAttribute("WhatGun")~=info.Name then
		net.FireServer("ApplyGun",info,vars.equipped) ---eeeeeeeeww
	end
end
