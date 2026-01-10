local renderer = {}

local evenc = '\143'
local oddc = '\131'

function renderer.new(o)
    o = o or {}
    o.term = o.term or term
    local w,h = o.term.getSize()
    o.size = o.size or {w,h}
    o.size.x = o.size.x or w
    o.size.y = o.size.y or math.floor(h*3/2)
    o.pixels = o.pixels or {}
    o.pos = o.pos or {x=0,y=0}
    o.dPixels = o.dPixels or {}
    o.paletteBlackList = o.paletteBlackList or {}
    if not o.palette then
        o.palette = {}
        for i=0,15 do
            local r,g,b = term.nativePaletteColor(2^i)
            o.term.setPaletteColor(2^i,r,g,b)
            o.palette[i+1] = {r,g,b}
        end
    end
    o.distance = o.distance or function(a,b)
        return (a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2
    end
    setmetatable(o,{__index=function(_,k)
        return renderer[k]
    end})
    return o
end

function renderer:ok(pos)
    return self.size.x >= pos.x and pos.x >= 1 and self.size.y >= pos.y and pos.y >= 1
end
function renderer:updatePalette(palette)
    for i,c in pairs(palette) do
        self.palette[i] = c
    end
    return self
end
function renderer:getPx(pos)
    if not self:ok(pos) then
        return {0,0,0}
    end
    pos.x = math.floor(pos.x+0.5)
    pos.y = math.floor(pos.y+0.5)-1
    return self.pixels[pos.x+pos.y*self.size.x] or {0,0,0}
end
function renderer:setPx(pos,col)
    if not self:ok(pos) then
        return self
    end
    local x = math.floor(pos.x+0.5)
    local y = math.floor(pos.y+0.5)-1
    self.pixels[x+y*self.size.x] = col
    local Y = math.floor((pos.y-1)*2/3+0.5)
    local i = x+Y*self.size.x
    self.dPixels[i] = self.dPixels[i] or {{0,0,0},{0,0,0}}
    if (Y)%2 == 0 then
        self.dPixels[i][2] = col
    else
        if (y+1)%3 == 0 then
            self.dPixels[i][2] = col
        else
            local j = i-self.size.x
            self.dPixels[j] = self.dPixels[j] or {{0,0,0},{0,0,0}}
            self.dPixels[i][1] = col
            self.dPixels[j][1] = col
        end
    end
    return self
end
function renderer:findClosest(col)
    col = col or {0,0,0}
    local mini = 1
    local mind = self.distance(self.palette[1],col)
    for i=1,16 do
        local d = self.distance(self.palette[i],col)
        if d < mind then
            mini = i
            mind = d
        end
    end
    return mini
end



function renderer:drawText(pos,text)

end

function renderer:uniqueColors(eps,keep)
    local ucolors = keep or {{0,0,0},{1,1,1}}
    for x=1,self.size.x do
        for y=1,self.size.y do
            local found = false
            local c = self:getPx{x=x,y=y}
            for _,col in pairs(ucolors) do
                if math.sqrt(self.distance(col,c)) <= eps then
                    found = true
                    break
                end
            end
            if not found then
                ucolors[#ucolors+1] = c
            end
        end
    end
    return ucolors
end

function renderer:optimizeColors(N,e,keep)
    local rcolors = self:uniqueColors(e,keep)
    local n = math.min(16,#rcolors)
    for i=0,15 do
        local r,g,b = term.nativePaletteColor(2^i)
        self.palette[i+1] = {r,g,b}
    end
    for _=1,N do
        local clusters = {}
        for i=1,#rcolors do
            local c = rcolors[i]
            local minj = 1
            local mind = self.distance(c,self.palette[1])
            for j=2,16 do
                local d = self.distance(c,self.palette[j])
                if d < mind then
                    minj = j
                    mind = d
                end
            end
            clusters[minj] = clusters[minj] or {}
            clusters[minj][#clusters[minj]+1] = c
        end
        local calcCentroid = function(cluster)
            local mean = {0,0,0}
            if #cluster > 0 then
                for i=1,#cluster do
                    mean[1] = mean[1] + cluster[i][1]
                    mean[2] = mean[2] + cluster[i][2]
                    mean[3] = mean[3] + cluster[i][3]
                end
                mean[1] = mean[1]/#cluster
                mean[2] = mean[2]/#cluster
                mean[3] = mean[3]/#cluster
            end
            return mean
        end
        local newpalette = {}
        for _,cluster in pairs(clusters) do
            newpalette[#newpalette+1]=calcCentroid(cluster)
        end
        self:updatePalette(newpalette)
    end
    return self
end

function renderer:floyddither(k)
    for x=2,self.size.x,3 do
        for y=1,self.size.y,2 do
            local oldpixel = self:getPx{x=x,y=y}
            local newpixel = self.palette[self:findClosest(oldpixel)]
            local quant_error = math.sqrt(self.distance(oldpixel,newpixel))*k
            local p = self:getPx{x=x+1,y=y}
            p[1] = p[1]+quant_error*7/16
            p[2] = p[2]+quant_error*7/16
            p[3] = p[3]+quant_error*7/16
            self:setPx({x=x+1,y=y},p)
            p = self:getPx{x=x-1,y=y+1}
            p[1] = p[1]+quant_error*3/16
            p[2] = p[2]+quant_error*3/16
            p[3] = p[3]+quant_error*3/16
            self:setPx({x=x-1,y=y+1},p)
            p = self:getPx{x=x,y=y+1}
            p[1] = p[1]+quant_error*5/16
            p[2] = p[2]+quant_error*5/16
            p[3] = p[3]+quant_error*5/16
            self:setPx({x=x,y=y+1},p)
            p = self:getPx{x=x+1,y=y+1}
            p[1] = p[1]+quant_error*1/16
            p[2] = p[2]+quant_error*1/16
            p[3] = p[3]+quant_error*1/16
            self:setPx({x=x+1,y=y+1},p)
        end
    end
    return self
end

function renderer:dither()
    local newpixels = {}
    for x=1,self.size.x,2 do
        for y=1,self.size.y,2 do
            local quant_error = 1/16
            local p = self:getPx{x=x+1,y=y}
            p[1] = p[1]+quant_error*0.5
            p[2] = p[2]+quant_error*0.5
            p[3] = p[3]+quant_error*0.5
            newpixels[x+1] = newpixels[x+1] or {}
            newpixels[x+1][y] = p

            p = self:getPx{x=x,y=y+1}
            p[1] = p[1]+quant_error*0.75
            p[2] = p[2]+quant_error*0.75
            p[3] = p[3]+quant_error*0.75
            newpixels[x] = newpixels[x] or {}
            newpixels[x][y+1] = p

            p = self:getPx{x=x+1,y=y+1}
            p[1] = p[1]+quant_error*0.25
            p[2] = p[2]+quant_error*0.25
            p[3] = p[3]+quant_error*0.25
            newpixels[x+1][y+1] = p
        end
    end
    for x=1,self.size.x do
        for y=1,self.size.y do
            if newpixels[x] and newpixels[x][y] then
                self:setPx({x=x,y=y},newpixels[x][y])
            end
        end
    end
    return self
end

function renderer:drawGrid(sx,sy,n,k,fc,bc)
    fc = fc or {1,1,1}
    bc = bc or {0,0,0}
    for x = 1,sx do
        for y = 1,sy do
            local u = x/sx
            local v = y/sy
            local offset = math.floor(n/2+0.499)+1
            local fcol = type(fc) == "table" and fc or fc(u,v)
            local bcol = type(bc) == "table" and bc or bc(u,v)
            --local c = pixels[math.floor(1+v*#pixels+0.499)] and pixels[1+math.floor(v*#pixels+0.4999)][1+math.floor(u*#pixels[1]+0.5)] or nil
            --c = c and {c.R/255,c.G/255,c.B/255} or {0,0,0}
            --local c = math.sqrt(r.distance({u,v,0},{0.5,0.5,0})) -->= 0.3 and 1 or 0
            self:setPx({x=x,y=y},((x-offset)%n>=n-k or (y-offset)%n >= n-k) and fcol or {0,0,0})
        end
    end
    return self
end

function renderer:render()
    for y=0,math.floor((self.size.y)*2/3+0.5)-1 do
        for x=1,self.size.x do
            local col = self.dPixels[x+y*self.size.x] or {{0,0,0},{0,0,0}}
            local tcol1 = 2^(self:findClosest(col[1])-1)
            local tcol2 = 2^(self:findClosest(col[2])-1)
            if y%2 == 1 then tcol1,tcol2=tcol2,tcol1 end
            self.term.setCursorPos(self.pos.x+x,self.pos.y+1+y)
            self.term.setBackgroundColor(tcol1)
            self.term.setTextColour(tcol2)
            self.term.write(y%2==0 and evenc or oddc)
        end
    end
    for i = 0,15 do
        self.term.setPaletteColour(2^i,table.unpack(self.palette[i+1]))
    end
end

return renderer
--[[
local r = renderer.new{size={x=20,y=20},pos={x=1,y=1}}
term.clear()
for x = 1,r.size.x do
    for y = 1,r.size.y do
        local u = x/r.size.x
        local v = y/r.size.y
        local c = math.random()
        r:setPx({x=x,y=y},{c,c,c})
    end
end
r:optimizeColors(10,0.01)
:render()
]]