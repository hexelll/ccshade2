local grapher = require "grapher"
local renderer = require "renderer"
local palette = require "catppuccinPalette"

local mon = peripheral.find("monitor")
mon.clear()
mon.setTextScale(0.5)
local g = grapher.new{r=renderer.new{term=mon,usecache=true},zoom={x=0.3,y=0.3},gridColor=palette.Base,bgColor=palette.Crust,lineColor=palette.Teal,coordsColor=palette.Overlay}
local i = 1
for k,c in pairs(palette) do
    g.r.palette[i] = c
    i=i+1
end
g:draw1dFunction(function(x)return math.sin(x*0.5) end,{-100,100})
:autoResize(false,true)
:run()
