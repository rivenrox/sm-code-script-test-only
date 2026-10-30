dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )

CreativePlayer = class( BasePlayer )

local UnstuckPopupGui = {}
UnstuckPopupGui.root = sm.json.open( "$GAME_DATA/Gui/JsonGuis/PopUp_YN.gui" )
UnstuckPopupGui.index = IndexWidgets( UnstuckPopupGui.root )
UnstuckPopupGui.index["Title"].Caption = "#{MENU_YN_TITLE_ARE_YOU_SURE}"
UnstuckPopupGui.index["Message"].Caption = "#{MENU_YN_MESSAGE_UNSTUCK_CREATIVE}"
UnstuckPopupGui.index["Yes"].onClick = "cl_e_unstuckYes"
UnstuckPopupGui.index["No"].onClick = "cl_e_unstuckNo"

function CreativePlayer.sv_n_unstuck( self )
	local character = self.player:getCharacter()
	if not character then
		return
	end
	local params = { player = self.player, x = 16, y = 16 }
	sm.event.sendToWorld( character:getWorld(), "sv_e_spawnNewCharacter", params )
end

function CreativePlayer.cl_e_unstuck( self )
	self.cl.unstuckPopUp = sm.jsonGui.createGui( { isInteractive = true, needsCursor = true } )
	self.cl.unstuckPopUp:render( UnstuckPopupGui.root )
end

function CreativePlayer.cl_e_unstuckYes( self )
	self.network:sendToServer( "sv_n_unstuck" )
	if self.cl.unstuckPopUp then
		self.cl.unstuckPopUp:close()
		self.cl.unstuckPopUp = nil
	end
end

function CreativePlayer.cl_e_unstuckNo( self )
	if self.cl.unstuckPopUp then
		self.cl.unstuckPopUp:close()
		self.cl.unstuckPopUp = nil
	end
end
