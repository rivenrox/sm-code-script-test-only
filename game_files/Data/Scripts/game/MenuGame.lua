dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/TutorialManager.lua" )

MenuGame = class( nil )
MenuGame.enableLimitedInventory = false
MenuGame.enableRestrictions = false
MenuGame.enableFuelConsumption = false
MenuGame.enableAmmoConsumption = false
MenuGame.enableUpgrade = true

g_godMode = true

-- Game Server side --

function MenuGame.server_onCreate( self )
	self.sv = {}
	local worldScriptFilename = "$GAME_DATA/Scripts/game/worlds/MenuWorld.lua"
	local worldScriptClass = "MenuWorld"
	self.sv.menuWorld = sm.world.createWorld( worldScriptFilename, worldScriptClass )
	sm.game.bindChatCommand( "/save", {}, "sv_onChatCommand", "Save the menu creation" )

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( nil )

	-- Creating TutorialManager explicitly since we can't have it exclusive for Menu Game via sob_managers.sobset
	sm.scriptableObject.createScriptableObject( sm.uuid.new( "a1b34167-f7c6-4d28-95f9-7e26e5d0458e" ) )
end

function MenuGame.server_onFixedUpdate( self, timeStep )
	g_unitManager:sv_onFixedUpdate()
 end

function MenuGame.server_onPlayerJoined( self, player, newPlayer )
	if not sm.exists( self.sv.menuWorld ) then
		sm.world.loadWorld( self.sv.menuWorld )
	end
	self.sv.menuWorld:loadCell( 2, 0, player, "sv_cellLoaded" )
end

function MenuGame.server_onSaveLevel( self )
	sm.event.sendToWorld( self.sv.menuWorld, "sv_e_export" )
end

function MenuGame.sv_onChatCommand( self, params )
	if params[1] == "/save" then
		sm.event.sendToWorld( self.sv.menuWorld, "sv_e_export" )
	end
end

function MenuGame.sv_cellLoaded( self, world, x, y, player )
	local params = { player = player, x = x, y = y }
	sm.event.sendToWorld( world, "sv_e_spawnNewCharacter", params )
	if player.id == 1 then
		sm.event.sendToWorld( self.sv.menuWorld, "sv_e_loadMenuCreations" )
	end
end

-- Game Client side --

function MenuGame.client_onCreate( self )
	sm.game.setTimeOfDay( 0.5 )
	sm.render.setOutdoorLighting( 0.5 )
	if g_unitManager == nil then
		assert( not sm.isHost )
		g_unitManager = UnitManager()
	end

	self.cl = {}
	if sm.isHost then
		sm.game.bindChatCommand( "/clear", {}, "cl_onChatCommand", "Clear creations from the menu" )
		self.cl.confirmClearGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout" )
		self.cl.confirmClearGui:setButtonCallback( "Yes", "cl_onButtonClick" )
		self.cl.confirmClearGui:setButtonCallback( "No", "cl_onButtonClick" )
		self.cl.confirmClearGui:setText( "Title", "#{MENU_YN_TITLE_ARE_YOU_SURE}" )
		self.cl.confirmClearGui:setText( "Message", "#{MENU_YN_MESSAGE_CLEAR_MENU}" )
	end
end

function MenuGame.client_onLoadingScreenLifted( self )
	EffectManager.Cl_OnLoadingScreenLifted()
	TutorialManager.Cl_OnLoadingScreenLifted()
	TutorialManager.Cl_TutorialEvent( TutorialEvent.MenuBuilding )
end

function MenuGame.cl_onChatCommand( self, params )
	if params[1] == "/clear" then
		self.cl.confirmClearGui:open()
	end
end

function MenuGame.cl_onButtonClick( self, name )
	if name == "Yes" then
		self.cl.confirmClearGui:close()
		self.network:sendToServer( "sv_clear" )
	elseif name == "No" then
		self.cl.confirmClearGui:close()
	end
end

function MenuGame.sv_clear( self )
	sm.event.sendToWorld( self.sv.menuWorld, "sv_e_clear" )
end