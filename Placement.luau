--Is comments hard to read? THIS IS VERY SELF EXPLANATORY AND EVEN A COCKROACH COULD UNDERSTAND!

--NOTHING here is complex, it's actually very old code that is ass!!!

--// Services \\--
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService('TweenService')

--// Paths \\--
local Camera = workspace.CurrentCamera
local Utils = ReplicatedStorage.Utils
local HighlightTemplate = script.Highlight
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local BoxTemplate = script.Box

--// Utils \\--
local Maid = require(Utils.Maid).new()
local UUID = require(Utils.UUID).new()
local Input = require(Utils.Input).new()
local Rays = require(Utils.Rays).new()

--// Modules \\--
local Studios = require(script.Parent).new()

--// Bindables \\--
local placementBind = script.PlacementProxy

local Placement = { modules = {} }
Placement.__index = Placement

--// Placement Object Constructor \\--
function Placement.new()
	local placementInstance = setmetatable({}, Placement)
	placementInstance.highlighter = HighlightTemplate:Clone()
	placementInstance.uuid = UUID.generate()
	Placement:initSubclasses()
	return placementInstance
end

--// Get Object Selection Based on Mouse Position \\--
function Placement:getSelection(studio)
	if not studio then return end

	local target = Mouse.Target
	if target and target.Parent and target.Parent.Parent == studio.PlayerObjects then
		return target
	end
	return nil
end

function Placement:initSubclasses()
	for _, module in ipairs(script:GetChildren()) do
		if module:IsA('ModuleScript') then
			self.modules[module.Name] = require(module).new()
		end
	end
end

--// Highlight the Selected Object \\--
function Placement:highlight(object)
	if not object then return end
	self.highlighter.Adornee = object.Parent
	self.highlighter.Parent = object.Parent
end

--// Get the Currently Highlighted Object \\--
function Placement:getObject()
	return self.highlighter.Adornee
end

--// Enable Object Placement Mode \\--
function Placement:enter()
	Input:register(self.uuid .. "_Interact", function(name, action)
		self:interact(action)
	end, false, {
		Keyboard = Enum.UserInputType.MouseButton1,
		Controller = Enum.KeyCode.ButtonR2
	})

	Maid:register(self.uuid, RunService.RenderStepped:Connect(function()
		local studio = Studios.get(Player)
		if studio then
			local result = self:getSelection(studio)
			if result then
				self:highlight(result)
			end
		end
	end))
end

-- THIS GETS A MODULE
function Placement:getModule()
	local object = self:getObject()
	if object then
		return self.modules[object.Name] or self.modules.Other
	end
	return nil
end

--THIS STOPS INTERACTIONS -- CLUES IN THE NAME!
function Placement:stopAllInteractions()
	for _, module in pairs(self.modules) do
		module:interact(Enum.UserInputState.End)
	end
end

--THIS INTERACTS!
function Placement:interact(action)
	local object = self:getObject()
	if object then
		local module = self:getModule()
		if module then
			module:interact(action)
		end
	end
end

--// Disable Object Placement Mode \\--
function Placement:leave()
	Maid:deregister(self.uuid)
	self.highlighter.Adornee = nil
	self.highlighter.Parent = nil
end

function Placement:getFloors(playerStudio)
	local objects = {}
	for _, object in playerStudio.PlayerObjects:GetChildren() do
		if object:GetPivot().Position.Y < 19 then
			objects[#objects + 1] = object
		end
	end
	return objects
end

--{{This is NOT the best}} -- THIS BOXES THE OBJECT! CRAZY IK!
function Placement:boxObject(player, object)
	
	local playerStudio = Studios.get(player)
	if not playerStudio then return end

	local box = BoxTemplate:Clone()
	local characterPosition = player.Character and player.Character:GetPivot().Position or Vector3.new()

	local offsetX, offsetZ
	repeat
		offsetX = math.random(-2, 2)
		offsetZ = math.random(-2, 2)
	until offsetX ~= 0 and offsetZ ~= 0

	box:SetPrimaryPartCFrame(CFrame.new(characterPosition + Vector3.new(offsetX, 5, offsetZ)))
	
	local includeList = self:getFloors(playerStudio)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {includeList}
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local result = Rays.raycast(box.PrimaryPart.Position, Vector3.new(4, -100, 4), raycastParams)
	if result then
		local surface = result.Instance
		local surfacePosition = surface.Position + Vector3.new(0, surface.Size.Y / 2 + box.PrimaryPart.Size.Y / 2, 0)

		box.Parent = workspace.Temp
		box.PrimaryPart.CanCollide = false
		object.PrimaryPart.CanCollide = false
		object.PrimaryPart.Anchored = true

		box.PrimaryPart.CFrame *= CFrame.new(0, 25, 0)
		local tweenMove = TweenService:Create(box.PrimaryPart, TweenInfo.new(1, Enum.EasingStyle.Bounce), {
			Position = surfacePosition + Vector3.new(offsetX, 0, offsetZ)
		})
		tweenMove:Play()
		tweenMove.Completed:Wait()

		local animation = box.Animation
		local animController = box.AnimationController:LoadAnimation(animation)
		
		task.spawn(function()
			local modelScale = object:GetScale()
			for i = modelScale, .1, -.1 do
				object:ScaleTo(i)
				task.wait(.05)
			end
		end)
		
		local cframeValue = Instance.new("CFrameValue")
		cframeValue.Value = object.PrimaryPart.CFrame
		
		local rotation = Instance.new('CFrameValue')
		task.spawn(function()
			while object and object.Parent do
				if not object.PrimaryPart then break end
				rotation.Value *= CFrame.Angles(0, 0, math.rad(-5))
				task.wait()
			end
			
			TweenService:Create(rotation, TweenInfo.new(.15), {
				Value = CFrame.new() * CFrame.Angles(0, 0, 0)
			}):Play()
		end)
		
		cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
			object:PivotTo(CFrame.new(cframeValue.Value.Position) * rotation.Value)
		end)
		
		
		local tweenObject = TweenService:Create(cframeValue, TweenInfo.new(0.5), {
			Value = CFrame.new(box.PrimaryPart.Position + Vector3.new(0, 4, 0)),
		})
		tweenObject:Play()
		tweenObject.Completed:Wait()
		
		local primaryPart = box.PrimaryPart
		object.PrimaryPart = nil
		
		local tweenDestroy = TweenService:Create(cframeValue, TweenInfo.new(0.25), {
			Value = primaryPart.CFrame,
		})
		
		task.spawn(function()
			for i = object:GetScale(), 0, -.1 do
				object:ScaleTo(i)
				task.wait(.1)
			end
		end)
		
		tweenDestroy:Play()
		
		tweenDestroy.Completed:Wait()
		
		self.highlighter.Adornee = nil
		self.highlighter.Parent = nil
		object:Destroy()
		
		animController:Play()
		animController:AdjustSpeed(5)
		
		animController:GetMarkerReachedSignal('Closed'):Connect(function()
			animController:AdjustSpeed(0)

			for _, emitter in box:GetDescendants() do
				if emitter.ClassName == 'ParticleEmitter' then
					emitter:Destroy()
				end
			end
			
			primaryPart.SpotLight.Enabled = false
			
			task.spawn(function()
				while box and box.Parent do
					if not primaryPart then break end
					primaryPart.CFrame *= CFrame.Angles(0, 0, math.rad(-5))
					task.wait()
				end
			end)

			local tweenBox = TweenService:Create(primaryPart, TweenInfo.new(.5), {
				Position = player.Character.PrimaryPart.Position + Vector3.new(0, 10, 0),
			})
			tweenBox:Play()
			
			task.spawn(function()
				for i = box:GetScale(), 0, -.001 do
					box:ScaleTo(i)
					task.wait(.085)
				end
			end)
			
			tweenBox.Completed:Wait()

			local tweenShrink = TweenService:Create(primaryPart, TweenInfo.new(0.25), {
				CFrame = player.Character.PrimaryPart.CFrame,
			})
			
			tweenShrink:Play()
			tweenShrink.Completed:Wait()

			box:Destroy()
		end)
	end
end

return Placement
