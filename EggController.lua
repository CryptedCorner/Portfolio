--[[
  EggController.lua -- Created by FindFirstAncestor aka TypicalGameDeveloper
  -----------------
  This script handles client-side visualisation of egg hatching and pet reveals using Knit.
]]

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
	--{{Knit Imports so i can use them within this scope.}}
	self.CameraController = Knit.GetController("CameraController")
	self.EggService = Knit.GetService("EggService")
	self.AssetController = Knit.GetController("AssetController")
	self.SoundContoller = Knit.GetController("SoundController")
	self.PetController = Knit.GetController("PetController")
	self.InventoryController = Knit.GetController("InventoryController")
	self.EggDisplayers = Knit.GetController("EggDisplayers")
	self.RarityController = Knit.GetController("RarityController")
	
	self.Camera = self.CameraController:Get()
	
	--{{Setup trove for easier connection handling}} 
	self._trove = Trove.new()
	self.Rarities = self.RarityController.Templates
end

--{{This will allow eggs/pets to be visually displayed/hatched on the client to show the player what pets they got.}}
function EggController:OpenEgg(EggName: string, Quantity: number)
	
	--{{Avoid duplicate hatches}}
	if self.HatchingEgg then
		return
	end

	--{{This will lock the function from any future calls to hatch an egg until the current one has finished.}}
	self.HatchingEgg = true
	
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
			--{{task.spawn this to avoid eggs dropping in at different times and not being synced.}}
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

	--{{Small wait here to avoid the next eggs dropping in too early}}
	task.wait(.2)
	repeat task.wait() until not self.HatchingEgg
	return HatchedPets, ErrorMessage -- (?) Hatch next egg
end

--{{Preload Animations for the Model, we do this to avoid any additional waiting time or odd animations.}}
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

--{{Make the pets surfacegui display the pets name, rarity, pet icon and whether it's a newly discovered pet.}}
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

--{{Returns rarity data for a given rarity level.}}
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
	--{{Hide the egg before the animation is played to avoid an awkward .5 seconds in the middle of the screen}}
	local StartSignal = Animation:GetMarkerReachedSignal("StartAnimation"):Connect(function()
		NewEggModel.Main.Transparency = 0
	end)

	--{{This will play the animation for the actual pet model, turning them towards the camera whilst playing a sound whilst also showing their name, rarity and their pet icon.
	local EndSignal = Animation:GetMarkerReachedSignal("EndAnimation"):Connect(function()
		NewEggModel:Destroy()
		--{{we only play the sound once here to avoid numerous sounds being played making it louder than it should.}}
		if PetIndex == 1 then
			self.SoundContoller:Play("rbxassetid://73448620845179", workspace.Temporary, {}, { Volume = .1 })
		end

		--{{Use the UUID i created earlier to avoid two binded connection having the same name}}
		NewEgg._trove:BindToRenderStep(`PetRender_{UUID}`, Enum.RenderPriority.Camera.Value, function()
			if PetModel then
				PetModel.PrimaryPart.CFrame = self.Camera.CFrame * PetOffsetFromCamera
			end
		end)

		--{{Play the animation that makes the pet look at the camera}}
		PetAnimations.Open:Play()
			
		--{{Make sure the animation doesn't play too slowly (for example, if the speed is .7 then this animation will be unaffected and play at base speed of 1.)
		PetAnimations.Open:AdjustSpeed(math.max(Speed, 1))
		
		local RadialEffect = PetModel.Main.PetInfo.Effect.Radial

		--{{Change the colour of the pets radial particle emitter based of their rarity}}
		RadialEffect.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, PetColor),
			ColorSequenceKeypoint.new(1, PetColor)
		}
		
		local EffectSignal = PetAnimations.Open:GetMarkerReachedSignal("Effect"):Connect(function()
			RadialEffect:Emit(1) -- (only play it once here as too many looks odd.)
		end)
			
		--{{Add to trove for easier disconnecting}}
		NewEgg._trove:Add(EffectSignal)

		--{{Lower the FOV here to help increase the focus to the pet models, also makes for a nice animation too.}}
		self.CameraController:SetFOV(65, 1)
			
		--{{Setup the SurfaceGui on the part welded to the pet to display the name, rarity, pet icon and where the pet was newly discovered}}
		self:ConfigurePetFrame(PetFrame, PetName, PetRarity, PetColor, PetThumbnailId, NewPet)
		
		--{{Animation has finished, remove the pet}}
		local RemoveSignal = PetAnimations.Open:GetMarkerReachedSignal("RemovePet"):Connect(function()
			--{{Play the animation that makes the pet drop out of view and then destroy them.}}
			PetAnimations.Close:Play()
					
			--{{Make sure the animation doesn't play too slowly (for example, if the speed is .7 then this animation will be unaffected and play at base speed of 1.)
			PetAnimations.Close:AdjustSpeed(math.max(Speed, 1))

			--{{Delay the clean so the animation can actually have time to drop the pets out of frame.}}
			task.delay(1, NewEgg._trove.Clean, NewEgg._trove)

			--{{Allow the next egg to be hatched}}
			self.HatchingEgg = false

			--{{Restore base Roblox Properties.}}
			self.CameraController:SetFOV(70, 1)
			self.CameraController:LockZoomDistance(.5, 128)
		end)

		--{{Also add this to trove to make sure all connections are removed}}
		NewEgg._trove:Add(RemoveSignal)
	end)

	return { StartSignal, EndSignal }
end

--[[ 
	Visually hatches the pet to the client.
	This function is called once the server has approved the egg opening to avoid any false hatches.
	It loads the egg and pet models, plays the hatch animation and manages the visual + UI feedback for the pets and eggs.
]]
function EggController:Visualise(EggName: string, PetName: string, PetRarity: string, PetColor: Color3, PetThumbnailId: string, PetIndex: number, TotalPets: number, NewPet: boolean)
	--{{I lock the camera zoom distance to avoid the player's zoom distance clipping into the floor, occluding the eggs/pets from their view}
	self.CameraController:LockZoomDistance(10, 128)

	--{{Players can purchase/upgrade their hatch speed so this just asks the client inventory cache for the speed}}
	local Speed = self.InventoryController:Get("PlayerConfig", "PetBatchSpeed")
	--{{We generate a new UUID here for RunService:BindToRenderStep as they don't allow connections with the same name.
	local UUID = HttpService:GenerateGUID(false)

	--{{Organise the pets in a layout that correctly fits the amount of pets hatched [1x, 2x etc]}}
	local PetOffsetFromCamera = self.Formats[TotalPets][PetIndex]

	--{{We use trove here to easily clean up the connections when the hatch is completed}}
	local NewEgg = { _trove = Trove.new() }

	--{{Obtain the egg folder}}
	local EggFolder = self.AssetController:Get("Eggs", EggName)
	if not EggFolder then return end

	--{{Check if the egg was found and prepared correctly}}
	local EggModel = self:SetupEggModel(EggFolder)
	if not EggModel then return end

	--{{Preload the pet model, animations and it's displayed information}}
	local PetModel, PetAnimations, PetFrame = self:LoadPet(PetName)

	--{{Scale the pet model down just a bit to avoid them being too big on the player's screen. i change it here as i want the actual pet model that follows me to normal scale.
	PetModel:ScaleTo(.8)
	NewEgg._trove:Add(PetModel)

	--{{Enable this to avoid duplicate/multiple hatches at once.
	self.HatchingEgg = true
	NewEgg._trove:Add(EggModel)

	--{{Preload all the animation beforehand so they are ready in time}}
	local Animations = self:LoadAnimations(EggModel, self.Animations)
	local CurrentAnimation = Animations["Standard"]

	--{{This will handle all "GetMarkerChangedSignal" connections --(?) admittedly this function should NOT be taking this many parameters but it is what it is now.
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


	--{{Again, we use trove to easily handle all connections at the end of the hatch with Trove:Clean()}}
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
		--{{It is strange to hear all sound for all eggs present on screen so i only play it for the first one so it's not too loud when hatching 8x for example.
		if PetIndex == 1 then
			PopCount += 1
			self.SoundContoller:Play("rbxassetid://6586979979", workspace.Temporary, {}, {
				PlaybackSpeed = .7 + (PopCount / 14),
				Volume = .1
			})
			task.wait()
		end
	end)

	--{{Add the signal to trove for easier removal later}}
	NewEgg._trove:Add(PopSignal)
	
	--{{Play the animation and ensure the aforemention speed variable is applied.}}
	CurrentAnimation:Play()
	CurrentAnimation:AdjustSpeed(Speed)
end

--{{Get an egg module from "AssetController". Admittedly would be better to have just called AssetController by itself as this function is unneccessary.}}
function EggController:GetEggModule(EggName: string)
	repeat task.wait() until self.AssetController
	return self.AssetController:Get("Eggs", EggName, true)
end

return EggController
