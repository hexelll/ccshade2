local png = require "png"

local pixels = png("/ccshade/examples/luc.png").pixels

local args = {...}

local path = args[1]
local x = args[2]
local y = args[3]
local cpath = args[4]

local compressed = {}

for i = 1,x do
    compressed[i] = {}
    for j = 1,y do
        local u = i/x
        local v = j/y
        local c = pixels[1+math.floor(v*#pixels+0.499)] and pixels[1+math.floor(v*#pixels+0.499)][1+math.floor(u*#pixels[1]+0.499)]
        c = c and {c.R/255,c.G/255,c.B/255} or {0,0,0}
        compressed[i][j] = c
    end
end
print(textutils.serialise(compressed))
local fh = fs.open(cpath,"w")
fh.write(textutils.serialise(compressed))