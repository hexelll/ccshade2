local renderer = require "renderer"

local grapher = {}

function grapher.new(o)
    o = o or {}
    o.r = o.r and o.r or renderer.new()
    o.points = o.points and o.points or {}
    o.gridSize = o.gridSize and o.gridSize or 5
    o.gridColor = o.gridColor and o.gridColor or {0.2,0.2,0.2}
    o.bgColor = o.bgColor and o.bgColor or {0,0,0}
    o.lineColor = o.lineColor and o.lineColor or {1,0,0}
    o.coordsColor = o.coordsColor and o.coordsColor or {0.8,0.8,0.8}
    o.originColor = o.originColor and o.originColor or {1,1,1}
    o.size = o.size and o.size or o.r.size
    o.offset = o.offset or {x=o.size.x/2,y=o.size.y/2}
    o.zoom = o.zoom and o.zoom or {x=1,y=1}
    setmetatable(o,{__index=function(_,k)
        return grapher[k]
    end})
    return o
end

function grapher:pushPoint(point)
    self.points[#self.points+1] = point
end

function grapher:draw1dFunction(f,interval,e)
    interval = interval and interval or {0,self.size.x}
    e = e and e or 0.1
    for x=interval[1],interval[2],e do
        self:pushPoint{x=x,y=f(x)}
    end
    return self
end

function grapher:autoResize(fitToScreen,center)
    fitToScreen = fitToScreen==nil and true or fitToScreen
    center = center==nil and true or center
    local minx,maxx,miny,maxy=math.huge,-math.huge,math.huge,-math.huge
    for _,p in pairs(self.points) do
        minx = p.x < minx and p.x or minx
        miny = p.y < miny and p.y or miny
        maxx = p.x > maxx and p.x or maxx
        maxy = p.y > maxy and p.y or maxy
    end
    if fitToScreen then
        self.zoom.x = (maxx-minx)/(self.size.x)
        self.zoom.y = (maxy-miny)/(self.size.y)
    end
    self.offset = {x=-((minx)/self.zoom.x),y=((miny)/self.zoom.y+self.size.y)}
    if center then
        self.offset = {x=self.size.x/2+(-minx-(maxx-minx)/2)/self.zoom.x,y=-self.size.y/2+(miny+(maxy-miny)/2)/self.zoom.y+self.size.y}
    end
    return self
end

function grapher:render()
    self.r:drawGrid(self.size.x,self.size.y,self.gridSize,1,self.gridColor,self.bgColor)
    self.r:drawLine({x=0,y=self.offset.y},{x=self.size.x,y=self.offset.y},self.coordsColor)
    self.r:drawLine({x=self.offset.x,y=0},{x=self.offset.x,y=self.size.y},self.coordsColor)
    self.r:setPx({x=self.offset.x,y=self.offset.y},self.originColor)
    for i=1,#self.points-1 do
        local p1,p2 = self.points[i],self.points[i+1]
        self.r:drawLine(
            {
                x=(p1.x)/self.zoom.x+self.offset.x,
                y=-(p1.y)/self.zoom.y+self.offset.y
            },
            {
                x=(p2.x)/self.zoom.x+self.offset.x,
                y=-(p2.y)/self.zoom.y+self.offset.y
            },
            self.lineColor)
    end
    self.r
    --:optimizeColors(1,0)
    :render()
    return self
end

function grapher:run()
    local lastt = os.clock()
    while true do
        self:render()
        local t = os.clock()
        self:onRender(t-lastt)
        lastt = t
        sleep()
    end
end

return grapher