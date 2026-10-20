local Grenade = {}
Sound = require(game.ReplicatedStorage.Modules.Sound)
local rs=game:GetService("RunService")
local amby=require(game.ReplicatedFirst.Ambassador)
local breakglass = require(game.ReplicatedStorage.Modules.Breakglass)
local CS=game:GetService("CollectionService")
local shk=require(game.ReplicatedStorage.Modules.Shucky)
local stepper=require(game.ReplicatedFirst.Stepper)

function getsin(c,d) return math.sin(math.acos(c:Dot(d))) end

function lerp(a,b,t,dt) return a+(b-a)*(1-math.exp(-t*dt)) end

Grenade.grav=50--game.Workspace.Gravity*0.34
function Grenade.doit(args)

	local elasticity=0.3
	local friction=1
	local cf=args.CF
	local v=args.Velocity
	local bruhmgn=v.Magnitude
	local g=args.Grenade
	local g2=Vector3.new(0,-Grenade.grav,0)
	local wep=game.ReplicatedStorage.Weapons:FindFirstChild(g:GetAttribute("Weapon"))
	if not wep then return end
	
	local dangman=wep:GetAttribute("BruhRotate") or CFrame.new()
	g.CFrame=cf*dangman
	
	local hit=nil
	local phit=nil
	local v2=Vector3.new()

	local p=cf.p
	local n=Vector3.new(0,1,0)
	local hco=0.25--🙄
	local realvector = v.unit --🙄
	local rightVector=(CFrame.new(Vector3.new(),realvector*100)*CFrame.Angles(0,math.rad(90),0)).LookVector
	local nom=Vector3.new(0,1,0)*hco
	local nom2=Vector3.new(0,1,0)*(hco+0.001)
	local bounces=0
	local wl={workspace.Terrain, workspace.Map.Geometry}
	if workspace.Map:FindFirstChild("Regen") and wep and wep:GetAttribute("Stick") then table.insert(wl,game.Workspace.Map.Regen) end
	local params=RaycastParams.new()
	params.RespectCanCollide=true
	params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances={workspace.Terrain, workspace.Map.Geometry}
	--workspace.Map.Clips
	local team=g:GetAttribute("Team")
	local heatseek=nil
	if wep:GetAttribute("HeatSeek") then
		heatseek={}
		for i,v in game.Players:GetPlayers() do
			if v and v:GetAttribute("Team")~=team and v.Character and v.Character.PrimaryPart then 
				table.insert(wl,v.Character) 
				table.insert(heatseek,v.Character)
			end
		end
		for i,v in CS:GetTagged("AI") do
			local suave:number = v:GetAttribute("Health") 
			if v and v.Parent ~= nil and suave and suave >= 1 and v:GetAttribute("Team")~=team and v.PrimaryPart then 
				table.insert(wl,v) 
				table.insert(heatseek,v)
			end	
		end
	end
	
	local breh=g2
	g2*=(wep:GetAttribute("Gravity") or 1)
	
	local expire=wep:GetAttribute("ExpireGravity")
	if expire then task.delay(expire,function() g2=breh end) end
	
	elasticity=wep:GetAttribute("Elasticity") or elasticity
	local conn2=nil
	local weld=nil
	conn2=g.AncestryChanged:Connect(function()
		if weld then weld:Destroy() end
		conn2:Disconnect()
		conn2=nil
	end)
	
	local bouncesc=wep and wep.Model:FindFirstChild("bounce1")
	local hitsc=wep and wep.Model:FindFirstChild("hit"..math.random(1,wep.Model:GetAttribute("hitcount") or 3))
	local maxbounces=4
	local MyGuy=game.Players:FindFirstChild(g:GetAttribute("Owner") or "")
	
	
	while true do
		local dt=task.wait()
		if heatseek then
			local closest=200^2
			local target=nil
			for i,v in heatseek do
				local eplr=game.Players:GetPlayerFromCharacter(v) or v
				if v and v.PrimaryPart and (eplr:GetAttribute("Health") or 0)>0 then
					local vdist= v.PrimaryPart.Position-p
					local y=vdist.Y^2
					local dist=vdist.X^2+y+vdist.Z^2
					if dist<=closest and dist-y<=1600 then
						local h,p,n=workspace:FindPartOnRayWithWhitelist(Ray.new(p,vdist),wl)
						if not h or h and h:IsDescendantOf(v) then
							closest=dist
							target=v.PrimaryPart
						end
					end
				end
			end
			
			if target then
				local dir=(target.Position-p).Unit*bruhmgn
				v=stepper.flerp(v,dir,4,dt)
			end	
		end
		if not (g and g:IsDescendantOf(game.Workspace) and g:GetAttribute("Stopped")==nil) then break end
		
		if (g and g:IsDescendantOf(workspace)) and workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Geometry") then
			if wep:GetAttribute("Smoke") then 
				local molly=CS:GetTagged("Molotov")
				for i,v in molly do
					local diff=g.Position-v.Position
					if diff.Y^2<=2^2 and diff.X^2+diff.Z^2<=(v.Size.X/2)^2 then
						amby.Fire("Explode",g)
						break
					end
				end
			end
			
			local hitglass = false
			--there are cases where the grenade can go through ceilings if you don't raycast the offset 🙄
			local ayy,sp,sn=workspace:FindPartOnRayWithWhitelist(Ray.new(p,nom),wl)
			sp=sp-Vector3.new(0,0.001,0)
			
			local v1=(v+v2)*dt --sum of forces
			
			local gradius=g and (g.Size.Y)/2 or 1 --weird ass approximation for general radius of ellipsoids

			--apply base velocity
			hit,phit,n=workspace:FindPartOnRayWithWhitelist(Ray.new(sp,v1-nom2),wl)
			if not hit then n=Vector3.new(0,1,0) end

			if hit and (hit.Name=="Glass" or hit:HasTag("ShatterPart")) and not hit.Locked then
				breakglass.BreakGlass(hit)
				continue
			end
			--apply gravity against slopes
			local hit2,phit2,n2=nil,nil,Vector3.new(0,1,0)
			if (v.Y+v2.Y)<0 then hit2,phit2,n2=workspace:FindPartOnRayWithWhitelist(Ray.new(sp,Vector3.new(0,1,0)*(v.Y+v2.Y)*(dt)-nom2),wl) end
			if not hit2 then n2=Vector3.new(0,1,0) end
			local c2=(CFrame.new(Vector3.new(),n2)*CFrame.Angles(math.rad(-90),math.rad(0),0))
			local c=c2.lookVector --vector of slope direction
			local d=Vector3.new(c.X,0,c.Z).unit --vector of slope direction without considering y
			local v2add=false
			if hit2 and c.magnitude>0 and d.magnitude>0 then
				local sin=getsin(c,d) --angle b/n vectors
				if sin<=0 then
					--rotate the vectors around y axis because roblox messed up normal calculations
					c=(c2*CFrame.Angles(0,math.rad(90),0)).lookVector
					if c.Y>0 then c=(c2*CFrame.Angles(0,math.rad(-90),0)).lookVector end
					d=Vector3.new(c.X,0,c.Z).unit
					sin=getsin(c,d)
				end
				if math.abs(sin)>0 then
					v2=v2+2*c*g2.magnitude*sin*dt/3
					v2add=true
				end
			end

			local diff=Vector3.new(0,1,0)*gradius
			
			local x,y,z
			if g then x,y,z=g.CFrame:toEulerAnglesXYZ() end
			p=phit
			local rot=((v1.X^2+v1.Z^2)^(1/2))/(gradius*dt)
			rot=rot*dt
			local goal=0
			if v1.unit.magnitude>0 then	
				local mv=v1.unit
				goal=mv:Dot(realvector)
			end
			if g then
				local cf=CFrame.new(p+diff)*CFrame.Angles(x,y,z)
				if wep and (wep:GetAttribute("NoFlipping") or wep:GetAttribute("FixedRotation")) then else cf*=CFrame.Angles(-goal*rot,0,0) end
				g.CFrame=cf
			end
			if hit then
				if v.unit.magnitude>0 then
					local passed=true
					local plr=false
					if hit and hit.Parent and hit.Parent:FindFirstChild("Humanoid") and hit.Parent.PrimaryPart then plr=true end
					if wep and wep:GetAttribute("OnlyOnTopSurfaces") and (n.Y<0.5 or hit.Anchored==false) then passed=false end
					local ori=wep and wep:GetAttribute("Reorient")
					if hit.Anchored==false and ori and not hit:GetAttribute("StickMe") then passed=false end
					if wep and wep:GetAttribute("BounceAngle") and math.abs(v.Unit:Dot(n))<=0.7 and bounces<=0 and not plr then passed=false end
					if passed and wep:GetAttribute("ExplodeOnHit") then amby.Fire("Explode",g,hit,phit,n) end
					if wep and wep:GetAttribute("Stick") and passed and hit.CanQuery then
						if wep and wep:GetAttribute("FaceIt") then g.CFrame=CFrame.lookAt(g.Position,g.Position-n,rightVector:Cross(n))*CFrame.new(0,0,0.6) end
						local go=true
						local noplr=true
						if plr and wep then
							go=false
							local eplr=game.Players:GetPlayerFromCharacter(hit.Parent) or hit.Parent
							if eplr and (eplr:GetAttribute("Health") or 0)>0 then
								go=true
								noplr=false
								if wep:GetAttribute("DmgOnHit") then
									amby.Fire("Explode",g,hit,phit,n)
								else
									g.Anchored=false
									g.Massless=true
									weld=Instance.new("Weld")
									weld.Name="GWeld"
									weld.Part0=hit.Parent.PrimaryPart
									weld.Part1=g
									weld.C0=weld.Part0.CFrame:Inverse()*weld.Part1.CFrame
									weld.Parent=hit.Parent
									if wep.Name=="Semtex" and MyGuy then
										amby.Fire("AwardXP",MyGuy,"Stuck!",50)
									end
								end
							end
						end
						if go then
							if hitsc then Sound.playsound(hitsc,g) end
							g:SetAttribute("Stopped",tick())
							if wep and wep:GetAttribute("FixedRotation") then g.CFrame=CFrame.new(g.Position)*g:GetAttribute("Rot")*dangman end
							if ori then g.CFrame=CFrame.new(g.Position,g.Position+n)*CFrame.Angles(math.rad(-90),0,0) end
							if wep and wep:GetAttribute("Hittable") then g.CanCollide=true; g.CollisionGroup="Default" end
							g:SetAttribute("Velocity",v)
							if noplr and not hit.Anchored then
								g.Anchored=false
								g.Massless=true
								weld=Instance.new("Weld")
								weld.Name="SWeld"
								weld.Part0=hit
								weld.Part1=g
								weld.C0=weld.Part0.CFrame:Inverse()*weld.Part1.CFrame
								weld.Parent=g
							end
							if wep and wep:GetAttribute("Laser") then
								local sp=g.Position
								local dir=n*20
								local r=game.Workspace:Raycast(sp,dir,params)
								local pos=r and r.Instance and r.Position or sp+dir
								if pos then
									local sz=(pos-g.Position).Magnitude
									local laser=script.Laser:Clone()
									laser.Color=shk.teamcolors[g:GetAttribute("Team")]
									local DEPTH=2
									laser.Size=Vector3.new(DEPTH,DEPTH,sz)
									laser.CFrame=CFrame.new(g.Position,g.Position+n)*CFrame.new(0,0,-sz/2)
									laser.Anchored=false
									laser.Massless=true
									laser.Parent=g
									local weld=Instance.new("Weld")
									weld.Name="LWeld"
									weld.Part0=g
									weld.Part1=laser
									weld.C0=weld.Part0.CFrame:Inverse()*weld.Part1.CFrame
									weld.Parent=laser
									Sound.playsound(game.ReplicatedStorage.Sounds.Laseridle,g)
								end
							end
						end
					end
					local bhit=workspace:FindPartOnRayWithWhitelist(Ray.new(p+diff,-nom2*2),wl)
					if bhit then
						local dot=math.abs(v.unit:Dot(Vector3.new(0,-1,0)))
						if dot>=0.5 then v*=(1-(dot-0.5)/2) end
						if n.Y>=0.9 then
							bounces+=1
							if maxbounces and bounces>=maxbounces then 
								g:SetAttribute("Stopped",tick())
								if wep:GetAttribute("Decoy") or wep:GetAttribute("Smoke") then amby.Fire("Explode",g) end
							end
						end
					end
					if not g:GetAttribute("Stopped") then
						if v.X^2+v.Y^2+v.Z^2>=10^2 then
							if bouncesc then
								Sound.playsound(wep.Model["bounce"],g)
							else
								Sound.playsound(game.ReplicatedStorage.Sounds["Bounce"..math.random(1,4)],g)
							end
						end
					end
					v=(v.unit-(1+elasticity)*(v.unit:Dot(n))*n)*v.magnitude
				end
			end
			if bounces>=1 then v=lerp(v,Vector3.new(),friction*bounces,dt) end
			
			v=v+g2*dt
		end
	end
	
end
return Grenade
