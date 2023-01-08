pico-8 cartridge // http://www.pico-8.com
version 39
__lua__
currentState={}
nextState={}
tick=0
clickState=0
mousePos={pos={x=0,y=0}}
mouseDown=false
mouseUp=false
win=false
lose=false
pause=true
lastSoundtrack=-1

earnings={}
harvest={}
roads={}
flowerLinks={}
baskets={}
lasers={}
turrets={}
player={}
player.selection = 4
player.red = 0
player.blue = 0

-- bucket hash lib - by github.com/selfsame CC4-BY-NC-SA

_9 = {}
function point(x,y) return {x=x,y=y} end
for x=-1,1 do for y=-1,1 do add(_9,point(x,y)) end end
function p_str(p) return p.x..","..p.y end
function coords(p, s) 
	return point(flr(p.x*(1/s)),flr(p.y*(1/s))) 
end

function str_p(s)
  for i=1,#s do if sub(s,i,i) == "," then
    return point(sub(s, 1, i-1)+0, sub(s, i+1, #s)+0)
end end end

function badd(k,e,_b)
  _b[k] = _b[k] or {} 
  add(_b[k], e)
end

function bstore(_b,e)
  local p = p_str(coords(e[_b.prop],_b.size))
  local k = e._k
  if k then
    if (k != p) then
      local b = _b[k]
      del(b,e)
      if (#b == 0) _b[k]=nil
      badd(p,e,_b)
    end
  else badd(p,e,_b) end
  e._k = p
end

function bget(_b, p)
  local p = coords(p, _b.size)
  local _ = {}
  for o in all(_9) do
    local found = _b[p_str(point(p.x+o.x,p.y+o.y))]
    if found then for e in all(found) do add(_,e) end end
  end
  return _
end

function bdel(_b, p)
	key = p_str(coords(p[_b.prop],_b.size))
	local found = _b[key]
    for e in all(found) do 
		if(e.x == p.x and e.y == p.y) then
			del(_b[key],e)
		end
	end
end

function pline(a,b,color) line(a.x+4,a.y+4,b.x+4,b.y+4,color) end

function tostring(any)
    if type(any)=="function" then 
        return "function" 
    end
    if any==nil then 
        return "nil" 
    end
    if type(any)=="string" then
        return any
    end
    if type(any)=="boolean" then
        if any then return "true" end
        return "false"
    end
    if type(any)=="table" then
        local str = "{ "
        for k,v in pairs(any) do
            str=str..tostring(k).."->"..tostring(v).." "
        end
        return str.."}"
    end
    if type(any)=="number" then
        return ""..any
    end
    return "unkown" -- should never show
end

function show_neighbors(store, me)
	for e in all(bget(store,me.pos)) do
	  if (e != me) then
		if(e.color != nil) then
			pline(me.pos,e.pos, e.color)
	  	else
			pline(me.pos,e.pos, 5)
	  	end
	  end
	end
  end

entities = {size=10,prop="pos"}
testEntity = {pos=point(8,48)}
add(entities, testEntity)
basketInitial = {pos=point(8,64)}
add(baskets,basketInitial)
roadInitial = {a={pos=point(8,48)},b={pos=point(8,64)}}
add(roads,roadInitial)

connection1 = {a={pos=point(0,72)},b={pos=point(8,64),color=11}}
connection2 = {a={pos=point(8,72)},b={pos=point(8,64),color=11}}
add(flowerLinks,connection1)
add(flowerLinks,connection2)

flowerStore = {size=10,prop="pos"}
blue1 = {pos=point(64,24),color=7}
blue2 = {pos=point(72,24),color=7}
red1 = {pos=point(8,72),color=11}
red2 = {pos=point(0,72),color=11}
add(flowerStore, blue1)
add(flowerStore, blue2)
add(flowerStore, red1)
add(flowerStore, red2)

flowerResources = {
	{pos=point(64,24),col="blue"},
	{pos=point(72,24),col="blue"},
	{pos=point(8,72),col="red"},
	{pos=point(0,72),col="red"},
}

function _init()
	pal({0,7,15,143,129,140,12,2,13,8,14,3,139,11,6}, 1)
	poke(0x5f2d, 1)
	for i=0, 31 do
		currentState[i] = {}
		nextState[i] = {}
		for z=0, 31 do
			currentState[i][z] = 0
			nextState[i][z] = 0
		end
	end
	currentState[31][16] = 4
end

function sort(a)
    for i=1,#a do
        local j = i
        while j > 1 and a[j-1] > a[j] do
            a[j],a[j-1] = a[j-1],a[j]
            j = j - 1
        end
    end
end

function getFillOrder(x,y)
	fillOrder = {}
	tempTable = {}
	if(y != 0) then
		local index = currentState[x][y-1]
		tempTable[index]={[0]=x,[1]=y-1}
	end
	if(y != 31) then
		local index = currentState[x][y+1]
		tempTable[index]={[0]=x,[1]=y+1}
	end
	if(x != 0) then
		local index = currentState[x-1][y]
		tempTable[index]={[0]=x-1,[1]=y}
	end
	if(x != 31) then
		local index = currentState[x+1][y]
		tempTable[index]={[0]=x+1,[1]=y}
	end

	local fillOrderkeys = {}
	-- populate the table that holds the keys
	for k in pairs(tempTable) do add(fillOrderkeys, k) end
	-- sort the keys
	sort(fillOrderkeys)
	-- use the keys to retrieve the values in the sorted order
	for i, k in pairs(fillOrderkeys) do 
		add(fillOrder,tempTable[k])
	end

	return fillOrder
end	

function moveLiquid(x,y)
	for x,row in pairs(currentState) do
		for y,depth in pairs(row) do
			if(depth!=0) then
				newDepth = depth
				fillOrder = getFillOrder(x,y)
				for neighborDepth,coor in pairs(fillOrder) do
					xCoor = coor[0]
					yCoor = coor[1]
					
					if(neighborDepth != 0 and neighborDepth < newDepth) then
						nextState[xCoor][yCoor] = neighborDepth+1
						newDepth = newDepth-1
					end
				end
				currentState[x][y] = depth
			end
		end
	end
	currentState = nextState
end

function is_empty(t)
    for _,_ in pairs(t) do
        return false
    end
    return true
end

function _update()
	heldMouse = stat(34)
	if(clickState == 0 and heldMouse == 1) then
		clickState = 1
		mouseDown = true
	else
		mouseDown = false
	end

	if(clickState == 1 and heldMouse == 0) then
		clickState = 0
		mouseUp = true
	else
		mouseUp = false
	end

	mousePos = {pos={x=stat(32)-1,y=stat(33)-1}}

	if(player.blue > 5) then
		win=true
	end

	if(win==true)then
		pause = true
		music(-1)
	elseif(lose==true)then
		pause = true
		music(-1)
	end 

	if(pause == true) then
		if(mouseUp)then
			if(mousePos.pos.x > 52 and mousePos.pos.x < 78 and mousePos.pos.y > 70 and mousePos.pos.y < 80) then
				music(0)
				lastSoundtrack=1
				pause = false
			end
		end
	else
		homeBaseDesert = currentState[2][12]
		if(homeBaseDesert>0)then
			lose=true
		end

		musicStat=stat(54)
		if(musicStat==-1)then
			if(lastSoundtrack==0)then
				music(1)
				lastSoundtrack=1
			else
				music(0)
				lastSoundtrack=0
			end
		end
		tick = tick + 1
		if(tick%100 == 0) then
			moveLiquid()
			currentState[31][16] = 4
		end

		if(tick%45 == 0) then
			for _,turret in pairs(turrets) do
				nearbyLiquid = {}
				shortestDistance = 10000
				localtarget = nil
				target = nil
				for x=turret.pos.x/4-4,turret.pos.x/4+4,1 do
					for y=turret.pos.y/4-4,turret.pos.y/4+4,1 do
						cx = mid(0, x, 31)
						cy = mid(0, y, 31)
						depth = currentState[cx][cy]
						if(depth > 0) then
							sfx(2)
							localx = cx - turret.pos.x/4
							localy = cy - turret.pos.y/4
							distance = sqrt(localx*localx+localy*localy)
							if(distance < shortestDistance) then
								shortestDistance = distance
								localtarget = {x=localx,y=localy}
								target = {x=cx,y=cy}
							end 
						end
					end
				end
				
				if(target != nil and player.red > 0) then
					add(lasers,{a={pos=turret.pos},b={pos={x=target.x*4,y=target.y*4}},life=20})
					player.red = player.red-1
					for x=-2,2,1 do
						for y=-2,2,1 do
							cx = mid(0, target.x+x, 31)
							cy = mid(0, target.y+y, 31)
							currentState[cx][cy] = 0
						end
					end
				end
			end
		end

		if(tick%4 == 0) then
			for i in pairs(earnings) do
				earnings[i].pos = point(earnings[i].pos.x,earnings[i].pos.y-1)
				if(earnings[i].life > 1)then
					earnings[i].life = earnings[i].life -1
				else
					deli( earnings,i)
				end
			end
			for i in pairs(harvest) do
				harvest[i].pos = point(harvest[i].pos.x,harvest[i].pos.y-1)
				if(harvest[i].life > 1)then
					harvest[i].life = harvest[i].life -1
				else
					deli( harvest,i)
				end
			end
		end

		for i in pairs(lasers) do
			if(lasers[i].life > 1)then
				lasers[i].life = lasers[i].life -1
			else
				deli(lasers,i)
			end
		end

		if(tick%200 == 0) then
			sfx(4)
			add(earnings,{pos=point(8,48),life=12})
			for i in pairs(baskets) do
				for e in all(bget(flowerStore,baskets[i].pos)) do
					if(e.color == 11) then
						add(earnings,{pos=baskets[i].pos,life=12})
					else
						add(harvest,{pos=baskets[i].pos,life=12})
					end
				end
			end

			
			player.red = player.red + count(earnings)
			player.blue = player.blue + count(harvest)
		end

		if(mouseUp == true) then
			if(mousePos.pos.x < 14 and mousePos.pos.y > 110) then
				player.selection = 0
			elseif(mousePos.pos.x > 16 and mousePos.pos.x < 40 and mousePos.pos.y > 110) then
				player.selection = 1
			elseif(mousePos.pos.x > 42 and mousePos.pos.x < 64 and mousePos.pos.y > 110) then
				player.selection = 2
			elseif(player.selection == 0 and player.red > 0) then
				player.red = player.red - 1
				xTileCoor = ceil((mousePos.pos.x-2)/4)
				yTileCoor = ceil((mousePos.pos.y-2)/4)
				nearbyEntities = bget(entities,point(xTileCoor*4,yTileCoor*4))
				if(is_empty(nearbyEntities) != true)then
					add(entities, {pos=point(xTileCoor*4,yTileCoor*4)})
					for e in all(nearbyEntities) do
						if (e != {pos=point(xTileCoor,yTileCoor)}) then
						add(roads, {a={pos=point(xTileCoor*4+1,yTileCoor*4+1)},b=e})
						end
					end
				end
			elseif(player.selection == 1 and player.red > 1) then
				player.red = player.red - 2
				xTileCoor = ceil((mousePos.pos.x-2)/4)
				yTileCoor = ceil((mousePos.pos.y-2)/4)
				nearbyEntities = bget(entities,point(xTileCoor*4,yTileCoor*4))
				if(is_empty(nearbyEntities) != true)then
					add(entities, {pos=point(xTileCoor*4,yTileCoor*4)})
					add(baskets, {pos=point(xTileCoor*4+1,yTileCoor*4+1)})
					for e in all(nearbyEntities) do
						if (e != {pos=point(xTileCoor,yTileCoor)}) then
						add(roads, {a={pos=point(xTileCoor*4+1,yTileCoor*4+1)},b=e})
						end
					end
					for e in all(bget(flowerStore,point(xTileCoor*4,yTileCoor*4))) do
						if (e != {pos=point(xTileCoor,yTileCoor)}) then
						add(flowerLinks, {a={pos=point(xTileCoor*4+1,yTileCoor*4+1)},b=e})
						end
					end
				end
			elseif(player.selection == 2 and player.red > 2) then
				player.red = player.red - 3
				xTileCoor = ceil((mousePos.pos.x-2)/4)
				yTileCoor = ceil((mousePos.pos.y-2)/4)
				nearbyEntities = bget(entities,point(xTileCoor*4,yTileCoor*4))
				if(is_empty(nearbyEntities) != true)then
					add(entities, {pos=point(xTileCoor*4,yTileCoor*4)})
					add(turrets, {pos=point(xTileCoor*4,yTileCoor*4)})
					for e in all(nearbyEntities) do
						if (e != {pos=point(xTileCoor,yTileCoor)}) then
						add(roads, {a={pos=point(xTileCoor*4+1,yTileCoor*4+1)},b=e})
						end
					end
				end
			end
		end
		bstore(entities, testEntity)
		
		for i,entity in pairs(roads) do
			bstore(entities, entity.a)
			if(currentState[ceil(entity.a.pos.x/4)][ceil(entity.a.pos.y/4)] != 0)then
				deli(roads,i)
				bdel(entities, entity.a)
			else
				bstore(entities, entity.a)
			end
		end
		for i,entity in pairs(baskets) do
			bstore(entities, entity)
			if(currentState[ceil(entity.pos.x/4)][ceil(entity.pos.y/4)] != 0)then
				deli(baskets,i)
				bdel(entities, entity)
			else
				bstore(entities, entity)
			end
		end
		for i,entity in pairs(turrets) do
			bstore(entities, entity)
			if(currentState[ceil(entity.pos.x/4)][ceil(entity.pos.y/4)] != 0)then
				deli(turrets,i)
				bdel(entities, entity)
			else
				bstore(entities, entity)
			end
		end
		for i,entity in pairs(flowerResources) do
			bstore(entities, entity)
			if(currentState[ceil(entity.pos.x/4)][ceil(entity.pos.y/4)] != 0)then
				deli(flowerResources,i)
				bdel(entities, entity)
			else
				bstore(entities, entity)
			end
		end
	end
end

function _draw()
	cls()
	for x=0,31 do
		for y=0,31 do
			depth = currentState[x][y]
			if(depth!=0) then
				if(depth==7) then
					rectfill(x*4,y*4,x*4+4,y*4+4,0)
				elseif(depth==6) then
     				rectfill(x*4,y*4,x*4+4,y*4+4,3)
				elseif(depth==5) then
					rectfill(x*4,y*4,x*4+4,y*4+4,3)
				elseif(depth==4) then
					rectfill(x*4,y*4,x*4+4,y*4+4,3)
				elseif(depth==3) then
					rectfill(x*4,y*4,x*4+4,y*4+4,3)
				elseif(depth==2) then
					if(x%3==0 and y%7==0) then
						spr(10, x*4, y*4)
					else
						rectfill(x*4,y*4,x*4+4,y*4+4,3)
					end
				elseif(depth==1) then
					rectfill(x*4,y*4,x*4+4,y*4+4,3)
				end
			else
				rectfill(x*4,y*4,x*4+4,y*4+4,12)
			end
		end
	end
	for i in pairs(roads) do
		pline(roads[i].a.pos,roads[i].b.pos, 9)
	end
	for _,turret in pairs(turrets) do
		spr(6, turret.pos.x, turret.pos.y)
	end
	for i in pairs(flowerLinks) do
		pline(flowerLinks[i].a.pos,flowerLinks[i].b.pos, flowerLinks[i].b.color)
	end
	for i in pairs(baskets) do
		bstore(entities, baskets[i])
		spr(5, baskets[i].pos.x, baskets[i].pos.y)
	end
	for _,flower in pairs(flowerResources) do
		if(flower.col=="red")then
			spr(2, flower.pos.x, flower.pos.y)
		else
			spr(3, flower.pos.x, flower.pos.y)
		end
		
	end
	bstore(flowerStore, blue1)
	bstore(flowerStore, blue2)
	bstore(flowerStore, red1)
	bstore(flowerStore, red2)

	map(0, 0, 0, 0, 128, 32)

	for _,laser in pairs(lasers) do
		pline(laser.a.pos,laser.b.pos, 14)
	end

	rectfill(0,0,127,10,5)
	rectfill(0,0,24,10,8)
	
	spr(20,0,119)
	print(1, 9, 121, 11)
	spr(7,11,119)
	
	spr(5,24,119)
	print(2, 33, 121, 11)
	spr(7,35,119)
	
	spr(6,48,119)
	print(3, 59, 121, 11)
	spr(7,61,119)

	print("harvested:", 68, 3, 6)
	print(player.blue, 108, 3, 6)
	print("/6", 113, 3, 6)
	spr(8,120,1)

	spr(7,1,1)
	print(tostr(player.red), 9, 3, 11)
	
	for i in pairs(earnings) do
		spr(16+earnings[i].life%4,earnings[i].pos.x,earnings[i].pos.y)
	end
	for i in pairs(harvest) do
		spr(32+harvest[i].life%4,harvest[i].pos.x,harvest[i].pos.y)
	end

	if(pause == true and win == false and lose == false) then
		rectfill(15,34,113,86,2)
		print("harvest the", 22,40,1)
		print("watergrass", 70,40,7)
		print("before desertification", 22,48,1)
		print("takes over!", 22,56,1)
		rectfill(54,70,76,78,0)
		print("start", 56,72,2)
	end
	if(win == true)then
		print("you win", 56,64,1)
	elseif(lose == true)then
		print("you lose", 56,64,1)
	end

	xTileCoor = ceil((mousePos.pos.x-2)/4)
	yTileCoor = ceil((mousePos.pos.y-2)/4)
	if(player.selection == 0) then
		spr(20,stat(32)-1,stat(33)-1)
		circ( mousePos.pos.x+3, mousePos.pos.y+5, 10,2)
		show_neighbors(entities,{pos=point(xTileCoor*4,yTileCoor*4)})
	elseif(player.selection == 1) then
		spr(5,stat(32)-1,stat(33)-1)
		circ( mousePos.pos.x+3, mousePos.pos.y+5, 10,2)
		show_neighbors(entities,{pos=point(xTileCoor*4,yTileCoor*4)})
		show_neighbors(flowerStore,{pos=point(xTileCoor*4,yTileCoor*4)})
	elseif(player.selection == 2) then
		spr(6,stat(32)-1,stat(33)-1)
		show_neighbors(entities,{pos=point(xTileCoor*4,yTileCoor*4)})
	elseif(player.selection == 4) then
		spr(4,stat(32)-1,stat(33)-1)
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000223200003b33000000000000000000000000000000000000
0000000000111100000000000000000000110000000000000000000000000000000000000000000023230000bb3b000000000000000000000000000000000000
00111000011111100000000000000000017110000033300000ffff00000aa000000660000000000032220000b33b000000000000000000000000000000000000
00111000111111110a0000a000000000017711000300030000faafff0099ab00005567000008800022220000b333000000000000000000000000000000000000
00010000111111110e00a0ea00007000017771100300030000faafff0099ab000055670000088000000000000000000000000000000000000000000000000000
00111000323a2323ae00e0e00700e707017777100333330000ffff00000aa0000006600000000000000000000000000000000000000000000000000000000000
00010000323e2a230ea0eae07e70e07e001111100033300000000000000000000000000000000000000000000000000000000000000000000000000000000000
00101000323e2e230e00e0e00e07e00e000017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000050001111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000040001ffffff100000000000000000000000000000000000000000000000000000000000000000000000000000000
0000a000000aa000000aa000000aa000000040001ffffff100000000000000000000000000000000000000000000000000000000000000000000000000000000
0000a0000099ab0000aaaa0000bba900000f5f001ffffff100000000000000000000000000000000000000000000000000000000000000000000000000000000
0000a0000099ab0000aaaa0000bba900000f5f001ffffff100000000000000000000000000000000000000000000000000000000000000000000000000000000
0000a000000aa000000aa000000aa000000f5f001ffffff100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000fff001ffffff100000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000f0001111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006000000660000006600000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006000005567000066660000776500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006000005567000066660000776500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006000000660000006600000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
115000202b7242b7242972427724297242772424724247241f724227241d7241b7241872418724187241872400000000000000000000000000000000000000000000000000000000000000000000000000000000
415000082472424724227242272424724267242772426724000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000039650326502a65020650166500c6500265000650006500065000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
471400200c7500c7500a7500c750000000c7000c7000a7000c7500c7500a7500c750000000c7000c7000a7000c7500c7500a7500a750087500875007750077500575005750077500775005750057500075000750
00080000177501b7502075022750277502c7502f75000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 01034344
00 03004344
00 03014344
00 01004344
00 43404344

