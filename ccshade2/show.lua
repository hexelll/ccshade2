local renderer = assert(loadfile(shell.resolve("renderer.lua"),nil,_ENV))()

local args = ({...})
local r = renderer.new{usecache=true}
local png = assert(loadfile(shell.resolve("png.lua"),nil,_ENV))()
local pixels = {}
local uniqueColors = {}
if args[1]:sub(args[1]:find("%.")+1,#args[1]) == "png" then
    local img = png(shell.resolve(args[1]))
    pixels = img.pixels
    uniquesColors = img.palette
else
    local fh = fs.open(shell.resolve(args[1]),"r")
    pixels = textutils.unserialise(fh.readAll())
    fh.close()
end

local lastt = os.clock()
while true do
    local m = peripheral.find("monitor")
    mon = args[2] and peripheral.wrap(args[2]) or ( m and m or term )
    if mon.setTextScale then
        mon.setTextScale(0.5)
    end
    local sx,sy = mon.getSize()
    r.term = mon
    r:applyPalette()
    sx=sx+1
    sy = math.floor(sy*3/2+0.4999)+1
    r.size = {x=sx,y=sy}
    for y=1,sy do
        for x=1,sx do
            local u,v = x/sx,y/sy
            local c = pixels[1+math.floor(v*#pixels+0.499)] and pixels[1+math.floor(v*#pixels+0.499)][1+math.floor(u*#pixels[1]+0.499)]
            c = c and {c.R/255,c.G/255,c.B/255} or {0,0,0}
            --c[1] = c[1]*(1+math.sin(os.clock()*0.5))/2
            --c[2] = c[2]*(1+math.sin(os.clock()*0.5))/2
            --c[3] = c[3]*(1+math.sin(os.clock()*0.5))/2
            r:setPx({x=x,y=y},c)
        end
    end
    --term.clear()
    local t = os.clock()
    print(t-lastt)
    lastt = t
    r
    :optimizeColors(10,0.03,16)
    :floyddither(0.005*(sx+sy))
    :render()
    r:applyPalette()
    sleep()
end
local f = fs.open("palette.txt","w")

f.write(textutils.serialise(r.palette))

f.close()
