-- Camera example.  The application should be set to 320x480.

-- Create our camera
local camera = Camera.new()
stage:addChild(camera)

-- Create an image that is bigger than the application size
local image = Bitmap.new(Texture.new("sky_world_big.png"))
camera:addChild(image)

