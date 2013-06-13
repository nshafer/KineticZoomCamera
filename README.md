KineticZoomCamera
=================

A camera class for Gideros that includes kinetics and pinch-to-zoom

This implements a camera class that allows the user to drag and zoom a virtual camera.  It works basically by having child elements that are bigger than the view size of the given device.  There isn't really a camera that moves, rather it just moves itself and any child elements relative to the devices normal view.  Further, when the user lifts their finger in the middle of a drag, the drag movement will continue with some kinetic energy and slow down based on simulated friction.

This has two distinct modes, DRAG and SCALE, based on how many touches are detected.  It doesn't combine them, but could be modified to do so.  It will change smoothly between the modes, however.

##Install

Just add Camera.lua to your project.

##Usage:

```lua	
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
```

###Note

This class by default is written for handling touch inputs from the user to move the camera around.  However, if you remove the touch events and functions, it can also be used to track objects in the game instead, such as a character sprite.

##Methods

###Camera.new(options)
Creates a new Camera object.

Parameters:
* options - A table of options.

Options:
* maxZoom - Maximum zoom allowed.  1 is normal zoom.  Default: 2
* friction - Percentage to slow the kinetic drag down on every frame.  Lower = more "slippery".  Default: .85
* maxPoints - Number of history points to keep in memory for kinetics.  Default: 10
* minPoints - Minimum points to enable kinetic scroll.  Default: 3

###Camera:updateAnchor()
Update our anchor point  that's the middle of the "camera".  This should be called whenever you change the camera position

###Camera:centerAnchor()
Center our anchor.  This should be called anytime you change the scale to recenter the view on the anchor, which will get moved by changing the scale since scaling will be changed based on the 0,0 anchor of the sprite, but we want it to zoom based on the center of the camera view

###Camera:centerPoint(x, y)
Center the camera on a point relitive to the child element(s)

###Camera:translateEvent(event)
Translate the x/y coordinates of an event to the cameras coordinates.  It takes both position and scale into consideration.

###Camera:stop()
Stop the camera from moving.













###Bezier:getPoints()
Returns a table/list of points, if any have been calculated.

###Bezier:setPoints(points)
Sets the points used to draw the curve.

Parameters:
* points - A table/list of points in the format {{x=0,y=0}, ...}

###Bezier:setAutoStepScale(scale)
Sets the factor used to estimate the number of steps to use if none are explicitly given.  The formula is:

	d1 = distance between p1 and p2
	d2 = distance between p2 and p3
	d3 = distance between p3 and p4

	steps = (d1 + d2 + d3) * scale

Parameters:
* scale - Basically the percentage of the distance between the start, end and control points of a curve.  Default: .1

###Bezier:getAutoStepScale()
Returns the current auto step scale factor.

###Bezier:getLength()
Returns the total length of the curve by adding up the distance between each point in the curve.

###Bezier:draw(isClosed)
Draws the curve using the inherited Shape methods as a series of lines.  Remember, you have to add the curve somewhere in the scene graph for it to be visible.

Parameters:
* isClosed - Controls whether the curve is drawn as a closed path or not.  Default: false

###Bezier:createQuadraticCurve(p1, p2, p3, steps)
Calculates the points needed to form a quadratic curve comprised of a start point (p1), a single control point (p2) and an end point (p3).

Parameters:
* p1: Beginning of the path. Must be table with 'x' and 'y' keys, i.e. {x=100,y=100}
* p2: First control point of the path. Must be table with 'x' and 'y' keys, i.e. {x=100,y=100}
* p3: End of the path. Must be table with 'x' and 'y' keys, i.e. {x=100,y=100}
* steps: Number of steps to create in the path.  Default: estimate based on distance between points.  See Bezier:setAutoStepScale

###Bezier:createCubicCurve(p1, p2, p3, p4, steps)
Calculates the points needed to form a cubic curve comprised of a start point (p1), a control point (p2), another control point (p3) and an end point (p4).

Parameters:
* p1: Beginning of the path. Must be table with 'x' and 'y' keys, i.e. {x=100,y=100}
* p2: First control point of the path. Must be table with 'x' and 'y' keys, i.e. {x=100,y=100}
* p3: Second control point of the path. Must be table with 'x' and 'y' keys, i.e. {x=100,y=100}
* p4: End of the path. Must be table with 'x' and 'y' keys, i.e. {x=100,y=100}
* steps: Number of steps to create in the path.  Default: estimate based on distance between points.  See Bezier:setAutoStepScale

###Bezier:reduce(epsilon)
Reduces the number of points in the path by examining the distance between each point and line from surrounding points.  If the point is greater than *epsilon* then it will be kept, otherwise it is discarded.

Parameters:
* epsilon: Minimum distance from the line of the curve for a point to be kept.  Higher values result in more points being thrown away.  Default: .1
