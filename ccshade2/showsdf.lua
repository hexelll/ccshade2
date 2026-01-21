local renderer = require "renderer"
local mon = peripheral.find("monitor")
mon.setTextScale(0.5)
local r = renderer.new{usecache=true,term=mon}
local pstatic = {x=r.size.x/2,y=r.size.y/2}
local staticsdf 
local rorbit = 10
local porbit = {x=math.random(1,r.size.x*2),y=math.random(1,r.size.y*2)}
local a = math.pi/2
local sv = 5
local vorbit = {x=math.cos(a)*sv,y=math.sin(a)*sv}
--local vorbit = {x=0,y=0}
local g = -1
local function step(dt)
    local d = staticsdf(porbit)
    local l = function(v) return math.sqrt(v.x*v.x+v.y*v.y) end
    local diff = {x=porbit.x-pstatic.x,y=porbit.y-pstatic.y}
    vorbit.x = vorbit.x+diff.x*g*dt
    vorbit.y = vorbit.y+diff.y*g*dt
    if d-rorbit < 0 then
        local lv = l(vorbit)
        local ld = l(diff)
        local n = {x=diff.x/ld,y=diff.y/ld}
        local an = math.acos(n.x)
        local nv = {x=vorbit.x/lv,y=vorbit.y/lv}
        local dot = n.x*nv.x+n.y*nv.y
        local cross = -n.x*nv.y+n.y*nv.x
        local a = math.acos(dot)*math.abs(cross)/-cross
        vorbit = {x=math.cos(a+an)*-lv,y=math.sin(a+an)*-lv}
    end
    porbit.x = porbit.x + vorbit.x*dt
    porbit.y = porbit.y + vorbit.y*dt
end
local t = os.clock()
while true do
    staticsdf = r.sphereSdf(
        pstatic,
        10
    )
    r:drawSdf(
        r.blendSdf(
            {
                staticsdf,
                r.sphereSdf(
                    porbit,
                    rorbit
                )
            },
            2
        ),
        function(d)
            if d < 0 then
                d=d*0.5
                return {1+0.4/(d+0.3),1+1/(d+0.3),0}
            end
            return {0,0,0}
        end
    )
    --:optimizeColors(100,0.01)
    :applyPalette()
    :dither()
    :render()
    sleep()
    local curt = os.clock()
    step(t-curt)
    t=curt
end