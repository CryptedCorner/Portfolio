--{{Created by FindFirstAncestor aka TypicalGameDeveloper}}

--{{Apologies for the previous applications, my attitude wasn't warranted and i didn't notice the line count on it on the last one.}}

--{{Services}}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

--{{Constants}}
local PetInfoTemplate = script.PetInfo

--{{Knit}}
local Knit = require(ReplicatedStorage.Packages.Knit.KnitClient)
local Trove = require(ReplicatedStorage.Packages.Trove)

--{{Knit Controller Constructor}}
local EggController = Knit.CreateController({
	Name           = "EggController",
	Animations     = {
		Standard   = "rbxassetid://114234996095933"
	},
	PetAnimations  = {
		Open       = "rbxassetid://71590430150831",
		Close      = "rbxassetid://89450201683852"
	},
	
	Formats        = require(script.Formats),
	Displayers     = require(script.Displayers)
})

--{{Methods}}
function EggController:KnitStart() -- (?) This Method can use other knit services as it is called after all services are started
	--{{Knit Imports}}
	self.CameraController = Knit.GetController("CameraController")
	self.EggService = Knit.GetService("EggService")
	self.AssetController = Knit.GetController("AssetController")
	self.SoundContoller = Knit.GetController("SoundController")
	self.PetController = Knit.GetController("PetController")
	self.InventoryController = Knit.GetController("InventoryController")
	self.EggDisplayers = Knit.GetController("EggDisplayers")
	self.RarityController = Knit.GetController("RarityController")
	
	self.Camera = self.CameraController:Get()
	self._trove = Trove.new()
	self.Rarities = self.RarityController.Templates
end

function EggController:OpenEgg(EggName: string, Quantity: number)
	
	--{{Avoid duplicate hatches}}
	if self.HatchingEgg then
		return
	end
	
	self.HatchingEgg = true
	
	local HatchedPets = nil
	
	--{{Only when the server accepts our request do we display the egg/pet animations to the client}}
	local Eggs, ErrorMessage = self.EggService:OpenEgg(EggName, Quantity):andThen(function(Pets, ErrorMessage)
		HatchedPets = Pets
		if not Pets then
			self.HatchingEgg = false
			return false, warn(ErrorMessage)
		end
		
		local UIController = Knit.GetController("UIController")
		
		--{{Set Main HUD invisible and blur the screen}}
		UIController:SetHUD(false)
		UIController:SetBlur(true, 4)
		
		for i = 1, Quantity do
			task.spawn(function()
				local Pet = Pets[i]
				
				--{{Update the SurfaceGui's on the egg model}}
				self.EggDisplayers:UpdateDisplayers(Pet.Name)
				
				local Rarity = self:GetRarityInfo(Pets[i].Rarity)
				local NewPet = not self.PetController:DoesClientOwnPet(Pet.Name) -- (?) Determines if the "ConfigurePetFrame" function displays the "NewPet" TextLabel
				--{{Hatch the egg and display the pet}}
				self:Visualise(EggName, Pet.Name, Rarity.Name, Rarity.Color, Pet.Thumbnail, i, Quantity, NewPet)
			end)
		end
		
		repeat task.wait() until not self.HatchingEgg
		
		--{{Set Main HUD visible and unblur the screen}}
		UIController:SetHUD(true)
		UIController:SetBlur(false)
		
		return HatchedPets, ErrorMessage
	end)
	task.wait(.2)
	repeat task.wait() until not self.HatchingEgg
	return HatchedPets, ErrorMessage -- (?) Hatch next egg
end

--{{Preload Animations for the Model}}
function EggController:LoadAnimations(Model: Model, Animations: {})
	local LoadedAnimations = {}
	local AnimationController = Model:FindFirstChild("AnimationController")
	if AnimationController then
		for Name, AnimationId in Animations do
			local Animation = Instance.new("Animation")
			Animation.AnimationId = AnimationId
			LoadedAnimations[Name] = AnimationController.Animator:LoadAnimation(Animation)
		end
	end
	return LoadedAnimations
end

--{{Returns the pet "Model" to animate/hatch}}
function EggController:GetPetModel(PetName)
	local PetFolder = self.AssetController:Get("Pets", PetName)
	if PetFolder then
		local Model = PetFolder:FindFirstChild("Model")
		if Model then
			return Model
		end
	end
	return false
end

--{{Preloads the pet model/animation to be used by Visualise function}}
function EggController:LoadPet(PetName)
	local PetModel = self:GetPetModel(PetName)
	if PetModel then
		local NewPetModel = PetModel:Clone()
		NewPetModel.Parent = workspace.Temporary
		
		--{{Just to hide from the client while it preloads as "AnimationClipProvider" requires it to be in the workspace.}}
		NewPetModel:PivotTo(CFrame.new(0, -500, 0))
		local Animations = self:LoadAnimations(NewPetModel, self.PetAnimations)
		
		--{{We weld the Part to the pet here to ensure the surfacegui is always centre of the pet and to avoid SurfaceGui's}}
		local PetInfo = PetInfoTemplate:Clone()
		if PetInfo then
			PetInfo.Parent = NewPetModel.Main
			
			local Weld = Instance.new("Motor6D")
			Weld.Part0 = NewPetModel.Main
			Weld.Part1 = PetInfo
			Weld.C0 = CFrame.new(0, 0, -.5)
			Weld.Parent = PetInfo

			return NewPetModel, Animations, PetInfo.Main
		end
		
	end
end

function EggController:ConfigurePetFrame(PetFrame: ScreenGui, PetName: string, PetRarity: string, PetColor: Color3, PetThumbnailId: string, NewPet: boolean)
	local Container = PetFrame:FindFirstChild("Container")
	if PetFrame and Container then
		
		--{{Name}}
		Container.PetInfo.PetName.Text = PetName
		Container.PetInfo.PetName.Backdrop.Text = PetName

		--{{PetThumbnailId}}
		Container.PetInfo.PetName.Icon.Image = PetThumbnailId
		
		--{{Has the pet been discovered before?}}
		Container.NewPetDiscovered.Visible = NewPet
		
		--{{Rarity}}
		Container.PetRarity.Text = PetRarity
		Container.PetRarity.Backdrop.Text = PetRarity
		Container.PetRarity.TextColor3 = PetColor
	end
	
end

--{{This returns a table containing the rarity name and it's corresponding colour.}}
function EggController:GetRarityInfo(Rarity: number)
	return self.Rarities[Rarity]
end

--{{Again, preload the model for hatching.}}
function EggController:SetupEggModel(EggFolder)
	local EggModel = EggFolder:FindFirstChild("Model")
	if not EggModel then return nil end

	local ModelClone = EggModel:Clone()
	ModelClone:ScaleTo(.8)
	ModelClone.Parent = workspace.Temporary
	ModelClone:PivotTo(CFrame.new(0, -500, 0))
	ModelClone.Main.Transparency = 1
	return ModelClone
end

--{{Handles animation markers effects, sounds and animation speed. }}
function EggController:HandleAnimationMarkers(Animation, NewEggModel, PetModel, PetAnimations, PetOffsetFromCamera, PetFrame, PetName, PetRarity, PetColor, PetThumbnailId, Speed, UUID, NewEgg, PetIndex, NewPet)
	local StartSignal = Animation:GetMarkerReachedSignal("StartAnimation"):Connect(function()
		NewEggModel.Main.Transparency = 0
	end)

	local EndSignal = Animation:GetMarkerReachedSignal("EndAnimation"):Connect(function()
		NewEggModel:Destroy()
		if PetIndex == 1 then
			self.SoundContoller:Play("rbxassetid://73448620845179", workspace.Temporary, {}, { Volume = .1 })
		end

		NewEgg._trove:BindToRenderStep(`PetRender_{UUID}`, Enum.RenderPriority.Camera.Value, function()
			if PetModel then
				PetModel.PrimaryPart.CFrame = self.Camera.CFrame * PetOffsetFromCamera
			end
		end)

		PetAnimations.Open:Play()
		PetAnimations.Open:AdjustSpeed(math.max(Speed, 1))
		
		local RadialEffect = PetModel.Main.PetInfo.Effect.Radial
		
		RadialEffect.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, PetColor),
			ColorSequenceKeypoint.new(1, PetColor)
		}
		
		local EffectSignal = PetAnimations.Open:GetMarkerReachedSignal("Effect"):Connect(function()
			RadialEffect:Emit(1)
		end)
		NewEgg._trove:Add(EffectSignal)

		self.CameraController:SetFOV(65, 1)
		self:ConfigurePetFrame(PetFrame, PetName, PetRarity, PetColor, PetThumbnailId, NewPet)
		
		--{{Animation has finished, remove the pet}}
		local RemoveSignal = PetAnimations.Open:GetMarkerReachedSignal("RemovePet"):Connect(function()
			PetAnimations.Close:Play()
			PetAnimations.Close:AdjustSpeed(math.max(Speed, 1))

			task.delay(1, NewEgg._trove.Clean, NewEgg._trove)
			self.HatchingEgg = false

			self.CameraController:SetFOV(70, 1)
			self.CameraController:LockZoomDistance(.5, 128)
		end)

		NewEgg._trove:Add(RemoveSignal)
	end)

	return { StartSignal, EndSignal }
end

--{{Visually hatches the pet to the client}}
function EggController:Visualise(EggName: string, PetName: string, PetRarity: string, PetColor: Color3, PetThumbnailId: string, PetIndex: number, TotalPets: number, NewPet: boolean)
	self.CameraController:LockZoomDistance(10, 128)
	
	local Speed = self.InventoryController:Get("PlayerConfig", "PetBatchSpeed")
	local UUID = HttpService:GenerateGUID(false)
	local PetOffsetFromCamera = self.Formats[TotalPets][PetIndex]

	local NewEgg = { _trove = Trove.new() }

	local EggFolder = self.AssetController:Get("Eggs", EggName)
	if not EggFolder then return end

	local EggModel = self:SetupEggModel(EggFolder)
	if not EggModel then return end

	local PetModel, PetAnimations, PetFrame = self:LoadPet(PetName)
	PetModel:ScaleTo(.8)
	NewEgg._trove:Add(PetModel)

	self.HatchingEgg = true
	NewEgg._trove:Add(EggModel)

	local Animations = self:LoadAnimations(EggModel, self.Animations)
	local CurrentAnimation = Animations["Standard"]

	local Signals = self:HandleAnimationMarkers(
		CurrentAnimation,
		EggModel,
		PetModel,
		PetAnimations,
		PetOffsetFromCamera,
		PetFrame,
		PetName,
		PetRarity,
		PetColor,
		PetThumbnailId,
		Speed,
		UUID,
		NewEgg,
		PetIndex,
		NewPet
	)

	for _, Signal in ipairs(Signals) do
		NewEgg._trove:Add(Signal)
	end
	
	--{{Prepare the egg hatching viewmodel.}}
	NewEgg._trove:BindToRenderStep(`EggRender_{UUID}`, Enum.RenderPriority.Camera.Value, function()
		if EggModel and EggModel.PrimaryPart then
			EggModel:PivotTo(self.Camera.CFrame * CFrame.new(PetOffsetFromCamera.Position))
		end
	end)
	
	--{{This could be better of as a function like "HandleAnimationMarkers" but i guess i never did that, mb.}}
	local PopCount = 1
	local PopSignal = CurrentAnimation:GetMarkerReachedSignal("Pop"):Connect(function()
		local Highlight = EggModel.Main:FindFirstChild("Highlight")
		if Highlight then
			Highlight.FillTransparency = .95
			EggModel:ScaleTo(.84)
			task.delay(.2, function()
				Highlight.FillTransparency = 1
				EggModel:ScaleTo(.8)
			end)
		end
		if PetIndex == 1 then
			PopCount += 1
			self.SoundContoller:Play("rbxassetid://6586979979", workspace.Temporary, {}, {
				PlaybackSpeed = .7 + (PopCount / 14),
				Volume = .1
			})
			task.wait()
		end
	end)

	NewEgg._trove:Add(PopSignal)
	
	--{{Hatch the egg.}}
	CurrentAnimation:Play()
	CurrentAnimation:AdjustSpeed(Speed)
end

--{{Information Proxies}}
function EggController:GetEggModule(EggName: string)
	repeat task.wait() until self.AssetController
	return self.AssetController:Get("Eggs", EggName, true)
end

return EggController
