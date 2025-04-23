--{{Services}}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--{{Modules}}
local Knit  = require(ReplicatedStorage.Packages.Knit.KnitClient)
local Input = require(ReplicatedStorage.Packages.Input)
local Timer = require(ReplicatedStorage.Packages.Timer)
local Trove = require(ReplicatedStorage.Packages.Trove)

--{{Input for different [Enum.UserInputType]}}
local Mouse = Input.Mouse.new()
local Touch = Input.Touch.new()

--{{Constants}}
local Player = Knit.Player
local PlayerGui = Player.PlayerGui
local Main = PlayerGui:WaitForChild("Main", 5)
local Frames = Main:WaitForChild("Frames", 5)
local AutoclickerFrame = Frames.HUD.Popups

--{{Knit Controller Constructor}}
local ClickerController = Knit.CreateController({
	Name               = "ClickerController",
	AutoclickerEnabled = false
})

--{{Methods}}
function ClickerController:KnitStart() -- (?) This Method can use other knit services as it is called after all services are started
	
	--{{This is for PC/Mouse input}}
	Mouse.LeftDown:Connect(function(preferred)
		self:Click(true)
	end)
	
	--{{This is for Mobile/Touchscreen input}}
	Touch.TouchTap:Connect(function(preferred)
		self:Click(true)
	end)
	
	--{{Importing other knit services/controllers}}
	self.ClickerService = Knit.GetService("ClickerService")
	self.UIController = Knit.GetController("UIController")
	self.PlayerdataService = Knit.GetService("PlayerdataService")
	self.InventoryController = Knit.GetController("InventoryController")
	
	--{{Handle runtime connections more efficiently}}
	self._trove = Trove.new()
	
	--{{Players have a server config that will save any action they was doing in the previous session. This just enables it again.}}
	local AutoclickerEnabled = self.InventoryController:Get("PlayerConfig", "AutoclickerEnabled")
	if AutoclickerEnabled then
		--{{Auto enable autoclicker}}
		self:Autoclicker()
	end
end

function ClickerController:Click(IsMouseClick: boolean)
	if IsMouseClick and self.AutoclickerEnabled then -- (?) If "IsMouseClick" is true then the position of the vfx will be at {0, Mouse.X, 0, Mouse.Y}
		return
	end
	
	--{{Validate if the click was accepted by the server so we don't have a false vfx that never modified our leaderstats value.}}
	return self.ClickerService:ClickRequest():andThen(function(Success: boolean, Amount: number)
		if Success then
			self.UIController:ClickVFX("rbxassetid://126214706053838", Amount, IsMouseClick)
		end
	end)
end

--{{}}
function ClickerController:Autoclicker()
	--{{Toggle autoclicker functionality}}
	self.AutoclickerEnabled = not self.AutoclickerEnabled
	
	AutoclickerFrame.ImageButton.ActiveIcon.Visible = self.AutoclickerEnabled
	AutoclickerFrame.ImageButton.InActiveIcon.Visible = not self.AutoclickerEnabled
	
	--{{Update the aforementioned server config to ensure it is correct for the next play session.}}
	self.PlayerdataService:ClientUpdatedConfig("AutoclickerEnabled", self.AutoclickerEnabled)
	
	--{{Disable the autoclicker if it is already active.}}
	if not self.AutoclickerEnabled then
		return self._trove:Clean()
	end
	
	--{{Autoclicker will attempt to click every .5 seconds}}
	self._timer = Timer.new(.05)

	self._timer.Tick:Connect(function()
		self:Click()
	end)
	
	--{{Add to connection handler}}
	self._trove:Add(self._timer)
	
	--{{Start the autoclicker}}
	self._timer:Start()
end

return ClickerController
