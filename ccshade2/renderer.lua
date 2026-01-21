local renderer = {}

local evenc = '\143'
local oddc = '\131'

function renderer.new(o)
    o = o or {}
    o.term = o.term and o.term or term
    local w,h = o.term.getSize()
    o.size = o.size and o.size or {}
    o.size.x = o.size.x and o.size.x or w+1
    o.size.y = o.size.y and o.size.y or math.floor(h*3/2+0.4999)+1
    o.pixels = o.pixels and o.pixels or {}
    o.pos = o.pos and o.pos or {x=0,y=0}
    o.dPixels = o.dPixels and o.dPixels or {}
    o.paletteBlackList = o.paletteBlackList or {}
    o.cache = o.cache and o.cache or {}
    if o.usecache == nil then
        o.usecache = true
    end
    o.cacheColAcc = o.cacheColAcc and o.cacheColAcc or 100
    if not o.palette then
        o.palette = {}
        local colors = {
            {20, 12, 28},
            {68, 36, 52},
            {48, 52, 109},
            {78, 74, 78},
            {133, 76, 48},
            {52, 101, 36},
            {208, 70, 72},
            {117, 113, 97},
            {89, 125, 206},
            {210, 125, 44},
            {133, 149, 161},
            {109, 170, 44},
            {210, 170, 153},
            {109, 194, 202},
            {218, 212, 94},
            {222, 238, 214}
        }
        for i=1,#colors do
            local c = colors[i]
            o.palette[i] = {c[1]/255,c[2]/255,c[3]/255}
        end
    end
    o.distance = o.distance and o.distance or function(a,b)
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

function renderer:applyPalette()
    for i,c in pairs(self.palette) do
        self.term.setPaletteColor(2^(i-1),table.unpack(c)) 
    end
    return self
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
    return self.pixels[pos.y+pos.x*self.size.y] or {0,0,0}
end
function renderer:setPx(pos,col)
    if not self:ok(pos) then
        return self
    end
    local x = math.floor(pos.x+0.5)
    local y = math.floor(pos.y+0.5)-1
    self.pixels[y+x*self.size.y] = col
    local Y = math.floor((pos.y-1)*2/3+0.5)
    local i = Y+x*self.size.y
    self.dPixels[i] = self.dPixels[i] or {{0,0,0},{0,0,0}}
    if (Y)%2 == 0 then
        self.dPixels[i][2] = col
    else
        if (y+1)%3 == 0 then
            self.dPixels[i][2] = col
        else
            local j = i-1
            self.dPixels[j] = self.dPixels[j] or {{0,0,0},{0,0,0}}
            self.dPixels[i][1] = col
            self.dPixels[j][1] = col
        end
    end
    return self
end

function renderer:findClosest(col)
    local r = math.floor(col[1]*self.cacheColAcc)
    local g = math.floor(col[2]*self.cacheColAcc)
    local b = math.floor(col[3]*self.cacheColAcc)
    if self.usecache then
        local ccol = (self.cache[r] and self.cache[r][g]) and self.cache[r][g][b]
        if ccol then
            return ccol
        end
    end
    col = col or {0,0,0}
    local mini = 1
    local mind = self.distance(self.palette[1],col)
    for i=1,#self.palette do
        local d = self.distance(self.palette[i],col)
        if d < mind then
            mini = i
            mind = d
        end
    end
    if self.usecache then
        self.cache[r] = self.cache[r] and self.cache[r] or {}
        self.cache[r][g] = self.cache[r][g] and self.cache[r][g] or {}
        self.cache[r][g][b] = mini
    end
    return mini
end

function renderer:drawText(pos,text)

end

function renderer.rectangleSdf(p,b)
    return function(x)
        local l = function(v) return math.sqrt(v.x*v.x+v.y*v.y) end
        return l{x=math.max(math.abs(x.x-p.x)-b.x/2,0),y=math.max(math.abs(x.y-p.y)-b.y/2,0)} - math.max(math.min(b.x/2-math.abs(x.x-p.x),b.y/2-math.abs(x.y-p.y)),0)
    end
end

function renderer.sphereSdf(p,r)
    return function(x)
        local l = function(v) return math.sqrt(v.x*v.x+v.y*v.y) end
        return l{x=x.x-p.x,y=x.y-p.y}-r
    end
end

function renderer.unionSdf(sdfs)
    return function(x)
        local mind = math.huge
        for _,sdf in pairs(sdfs) do
            local d = sdf(x)
            mind = mind<d and mind or d
        end
        return mind
    end
end

function renderer.blendOp(d1,d2,k)
    local h = math.max(k-math.abs(d1-d2),0)/k
    return math.min(d1,d2) - h*h*k/4
end

function renderer.blendSdf(sdfs,k)
    return function(x)
        local d = sdfs[1](x)
        for i=2,#sdfs do
            d = renderer.blendOp(d,sdfs[i](x),k)
        end
        return d
    end
end

function renderer:debugSdf(sdf,n)
    for x=1,self.size.x do
        for y=1,self.size.y do
            local d = sdf{x=x,y=y}
            local k = math.fmod(math.abs(d),n)/n
            local c = d>=0 and {k,0.5*k,0} or {0,0,0.8*k}
            self:setPx({x=x,y=y},c)
        end
    end
    return self
end

function renderer:drawSdf(sdf,col)
    for x=1,self.size.x do
        for y=1,self.size.y do
            local d = sdf{x=x,y=y}
            local c = type(col) == "table" and (d<0 and col or {0,0,0}) or col(d)
            self:setPx({x=x,y=y},c)
        end
    end
    return self
end


function renderer:uniqueColors(eps,keep)
    local ucolors = keep or {}
    for x=1,self.size.x do
        for y=1,self.size.y do
            local found = false
            local i = 1
            local c = self:getPx{x=x,y=y}
            for j,v in pairs(ucolors) do
                if math.sqrt(self.distance(v.col,c)) <= eps then
                    found = true
                    i=j
                    break
                end
            end
            if not found then
                ucolors[#ucolors+1] = {count=0,col=c}
            else
                ucolors[i].count = ucolors[i].count+1
            end
        end
    end
    return ucolors
end

function renderer:optimizeColors(N,e,maxColors,colors)
    N=N and N or 10
    e = e and e or 0.05
    maxColors = maxColors or 16
    local oldpalette = {}
    for i,c in pairs(self.palette) do
        oldpalette[i] = c
    end
    local rcolors = not colors and self:uniqueColors(e,keep) or colors
    for _=1,N do
        local clusters = {}
        for i=1,#rcolors do
            local c = rcolors[i]
            local minj = 1
            local mind = self.distance(c.col,self.palette[1])
            for j=2,math.min(#self.palette,maxColors) do
                local d = self.distance(c.col,self.palette[j])
                if d < mind then
                    minj = j
                    mind = d
                end
            end
            clusters[minj] = clusters[minj] and clusters[minj] or {}
            clusters[minj][#clusters[minj]+1] = c
        end
        local calcCentroid = function(cluster)
            local mean = {0,0,0}
            if #cluster > 0 then
                local l = 0
                for i=1,#cluster do
                    local c = cluster[i]
                    l=l+1
                    mean[1] = mean[1] + c.col[1]
                    mean[2] = mean[2] + c.col[2]
                    mean[3] = mean[3] + c.col[3]
                end
                if l > 0 then
                mean[1] = mean[1]/l
                mean[2] = mean[2]/l
                mean[3] = mean[3]/l
                end
            end
            return mean
        end
        local newpalette = {}
        local maxd = 0
        for i,cluster in pairs(clusters) do
            local c = calcCentroid(cluster)
            local d = self.distance(c,self.palette[i])
            newpalette[#newpalette+1]=c
            maxd = maxd<d and d or maxd
        end
        self:updatePalette(newpalette)
        if math.sqrt(maxd) < e then
            break
        end
    end
    if self.usecache then
        self.cache = {}
        --[[for r,t1 in pairs(self.cache) do
            for g,t2 in pairs(t1) do
                for b,i in pairs(t2) do
                    self.usecache = false
                    self.cache[r][g][b] = self:findClosest({r/self.cacheColAcc,b/self.cacheColAcc,b/self.cacheColAcc})
                    self.usecache = true
                end
            end
        end]]
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

function renderer:drawLine(p1,p2,col)
    col = col and col or {1,1,1}
    local dx = (p2.x - p1.x);
    local dy = (p2.y - p1.y);
    if dx == 0 and dy == 0 then
        self:setPx(p1,type(col)=="table" and col or col(p1))
        return self
    end
    local numPixels = math.abs(dx) > math.abs(dy) and math.abs(dx) or math.abs(dy)
    numPixels = numPixels*2
    local stepX = dx / numPixels;
    local stepY = dy / numPixels;
    local x = p1.x
    local y = p1.y
    for i=0,numPixels do
        local d = 1-math.abs(y-math.floor(y*2+0.499)/2)
        self:setPx({x=x,y=y},type(col)=="table" and col or col{x=x,y=y})
        x = x+stepX;
        y = y+stepY;
    end
    return self
end

function renderer:render()
    for y=0,math.floor((self.size.y)*2/3+0.5)-1 do
        for x=1,self.size.x do
            local col = self.dPixels[y+x*self.size.y] or {{0,0,0},{0,0,0}}
            local i1 = self:findClosest(col[1])
            local i2 = self:findClosest(col[2])
            local tcol1 = 2^(i1-1)
            local tcol2 = 2^(i2-1)
            local c = y%2==1
            tcol1,tcol2 = c and tcol2 or tcol1,c and tcol1 or tcol2
            self.term.setCursorPos(self.pos.x+x,self.pos.y+1+y)
            self.term.setBackgroundColor(tcol1)
            self.term.setTextColour(tcol2)
            self.term.write(y%2==0 and evenc or oddc)
        end
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