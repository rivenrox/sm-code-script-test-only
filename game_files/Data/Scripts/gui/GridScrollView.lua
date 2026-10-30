dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

GridScrollView = class( nil )

function GridScrollView.setup( self, hostWidget, gui )
	self.gui = gui
	self.hostWidget = hostWidget
	self.widgets = { -- collection for named widgets
		mainPanel = FindWidget( hostWidget, "MainPanel" ),
		scrollView = FindWidget( hostWidget, "ScrollView" ),
		scrollBar = FindWidget( hostWidget, "ScrollBar" ),
		scrollButton = FindWidget( hostWidget, "ScrollButton" )
	}

	assert( self.widgets.mainPanel )
	assert( self.widgets.scrollView )
	assert( self.widgets.scrollBar )
	
	if self.widgets.scrollView.Childs[1] then
		self.baseItem = PopBaseItem( self.widgets.scrollView )
	end

	self.scrollStrength = 2
	self.defaultWidth = self.widgets.mainPanel.width
	self.defaultHeight = self.widgets.mainPanel.height
	self.allowedScrollRange = 0

	assert( self.defaultWidth ~= 0 )

	if self.defaultWidth ~= hostWidget.width and self.defaultWidth ~= 0 then
		local function scaleToHostWidth( widget )
			widget.x = widget.x * ( hostWidget.width / self.defaultWidth )
			widget.width = widget.width * ( hostWidget.width / self.defaultWidth )

			widget.x = round( widget.x )
			widget.width = round( widget.width )
		end

		local function positionToHostWidth( widget)
			widget.x = widget.x * ( hostWidget.width / self.defaultWidth )
			widget.x = round( widget.x )
		end

		local function scaleToHostHeight( widget )
			widget.y = widget.y * ( hostWidget.height / self.defaultHeight )
			widget.height = widget.height * ( hostWidget.height / self.defaultHeight )

			widget.y = round( widget.y )
			widget.height = round( widget.height )
		end

		scaleToHostWidth( self.widgets.mainPanel )
		scaleToHostWidth( self.widgets.scrollView )
		positionToHostWidth( self.widgets.scrollBar )

		scaleToHostHeight( self.widgets.mainPanel )
		scaleToHostHeight( self.widgets.scrollView )
		scaleToHostHeight( self.widgets.scrollBar )
	end
	self.scrollBarLength = self.widgets.scrollBar.height - self.widgets.scrollButton.height
	assert( self.scrollBarLength > 0 )
	return self
end

function GridScrollView.setGridItemSize( self, width, height )
	assert( width ~= 0 and width <= self.widgets.mainPanel.width )
	assert( height ~= 0 and height <= self.widgets.mainPanel.height )
	self.widgets.scrollView.GridItemSize.width = clamp( width, 1, self.widgets.mainPanel.width )
	self.widgets.scrollView.GridItemSize.height = clamp( height, 1, self.widgets.mainPanel.height )
end

function GridScrollView.addGridItem( self, item )
	self.widgets.scrollView.Childs[#self.widgets.scrollView.Childs+1] = DeepCopy( item )
	local horizontalCount = max( math.floor( self.widgets.scrollView.width / self.widgets.scrollView.GridItemSize.width ), 1 )
	local verticalCount = max( math.floor( ( #self.widgets.scrollView.Childs + horizontalCount - 1 ) / horizontalCount ), 1 )
	local currentHeight = verticalCount * self.widgets.scrollView.GridItemSize.height
	self.allowedScrollRange = math.min( self.widgets.scrollView.height - currentHeight, 0 )
	self.widgets.scrollButton.Visible = self.allowedScrollRange ~= 0
	self.widgets.scrollBar.Visible = self.widgets.scrollButton.Visible
	if self.allowedScrollRange < 0 then
		self.widgets.scrollButton.height = clamp( math.floor( self.widgets.scrollBar.height / max( ( verticalCount - ( self.widgets.mainPanel.height / self.widgets.scrollView.GridItemSize.height ) ), 1 ) ), 24, math.floor( self.widgets.scrollBar.height * 0.75 ) )
		self.scrollBarLength = self.widgets.scrollBar.height - self.widgets.scrollButton.height
	end
end

function GridScrollView.getGridChilds( self )
	return self.widgets.scrollView.Childs
end

function GridScrollView.clearGrid( self )
	self.widgets.scrollView.Childs = {}
end

function GridScrollView.setScrollStrength( self, scrollStrength )
	self.scrollStrength = math.max( scrollStrength * self.widgets.scrollView.GridItemSize.height, 1 )
end

function GridScrollView.handleScroll( self, scrollValue )
	if self.allowedScrollRange == 0 then
		return
	end
	local scrollDir = ( scrollValue > 0 ) and 1 or -1
	local modifiedScroll = scrollDir * self.scrollStrength
	self.widgets.scrollView.GridScrollOffset.top = clamp( self.widgets.scrollView.GridScrollOffset.top + modifiedScroll , self.allowedScrollRange, 0 )
	local buttonPosition = lerp( 0, self.scrollBarLength, self.widgets.scrollView.GridScrollOffset.top / self.allowedScrollRange )
	self.widgets.scrollButton.y = math.floor( buttonPosition )
end

function GridScrollView.handleScrollButtonPressed( self, _, y )
	local _, absY = self.gui:getWidgetAbsolutePosition( "ScrollButton" )
	self.buttonPressOffset = y - absY
end

function GridScrollView.handleScrollButtonReleased( self, x, y )

end

function GridScrollView.handleScrollBarPressed( self, x, y )
	self.buttonPressOffset = self.widgets.scrollButton.height / 2
	self:handleScrollButtonDrag( x, y )
end

function GridScrollView.handleScrollButtonDrag( self, x, y )
	local absX, absY = self.gui:getWidgetAbsolutePosition( "ScrollBar" )
	x = x - absX
	y = y - absY
	local newY = math.floor( clamp( y - self.buttonPressOffset, 0, self.scrollBarLength ) )
	self.widgets.scrollButton.y = newY
	self.widgets.scrollView.GridScrollOffset.top = math.floor( lerp( 0, self.allowedScrollRange, newY / self.scrollBarLength ) )
end

function GridScrollView.resetScroll( self )
	self.widgets.scrollView.GridScrollOffset.top = 0
	self.widgets.scrollButton.y = 0
end