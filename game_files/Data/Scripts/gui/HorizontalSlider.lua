dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

HorizontalSlider = class( nil )

local LimitHighlightColour = "0.988 0.827 0.058 1.0"
local LineColour = "0.227 0.231 0.239 1.0"
local IndexTextColour = "0.533 0.533 0.533 1.0"
local IndexHighlightColour = "1 0.815 0.274 1.0"

function HorizontalSlider.setup( self, hostWidget, snapping, inverted )
	self.hostWidget = hostWidget
	self.widgets = { -- collection for named widgets
		mainPanel = FindWidget( hostWidget, "MainPanel" ),
		rightSpeed = FindWidget( hostWidget, "RightSpeed" ),
		background = FindWidget( hostWidget, "Background" ),
		limiter = FindWidget( hostWidget, "Limiter" ),
		limiterEnd = FindWidget( hostWidget, "LimiterEnd" ),
		rangeLimitText = FindWidget( hostWidget, "RangeLimitText" ),
		progress = FindWidget( hostWidget, "Progress" ),
		innerShadow = FindWidget( hostWidget, "InnerShadow" ),
		handle = FindWidget( hostWidget, "Handle" ),
		lineContainer = FindWidget( hostWidget, "LineContainer" ),
		indexContainer = FindWidget( hostWidget, "IndexContainer" ),
	}

	--[[assert( self.widgets.handle )
	assert( self.widgets.progress )
	assert( self.widgets.limiter )
	assert( self.widgets.limiterEnd )
	assert( self.widgets.rangeLimitText )
	assert( self.widgets.lineContainer )
	assert( self.widgets.indexContainer )]]

	self.defaultSliderWidth = self.widgets.mainPanel.width

	if self.defaultSliderWidth ~= hostWidget.width then
		local function scaleToHostWidth( widget )
			widget.x = widget.x * ( hostWidget.width / self.defaultSliderWidth )
			widget.width = widget.width * ( hostWidget.width / self.defaultSliderWidth )

			widget.x = round( widget.x )
			widget.width = round( widget.width )
		end

		scaleToHostWidth( self.widgets.mainPanel )
		scaleToHostWidth( self.widgets.rightSpeed )
		scaleToHostWidth( self.widgets.background )
		scaleToHostWidth( self.widgets.limiter )
		self.widgets.limiterEnd.x = self.widgets.limiterEnd.x * ( hostWidget.width / self.defaultSliderWidth )
		self.widgets.limiterEnd.x = round( self.widgets.limiterEnd.x )
		scaleToHostWidth( self.widgets.rangeLimitText )
		scaleToHostWidth( self.widgets.progress )
		scaleToHostWidth( self.widgets.innerShadow )
		scaleToHostWidth( self.widgets.handle )
		scaleToHostWidth( self.widgets.lineContainer )
		scaleToHostWidth( self.widgets.indexContainer )
	end
	self.inverted = inverted or false
	self.snapping = snapping or false
	self.highlightIndex = false

	self.range = 1
	self.rangeLimit = 0
	self.sliderPosition = 1
	self.sliderStep = 1.0
	self.mouseDragOffset = 0
	self.dragged = false

	self.progressAnchorPos = { x = 0, y = 0 }
	self.limiterAnchorPos = { x = 0, y = 0 }
	if self.widgets.progress then
		self.progressAnchorPos.x = self.widgets.progress.x
		self.progressAnchorPos.y = self.widgets.progress.y
	end
	if self.widgets.limiter then
		self.limiterAnchorPos.x = self.widgets.limiter.x + self.widgets.limiter.width
		self.limiterAnchorPos.y = self.widgets.limiter.y
	end

	return self
end

function HorizontalSlider.setSliderRangeLimit( self, limit )
	self.rangeLimit = min( limit, self.range )

	local visible = self.rangeLimit < self.range and self.rangeLimit > 0

	if self.widgets.limiter then
		if self.rangeLimit ~= self.range then
			local size = ( ( self.range - self.rangeLimit ) * self.sliderStep )
			self.widgets.limiter.x = round(self.limiterAnchorPos.x - size)
			self.widgets.limiter.width = round(size)
		end

		self.widgets.limiter.Visible = visible
	end

	local  limitIndex = self.range
	if self.rangeLimit ~= self.range  then
		limitIndex = self.rangeLimit
	end

	if self.widgets.lineContainer then
		if not self.widgets.lineContainer.Childs then
			self.widgets.lineContainer.Childs = {}
		end
		for lineIndex, _ in ipairs( self.widgets.lineContainer.Childs ) do
			if lineIndex == limitIndex and visible then
				self.widgets.lineContainer.Childs[lineIndex].Colour = LimitHighlightColour
			else
				self.widgets.lineContainer.Childs[lineIndex].Colour = LineColour
			end
		end
	end
	
	if self.widgets.indexContainer then
		if not self.widgets.indexContainer.Childs then
			self.widgets.indexContainer.Childs = {}
		end
		for lineIndex, _ in ipairs( self.widgets.indexContainer.Childs ) do
			if lineIndex == limitIndex and visible then
				self.widgets.indexContainer.Childs[lineIndex].TextColour = LimitHighlightColour
			else
				self.widgets.indexContainer.Childs[lineIndex].TextColour = IndexTextColour
			end
		end
	end

	if self.widgets.rangeLimitText then
		self.widgets.rangeLimitText.Visible = visible

		local limitText = self.widgets.rangeLimitText
		local calculatedTextWidth, _ = sm.gui.computeTextSize( limitText.Caption, limitText.FontName, limitText.TextAlign, limitText.width )
		self.widgets.rangeLimitText.x = round(calculatedTextWidth / 4)
		self.widgets.rangeLimitText.width = round( calculatedTextWidth )
	end
end

function HorizontalSlider.setSliderRange( self, range, numbered )
	assert( range > 1 )
	self.range = range
	self:setSliderRangeLimit( self.rangeLimit )

	self.sliderStep = ( self.hostWidget.width - self.widgets.handle.width ) / ( range - 1 )

	self.sliderPosition = min( self.sliderPosition, range )
	self.widgets.handle.x = round(self.sliderStep * ( self.sliderPosition - 1 ))

	local handleHalfWidth = self.widgets.handle.width / 2

	-- Step lines
	if self.widgets.lineContainer then
		self.widgets.lineContainer.Childs = {}
		local lineWidth = 1
		for index = 0, range - 1, 1 do
			self.widgets.lineContainer.Childs[#self.widgets.lineContainer.Childs+1] = {
				Name = "Line"..index,
				Type = "Widget",
				Skin = "WhiteSkin",
				x = round( index * self.sliderStep + handleHalfWidth - lineWidth / 2 ),
				y = 0,
				width = lineWidth,
				height = self.widgets.lineContainer.height,
				NeedKey = false,
				NeedMouse = false,
				Colour = LineColour
			}
		end
	end

	
	-- Step numbers
	if self.widgets.indexContainer then
		self.widgets.indexContainer.Childs = {}
		
		for index = 0, range - 1, 1 do
			local caption = tostring( index + 1 )
			local fontName = "SM_SliderLabel"
			local textAlign = "Center"
			local width, _ = sm.gui.computeTextSize( caption, fontName, textAlign, 0 )

			self.widgets.indexContainer.Childs[#self.widgets.indexContainer.Childs+1] = {
				Name = "Index"..index,
				Type = "TextBox",
				Skin = "TextBox",
				x = math.floor( index * self.sliderStep + handleHalfWidth - width / 2 ),
				y = 0,
				width = width,
				height = self.widgets.indexContainer.height,
				NeedKey = false,
				NeedMouse = false,
				TextColour = IndexTextColour,
				TextAlign = textAlign,
				Caption = caption,
				FontName = fontName
			}
		end
	end

	self:updateProgressBar()
end

function HorizontalSlider.eventHandlePressed( self, jsonGui, left, buttonId )
	if buttonId == 0 then
		self.dragged = true
		local handleAbsLeft = jsonGui:getWidgetAbsolutePosition( self.widgets.handle.Name )
		self.mouseDragOffset = left - handleAbsLeft
	end
end

function HorizontalSlider.clampPosition( self, position )
	local max
	if self.rangeLimit < 1 then
		max = ( self.range - 1 ) * self.sliderStep
	else
		max = ( min( self.range, self.rangeLimit ) - 1 ) * self.sliderStep
	end
	
	return clamp( position, 0, max )
end

function HorizontalSlider.updateProgressBar( self )
	if self.widgets.progress then
		self.widgets.progress.x = math.floor( self.progressAnchorPos.x )
		self.widgets.progress.y = math.floor( self.progressAnchorPos.y )
		self.widgets.progress.width = math.floor( self.progressAnchorPos.x + self.widgets.handle.x )
	end
end

function HorizontalSlider.enableHighlightIndex( self, highlight )
	self.highlightIndex = highlight
end

function HorizontalSlider.updateHighlightIndex( self, position )
	if self.highlightIndex then
		for index, indexText in ipairs( self.widgets.indexContainer.Childs ) do
			if index == position+1 then
				indexText.TextColour = IndexHighlightColour
			else
				indexText.TextColour = IndexTextColour
			end
		end
	end
end

function HorizontalSlider.eventHandleDrag( self, jsonGui, left, buttonId )
	if buttonId == 0 then
		local absBgLeft = jsonGui:getWidgetAbsolutePosition( self.hostWidget.Name )
		local sliderLocalMouse = left - absBgLeft - self.mouseDragOffset
		local clampedPos = self:clampPosition( sliderLocalMouse )
		self.widgets.handle.x = round( clampedPos )

		local calculatedPosition = round( clampedPos / self.sliderStep )
		if calculatedPosition + 1  ~= self.sliderPosition then
			self.sliderPosition = calculatedPosition + 1
			self:updateHighlightIndex( calculatedPosition )
		end
		self:updateProgressBar()
	end
end

function HorizontalSlider.eventHandleReleased( self, jsonGui, left, buttonId )
	if buttonId == 0 then
		local absBgLeft = jsonGui:getWidgetAbsolutePosition( self.hostWidget.Name )
		
		local sliderLocalMouse = left - absBgLeft - self.mouseDragOffset
		local clampedPos = self:clampPosition( sliderLocalMouse )
		self.widgets.handle.x = round( clampedPos )

		local calculatedPosition = round( clampedPos / self.sliderStep )

		if calculatedPosition + 1 ~= self.sliderPosition then
			self.sliderPosition = calculatedPosition + 1
			self:updateHighlightIndex( calculatedPosition )
		end

		if self.snapping then
			self.widgets.handle.x = round( calculatedPosition * self.sliderStep )
		end

		self.mouseDragOffset = 0
		self.dragged = false

		self:updateProgressBar()
	end
end

function HorizontalSlider.setSliderPosition( self, position )
	position = clamp( position, 1, self.range )

	self.sliderPosition = min( position, self.rangeLimit ) - 1

	if not self.dragged then
		self.widgets.handle.x = round( self.sliderPosition * self.sliderStep )
		self:updateProgressBar()
		self:updateHighlightIndex( position )
	end
end