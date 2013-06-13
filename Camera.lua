-- Kinetic Zoom Camera
-- https://github.com/nshafer/KineticZoomCamera

-- The MIT License (MIT)

-- Copyright (c) 2013 Nathan Shafer

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.


--[[

	This implements a camera class that allows the user to drag and zoom a virtual camera.  It works
	basically by having child elements that are bigger than the view size of the given device.  There
	isn't really a camera that moves, rather it just moves itself and any child elements relative
	to the devices normal view.  Further, when the user lifts their finger in the middle of a drag, the
	drag movement will continue with some kinetic energy and slow down based on simulated friction.
	
	This has two distinct modes, DRAG and SCALE, based on how many touches are detected.  It doesn't
	combine them, but could be modified to do so.  It will change smoothly between the modes, however.
	
	Usage:
	
	local camera = Camera.new()
	local camera = Camera.new({maxZoom=1.5,friction=.5})
	stage:addChild(camera)
	
	-- Add whatever you want as a child of the camera
	local image = Bitmap.new(Texture.new("sky_world_big.png"))
	camera:addChild(image)
	
	-- If you want to center the camera on a child element, such as a player, you can do:
	local player = Sprite.new()  -- example player sprite
	camera:centerPoint(player:getX(), player:getY())
	
	-- If you want to process touch events relative to where the camera is, you can translate the event
	function onTouchBegin(event)
		local point = camera:translateEvent(event)
		-- point.x = x position of the touch relative to the camera
		-- point.y = y position of the touch relative to the camera
	end
--]]

Camera = Core.class(Sprite)

-- Constants
Camera.DRAG = 1
Camera.SCALE = 2

function Camera:init(options)
	options = options or {}
	self.maxZoom = options.maxZoom or 2 -- Maximum scale allowed.  1 = normal unzoomed
	self.friction = options.friction or .85 -- Percentage to slow the drag down by on every frame.  Lower = more slippery
	self.maxPoints = options.maxPoints or 10 -- Number of history points to keep in memory
	self.minPoints = options.minPoints or 3 -- Minimum points to enable kinetic scroll

	-- These are tables that store a history of touch events and times
	self.previousPoints = nil
	self.previousTimes = nil
	
	-- We maintain an anchor that is the center of the "camera"
	self.anchorX = 0
	self.anchorY = 0
	
	-- Add our event listeners for touch events
	self:addEventListener(Event.TOUCHES_BEGIN, self.onTouchesBegin, self)
	self:addEventListener(Event.TOUCHES_MOVE, self.onTouchesMove, self)
	self:addEventListener(Event.TOUCHES_END, self.onTouchesEnd, self)
	self:addEventListener(Event.TOUCHES_CANCEL, self.onTouchesCancel, self)
end

-- Override the Sprite position functions so that we can enforce boundaries
function Camera:setX(x) -- override
	-- Check boundaries
	x = math.max(x, application:getContentWidth() - self:getWidth())
	x = math.min(x, 0)
	
	Sprite.setX(self, x)
end

function Camera:setY(y) -- override
	-- Check boundaries
	y = math.max(y, application:getContentHeight() - self:getHeight())
	y = math.min(y, 0)
	
	Sprite.setY(self, y)
end

function Camera:setPosition(x, y) -- override
	self:setX(x)
	self:setY(y or x)
end

-- Override the Sprite setScale function so we can enforce boundaries
function Camera:setScale(scaleX, scaleY) -- override
	-- Calculate boundaries
	local minScaleX = application:getContentWidth() / (self:getWidth() * (1/self:getScaleX()))
	local minScaleY = application:getContentHeight() / (self:getHeight() * (1/self:getScaleY()))
	
	-- Check the boundaries
	scaleX = math.max(scaleX, minScaleX, minScaleY)
	scaleX = math.min(scaleX, self.maxZoom)
	
	scaleY = math.max(scaleY or scaleX, minScaleY, minScaleX)
	scaleY = math.min(scaleY or scaleX, self.maxZoom)

	Sprite.setScale(self, scaleX, scaleY)
end

-- Update our anchor point  that's the middle of the "camera".  This should be called
-- whenever you change the camera position
function Camera:updateAnchor()
	self.anchorX = (-self:getX() + application:getContentWidth()/2) * (1/self:getScaleX())
	self.anchorY = (-self:getY() + application:getContentHeight()/2) * (1/self:getScaleY())
end

-- Center our anchor.  This should be called anytime you change the scale to recenter the
-- view on the anchor, which will get moved by changing the scale since scaling will be
-- changed based on the 0,0 anchor of the sprite, but we want it to zoom based on the
-- center of the camera view
function Camera:centerAnchor()
	self:centerPoint(self.anchorX, self.anchorY)
end

-- Center the camera on a point relitive to the child element(s)
function Camera:centerPoint(x, y)
	self:setX(-(x * self:getScaleX() - application:getContentWidth()/2))
	self:setY(-(y * self:getScaleY() - application:getContentHeight()/2))
	
	self:updateAnchor()
end

-- Translate the x/y coordinates of an event to the cameras coordinates.  It
-- takes both position and scale into consideration.
function Camera:translateEvent(event)
	local point = {x=0,y=0}
	
	point.x = (-self:getX() + event.x or event.touch.x) * (1/self:getScaleX())
	point.y = (-self:getY() + event.y or event.touch.y) * (1/self:getScaleY())
	
	return(point)
end

-- Calculate distance between two points
function Camera:getDistance(p1, p2)
	local dx = p2.x - p1.x
	local dy = p2.y - p1.y
	
	return(math.sqrt(dx^2 + dy^2))
end

-- Stop the camera from moving any more
function Camera:stop()
	self:removeEventListener(Event.ENTER_FRAME, self.onEnterFrame, self)
	self.velocity = nil
	self.time = nil
end

-- A finger or mouse is pressed
function Camera:onTouchesBegin(event)
	if self:hitTestPoint(event.touch.x, event.touch.y) then
		self.isFocus = true
		
		if #event.allTouches <= 1 then
			self.mode = Camera.DRAG
			
			-- Record the starting point
			self.x0 = event.touch.x
			self.y0 = event.touch.y
			
			-- Stop any current camera movement
			self:stop()
			
			-- Initialize our touch histories
			self.previousPoints = {{x=event.touch.x,y=event.touch.y}}
			self.previousTimes = {os.timer()}
		else
			self.mode = Camera.SCALE
			
			-- Only look at the last finger to touch, ignore intermediate fingers
			if event.touch.id == event.allTouches[#event.allTouches].id then
				-- Figure out initial distance
				self.initialDistance = self:getDistance(event.touch, event.allTouches[1])
				self.initialScale = self:getScale()
				self.initialX = self:getX()
				self.initialY = self:getY()
			end
		end
		
		event:stopPropagation()
	end
end

function Camera:onTouchesMove(event)
	if self.isFocus then
		if self.mode == Camera.DRAG then
			-- Figure out how far we moved since last time
			local dx = event.touch.x - self.x0
			local dy = event.touch.y - self.y0
			
			-- Move the camera
			self:setX(self:getX() + dx)
			self:setY(self:getY() + dy)
			
			-- Update our location
			self.x0 = event.touch.x
			self.y0 = event.touch.y
			
			-- Update the anchor point
			self:updateAnchor()
			
			-- Add to the stack for velocity calculations later
			table.insert(self.previousPoints, {x=event.touch.x,y=event.touch.y})
			table.insert(self.previousTimes, os.timer())
			
			-- Clean up old points
			-- NOTE: This is not the most efficient way to implement a stack with tables
			--       in LUA, but it's the simplest and performs fine for our purposes
			while #self.previousPoints > self.maxPoints do
				table.remove(self.previousPoints, 1)
				table.remove(self.previousTimes, 1)
			end
		elseif self.mode == Camera.SCALE then
			if #event.allTouches > 1 then
				-- Only look at the last finger to touch, ignore intermediate fingers
				if event.touch.id == event.allTouches[#event.allTouches].id then
					-- Figure out current distance
					local currentDistance = self:getDistance(event.touch, event.allTouches[1])
					
					-- Change our scale
					self:setScale(currentDistance / self.initialDistance * self.initialScale)
					
					-- Center on our anchor
					self:centerAnchor()
				end
			end
		end
			
		event:stopPropagation()
	end
end

function Camera:onTouchesEnd(event)
	if self.isFocus then
		if self.mode == Camera.DRAG then
			if self.previousPoints and #self.previousPoints > self.minPoints then
				-- calculate vectors between now and x points ago
				local new_time = os.timer()
				local vx = event.touch.x - self.previousPoints[1].x
				local vy = event.touch.y - self.previousPoints[1].y
				local vt = new_time - self.previousTimes[1]
				
				-- Calculate our velocities
				self.velocity = {x=vx/vt, y=vy/vt}
				self.time = new_time
				
				-- add an event listener to finish drawing the movement
				self:addEventListener(Event.ENTER_FRAME, self.onEnterFrame, self)
			end
			
			self.isFocus = false
		elseif self.mode == Camera.SCALE then
			-- If we're left with just 2 touches, then go back to DRAG mode
			if #event.allTouches == 2 then
				self.mode = Camera.DRAG
				
				-- reset our last position based on whatever finger is left for a smooth
				-- transition back to DRAG mode
				if event.allTouches[1].id == event.touch.id then
					self.x0 = event.allTouches[2].x
					self.y0 = event.allTouches[2].y
				else
					self.x0 = event.allTouches[1].x
					self.y0 = event.allTouches[1].y
				end
				
				-- Reset our histories
				self:stop()
				
				self.previousPoints = {{x=self.x0,y=self.y0}}
				self.previousTimes = {os.timer()}
			end
		end
			
		event:stopPropagation()
	end
end

function Camera:onTouchesCancel(event)
	if self.isFocus then
		print("Camera TOUCHES_CANCEL", self.mode)
		self.isFocus = false
		event:stopPropogation()
	end
end

-- This will continue moving the camera based on the velocities that were imparted on it,
-- eventually slowing to a stop based on the friction.
function Camera:onEnterFrame(event)
	if self.mode == Camera.DRAG then
		-- Figure out how much time has passed since the last frame
		local new_time = os.timer()
		local dt = new_time - self.time
		self.time = new_time
		
		-- Calculate the distance we should move this frame
		local sx = self.velocity.x * dt
		local sy = self.velocity.y * dt
		
		-- Apply friction
		self.velocity.x = self.velocity.x * self.friction
		self.velocity.y = self.velocity.y * self.friction
		
		-- Check if we're slow enough to just stop
		if math.abs(self.velocity.x) < .1 then self.velocity.x = 0 end
		if math.abs(self.velocity.y) < .1 then self.velocity.y = 0 end
		
		if self.velocity.x == 0 and self.velocity.y == 0 then
			self:stop()
		else
			-- Move us
			self:setX(self:getX() + sx)
			self:setY(self:getY() + sy)
			
			-- Update our anchor
			self:updateAnchor()
		end
	end
end

