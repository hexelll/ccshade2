local renderer = require "renderer"
local png = require "png"
local pixels = png(shell.resolve("./gato.png")).pixels
local r = renderer.new{pos={x=0,y=0}}
local function draw()
    local mon = peripheral.wrap("right")
    r.term = mon
    mon.setTextScale(0.5)
    local sx,sy = mon.getSize()
    r.size = {x=sx,y=math.floor(sy*3/2+0.4999)}
    sx=sx+1
    sy = math.floor(sy*3/2+0.4999)+1
    for x=1,sx do
        for y=1,sy do
            local u,v = x/sx,y/sy
            local c = pixels[1+math.floor(v*#pixels+0.499)] and pixels[1+math.floor(v*#pixels+0.499)][1+math.floor(u*#pixels[1]+0.499)]
            c = c and {c.R/255,c.G/255,c.B/255} or {0,0,0}
            r:setPx({x=x,y=y},c)
        end
    end
    r
    :optimizeColors(10,0.1,{{1,1,1},{0,0,0}})
    :floyddither(1.5)
    :render()
end
draw()
while true do
    draw()
    sleep()
end