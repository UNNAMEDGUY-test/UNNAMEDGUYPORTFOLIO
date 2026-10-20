local RF = game:GetService("ReplicatedFirst")
local amby=require(RF.Ambassador)
local player=game.Players.LocalPlayer
local vars=require(RF.Variables)
local rs=game:GetService("RunService")
local shk=require(game.ReplicatedFirst.Modules.Shucky)

local gotcha=false
local hitit=false

function calc(e,s,g,t)
	return ((e-s)*Vector3.new(1,1,0)-0.5*g*t*t)/t
end
local g=Vector3.new(0,-game.Workspace.Gravity,0)
local st=0.65
local st2=0.45
local brotime=0 --the time it takes the ball to travel
local lesstime=0.7
local t=nil
local tall=false
amby.HookEvent("VisualStart_"..script.Name,function(myt)
	local freez=vars.arena and vars.arena:GetAttribute("Freeze")
	t=myt
	local pfx=game.ReplicatedStorage.Particles:FindFirstChild("Trail_"..(t.Wep and t.Wep.Name or ""))
	local user=t.User
	local target=t.Target
	
	gotcha=false
	hitit=false
	local wep=script.Parent[user:GetAttribute("Ball")]
	amby.Fire("EquipWep",user.Model,wep,nil,true)	
	local e=(target:GetAttribute("MyRealPos") or target.PrimaryPart.Position)
	local scale=target and target:FindFirstChild("Model") and target.Model:GetScale() or 1
	e=e*Vector3.new(1,0,1)+Vector3.new((target:GetAttribute("BallX") or 0)*scale,target.PrimaryPart.Position.Y+(target:GetAttribute("BallY") or 0)*scale,0)
	local nt = 0;
	local conn=nil
	
	shk:PlayAnim(user,"SuperballEquip")
	game.Workspace.Sounds.Boing:Play()
	
	vars.impact=st+1
	local ball=wep:Clone()
	
	if pfx then
		for i,v in pfx:GetChildren() do
			v:Clone().Parent=ball
		end
	end
	
	ball.RWeld:Destroy()
	ball.Anchored=true
	ball.Transparency=1
	shk.scaleit(ball,user.Model)
	ball.Parent=game.Workspace.BattleDump
	ball.CollisionGroup="Passable"
	
	task.wait(st)
	local s=(user.Model["Right Arm"].CFrame*CFrame.new(0,-1,0)).Position
	ball.CFrame=CFrame.new(s)
	if not freez then task.delay(4,function() ball:Destroy() end) end
	brotime=t.Wep:GetAttribute("BaseTime") or 0.4+0.15*math.max(((e-s).Magnitude-12)/12,0)
	local v0=calc(e,s,g,brotime)
	vars.impact=st+brotime
	
	amby.Fire("EquipWep",user.Model)
	ball.Transparency=0
	ball.Trail.Enabled=true
	ball.Trail2.Enabled=true
	
	local function go()
		if pfx then for i,v in ball:GetDescendants() do if v:IsA("ParticleEmitter") then v.Enabled=true end end end
	end
	local function stop()
		if pfx then for i,v in ball:GetDescendants() do if v:IsA("ParticleEmitter") then v.Enabled=false; v:Clear() end end end
	end
	go()
	
	local ruined=false
	if shk.isdodgy(t.Target) then ruined=true end
	local freezie=false
	conn=rs.Heartbeat:connect(function(hb)
		if nt then
			if nt>=brotime and freez and not freezie then freezie=true; vars.curchat="ball_stop"; amby.Fire("SwapBubble") end
			if hitit==true and nt>=brotime and not ruined then
				nt=nil
				ball.Anchored=false
				ball.CanCollide=true
				v0=calc(e,s,g,brotime)
				if gotcha==true then
					vars.curchat="ball_win"; amby.Fire("SwapBubble")
					gotcha=false
					--bounce back
					if tall then
						ball.Anchored=true
						ball.CanCollide=false
						s=e
						
						local target=t.Target
						e=(target:GetAttribute("MyRealPos") or target.PrimaryPart.Position)
						local scale=target and target:FindFirstChild("Model") and target.Model:GetScale() or 1
						e=e*Vector3.new(1,0,1)+Vector3.new((target:GetAttribute("BallX") or 0)*scale,target.PrimaryPart.Position.Y+(target:GetAttribute("BallY") or 0)*scale,0)
						
						if shk.isdodgy(t.Target) then ruined=true end 
						v0=calc(e,s,g,brotime)
						nt=0
						game.Workspace.Sounds.Boing:Play()
					else
						v0=calc(s,e,g,brotime*lesstime)
						ball.AssemblyLinearVelocity=v0
						task.delay(brotime*lesstime,function()
							--toss it again
							amby.Fire("EquipWep",user.Model,wep,nil,true)
							ball.Anchored=true
							ball.CanCollide=false
							ball.Transparency=1
							stop()
							ball.Trail.Enabled=false
							ball.Trail2.Enabled=false
							shk:PlayAnim(user,"SuperballCatch")
							task.wait(st2)
							s=user.Model.Weapon.Position
							amby.Fire("EquipWep",user.Model)
							game.Workspace.Sounds.Boing:Play()
							ball.Transparency=0
							go()
							brotime=brotime*lesstime
							v0=calc(e,s,g,brotime)
							nt=0
						end)
					end
				else
					--simply bounce the superball off
					ball.CanCollide=false
					hitit=false
					if not vars.cutit then 
						ball.AssemblyLinearVelocity=v0 
						task.delay(2,function() ball:Destroy() end)
					else 
						shk:PlayParticle((vars.cutit=="flaming" and "SuperAsh" or "SuperPop"),ball.Position+Vector3.new(0,0.5,5))
						ball:Destroy() 
					end
					conn:disconnect()
				end
			end			
			if nt and (nt<brotime or ruined) and ball and ball.Anchored==true then
				ball.CFrame=CFrame.new(s+v0*nt+0.5*g*nt*nt)
				if ball and ball:FindFirstChild("Trail") and ball.Trail.Enabled==false then
					ball.Trail.Enabled=true
					ball.Trail2.Enabled=true
					go()
				end
				nt=nt+hb
				if nt>=brotime*2 then
					ball.Transparency=1
					stop()
					conn:disconnect()
				end
			end
		end
	end)
end)

amby.HookEvent("VisualImpact_"..script.Name,function(myt,success)
	t=myt
	if success then
		if t.Wep:GetAttribute("Target")~="All" then
			tall=false
			vars.impact+=st2+(brotime*lesstime*2)
		else
			tall=true
			vars.impact+=brotime
		end
		gotcha=true 
	end
	hitit=true
end)
