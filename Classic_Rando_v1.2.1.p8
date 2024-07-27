pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- game code

-- celeste classic randomizer
-- v.1.2.1
-- cart mod by swordf

-- original celeste cart made by
-- maddy thorson and noel berry


-- "data structures"

function vector(x,y)
 return {x=x,y=y}
end

function rectangle(x,y,w,h)
 return {x=x,y=y,w=w,h=h}
end

-- [globals]
max_djump,deaths,frames,seconds,minutes,music_timer=1,0,0,0,0,0
title_screen=true
rando_screen,arrow,seed_arrow=0,0,0

level=1

objects,got_fruit,
freeze,shake,delay_restart,sfx_timer,music_timer,
screenshake=
{},{},
0,0,0,0,0,
true

-- [entry point]

function _init()
 title_screen()
end

function title_screen()
	title_screen=true
 frames,start_game_flash=0,0
 music(40,0,7)
 load_room(8,0)
end

function begin_game()
	graphic_ref[10]=rand_int(120)
	generate_map()
	
	title_screen=false
	rando_screen=0
	
	level=1
 music(0,0,7)
 load_room(0,0)
end

function level_index()
 return room.y*8+room.x+1
end

function is_title()
 return title_screen
end

-- [effects]

clouds={}
for i=0,16 do
 add(clouds,{
  x=rnd"128",
  y=rnd"128",
  spd=1+rnd"4",
  w=32+rnd"32"
 })
end

particles={}
for i=0,24 do
 add(particles,{
  x=rnd"128",
  y=rnd"128",
  s=flr(rnd"1.25"),
  spd=0.25+rnd"5",
  off=rnd(),
  c=6+rnd"2",
 })
end

dead_particles={}

-- [player entity]

player={
 init=function(this)
  this.grace,this.jbuffer=0,0
  this.djump=max_djump
  this.dash_time,this.dash_effect_time=0,0
  this.dash_target_x,this.dash_target_y=0,0
  this.dash_accel_x,this.dash_accel_y=0,0
  this.hitbox=rectangle(1,3,6,5)
  this.spr_off=0
  this.solids=true
  create_hair(this)
 end,
 update=function(this)
  if pause_player then
   return
  end

  -- horizontal input
  local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0

  -- spike collision / bottom death
  if spikes_at(this.left(),this.top(),this.right(),this.bottom(),this.spd.x,this.spd.y) or
   this.y>128 then
   kill_player(this)
  end

  -- on ground checks
  local on_ground=this.is_solid(0,1)

  -- landing smoke
  if on_ground and not this.was_on_ground then
   this.init_smoke(0,4)
  end

  -- jump and dash input
  local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
  this.p_jump,this.p_dash=btn(🅾️),btn(❎)

  -- jump buffer
  if jump then
   this.jbuffer=4
  elseif this.jbuffer>0 then
   this.jbuffer-=1
  end

  -- grace frames and dash restoration
  if on_ground then
   this.grace=6
   if this.djump<max_djump then
    psfx"54"
    this.djump=max_djump
   end
  elseif this.grace>0 then
   this.grace-=1
  end

  -- dash effect timer (for dash-triggered events, e.g., berry blocks)
  this.dash_effect_time-=1

  -- dash startup period, accel toward dash target speed
  if this.dash_time>0 then
   this.init_smoke()
   this.dash_time-=1
   this.spd=vector(
    appr(this.spd.x,this.dash_target_x,this.dash_accel_x),
    appr(this.spd.y,this.dash_target_y,this.dash_accel_y)
   )
  else
   -- x movement
   local maxrun=1
   local accel=this.is_ice(0,1) and 0.05 or on_ground and 0.6 or 0.4
   local deccel=0.15

   -- set x speed
   this.spd.x=abs(this.spd.x)<=maxrun and
    appr(this.spd.x,h_input*maxrun,accel) or
    appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)

   -- facing direction
   if this.spd.x~=0 then
    this.flip.x=this.spd.x<0
   end

   -- y movement
   local maxfall=2

   -- wall slide
   if h_input~=0 and this.is_solid(h_input,0) and not this.is_ice(h_input,0) then
    maxfall=0.4
    -- wall slide smoke
    if rnd()<0.2 then
     this.init_smoke(h_input*6)
    end
   end

   -- apply gravity
   if not on_ground then
    this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and 0.21 or 0.105)
   end

   -- jump
   if this.jbuffer>0 then
    if this.grace>0 then
     -- normal jump
     psfx"1"
     this.jbuffer=0
     this.grace=0
     this.spd.y=-2
     this.init_smoke(0,4)
    else
     -- wall jump
     local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
     if wall_dir~=0 then
      psfx"2"
      this.jbuffer=0
      this.spd=vector(wall_dir*(-1-maxrun),-2)
      if not this.is_ice(wall_dir*3,0) then
       -- wall jump smoke
       this.init_smoke(wall_dir*6)
      end
     end
    end
   end

   -- dash
   local d_full=5
   local d_half=3.5355339059 -- 5 * sqrt(2)

   if this.djump>0 and dash then
    this.init_smoke()
    this.djump-=1
    this.dash_time=4
    has_dashed=true
    this.dash_effect_time=10
    -- vertical input
    local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
    -- calculate dash speeds
    this.spd=vector(
     h_input~=0 and h_input*(v_input~=0 and d_half or d_full) or (v_input~=0 and 0 or this.flip.x and -1 or 1),
     v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0
    )
    -- effects
    psfx"3"
    freeze=2
    shake=6
    -- dash target speeds and accels
    this.dash_target_x=2*sign(this.spd.x)
    this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
    this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
    this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
   elseif this.djump<=0 and dash then
    -- failed dash smoke
    psfx"9"
    this.init_smoke()
   end
  end

  -- animation
  local base=graphic_ref[graphic]
  
  this.spr_off+=0.25
  this.spr = not on_ground and (this.is_solid(h_input,0) and base+4 or base+2) or  -- wall slide or mid air
   btn(⬇️) and base+5 or -- crouch
   btn(⬆️) and base+6 or -- look up
   this.spd.x~=0 and h_input~=0 and base+this.spr_off%4 or base -- walk or stand

  -- exit level off the top (except summit)
  if this.y<-4 and level_index()<31 then
   next_room()
  end

  -- was on the ground
  this.was_on_ground=on_ground
 end,

 draw=function(this)
  -- clamp in screen
  local clamped=mid(this.x,-1,121)
  if this.x~=clamped then
   this.x=clamped
   this.spd.x=0
  end
  -- draw player hair and sprite
  set_hair_color(this.djump)
  draw_hair(this)
  draw_obj_sprite(this)
  unset_hair_color()
 end
}

function create_hair(obj)
 obj.hair={}
 for i=1,hair_ref[graphic].nodes do
  add(obj.hair,vector(obj.x,obj.y))
 end
end

function set_hair_color(djump)
	local base=hair_ref[graphic].color
	local zero=base[1]
	local one=base[2]
	local two=base[3]
	local flash=base[4]
 pal(one, ({one,frames%6<3 and flash or two})[djump] or zero)
end

function draw_hair(obj)
	local tail=graphic==7 and 2 or 0
 local last=vector(obj.x+(obj.flip.x and 6 or 2),obj.y+(btn(⬇️) and 4 or 3))
 for i,h in ipairs(obj.hair) do
  h.x+=(last.x-h.x)/1.5
  h.y+=(last.y+0.5-h.y)/1.5
  circfill(h.x,h.y+tail,mid(4-i,1,2),hair_ref[graphic].color[2])
  last=h
 end
end

function unset_hair_color()
 pal(8,8) -- use pal(8,8) to preserve other palette swaps
end

-- [other entities]



player_spawn={
 init=function(this)
  sfx"4"
  this.spr=graphic_ref[graphic]+2
  this.target=this.y
  this.y=128
  this.spd.y=-4
  this.state=0
  this.delay=0
  this.djump=max_djump
  create_hair(this)
 end,
 update=function(this)
 	local base=graphic_ref[graphic]
 	
  -- jumping up
  if this.state==0 and this.y<this.target+16 then
   this.state=1
   this.delay=3
  -- falling
  elseif this.state==1 then
   this.spd.y+=0.5
   if this.spd.y>0 then
    if this.delay>0 then
     -- stall at peak
     this.spd.y=0
     this.delay-=1
    elseif this.y>this.target then
     -- clamp at target y
     this.y=this.target
     this.spd=vector(0,0)
     this.state=2
     this.delay=5
     shake=5
     this.init_smoke(0,4)
     sfx"5"
    end
   end
  -- landing and spawning player object
  elseif this.state==2 then
   this.delay-=1
   this.spr=base+5
   if this.delay<0 then
    destroy_object(this)
    init_object(player,this.x,this.y)
   end
  end
 end,
 draw=player.draw
}

spring={
 init=function(this)
  this.hide_in=0
  this.hide_for=0
 end,
 update=function(this)
  if this.hide_for>0 then
   this.hide_for-=1
   if this.hide_for<=0 then
    this.spr=18
    this.delay=0
   end
  elseif this.spr==18 then
   local hit=this.player_here()
   if hit and hit.spd.y>=0 then
    this.spr=19
    hit.y=this.y-4
    hit.spd.x*=0.2
    hit.spd.y=-3
    hit.djump=max_djump
    this.delay=10
    this.init_smoke()
    -- crumble below spring
    break_fall_floor(this.check(fall_floor,0,1) or {})
    psfx"8"
   end
  elseif this.delay>0 then
   this.delay-=1
   if this.delay<=0 then
    this.spr=18
   end
  end
  -- begin hiding
  if this.hide_in>0 then
   this.hide_in-=1
   if this.hide_in<=0 then
    this.hide_for=60
    this.spr=0
   end
  end
 end
}

balloon={
 init=function(this)
  this.offset=rnd()
  this.start=this.y
  this.timer=0
  this.hitbox=rectangle(-1,-1,10,10)
 end,
 update=function(this)
  if this.spr==22 then
   this.offset+=0.01
   this.y=this.start+sin(this.offset)*2
   local hit=this.player_here()
   if hit and hit.djump<max_djump then
    psfx"6"
    this.init_smoke()
    hit.djump=max_djump
    this.spr=0
    this.timer=60
   end
  elseif this.timer>0 then
   this.timer-=1
  else
   psfx"7"
   this.init_smoke()
   this.spr=22
  end
 end,
 draw=function(this)
  if this.spr==22 then
   spr(13+(this.offset*8)%3,this.x,this.y+6)
   draw_obj_sprite(this)
   --spr(this.spr,this.x,this.y)
  end
 end
}

fall_floor={
 init=function(this)
  this.state=0
  --this.delay=0
 end,
 update=function(this)
  -- idling
  if this.state==0 then
   for i=0,2 do
    if this.check(player,i-1,-(i%2)) then
     break_fall_floor(this)
    end
   end
  -- shaking
  elseif this.state==1 then
   this.delay-=1
   if this.delay<=0 then
    this.state=2
    this.delay=60--how long it hides for
    this.collideable=false
   end
  -- invisible, waiting to reset
  elseif this.state==2 then
   this.delay-=1
   if this.delay<=0 and not this.player_here() then
    psfx"7"
    this.state=0
    this.collideable=true
    this.init_smoke()
   end
  end
 end,
 draw=function(this)
  spr(this.state==1 and 26-this.delay/5 or this.state==0 and 23,this.x,this.y)
 end
}

function break_fall_floor(obj)
 if obj.state==0 then
  psfx"15"
  obj.state=1
  obj.delay=15--how long until it falls
  obj.init_smoke();
  (obj.check(spring,0,-1) or {}).hide_in=15
 end
end

smoke={
 init=function(this)
  this.spd=vector(0.3+rnd"0.2",-0.1)
  this.x+=-1+rnd"2"
  this.y+=-1+rnd"2"
  this.flip=vector(rnd()<0.5,rnd()<0.5)
 end,
 update=function(this)
  this.spr+=0.2
  if this.spr>=32 then
   destroy_object(this)
  end
 end
}

fruit={
 if_not_fruit=true,
 init=function(this)
  this.start=this.y
  this.off=0
 end,
 update=function(this)
  check_fruit(this)
  this.off+=0.025
  this.y=this.start+sin(this.off)*2.5
 end
}

fly_fruit={
 if_not_fruit=true,
 init=function(this)
  this.start=this.y
  this.off=0.5
  this.sfx_delay=8
 end,
 update=function(this)
  --fly away
  if has_dashed then
   if this.sfx_delay>0 then
   this.sfx_delay-=1
   if this.sfx_delay<=0 then
    sfx_timer=20
    sfx"14"
   end
   end
   this.spd.y=appr(this.spd.y,-3.5,0.25)
   if this.y<-16 then
    destroy_object(this)
   end
  -- wait
  else
   this.off+=0.05
   this.spd.y=sin(this.off)*0.5
  end
  -- collect
  check_fruit(this)
 end,
 draw=function(this)
  draw_obj_sprite(this)
  --spr(this.spr,this.x,this.y)
  for ox=-6,6,12 do
   spr((has_dashed or sin(this.off)>=0) and 45 or this.y>this.start and 47 or 46,this.x+ox,this.y-2,1,1,ox==-6)
  end
 end
}

function check_fruit(this)
 local hit=this.player_here()
 if hit then
  hit.djump=max_djump
  sfx_timer=20
  sfx"13"
  got_fruit[level]=true
  init_object(lifeup,this.x,this.y)
  destroy_object(this)
 end
end

lifeup={
 init=function(this)
  this.spd.y=-0.25
  this.duration=30
  this.flash=0
 end,
 update=function(this)
  this.duration-=1
  if this.duration<=0 then
   destroy_object(this)
  end
 end,
 draw=function(this)
  this.flash+=0.5
  ?"1000",this.x-4,this.y-4,7+this.flash%2
 end
}

fake_wall={
 if_not_fruit=true,
 update=function(this)
  this.hitbox=rectangle(-1,-1,18,18)
  local hit=this.player_here()
  if hit and hit.dash_effect_time>0 then
   hit.spd=vector(sign(hit.spd.x)*-1.5,-1.5)
   hit.dash_time=-1
   for ox=0,8,8 do
    for oy=0,8,8 do
     this.init_smoke(ox,oy)
    end
   end
   init_fruit(this,4,4)
  end
  this.hitbox=rectangle(0,0,16,16)
 end,
 draw=function(this)
  spr(64,this.x,this.y,2,2)
 end
}

function init_fruit(this,ox,oy)
 sfx_timer=20
 sfx"16"
 init_object(fruit,this.x+ox,this.y+oy,26)
 destroy_object(this)
end

key={
 if_not_fruit=true,
 update=function(this)
  this.spr=9.5+sin(frames/30)
  if frames==18 then
   this.flip.x=not this.flip.x
  end
  if this.player_here() then
   sfx"23"
   sfx_timer=10
   destroy_object(this)
   has_key=true
  end
 end
}

chest={
 if_not_fruit=true,
 init=function(this)
  this.x-=4
  this.start=this.x
  this.timer=20
 end,
 update=function(this)
  if has_key then
   this.timer-=1
   this.x=this.start-1+rnd"3"
   if this.timer<=0 then
    init_fruit(this,0,-4)
   end
  end
 end
}

platform={
 init=function(this)
  this.x-=4
  this.hitbox.w=16
  this.last=this.x
  this.dir=this.spr==11 and -1 or 1
 end,
 update=function(this)
  this.spd.x=this.dir*0.65
  if this.x<-16 then this.x=128
  elseif this.x>128 then this.x=-16 end
  if not this.player_here() then
   local hit=this.check(player,0,-1)
   if hit then
    --hit.move_x(this.x-this.last,1)
    --hit.move_loop(this.x-this.last,1,"x")
    hit.move(this.x-this.last,0,1)
   end
  end
  this.last=this.x
 end,
 draw=function(this)
   spr(11,this.x,this.y-1,2,1)
 end
}

message={
 draw=function(this)
  this.text="-- celeste mountain --#this memorial to those# perished on the climb"
  if this.check(player,4,0) then
   if this.index<#this.text then
    this.index+=0.5
    if this.index>=this.last+1 then
     this.last+=1
     sfx"35"
    end
   end
   local _x,_y=8,96
   for i=1,this.index do
    if sub(this.text,i,i)~="#" then
     rectfill(_x-2,_y-2,_x+7,_y+6 ,7)
     ?sub(this.text,i,i),_x,_y,0
     _x+=5
    else
     _x=8
     _y+=7
    end
   end
  else
   this.index=0
   this.last=0
  end
 end
}

big_chest={
 init=function(this)
  this.state=0
  this.hitbox.w=16
 end,
 draw=function(this)
  if this.state==0 then
   local hit=this.check(player,0,8)
   if hit and hit.is_solid(0,1) then
    music(-1,500,7)
    sfx"37"
    pause_player=true
    hit.spd=vector(0,0)
    this.state=1
    this.init_smoke()
    this.init_smoke(8)
    this.timer=60
    this.particles={}
   end
   sspr(0,48,16,8,this.x,this.y)
  elseif this.state==1 then
   this.timer-=1
   shake=5
   flash_bg=true
   if this.timer<=45 and #this.particles<50 then
    add(this.particles,{
     x=1+rnd"14",
     y=0,
     h=32+rnd"32",
     spd=8+rnd"8"
    })
   end
   if this.timer<0 then
    this.state=2
    this.particles={}
    flash_bg=false
    new_bg=true
    init_object(orb,this.x+4,this.y+4)
    pause_player=false
   end
   foreach(this.particles,function(p)
    p.y+=p.spd
    line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
   end)
  end
  sspr(0,56,16,8,this.x,this.y+8)
 end
}

orb={
 init=function(this)
  this.spd.y=-4
 end,
 draw=function(this)
  this.spd.y=appr(this.spd.y,0,0.5)
  local hit=this.player_here()
  if this.spd.y==0 and hit then
   music_timer=45
   sfx"51"
   freeze=10
   shake=10
   destroy_object(this)
   max_djump=2
   hit.djump=2
  end
  spr(102,this.x,this.y)
  for i=0,0.875,0.125 do
   circfill(this.x+4+cos(frames/30+i)*8,this.y+4+sin(frames/30+i)*8,1,7)
  end
 end
}

flag={
 init=function(this)
  --this.show=false
  this.x+=5
  this.score=0
  for _ in pairs(got_fruit) do
   this.score+=1
  end
 end,
 draw=function(this)
  this.spr=118+frames/5%3
  draw_obj_sprite(this)
  --spr(this.spr,this.x,this.y)
  if this.show then
   rectfill(32,2,96,39,0)
   spr(26,55,6)
   ?"x"..this.score,64,9,7
   draw_time(49,16)
   ?"deaths:"..deaths,48,24,7
   ?"seed:"..seed,47,31
  elseif this.player_here() then
   sfx"55"
   sfx_timer=30
   this.show=true
  end
 end
}

room_title={
 init=function(this)
  this.delay=5
 end,
 draw=function(this)
  this.delay-=1
  if this.delay<-30 then
   destroy_object(this)
  elseif this.delay<0 then
   rectfill(24,58,104,70,0)
   if level==12 then
    ?"old site",48,62,7
   elseif level==31 then
    ?"summit",52,62,7
   else
    ?level.."00 m",level<10 and 54 or 52,62,7
   end
   draw_time(4,4)
  end
 end
}

function psfx(num)
 if sfx_timer<=0 then
  sfx(num)
 end
end

-- [tile dict]
tiles={}
foreach(split([[
1,player_spawn
8,key
11,platform
12,platform
18,spring
20,chest
22,balloon
23,fall_floor
26,fruit
28,fly_fruit
64,fake_wall
86,message
96,big_chest
118,flag
]],"\n"),function(t)
 local tile,obj=unpack(split(t))
 tiles[tile]=_ENV[obj]
end)

-- [object functions]

function init_object(type,x,y,tile)
 if type.if_not_fruit and got_fruit[level] then
  return
 end

 local obj={
  type=type,
  collideable=true,
  --solids=false,
  spr=tile,
  flip=vector(),
  x=x,
  y=y,
  hitbox=rectangle(0,0,8,8),
  spd=vector(0,0),
  rem=vector(0,0),
 }

 function obj.left() return obj.x+obj.hitbox.x end
 function obj.right() return obj.left()+obj.hitbox.w-1 end
 function obj.top() return obj.y+obj.hitbox.y end
 function obj.bottom() return obj.top()+obj.hitbox.h-1 end

 function obj.init_smoke(ox,oy)
  init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),29)
 end

 function obj.is_solid(ox,oy)
  return (oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy)) or
      obj.is_flag(ox,oy,0) or
      obj.check(fall_floor,ox,oy) or
      obj.check(fake_wall,ox,oy)
 end

 function obj.is_ice(ox,oy)
  return obj.is_flag(ox,oy,4)
 end

 function obj.is_flag(ox,oy,flag)
  for i=max(0,(obj.left()+ox)\8),min(15,(obj.right()+ox)/8) do
   for j=max(0,(obj.top()+oy)\8),min(15,(obj.bottom()+oy)/8) do
    if fget(tile_at(i,j),flag) then
     return true
    end
   end
  end
  --return tile_flag_at(obj.left()+ox,obj.top()+oy,obj.right()+ox,obj.bottom()+oy,flag)
 end

 function obj.check(type,ox,oy)
  for other in all(objects) do
   if other and other.type==type and other~=obj and other.collideable and
    other.right()>=obj.left()+ox and
    other.bottom()>=obj.top()+oy and
    other.left()<=obj.right()+ox and
    other.top()<=obj.bottom()+oy then
    return other
   end
  end
 end

 function obj.player_here()
  return obj.check(player,0,0)
 end

 function obj.move(ox,oy,start)
  for axis in all{"x","y"} do
   obj.rem[axis]+=vector(ox,oy)[axis]
   local amt=flr(obj.rem[axis]+0.5)
   obj.rem[axis]-=amt
   if obj.solids then
    local step=sign(amt)
    local d=axis=="x" and step or 0
    for i=start,abs(amt) do
     if not obj.is_solid(d,step-d) then
      obj[axis]+=step
     else
      obj.spd[axis],obj.rem[axis]=0,0
      break
     end
    end
   else
    obj[axis]+=amt
   end
  end
 end

 add(objects,obj);
 (obj.type.init or max)(obj)

 return obj
end

function destroy_object(obj)
 del(objects,obj)
end

function kill_player(obj)
 sfx_timer=12
 sfx"0"
 deaths+=1
 shake=10
 destroy_object(obj)
 dead_particles={}
 for dir=0,0.875,0.125 do
  add(dead_particles,{
   x=obj.x+4,
   y=obj.y+4,
   t=2,--10,
   dx=sin(dir)*3,
   dy=cos(dir)*3
  })
 end
 --restart_room()
 delay_restart=15
end

-- [room functions]

--function restart_room()
--  delay_restart=15
--end

function next_room()
	local l=level
	level+=1
	if (level==17) load_map(bottom_map)
	
 if l==11 or l==21 or l==30 then -- quiet for old site, 2200m, summit
  music(30,500,7)
 elseif l==12 then -- 1300m
  music(20,500,7)
 end
 
 
 if (l>15) l-=16
 load_room(l%8,l\8)
 
end

function load_room(x,y)
 has_dashed,has_key=false,--false
 --remove existing objects
 foreach(objects,destroy_object)
 --current room
 room=vector(x,y)
 -- entities
 for tx=0,15 do
  for ty=0,15 do
   local tile=tile_at(tx,ty)
   if tiles[tile] then
    init_object(tiles[tile],tx*8,ty*8,tile)
   end
  end
 end
 -- room title
 if not is_title() then
  init_object(room_title,0,0)
 end
end

-- [main update loop]

function _update()
	if (rando_screen>0) rando_screen=(rando_screen+25.5)/1.2
	
 frames+=1
 if level<31 and not title_screen then
  seconds+=frames\30
  minutes+=seconds\60
  seconds%=60
 end
 frames%=30

 if music_timer>0 then
  music_timer-=1
  if music_timer<=0 then
   music(10,0,7)
  end
 end

 if sfx_timer>0 then
  sfx_timer-=1
 end

 -- cancel if freeze
 if freeze>0 then
  freeze-=1
  return
 end

 -- screenshake
 if btnp(⬆️,1) then
  screenshake=not screenshake
 end
 if shake>0 then
  shake-=1
  camera()
  if screenshake and shake~=0 then
   camera(-2+rnd"5",-2+rnd"5")
  end
 end

 -- restart (soon)
 if delay_restart>0 then
  delay_restart-=1
  if delay_restart==0 then
   load_room(room.x,room.y)
  end
 end

 -- update each object
 foreach(objects,function(obj)
  obj.move(obj.spd.x,obj.spd.y,0);
  (obj.type.update or max)(obj)
 end)

 -- start game
 if is_title() then
  if start_game then
   start_game_flash-=1
   if (start_game_flash<=-30) begin_game()
  elseif (btn(🅾️) or btn(❎)) and rando_screen<1 then
   rando_screen=1
  end
 end
end

-- [drawing functions]

function _draw()
 if freeze>0 then
  return
 end

 -- reset all palette values
 camera(0,rando_screen)
 pal()
 if (graphic==6) updatepal(13,pal_axew)
	
 -- start game flash
 if is_title() and start_game then
  for i=1,15 do
   pal(i, start_game_flash<=10 and ceil(max(start_game_flash)/5) or frames%10<5 and 7 or i)
  end
 end

 -- draw bg color (pad for screenshake)
 cls()
 rectfill(0,0,127,127,flash_bg and frames/5 or new_bg and 2 or 0)

 -- bg clouds effect
 if not is_title() then
  foreach(clouds,function(c)
   c.x+=c.spd
   crectfill(c.x,c.y,c.x+c.w,c.y+16-c.w*0.1875,new_bg and 14 or 1)
   if c.x>128 then
    c.x=-c.w
    c.y=rnd"120"
   end
  end)
 end

 local rx,ry=room.x*16,room.y*16

 -- draw bg terrain
 map(rx,ry,0,0,16,16,4)

 -- draw clouds + orb chest
 foreach(objects,function(o)
  if o.type==platform then
   draw_object(o)
  end
 end)

 -- draw terrain (offset if title screen)
 map(rx,ry,is_title() and -4 or 0,0,16,16,2)

 -- draw objects
 foreach(objects,function(o)
  if o.type~=platform then
   draw_object(o)
  end
 end)

 -- draw fg terrain (not a thing)
 --map(room.x*16,room.y*16,0,0,16,16,8)

 -- particles
 foreach(particles,function(p)
  p.x+=p.spd
  p.y+=sin(p.off)
  p.off+=min(0.05,p.spd/32)
  crectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
  if p.x>132 then
   p.x=-4
   p.y=rnd"128"
  end
 end)

 -- dead particles
 foreach(dead_particles,function(p)
  p.x+=p.dx
  p.y+=p.dy
  p.t-=0.2--1
  if p.t<=0 then
   del(dead_particles,p)
  end
  crectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+p.t*5%2)
 end)

 -- credits
 if is_title() then
 	spr(73,36,40,7,2)
 	spr(105,60,32)
 	spr(106,36,56)
 	spr(107,76,56,2,1)
 	?"randomizer",44,52,12
  ?"z+x",58,80,5
  ?"v1.2.1",52,58,5
  ?"mod by swordf",39,110,5
 end

 -- summit blinds effect
 if level==31 and objects[2].type==player then
  local diff=min(24,40-abs(objects[2].x-60))
  rectfill(0,0,diff,127,0)
  rectfill(127-diff,0,127,127,0)
 end
 
 
 -- randomizer screen
 if rando_screen>0 and arrow!=0 then
 	local pos=split("144,160,169,178,187,214,234")
 	
 	-- arrow
 	if not start_game then
	 	if btnp(⬆️) then arrow-=1 sfx"2" end
	 	if btnp(⬇️) then arrow+=1 sfx"2" end
	 	arrow= (arrow-1)%7+1
	 	
	 	-- change options
	 	if btnp(🅾️) or btnp(❎) then
	 		local value=btnp(🅾️) and 1 or -1
	 		if (arrow!=7) sfx"7"
	 		if arrow==1 then
	 			digits[seed_arrow]+=value
	 			if (digits[seed_arrow]>9) digits[seed_arrow]=0
	 			if (digits[seed_arrow]<0) digits[seed_arrow]=9
	 		end
	 		if (arrow==2) player_spawn=change_settings(player_spawn,value)
	 		if (arrow==3) strawberry=change_settings(strawberry,value)
	 		if (arrow==4) terrain=change_settings(terrain,value)
	 		if (arrow==5) background=change_settings(background,value)	 		
	 		if arrow==6 then
	 			graphic+=value
	 			if (graphic>#graphic_names) graphic=1
	 			if (graphic<1) graphic=#graphic_names
	 		end
	 		
	 		if arrow==7 then
	 		 -- start game
	 			for i=4,1,-1 do
	 				seed+=digits[i]*exponent(10,4-i)
	 			end
	 			
	 			music"-1"
	    start_game_flash,start_game=50,true
	    sfx"38"
	 		end
	 	end
 	end
 	
 	swag_text("randomizer settings",25,132,12,1)
 	
 	-- seed
 	swag_text("seed -",11,145)
 	spr(123,34+seed_arrow*4,145)
 	for i=1,4 do
 		swag_text(digits[i],35+i*4,145)
 	end
 	if arrow==1 then
 		if (seed_arrow==0) seed_arrow=1
 		if (btnp(⬅️)) seed_arrow-=1
 		if (btnp(➡️)) seed_arrow+=1
 		seed_arrow=(seed_arrow-1)%4+1
 	else seed_arrow=997 end
 	
 	-- other text
 	swag_text("player spawn - "..player_spawn,11,160)
 	swag_text("berry spawn - "..strawberry,11,169)
 	swag_text("terrain - "..terrain,11,178)
		swag_text("background - "..background,11,187)
		
		swag_text("player graphic - "..graphic_names[graphic],11,215)
		rect(10,222,19,231,12)
		spr(graphic_ref[graphic],11,223)
		
		swag_text("climb!",11,235,11)
		spr(121,1,pos[arrow])
		
		-- tell text
		if arrow==1 then
			?"the seed to generate the map.",1,249,1
		elseif arrow<7 then
			options_on[6]=graphic
			?tells[arrow][options_on[arrow]],1,249,1
		end
		
 end
 
 if (rando_screen>0 and arrow==0) arrow=1
 
end

function draw_object(obj)
 (obj.type.draw or draw_obj_sprite)(obj)
end

function draw_obj_sprite(obj)
 spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end

function draw_time(x,y)
 rectfill(x,y,x+32,y+6,0)
 ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,7
end

function two_digit_str(x)
 return x<10 and "0"..x or x
end

function crectfill(x1,y1,x2,y2,c)
 if x1<128 and x2>0 and y1<128 and y2>0 then
  rectfill(max(0,x1),max(0,y1)+rando_screen,min(127,x2),min(127,y2)+rando_screen,c)
 end
end

-- [helper functions]

function appr(val,target,amount)
 return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
 return v~=0 and sgn(v) or 0
end

function tile_at(x,y)
 return mget(room.x*16+x,room.y*16+y)
end

function spikes_at(x1,y1,x2,y2,xspd,yspd)
 for i=max(0,x1\8),min(15,x2/8) do
  for j=max(0,y1\8),min(15,y2/8) do
   if ({[17]=yspd>=0 and y2%8>=6,
    [27]=yspd<=0 and y1%8<=2,
    [43]=xspd<=0 and x1%8<=2,
    [59]=xspd>=0 and x2%8>=6})[tile_at(i,j)] then
    return true
   end
  end
 end
end

function rand_int(x)
	return flr(rnd(x))
end

function table_has(tab,val)
	for i=1,#tab do
		if (tab[i]==val) return tab[i]
	end
	return false
end

function index_of(tab,val)
	local c=1
	for i in all(tab) do
		if (i==val) return c
		c+=1
	end
	return false
end

function add_tables(tab1,tab2)
	for e in all(tab2) do
		add(tab1,e)
	end
end

function level_has_player(x,y)
	for _y=0,15 do
		for _x=0,15 do
			local x_cord=_x+x*16
			local y_cord=_y+y*16
			if (mget(x_cord,y_cord)==1) return true
		end
	end
	return false
end

function swag_text(txt,x,y,c1,c2)
	local a=c1 or 7
	local b=c2 or 1
	
	for i=0,1,0.125 do
		?txt,x+sin(i),y+cos(i),b
	end
	?txt,x,y,a
end

function bool(b)
	if (b) return "yes"
	return "no"
end

function change_settings(set,v)
	local t=choices[option_choice[arrow]]
	local new=index_of(t,set)+v
	if (new>#t) new=1
	if (new<1) new=#t
	
	options_on[arrow]=new
	return t[new]
end

function exponent(base,pow)
	local x=1
	for i=1,pow do
		x*=base
	end
	return x
end

function hair_setting(n,z,o,t,f)
	return {nodes=n,color={z,o,t,f}}
end
-->8
-- randomizer
seed=0
digits={}
for i=1,4 do add(digits,rand_int(9)) end

-- tiles
local berry_tiles={26,28,8,20,64}
local terrain_tiles=split([[
		32,33,34,35,36,37,38,39,
		48,49,50,51,52,53,54,55,72,
		
		66,67,68,69,
		82,83,84,85,
		98,99,100,101,
		114,115,116,117
]])
local bg_tiles=split([[
		16,40,41,42,56,57,58,88,103,104,44,60,61,62,63
]])
local obj_tiles=split([[
		11,12,17,27,43,59,18,22,23,
]])

choices={
	{"default","random","multiple"},
	{"default","multiple"},
	{"default","random"},
	{true,false},
	{"default","procedural","random","none"},
}
options_on=split("nil,1,1,1,1,1,nil")
option_choice={
	nil,
	1,2,
	5,3
}

tells={
	nil,
	split("spawn position is vanilla.,spawn position is random.,puts player spawn in tilepool."),
	split("berry spots are vanilla.,berries are in tilepool."),
	split("terrain is vanilla.,terrain proceduraly generated.,puts terrain tiles in tilepool.,you get nothing! you lose!"),
	split("background is vanilla.,puts bg tiles into tilepool"),
	
	split("vanilla sprite.,from celeste 2.,from celeste.,i think we know who this is.,did you know this is from gen1?,from pokemon.,...,you're grounded son.,have fun :],anything goes!"),
	nil
}

-- settings
empty_tile_chance=0.7 -- between 0 and 1
player_spawn="default" -- default, random, or multiple
strawberry="default" -- default, or multiple

terrain="default" -- default, or random
background="default" -- default, or random

-- graphics
graphic=1
graphic_names={
	"madeline",
	"lani",
	"theo",
	"plumber",
	"vaporeon",
	"axew",
	"puro",
	"tile",
	"invisible",
	"random"
}
graphic_ref={1,128,135,167,144,151,160,32,256,124}
hair_ref={
	-- madeline
	hair_setting(5,12,8,11,7),
	
	-- lani
	hair_setting(0,12,1,11,7),
	
	-- theo
	hair_setting(0,12,2,11,7),
	
	-- plumber
	hair_setting(0,12,8,3,11),
	
	-- vaporeon
	hair_setting(0,9,12,14,14),
	
	-- axew
	hair_setting(0,12,13,15,15),
	
	-- puro
	hair_setting(0,12,1,6,7),
	
	-- tile
	hair_setting(0,2,12,3,11),
	
	-- invis
	hair_setting(0,0,0,0,0),
	
	-- random
	hair_setting(5,12,8,11,7),
}

-- define tile pool
function generate_tile_pool()
	local pool=split([[
	
		11,12,
		17,27,43,59,
		18,22,23,
	
	]])
	
	-- empty pool if progen
	if (terrain=="procedural") pool={}
	
	-- add terrain to tile pool
	if terrain=="random" then
		add_tables(pool,terrain_tiles)
	end
	
	-- add bg tiles to tile pool
	if background=="random" then
		add_tables(pool,bg_tiles)
	end
	
	-- add others to tile pool
	if (player_spawn=="multiple") add(pool,1)
	if strawberry=="multiple" then
		add_tables(pool,berry_tiles)
	end
	
	return pool
end

function generate_room(x,y)
	if (terrain=="random") empty_tile_chance=0.85-level*0.01
	
	-- generate map
	for _y=0,15 do
		if _y>0 or terrain=="random" or terrain=="none" then
		for _x=0,15 do
			-- grab cords
			local x_cord=_x+x*16
			local y_cord=_y+y*16
			local _t=mget(x_cord,y_cord)
			
			local can_write=true
			
			-- ways to not write
			if (_t==1 and player_spawn=="default") can_write=false
			if (table_has(berry_tiles,_t)) can_write=false
			if (table_has(terrain_tiles,_t) and (terrain=="default" or terrain=="procedural")) can_write=false
			if (table_has(bg_tiles,_t) and background=="default") can_write=false
			if (table_has(obj_tiles,_t)) can_write=false
			if (_t==64 and strawberry=="default") can_write=false
			
			-- can we write tile?
			if can_write then
				-- erase og contents
				mset(x_cord,y_cord,0)
				
				-- place random tile
				local choice = 1+rand_int(#tile_pool)
				local tile = tile_pool[choice]
				
			 if (rnd"1">empty_tile_chance) mset(x_cord,y_cord,tile)
			end
			
		end end
	end
	
	-- random player spawn
	if player_spawn=="random" or not level_has_player(x,y) then
		while true do
			local x_cord= rand_int(15)+x*16
			local y_cord= 1+rand_int(14)+y*16
			
			if not table_has(terrain_tiles,mget(x_cord,y_cord)) then
				mset(x_cord,y_cord,1)
				local bottom=mget(x_cord,y_cord+1)
				break
			end
		end
	end
	
	-- place safety platforms
	for _y=0,15 do
		for _x=0,15 do
			local x_cord=_x+x*16
			local y_cord=_y+y*16
			local bottom=mget(x_cord,y_cord+1)
			
			if mget(x_cord,y_cord)==1 and not(table_has(terrain_tiles,bottom) or bottom==23) then
				mset(x_cord,y_cord+1,32)
			end
		end
	end
	
end



-- generate map
function generate_map()
	srand(seed)
	if (level>16) srand(rand_int(9999))
	
	local index=function(x,y)
	 return y*8+x+1
	end
	
	tile_pool=generate_tile_pool()
	local keep_rooms={12,22,31,32}
	
	local n=1
	if (level>16) n=17
	
	for j=0,1 do
		for i=0,7 do
			if not table_has(keep_rooms,n) then 
				if (terrain=="procedural") progen(i,j)
				generate_room(i,j)
			end
			n+=1
		end
	end
	
end
-->8
-- map loading

bottom_map=[[
000000000000000028242525252548253329000031323232253232323232253200000000000000003b200000313232252526002a283824252532323232323232000000000000002a10282900313232256363636452535353545500000055525325482525262b0000000000002425252526282828242548252525482525252525000000000000586828244825252525251b0016001b1b1b1b301b1b1b1b1b301b000000000000001111200000002a282425330000002a313233000029000038290000000000001100002a0000002a28310000000062636363645500000055525325252548262b3a000000000024254825262838283132323232323232252548250000000000002a102831322525482525000000000000000037000000000037000000000000003b343536001400001031262b0000000000000000000000002a0000000000003b202b0012000000002a280000000000000000006500000055626325252532332b28290011112024252525261029002829000000002a283125252500000000000000002a2828242525254800000000000000001b00000000001b0000000000000000003b3435363900001b267273737373737373737374110000160000001100001b003b202b00000016280000000000000000000000000065000025253328282828103a21222225252525262800002a001111110000283824252500000000000000393a282824252525250000160000110000000000110000000011000000000000000000002010280011252222222222222222222222232b000000003b202b000000001b00000000002a000000000000000039000000000000004826282828382828283132322548252526290000001142434400002a28242548000000000000002a2838282448252525000000003b202b3916003b202b00160027393a00000000000000001b2a283921254825252525253232323232262b00000000001b00000011000000000000000000000000390000682800003a0000000025262828102a002a282829003132323226111111114253535400003b21252525000000000000000028282831323232322800003a001b3a283900001b000000003728383911000000000000113a282831323232322548262829002a10372b00160000000000003b202b0000160000000000003a582828682828282828390000002526382829000000002a00000000000025222222236263636400003b24252525000000111111113a2828101b1b1b1b1b283928283900282800000000000000001b002a282711000000003b272828381b22222223313233160000682900000000000100000000001b0000000000000000683928282828102900002a10283a67682526282839000000000000000000000025254825252328382900003b24482525000068212222232838282839000000002828282828382829000000000000160011003a283727000000003b372a2829112525482638282a0000002a0000000000002011111111111111111111111100162828282a38282800000000002828282825262829000000000000000000000000252525252526102a0000003b24252525000010313225252235353536000000002838002a282828103939000011000000272828291b3039000000001b002a282125322526290000000000003a0000000000343535353535353535353535362b0028282900282829006061003a2838282a482600000000000000000000000000002548252525262900001111112425252500002a28283132261b1b1b1b0000000029000000002a28282828393b272b0000372810001130283a00000011002828312601313316000000000000283900000000202838282828202828282828272b00382800002a283d0070713f28282900002526000000000000390000000000000025252525482600003b212223312548250000002838293b30000000000012000000000000000000282828283b302b00001b2a283827302810390000273a28291b26170000000000003900003828000000001b2a282810281b2a28382a28372b002828390000282122232122232800003a3233000000000000282900000000000032323232323300003b242525233125250000002a28003b37000000003a27000000010000001111111128383b372b003a000028283730290028380037283800112639000000000000280000282829000000000029162a28000028160028280000102900000020313233244826284243430000000000000000280000586800000038282829000000003b2425482523313200000100280000280000002a2830000022222311112135353610282829000038000029001b3000002a28000028280021262829000000003a2829002828000000005868000028283a2828390028291600280001000021222222252525235253530000003f0100003a2800002a1000000028290000000039003b2425252525222240002122232b003839120068383039002548252222260c002a28282800003a28010000003a3708000028390028290031262800000000002838003a2810000000002a282828292a2828382828280000004343434344242548252525252652535300000021360000382839000028001c0028013d3e003a28003b2425252548252521232425262b68282827282810302800252525254826000000282829000028282300000038283900002a28102800001b2638390000000028280028282839000000000038280000002a28102800000000535353535424252525252548265253530000003042440028282800002839000022222223102838393b242525252525252525252525262b1b1b1b3132322526004825323232323232252532323233282825252525252525252525482532332b2832323232322526282800003b24252525254825252525254848252525263828242548252532332828292425323232252500000000000000000000000000000000000000000000000000000000000000002525254825262b0000001b1b1b242600323328670000002824332b2a281028382525254825253232323225261b1b00382901003a282426382900003b2432323232323232323232323232322526102831252532331b1b1028143133382828244800000000000000000000000000000000000000000000000000000000000000002525252525262b00000000002a242667282838290000112a372b003a282729002525252525331b1b1b1b31330000002835353536282426281400003b30282a2a1a2829002a2838282810282426002a3825261b1b00003821232b0000081024250000000000003a000000000000000000000000000000000000000000000000002548253232332b00000011002824262928102a00003b2700290000003830000032322525262b000000003b2700003a282828382828242522232b003b372908000010001100292a2829112a3133003a2825262b0000002a31332b00006828242500000000000010000039000000000000000000000000000000000000000000002525262122232b003a67272b2a24263828290000003b30000000003a2830000022233132332b000000003b302839002a3828291029244825262b000000000000002a3b202b3a16283b202b001100002825262b000000001b1b00002a382a2425000000003a00280000380000000000000000000000494a4b4c4d4e4f000000002525262448262b002a38302b1224262938000000003b3000000000002a303e1425252222232b000000003b30290000002829000000242525262b0000000000000000001b002a2828001b003b202b112a25262b000000000000000000293b2448000000002867280000100039000000000000000000595a5b5c5d5e5f000000003232333132262b120028302b1731330028395868393b3011111111111124222225254825262b000011003b302b0000002811111111242548262b0000000000000000000000001110675811001b3b2016482611111111000000160000003b3125000000002838287600286728000000000000000000696a6b6c6d6e6f00000000280000002a301127002a302b001010392828382834353235353535353525254825252525262b003b27003b302b0000002834353535323225262b00001100000000000000003b20282838272b16001b002525232122232b000000000000001b24000000002a28282123283829000000000000000000797a7b7c7d7e7f0000000029001100003135262b0031353535353529002a0000102828282829003b24252532323232262b163b30003b3000000000291b1b1b1b1b3b24262b003b272b00000011000000001b2a2828372b000000003232333132332b000011110000003b240000006838282125252328393a00000000000000000000000000000000000000003b272b002a38302b0000002a28393b0000000000002a2838282867212525251b1b1b1b372b003b30393b30160000000000000000003b24262b173b302b00003b202b110000001100291b000000003a1b1b1b1b1b1b00111121231100003b240000002a28212548252523283868000000000000000000000000000000000000083b302b00002830111111110028383b111111111100002829002928242548250000003a2800003b30283b37000000000000000000003b2426111111302b0000001b3b202b003b272b000000000000282b01000000003b21222532362b003b315858682829242525252526102828680000000000000000000000000000000000003b372b00002a31353535360028293b22222222231111202b00002a31322525000000103829003b3028282800000000111111113900112425222222332b00000100001b00003b302b000000005868282b17000000003b2425331b1b0000001b281028380031322525482629002a28000000000000000000000000000000000039001b000000001b1b1b1b1b002a003b323232323235361b000000001b1b3125000000002800003b30283829000000002222222328383432323232332b0000002339000000003b372b000000002a10281111111100003b31331b003a00160000002a28393f2123242532332000002800000000000000000000000000000000002829000001001400000000000000003b39013d00002a28000000000000002824000000682867003b30002a286700000025252526002828003a10282a0016003a262800000000001b000000393a283828222222232b00001b1b0000380000006800002122222526313321222328392867000000000000000000000000000000001067583a21222311111111110012003b222223390010283900000000083a103101003a382829003b370000382900000025482526002a28282838290000000028263839120000000000003a2828282810254825262b160000390000283a003a2801003125254825222225252523103828000000000000000000000000000000002838282824252522222222230017003b252526283a28382800000000003828282300102828000000380000281000000025252526171728382800000000003a282628102739000000002a282838282828252548262b00003a38003a28102838282122232425252525252548252522222300000000000000000000000000000000
]]

function load_map(token)
	-- erase the old one
	for j=0,31 do for i=0,127 do
		mset(i,j,0)
	end end
	
	-- hex loader
	local hex={"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"}
	local to_dec=function(str)
		if (index_of(hex,str)==false) return 0
		
		return index_of(hex,str)-1
	end
	
	local _x=0
	local _y=0
	for i=1,#token,2 do
		--local tile=to_dec(token[i])*16 + to_dec(token[i+1])
		local tile=to_dec(token[i])*16 + to_dec(token[i+1])
		
		-- tile
		mset(_x,_y,tile)
		
		-- itterate
		_x+=1
		if _x>127 then
			_x=0
			_y+=1
		end
		
	end
	
	-- randomize it
	generate_map()
end
-->8
-- procedural generation
function progen(a,b)
	--sfx"0"
	--if (true) return
	
	local rx=a
	local ry=b
	
	local pos={x=flr(rnd"3"),y=3}
	local visit={
		{0,0,0,0},
		{0,0,0,0},
		{0,0,0,0},
		{0,0,0,0}
	}
	local peak_pos=function()
		return visit[pos.y+1][pos.x+1]
	end
	local nil_table=function(v)
		if (v==nil) return {}
		return v
	end
	
	-- define chunk placement
	local place_chunk=function(x,y,c,subc)
		visit[y+1][x+1]=1
		local option=subc or rand_int(4)
		
		local sy,sx=48+4*option,0+4*c
		for j=0,3 do for i=0,3 do
			local t=mget(sx+i,sy+j)
			mset(i+x*4+rx*16,j+y*4+ry*16,t)
		end end
	end
	
	-- generate solution
	place_chunk(pos.x,pos.y,3)
	visit[pos.y+1][pos.x+1]=2
	local continue=true
	while continue do
		local px=pos.x
		local options=split("1,1,1,1,1,2,2,2,2,2,3")
		local option = options[1+flr(rnd"11")]
		
		-- hit wall?
		if (option==1 and pos.x==0) option=3
		if (option==2 and pos.x==3) option=3

		if (option==1) pos.x-=1
		if (option==2) pos.x+=1
		if (option==3) pos.y-=1
		
		-- in existing room?
		if peak_pos()>0 then
			pos.x=px
		else -- place
			local ck=1
			if (option==3) ck=2
			place_chunk(pos.x,pos.y,ck)
			
			-- top of screen?
			if (pos.y==0) continue=false
		end
	end
		
	-- place berry room
	local pick=rand_int(3)
	if pick>0 then
		while true do
			local i=rand_int(4)
			local j=rand_int(4)
			
			if visit[j+1][i+1]==0 then
				local dir=rand_int(4)
				local go=false
				
				if (dir==0 and nil_table(visit[j+2])[i+1]==1) go=true
				if (dir==1 and nil_table(visit[j])[i+1]==1) go=true
				if (dir==2 and visit[j+1][i]==1) go=true
				if (dir==3 and visit[j+1][i+2]==1) go=true
				
				if go then
					place_chunk(i,j,3+pick,dir)
					break
				end
			end	
		end
	end
	
	for j=1,4 do
		for i=1,4 do
			if (visit[j][i]==0) place_chunk(i-1,j-1,0)
		end
	end
	
	-- place key
	if pick==2 then while true do
		i=rand_int(15)
		j=rand_int(14)
		local t=mget(i+rx*16,j+ry*16)
		if t==0 then
			mset(i+rx*16,j+ry*16,8)
			break
		end
	end end
	
end
-->8
-- palettes
pal_axew={[0]=134,134,134,134,134,134,134,134,134,134,134,134,134,134,134,134}

function updatepal(c,p,b)
	for i=0,15 do
		pal(i,i+128,2)
	end
	pal(p,2)
	
	poke(0x5f5f,0x30+c)
	local byte=0b00000000
	if (b!=nil) byte=b
	memset(0x5f70,byte,16)
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770000060000000600000060000
000000008888888888888888888ffff888888888888888800888888088f1ff1800a909a0000a0a000000a0007766666667767777000600000000600000060000
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8009aaa900009a9000000a0007677766676666677000600000000600000060000
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000000600000006000000006000
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000000600000006000000006000
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
555555550000000000000000000000000000000000000000008888004999999449999994499909940300b0b0666566650300b0b0000000000000000070000000
55555555000000000000000000000000000000000000000008888880911111199111411991140919003b330067656765003b3300007700000770070007000007
550000550000000000000000000000000aaaaaa00000000008788880911111199111911949400419028888206770677002888820007770700777000000000000
55000055007000700499994000000000a998888a1111111108888880911111199494041900000044089888800700070078988887077777700770000000000000
55000055007000700050050000000000a988888a1000000108888880911111199114094994000000088889800700070078888987077777700000700000000000
55000055067706770005500000000000aaaaaaaa1111111108888880911111199111911991400499088988800000000008898880077777700000077000000000
55555555567656760050050000000000a980088a1444444100888800911111199114111991404119028888200000000002888820070777000007077007000070
55555555566656660005500004999940a988888a1444444100000000499999944999999444004994002882000000000000288200000000007000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555500000007777770000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555556670000077777777000777770000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775555555555555500005555556777700077777777007766700000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555556660000077773377076777000000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500000077773377077660000777770000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005556670000073773337077770000777767007700000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc77555555555500000000000055677770007333bb37000000000000007700777770
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc77555555555000000000000005666000000333bb30000000000000000000077777
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc775555555550000000000000050000066603333330000000000000000000000000
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc7775055555555000000000000550007777603b333300000000000ee0ee000000000
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee000000030
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e00000000b0
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee000000b30
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee003000b00
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
5777755777577775077777777777777777777770077777700000000000000000cccccccc00000000000000000000000c0000000c000600000000000000000000
7777777777777777700007770000777000007777700077770000000000000000c77ccccc0000000000000000000000d000000000c060d0000000000000000000
7777cc7777cc777770cc777cccc777ccccc7770770c777070000000000000000c77cc7cc000000000000000000000c00000000000d000d000000000000000000
777cccccccccc77770c777cccc777ccccc777c0770777c070000000000000000cccccccc000000000000000000000c0000000000000000000000000000000000
77cccccccccccc77707770000777000007770007777700070002eeeeeeee2000cccccccc06666600666666006600c00066666600066666006666660066666600
57cc77ccccc7cc7577770000777000007770000777700007002eeeeeeeeee200cc7ccccc6666666066666660660c000066666660666666606666666066666660
577c77ccccccc7757000000000000000000c000770000c0700eeeeeeeeeeee00ccccc7cc66000660660000006600000066000000660000000066000066000000
777cccccccccc7777000000000000000000000077000000700e22222e2e22e00ccccccccdd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000
777cccccccccc7777000000000000000000000077000000700eeeeeeeeeeee0000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000
577cccccccccc7777000000c000000000000000770cc000700e22e2222e22e0000000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00
57cc7cccc77ccc7570000000000cc0000000000770cc000700eeeeeeeeeeee00000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0
77ccccccc77ccc7770c00000000cc00000000c0770000c0700eee222e22eee000000000000000000000000000000000000000000000000000000000000000000
777cccccccccc7777000000000000000000000077000000700eeeeeeeeeeee005555555500000000000000000000000000000000000000000000000000000000
7777cc7777cc777770000000000000000000000770c0000700eeeeeeeeeeee005555555500000000000000000000000000000000000000000000000000000000
777777777777777770000000c0000000000000077000000700ee77eee7777e005555555500000000000000000000000000000000000000000000000000000000
57777577775577757000000000000000000000077000c00707777777777777705555555500000000000000000000000000000000000000000000000000000000
00000000000000007000000000000000000000077000000700777700500000000000000500000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaa00700000000000000000000007700c00070700007055000000000000550000000000000000000000000c000000000000000000000000000000
0a999999999999a0700000000000c000000000077000000770770007555000000000055500000000000000c00000001010c00000000000000000000000000000
a99aaaaaaaaaa99a7000000cc0000000000000077000cc077077bb075555000000005555000060000000010000000001000c0000000000000000000000000000
a9aaaaaaaaaaaa9a7000000cc0000000000c00077000cc07700bbb07555555555555555500060600000001000000000000010000000000000000000000000000
a99999999999999a70c00000000000000000000770c00007700bbb07555555555555555500d00060000001000000000000001000000000000000000000000000
a99999999999999a700000000000000000000007700000070700007055555555555555550d00000c000000000000000000000000000000000000000000000000
a99999999999999a07777777777777777777777007777770007777005555555555555555d000000c000100000000000000000010000000000000000000000000
aaaaaaaaaaaaaaaa07777777777777777777777007777770004bbb00004b000000400bbb00077000000000000000000000000000000000000000000000000000
a49494a11a49494a70007770000077700000777770007777004bbbbb004bb000004bbbbb00077700000000000000000000666600000000000000000000000000
a494a4a11a4a494a70c777ccccc777ccccc7770770c7770704200bbb042bbbbb042bbb0067777770000000000000000006777770000000000000000000000000
a49444aaaa44494a70777ccccc777ccccc777c0770777c07040000000400bbb00400000067777777000000000000000006700770000000000000000000000000
a49999aaaa99994a7777000007770000077700077777000704000000040000000400000066677770000000000000000000007700000000000000000000000000
a49444999944494a77700000777000007770000777700c0742000000420000004200000000067700000000001111000000000000000000000000000000000000
a494a444444a494a7000000000000000000000077000000740000000400000004000000000066000000000001777100000007000000000000000000000000000
a49499999999494a0777777777777777777777700777777040000000400000004000000000000000000000000111000000000000000000000000000000000000
00111100001111000111111000111100011111000000000001111110000022000000220000022220000022000022000000000000000222200000000000000000
01111110011111101114441101111110111111100011110011174471000222200002222000222220000222200222200000000000002222200000000000000000
11144411111444111147447111144411144441100111111011444441002222200022222002244440002222200222220000022220022144100000000000000000
11474471114744710144444011474471174474101111111111444440022444400224444004214410022444400444422000222220042444400000000000000000
014444400144444000aaaa0001444440044444101114444101aaaa00042144100421441009222220042144100144124002222220002222200000000000000000
00aaaa0000aaaa000022220000aaaa0000aaaa700147447000aaaa00092222200922222009139300092222200222229004244440091393000000000000000000
002222000022220007000070072222000022220000aaaa0000222200091393000913930004000040041393000039314002214410093131000000000000000000
00700700007000700000000000000700000070000772227000700700004004000040004000000000000004000000400004439340004004000000000000000000
00000000000000000000f1000000f1000001f000000000000010f101000530000005300000533000000530000003500000053000005330000000000000000000
0000f1000000f1000010f1010010f1010101f0100000f10000f1111f000533000005330000053300000533000033500000053300000533000000000000000000
0010f1010010f10100f1111f00f1111f0f1111f00010f1010015c151005333000053330000173370005333000033350000053300001733700000000000000000
00f1111f00f1111f0015c1510015c1510151c51000f1f11f000cc5c000173370001733700018dd800017337007337100005333300018dd800000000000000000
0015c1510015c151c07cc5c0c07cc5c000c5cc7100111111007cccc00018dd800018dd80077d1d170018dd8008dd810000173370077d1d170000000000000000
007cc5c0007cc5c0ccc77770ccc77770007777c0c075c150c0c71710077d1d17077d1d170d3bbb00077d1d1771d1d7700018dd80003bbb000000000000000000
c0c77770c0c7171001ccc10101cccc00000cc1c1ccc77570cccccc000d3bbb000d3bbb000d0000d00d3bbb0000bbb3d0077d1d170d3333000000000000000000
cc1c1c10c1cccc00000000000001001000001000c1c1cc100c10010000d00d0000d000d00000000000000d00000d00000ddbbbd000d00d000000000000000000
00000000000000000010001000000000000000000000000000000000002888800028888000288880002888800888820000000000002827800000000000000000
001000100010001000210120001000100100010000000000000000000288278802882788028827880288278888728820002888000281ff100000000000000000
00210120002101200017777000210120021012000010001000717710088ffff0088ffff0088ffff0088ffff00ffff88002888888084555500000000000000000
001777700017777000717710001777700777710000210120011777700f41ff100f41ff100f41ff100f41ff1001ff14f00888278800fffff00000000000000000
0071771000717710001777700071771001771700001111100211110000f5555000f5555000f5555000f5555005555f00044ffff0001881000000000000000000
001777700017777000111100001777700777710000177770001111000018810000188100041a1a4000188100001881000f41ff10001a1a000000000000000000
00111100001111000200002002111100001111200071771000111100001a1a00001a1a0000000000041a1a0000a1a14000155550001111000000000000000000
002002000020002000000000000002000000200002211120002002000040040000400040000000000000040000040000044a1a40004004000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12222232000000000000000000009300021222324363436300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
42525262000000000000110000000100432352620000410000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
42845262f31100e3000072f3d3108293040013330043630000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
132323334363000200001363122222320000436300b1b10000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02122232008300000000000000c2000000a100110000930000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12845262a39211000000610000c31000117100728586017600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
42621333010072d3000000000043630072111103a392418300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13334363020013630000000000b1b100135353334363436300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0212320200000000858643630000000002b100a20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12845232c2000000a283b182001000000000a1a30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13528433c30021d3019200830071710011a3838200f3410000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02133302027171020200000200000000435353630043630000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4363123200000000000072b20000b3029200a2760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1222846200e300000000730000c2000000a1001100c2000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
428423620072b2d30000710011c310d37685867211c3411100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13330273007343630000020012222232435363734353536300000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000f000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000f00000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000070000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000f00000000000060600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d000600000000000000660000000000000000000000000000000f0000000000000
0000000000000000000000000000000000000000000000000000000000000d00000c00f000000000066000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d000000c000000000000000000000000000000000000000000000000060000000000
00000000000000000000000000000000000000000000000000000000000c0000000c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000000c060d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006666600666666006600c00066666600066666006666660066666600000000000000000000000000000000000000
0000000000000000000000000000000000006666666066666660660c000066666660666666606666666066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000660660000006600000066000000660000000066000066000000000000000000000000000000000000000000
000000000000000000000000000000000000dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000000000000000000000000000000000000000
000000000000000000000000000000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000000000000000000000000000000000000000
000000000000000000000000000000000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00000000000000000000000000000000000000
0000000000000000000000000000000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd000000f000000000000000f00000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c000000000000000000000000000000c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c00000000000000000000000000000000c0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc0000000000000000000000000000000000c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c000000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000f0f0f0f0f0f0f0f0c0f00000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000000000000001010c0f000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c00000000000000000000000000000000f0f0f0f0
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000600000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000000000010000000000000f000f000f000f000f000f00000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000f0000000f00000000000f00000000000f0f0f000f00000000000f0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000f0f00000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000f000f0000000f000f000f000f000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000f000f000f000f0000000f000f0000000000000000000000000
00f000f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050006000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500555050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050000000000000600000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000f00000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000
000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f0000000000000000000000000f0000000000000000000000000000000000000000000f00000000000000000000
0000000000f000000000f000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000
0000000000000000f000f000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000700000000006600f0000000000000000000000000000f0000000000000000000f000f00
000000000000f000000000000000000f000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000f00000000000000000000000f00000f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000f000f00000000000000000000000000000000
f0000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505550555055500000555050500550555005500550550000000000000000000000000000000000000000
0000000000000000000000000f000000000000000055505050f500050000000500505050505050500050505050000000000000f0000000000000000000000000
00000000000000000000000000000000000000000050505550050005000000050055505050550055505050505000000000000000000000000000000000000000
000000000f00000000000000000000000000f0000050505050050005000000050050505050505000505050505000000000000000000000000000000000000000
000000000000000000000000000000000000000000505050500500050000000500505055005050550055005050000000f0000000000000000000000000000000
f000000000000000000000000000000000000000f00000000000000000000f0000000000000000000000000000000000000000000000000000000f0000000000
0000000000000000000000000000000000000000000060550f0550555050f0000055505550555055505050000000000000000000000000000000000000000000
000f000f000000000000000000000000000000000000005050505f50005000000050505000505050505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505055005000000055005500550055005550000000000000000000000000000000000000000000
000f0000000000000000000000000000000000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000050505500555055500000555055505050505055500000000f0000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000f00000000000000000000000f0000000000000000000000000000000000000f0000000000000
000000000000000000000000000000f000000000f0000000000000f0f0f0f000f0f0f0f0f000000000000000000000000000000000000000000000000000000f
000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000f00000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000
00000000000600000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000600000000000000000000000000000000000000000
0000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000f0000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000f00000000f000000000000000000000
0000000000000000000f00000f0000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000f00000
0000000000f0000f0000000000000000000000000000000000000f00000000000f000000f0000000000000000000000000000000000000000000000000000000
0000000000000000000000000000f0000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000f000000000000000f0000000000000f0000000000000000000000000000000000000000000
000000000000000000000000000000f00000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000f00000000000000f00000000000000000000000000000000000000000000000f0f00000000000
0000000000000000000000000000000000000000f000f00f0f00f000000000000000000000000000000000000000000000000000000000000000000000000000
00000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131302020302020202020202000013131313020204020202020202020000131313130004040202020200000000001313131300000000000002020000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2331252548252532323232323300002425262425252631323232252628282824252525252525323328382828312525253232323233000000313232323232323232330000002432323233313232322525252525482525252525252526282824252548252525262828282824254825252526282828283132323225482525252525
252331323232332900002829000000242526313232332828002824262a102824254825252526002a2828292810244825282828290000000028282900000000002810000000372829000000002a2831482525252525482525323232332828242525254825323338282a283132252548252628382828282a2a2831323232322525
252523201028380000002a0000003d24252523201028292900282426003a382425252548253300002900002a0031252528382900003a676838280000000000003828393e003a2800000000000028002425253232323232332122222328282425252532332828282900002a283132252526282828282900002a28282838282448
3232332828282900000000003f2020244825262828290000002a243300002a2425322525260000000000000000003125290000000021222328280000000000002a2828343536290000000000002839242526212223202123313232332828242548262b000000000000001c00003b242526282828000000000028282828282425
2340283828293a2839000000343522252548262900000000000030000000002433003125333d3f00000000000000003100001c3a3a31252620283900000000000010282828290000000011113a2828313233242526103133202828282838242525262b000000000000000000003b2425262a2828670016002a28283828282425
263a282828102829000000000000312525323300000000110000370000003e2400000037212223000000000000000000395868282828242628290000000000002a2828290000000000002123283828292828313233282829002a002a2828242525332b0c00000011110000000c3b314826112810000000006828282828282425
252235353628280000000000003a282426003d003a3900270000000000002125001a000024252611111111000000002c28382828283831332800000017170000002a000000001111000024261028290028281b1b1b282800000000002a2125482628390000003b34362b000000002824252328283a67003a28282829002a3132
25333828282900000000000000283824252320201029003039000000005824480000003a31323235353536675800003c282828281028212329000000000000000000000000003436003a2426282800003828390000002a29000000000031323226101000000000282839000000002a2425332828283800282828390000001700
2600002a28000000003a283a2828282425252223283900372858390068283132000000282828282820202828283921222829002a28282426000000000000000000000000000020382828312523000000282828290000000000163a67682828003338280b00000010382800000b00003133282828282868282828280000001700
330000002867580000281028283422252525482628286720282828382828212200003a283828102900002a28382824252a0000002838242600000017170000000000000000002728282a283133390000282900000000000000002a28282829002a2839000000002a282900000000000028282838282828282828290000000000
0000003a2828383e3a2828283828242548252526002a282729002a28283432250000002a282828000000002810282425000000002a282426000000000000000000000000000037280000002a28283900280000003928390000000000282800000028290000002a2828000000000000002a282828281028282828675800000000
0000002838282821232800002a28242532322526003a2830000000002a28282400000000002a281111111128282824480000003a28283133000000000000171700013f0000002029000000003828000028013a28281028580000003a28290000002a280c0000003a380c00000000000c00002a2828282828292828290000003a
00013a2123282a313329001111112425002831263a3829300000000000002a310000000000002834222236292a0024253e013a3828292a00000000000000000035353536000020000000003d2a28671422222328282828283900582838283d00003a290000000028280000000000000000002a28282a29000058100012002a28
22222225262900212311112122222525002a3837282900301111110000003a2800013f0000002a282426290000002425222222232900000000000000171700002a282039003a2000003a003435353535252525222222232828282810282821220b10000000000b28100000000b0000002c00002838000000002a283917000028
2548252526111124252222252525482500012a2828673f242222230000003828222223000012002a24260000001224252525252600000000171700000000000000382028392827080028676820282828254825252525262a28282122222225253a28013d0000006828390000000000003c0168282800171717003a2800003a28
25252525252222252525252525252525222222222222222525482667586828282548260000270000242600000021252525254826171700000000000000000000002a2028102830003a282828202828282525252548252600002a2425252548252821222300000028282800000000000022222223286700000000282839002838
2532330000002432323232323232252525252628282828242532323232254825253232323232323225262828282448252525253300000000000000000000005225253232323233313232323233282900262829286700000000002828313232322525253233282800312525482525254825254826283828313232323232322548
26282800000030402a282828282824252548262838282831333828290031322526280000163a28283133282838242525482526000000000000000000000000522526000016000000002a10282838390026281a3820393d000000002a3828282825252628282829003b2425323232323232323233282828282828102828203125
3328390000003700002a3828002a2425252526282828282028292a0000002a313328111111282828000028002a312525252526000000000000000000000000522526000000001111000000292a28290026283a2820102011111121222328281025252628382800003b24262b002a2a38282828282829002a2800282838282831
28281029000000000000282839002448252526282900282067000000000000003810212223283829003a1029002a242532323367000000000000000000004200252639000000212300000000002122222522222321222321222324482628282832323328282800003b31332b00000028102829000000000029002a2828282900
2828280016000000162a2828280024252525262700002a2029000000000000002834252533292a0000002a00111124252223282800002c46472c00000042535325262800003a242600001600002425252525482631323331323324252620283822222328292867000028290000000000283800111100001200000028292a1600
283828000000000000003a28290024254825263700000029000000000000003a293b2426283900000000003b212225252526382867003c56573c4243435363633233283900282426111111111124252525482526201b1b1b1b1b24252628282825252600002a28143a2900000000000028293b21230000170000112867000000
2828286758000000586828380000313232323320000000000000000000272828003b2426290000000000003b312548252533282828392122222352535364000029002a28382831323535353522254825252525252300000000003132332810284825261111113435361111111100000000003b3133111111111127282900003b
2828282810290000002a28286700002835353536111100000000000011302838003b3133000000000000002a28313225262a282810282425252662636400000000160028282829000000000031322525252525252667580000002000002a28282525323535352222222222353639000000003b34353535353536303800000017
282900002a0000000000382a29003a282828283436200000000000002030282800002a29000011110000000028282831260029002a282448252523000000000039003a282900000000000000002831322525482526382900000017000058682832331028293b2448252526282828000000003b201b1b1b1b1b1b302800000017
283a0000000000000000280000002828283810292a000000000000002a3710281111111111112136000000002a28380b2600000000212525252526001c0000002828281000000000001100002a382829252525252628000000001700002a212228282908003b242525482628282912000000001b00000000000030290000003b
3829000000000000003a102900002838282828000000000000000000002a2828223535353535330000000000002828393300000000313225252533000000000028382829000000003b202b00682828003232323233290000000000000000312528280000003b3132322526382800170000000000000000110000370000000000
290000000000000000002a000000282928292a0000000000000000000000282a332838282829000000000000001028280000000042434424252628390000000028002a0000110000001b002a2010292c1b1b1b1b0000000000000000000010312829160000001b1b1b313328106700000000001100003a2700001b0000000000
00000100000011111100000000002a3a2a0000000000000000000000002a2800282829002a000000000000000028282800000000525354244826282800000000290000003b202b39000000002900003c000000000000000000000000000028282800000000000000001b1b2a2829000001000027390038300000000000000000
1111201111112122230000001212002a00010000000000000000000000002900290000000000000000002a6768282900003f01005253542425262810673a3900013f0000002a3829001100000000002101000000000000003a67000000002a382867586800000100000000682800000021230037282928300000000000000000
22222222222324482611111120201111002739000017170000001717000000000001000000001717000000282838393a0021222352535424253328282838290022232b00000828393b27000000001424230000001200000028290000000000282828102867001717171717282839000031333927101228370000000000000000
254825252526242526212222222222223a303800000000000000000000000000001717000000000000003a28282828280024252652535424262828282828283925262b00003a28103b30000000212225260000002700003a28000000000000282838282828390000005868283828000022233830281728270000000000000000
__sfx__
0102000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 150a5644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

