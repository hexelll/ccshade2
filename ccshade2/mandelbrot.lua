local renderer = require "renderer"

local r = renderer.new{term=peripheral.find("monitor"),usecache=true}

local maxn =100

local lastt = os.clock()

while true do
    for x=1,r.size.x do
        for y=1,r.size.y do
            local x0 = (((x)/r.size.x))*2-1.5
            local y0 = (((y)/r.size.y)-1/2)*(2*1.12)
            local i = 0
            local X,Y = 0,0
            while X^2+Y^2 < 2^2 and i < maxn do
                xtemp = X^2-Y^2+x0
                Y=2*X*Y + y0
                X=xtemp
                i=i+1
            end
            print(i)
            r:setPx({x=x,y=y},{i/maxn,i/maxn,i/maxn})
        end
    end
    t = os.clock()
    local dt = t-lastt
    --maxn=maxn+dt
    r
    :optimizeColors()
    :applyPalette()
    :render()
    sleep()
end
