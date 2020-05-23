pico-8 cartridge // http://www.pico-8.com
version 27
__lua__

-- game 20
-- added a few sound effects, revised enemy generation
-- submission

local game_objects
local gravity=0.3
local lives=2

local stage=0

local camera_x=256*stage
local camera_y=256*stage

local score=0

local stages_cleared=0
local enemy_code=0



function _init()
    game_objects={}
    -- make_player(256*stage+64,24)
    -- make_enemy(32, 24, 1)

    generate_new_stage()
end

function _update()
    if not game_over() then
        if check_stage_end() then
            generate_new_stage()
        end
        
        
        local obj
        local dead=true

        for obj in all(game_objects) do
            if obj.name=="player" then
                dead=false
            end
            obj:update()
        end

        if dead then
            make_player(256*stage+64,24)
        end
    end
end

function _draw()
    -- clear screen
    cls()

    -- camera
    camera_x=mid(256*stage,camera_x,127+256*stage+1)
    camera_y=mid(0,camera_y,127)
    camera(camera_x,camera_y)

        

    -- draw map
    map(0,0,0,0,128,32)

    if not game_over() then
        local obj
        for obj in all(game_objects) do
            obj:draw()
        end

        -- draw lives
        spr(50,camera_x+30,camera_y+5)
        print(lives,camera_x+38,camera_y+4,7)


    else
        print("game over", camera_x+47, camera_y+62, 7)
    end

    -- draw score
    print("score:", camera_x+89, camera_y+4)
    print(score, camera_x+113, camera_y+4)

    
    
    -- print(stages_cleared, camera_x+74, camera_y+34, 7)
    -- print(enemy_code, camera_x+74, camera_y+24, 7)


    -- frame rate
    -- print(stat(7), 121+camera_x, camera_y, 7)
end

-- function to make generic game object
function make_game_object(name,x,y,props)
    local obj={
        name=name,
        x=x,
        y=y,
        update=function(self)
        end,
        draw=function(self)
        end
    }

    -- add props
    local key, value
    for key, value in pairs(props) do
        obj[key] = value
    end

    -- add to list
    add(game_objects, obj)
end

-- function to make player object
function make_player(x,y)
    make_game_object("player", x, y, {
        -- unique player traits
        width=6,
        height=6,
        vx=0,
        vy=0,
        
        is_facing_left=false,
        move_speed=1,
        friction=0,
        jump_vy=-3,
        
        is_grounded=false,
        walk_counter=0,
        ground_counter=0,
        max_vy=-1,
        air_counter=5,
        jump_input=false,
        jump_buffer=0,
        jump_counter=0,
        jumping=false,
        jump_reset=true,

        indent=2,

        shoot_counter=0,
        fire_rate=5,        -- how many frames to wait before shooting again
        duration=3,         -- how many frames the beams/eyeglow last
        shooting=false,
        shoot_reset=true,
        eye_glow=false,
        eye_color=8,

        shoot_input=false,
        shoot_buffer=0,

        hit=false,
        i_frames=0,
        life=3,

        amped=false,
        amped_counter=0,
        beam_color=8,



        update=function(self)
            -- update camera position
            camera_x=self.x-64
            camera_y=self.y-64
            
            -- walk counter
            if self.walk_counter==0 then
                self.walk_counter=6
            else
                self.walk_counter-=1
            end

            -- ground counter and air counter
            if self.is_grounded then
                if self.ground_counter>self.max_vy*2 then
                    self.ground_counter=0
                    self.max_vy=-1
                else
                    self.ground_counter+=1
                end
                
                self.air_counter=0
            else
                self.ground_counter=0
                if self.vy>self.max_vy then
                    self.max_vy=self.vy
                end
                
                if self.air_counter<30 then
                    self.air_counter+=1
                end
            end

            -- apply friction
            self.vx*=self.friction

            -- apply gravity
            self.vy+=gravity

            -- move
            if btn(0) then
                self.vx=-self.move_speed
                self.is_facing_left=true
            end
            if btn(1) then
                self.vx=self.move_speed
                self.is_facing_left=false
            end

            -- jump buffer
            if btn(4) then
                self.jump_input=true
                self.jump_buffer=0
                
            else
                self.jump_buffer+=1
                if self.jump_buffer>3 then
                    self.jump_input=false
                end
            end
                
                
            -- jump
            if self.jump_input and self.air_counter<5 and self.jump_reset==true then
                self.jump_input=false
                self.jumping=true
                self.jump_reset=false
            end

            -- jumping coyote time
            if self.jumping then
                if self.jump_counter==0 then
                    self.vy=self.jump_vy
                    sfx(3)
                elseif (self.jump_counter==4 and btn(4)) then
                    self.vy=self.jump_vy
                end
                if self.jump_counter>4 then
                    self.jumping=false
                    self.jump_counter=0                        
                else
                    self.jump_counter+=1
                end
            end

            if not btn(4) then
                self.jump_reset=true
                self.jump_input=false
            end



            -- update positions
            self.x+=self.vx
            self.y+=self.vy


            -- collision detection
            self.is_grounded=false
            if self:check_map_collision("down") then
                self.vy=0
                self.y-=(self.y+self.height)%8
                self.is_grounded=true
            end

            if self:check_map_collision("up") then
                self.vy=0
                self.y+=8-self.y%8
            end

            if self:check_map_collision("right") then
                self.vx=0
                self.x-=(self.x+self.width)%8
            end

            if self:check_map_collision("left") then
                self.vx=0
                self.x+=8-self.x%8
            end


            -- shoot buffer
            if btn(5) then
                self.shoot_input=true
                self.shoot_buffer=0
                
            else
                self.shoot_buffer+=1
                if self.shoot_buffer>3 then
                    self.shoot_input=false
                end
            end
            
            
            -- shoot laser
            if self.shooting==false and self.shoot_reset==true then
                if self.shoot_input then
                    self.shooting=true
                    self.shoot_reset=false
                    self.eye_glow=true
                    local dir
                    local x_offset
                    if self.is_facing_left then
                        dir=-1
                        x_offset=-2
                    else
                        dir=1
                        x_offset=self.width+1
                    end
                    make_beam("player",self.x+x_offset, self.y+2, dir, self.duration, -1, 128, 6, self.beam_color)
                    sfx(1)
                    sfx(2)
                    
                end
                self.shoot_counter=0
            else
                self.shoot_counter+=1
                if not btn(5) then
                    self.shoot_reset=true
                    self.shoot_input=false
                end
                
                if self.shoot_counter>self.duration-1 then
                    self.eye_glow=false
                end
                if self.shoot_counter>self.fire_rate-2 then
                    self.shooting=false
                end
            end

            -- landing
            if self.ground_counter==1 then
                sfx(0)
            end

            -- bounding box collision (enemy or powerup)
            local obj
            for obj in all(game_objects) do
                if obj.name=="enemy" then
                    if rect_in_rect(self,obj) then
                        self.hit=true
                    end
                elseif obj.name=="dead" then
                    if rect_in_rect(self,obj) then
                        self.amped=true
                        del(game_objects,obj)
                        lives+=1
                    end
                end
            end
            

            -- hit
            if self.hit then
                if self.i_frames<15 then
                    self.i_frames+=1
                else
                    self.i_frames=0
                    self.hit=false
                end

                if self.i_frames==1 then
                    self.life-=1
                    sfx(5)
                end
            end

            -- dead

            if self.life==0 then
                make_dead_body(self.x,self.y+1)
                del(game_objects,self)
                lives-=1
            end

            -- amped

            if self.amped then
                self.move_speed=1.5
                self.jump_vy=-4
                self.beam_color=12
                self.amped_counter+=1
                if self.amped_counter>299 then
                    self.move_speed=1
                    self.jump_vy=-3
                    self.beam_color=8
                    self.amped_counter=0
                    self.amped=false
                    
                end
            end

            
            

            







        end,


        draw=function(self)
            local sprite_num=1
            if self.is_grounded then
                if self.vx != mid(-0.1, self.vx, 0.1) then
                    if self.walk_counter<3 then
                        sprite_num=2
                    end
                end

                if self.ground_counter>0 and self.ground_counter<self.max_vy*2 then
                    sprite_num=18
                end
            else
                if self.vy<-1 then
                    sprite_num=17
                elseif self.vy<-0.5 then
                    sprite_num=33
                end


            end

            -- change eye color
            if self.amped then
                pal(10, 12)
            elseif self.eye_glow then
                pal(10, self.eye_color)
            else
                pal()
            end

            -- null sprite
            if self.i_frames%3==1 or self.i_frames%3==2 then
                sprite_num=48
            end

            -- draw sprite
            spr(sprite_num, self.x, self.y, 0.75, 1, self.is_facing_left)

            -- hit
            -- print(self.life, self.x, self.y-10, 7)

            -- draw life
            self:draw_hearts()

            
            

            
            
            -- print(self.y, self.x, self.y-10, 7)
            -- print(self.x, self.x, self.y-16, 7)
            -- print(self.air_counter, self.x, self.y-22, 7)
            -- print(btn(2), self.x, self.y-28, 7)
        end,



        check_map_collision=function(self, dir)
            local x_test_1=0
            local y_test_1=0
            local x_test_2=0
            local y_test_2=0
            if (dir=="down") then
                x_test_1=self.x+self.indent
                y_test_1=self.y+self.height
                x_test_2=self.x+self.width-self.indent
                y_test_2=self.y+self.height
            elseif (dir=="up") then
                x_test_1=self.x+self.indent
                y_test_1=self.y
                x_test_2=self.x+self.width-self.indent
                y_test_2=self.y
            elseif (dir=="left") then
                x_test_1=self.x
                y_test_1=self.y+self.indent
                x_test_2=self.x
                y_test_2=self.y+self.height-self.indent
            elseif (dir=="right") then
                x_test_1=self.x+self.width
                y_test_1=self.y+self.indent
                x_test_2=self.x+self.width
                y_test_2=self.y+self.height-self.indent
            end

            return fget(mget(x_test_1/8, y_test_1/8), 0)
            or fget(mget(x_test_2/8, y_test_2/8), 0)
        end,

        draw_hearts=function(self)
            local i
            for i=0,self.life-1 do
                spr(32, 4+camera_x+i*6, 4+camera_y)
            end
        end



    })
end

function make_beam(type, x,y,dir,duration,speed,length,ray_length,color)
    make_game_object("beam", x, y, {
        type=type,
        dir=dir,
        life=duration,
        speed=speed,
        length=length,
        ray_length=ray_length,
        color_1=color,
        color_2=7,
        
        x2=x,
        hit=false,

        update=function(self)
            self.life-=1
            if self.life<0 or (self.hit and self.speed>-1) then
                del(game_objects, self)
            end

            self:check_beam_map_collision()
            self:check_beam_hit()

            if self.dir==1 then
                self.x=max(self.x, self.x2-self.length)
            else
                self.x=min(self.x,self.x2+self.length)
            end
        end,

        draw=function(self)
            line(self.x,self.y-1,self.x2, self.y-1, self.color_1)
            line(self.x,self.y,self.x2, self.y, self.color_2)
            line(self.x,self.y+1,self.x2, self.y+1, self.color_1)

            -- print(self.dir, self.x, self.y-10, 7)
            -- print(self.x, self.x, self.y-16, 7)
            -- print(self.x2, self.x, self.y-22, 7)
            -- print(self.hit, self.x, self.y-22, 7)
        end,

        check_beam_map_collision=function(self)
            -- go ray_length tiles and then check
            -- if collided, go back so it hits the wall
            local x_test=self.x2
            local y_test=self.y

            if self.speed==-1 then
                while not fget(mget(x_test/8, y_test/8), 0)
                and x_test<160+camera_x and x_test>-33+camera_x do
                    x_test+=self.dir*self.ray_length
                end
                self.hit=true
            else
                local i
                for i=0,self.speed do
                    -- x_test+=self.dir*8
                    if not fget(mget(x_test/8, y_test/8), 0)
                    and x_test<160+self.length+camera_x and x_test>-33-self.length+camera_x then
                        x_test+=self.dir*self.ray_length
                    end
                end
                if fget(mget(x_test/8, y_test/8), 0)
                or not (x_test<160+self.length+camera_x and x_test>-33-self.length+camera_x) then
                    self.hit=true
                end
            end
            
            if self.hit then
                if self.dir==1 then
                    x_test-=x_test%8+1
                else    
                    x_test+=8-x_test%8
                end
            end
            
            self.x2=x_test

        end,

        check_beam_hit=function(self)
            -- hit detection
            local obj
            for obj in all(game_objects) do
                if obj.name=="player" then
                    if self.type=="enemy" then
                        if beam_in_rect(self,obj) then
                            self.hit=true
                            obj.hit=true
                        end
                    end
                elseif obj.name=="enemy" then
                    if self.type=="player" then
                        if beam_in_rect(self,obj) then
                            self.hit=true
                            obj.hit=true
                        end
                    end
                end
            end
        end


    })

end

function make_enemy(x,y,type)
    local type = type
    local base_sprite_num
    local life
    local bullet_type
    local speed
    local is_berserker
    local shoot_counter

    -- green berserker
    if type==1 then
        base_sprite_num=8
        life=3
        bullet_type=0
        move_speed=0.5
        is_berserker=true
        shoot_counter=59
    -- purple sniper
    elseif type==2 then
        base_sprite_num=10
        life=5
        bullet_type=1
        move_speed=0.75
        is_berserker=false
        shoot_counter=29
    -- red berserker
    elseif type==3 then
        base_sprite_num=11
        life=5
        bullet_type=1
        move_speed=0.75
        is_berserker=true
        shoot_counter=29
    -- green grunt
    else
        base_sprite_num=7
        life=3
        bullet_type=0
        move_speed=0.5
        is_berserker=false
        shoot_counter=59
    end


    make_game_object("enemy", x, y, {
        width=7,
        height=8,
        vx=0,
        vy=0,
        indent=2,
        
        move_speed=move_speed,
        direction=0,

        is_grounded=false,
        walk_counter=0,
        is_facing_left=false,
        jumping=false,
        
        target_x=64,
        deadzone=32,

        shoot_counter=shoot_counter,

        hit=false,
        i_frames=0,
        life=life,

        base_sprite_num=base_sprite_num,

        bullet_type=bullet_type,
        is_berserker=is_berserker,

        awake=false,

        update=function(self)
            -- calculate target movement
            local obj
            for obj in all(game_objects) do
                if obj.name=="player" then
                    self.target_x=obj.x
                    self.target_y=obj.y
                end
            end

            -- wake up or put to sleep
            if abs(self.target_x-self.x+self.width/2) < 80
            and abs(self.target_y-self.y+self.height/2) < 80 then
                self.awake=true
            else
                self.awake=false
            end
            
            -- check enemy state (berserker)
            if self.is_berserker and self.life<life-1 then
                self.move_speed=move_speed+0.25
                self.deadzone=6
                self.base_sprite_num=base_sprite_num+1
            end
            
            -- walk counter
            if self.walk_counter==0 then
                self.walk_counter=11
            else
                self.walk_counter-=1
            end

            -- apply gravity
            self.vy+=gravity


            -- walk
            if self.x<self.target_x then
                self.direction=1
                self.is_facing_left=false
            elseif self.x>self.target_x then
                self.direction=-1
                self.is_facing_left=true
            end

            if abs(self.x-self.target_x)<self.deadzone or not self.awake then
                self.direction=0
            end
            
            self.vx=self.direction*self.move_speed


            -- update position
            self.x+=self.vx
            self.y+=self.vy
            
            
            -- collision detection
            self.is_grounded=false
            if self:check_map_collision("down") then
                self.vy=0
                self.y-=(self.y+self.height)%8
                self.is_grounded=true
            end

            if self:check_map_collision("up") then
                self.vy=0
                self.y+=8-self.y%8
            end

            if self:check_map_collision("right") then
                self.vx=0
                self.x-=(self.x+self.width)%8
                self.jumping=true
            elseif self:check_map_collision("left") then
                self.vx=0
                self.x+=8-self.x%8
                self.jumping=true
            else
                self.jumping=false
            end

            if self.jumping and self.is_grounded then
                self.vy=-3
            end

            -- shoot (on timer)
            if (self.life>life-2 or not self.is_berserker) and self.awake then
                if self.shoot_counter==0 then
                    self.shoot_counter=shoot_counter
                    local dir
                    local x_offset
                    if self.is_facing_left then
                        dir=-1
                        x_offset=-1
                    else
                        dir=1
                        x_offset=self.width
                    end
                    if self.bullet_type==0 then
                        make_beam("enemy",self.x+x_offset, self.y+5, dir, 60, 1, 6, 2, 9)
                    elseif self.bullet_type==1 then
                        make_beam("enemy",self.x+x_offset, self.y+5, dir, 60, 3, 24, 2, 9)
                    end
                    sfx(4)

                else
                    self.shoot_counter-=1
                end
            end


            -- hit
            if self.hit then
                if self.i_frames<5 then
                    self.i_frames+=1
                else
                    self.i_frames=0
                    self.hit=false
                end

                if self.i_frames==1 then
                    self.life-=1
                end
            end

            -- dead
            if self.life==0 then
                del(game_objects, self)
                score+=1+type
            end



        end,
        draw=function(self)
            -- walking animation
            local sprite_num=self.base_sprite_num
            if self.is_grounded then
                if self.vx != mid(-0.1, self.vx, 0.1) then
                    if self.walk_counter<2 then
                        sprite_num+=16
                    elseif self.walk_counter>5 and self.walk_counter<9 then
                        sprite_num+=32
                    end
                end
            end

            -- null sprite
            if self.i_frames%3==1 or self.i_frames%3==2 then
                sprite_num=48
            end

            -- draw sprite
            spr(sprite_num, self.x, self.y, 0.875, 1, self.is_facing_left)



            -- print(self.awake, self.x, self.y-10, 7)
            -- print(self.target_x-self.x+self.width/2, self.x, self.y-16, 7)
            -- print(self.target_x, self.x, self.y-22, 7)
            -- print(self.x+self.width/2, self.x, self.y-28, 7)
        end,

        check_map_collision=function(self, dir)
            local x_test_1=0
            local y_test_1=0
            local x_test_2=0
            local y_test_2=0
            if (dir=="down") then
                x_test_1=self.x+self.indent
                y_test_1=self.y+self.height
                x_test_2=self.x+self.width-self.indent
                y_test_2=self.y+self.height
            elseif (dir=="up") then
                x_test_1=self.x+self.indent
                y_test_1=self.y
                x_test_2=self.x+self.width-self.indent
                y_test_2=self.y
            elseif (dir=="left") then
                x_test_1=self.x
                y_test_1=self.y+self.indent
                x_test_2=self.x
                y_test_2=self.y+self.height-self.indent
            elseif (dir=="right") then
                x_test_1=self.x+self.width
                y_test_1=self.y+self.indent
                x_test_2=self.x+self.width
                y_test_2=self.y+self.height-self.indent
            end

            return fget(mget(x_test_1/8, y_test_1/8), 0)
            or fget(mget(x_test_2/8, y_test_2/8), 0)
        end

    })
end

function make_dead_body(x,y)
    make_game_object("dead",x,y,{
        width=6,
        height=5,
        indent=2,

        vy=0,
        
        update=function(self)
            self.vy+=gravity

            self.y+=self.vy

            if self:check_map_collision() then
                self.vy=0
                self.y-=(self.y+self.height)%8
            end

        end,
        draw=function(self)
            spr(34,self.x,self.y)
        end,

        check_map_collision=function(self)
            return fget(mget((self.x+self.indent)/8, (self.y+self.height)/8), 0)
            or fget(mget((self.x+self.width-self.indent)/8, (self.y+self.height)/8), 0)
        end




    })
end




-- beam collision
-- note if beam.dir==1 then x2>x and if beam.dir==-1 then x2<x
function beam_in_rect(beam, obj)
    return max(beam.x2, beam.x)>obj.x and min(beam.x, beam.x2)<obj.x+obj.width
    and beam.y>obj.y and beam.y<obj.y+obj.height
end

-- rect collision
function rect_in_rect(obj1, obj2)
    return obj1.x<obj2.x+obj2.width and obj1.x+obj1.width>obj2.x
    and obj1.y<obj2.y+obj2.height and obj1.y+obj1.height>obj2.y
end



-- generates new stage
-- picks stage 0-3, randomizes enemies
function generate_new_stage()
    enemy_code=0
    
    stage=flr(rnd(4))
    
    local counter=stages_cleared
    local num_0=0
    local num_1=0
    local num_2=0
    local num_3=0

    local i=0
    for i=0,stages_cleared do
        if i%3<2 then
            spawn_enemy(0)
        elseif i%6<5 then
            spawn_enemy(1)
        elseif i%12<11 then
            spawn_enemy(2)
        else
            spawn_enemy(3)
        end
    end
    -- while counter>0 do
    --     if i==0 then
    --         num_0=counter%3
    --     elseif i==1 then
    --         num_1=counter%3
    --     elseif i==2 then
    --         num_2=counter%3
    --     else
    --         num_3=counter%3
    --     end
        
    --     i+=1
        
    --     counter=flr(counter/3)
    -- end
    
    -- for i=1,num_0 do
    --     spawn_enemy(0)
    -- end
    -- for i=1,num_1 do
    --     spawn_enemy(1)
    -- end
    -- for i=1,num_2 do
    --     spawn_enemy(2)
    -- end
    -- for i=1,num_3 do
    --     spawn_enemy(3)
    -- end


    make_player(256*stage+64,24)

end

function spawn_enemy(type)
    local enemy_x
    local enemy_y
    
    enemy_x=256*stage+8 + flr(rnd(239))
    enemy_y=8+flr(rnd(199))

    if type==0 then
        enemy_code+=1
    elseif type==1 then
        enemy_code+=10
    elseif type==2 then
        enemy_code+=100
    elseif type==3 then
        enemy_code+=1000
    end

    make_enemy(enemy_x,enemy_y,type)
end

-- check if stage is complete
-- see if any enemies are left
function check_stage_end()
    local obj
    local temp_player
    local no_enemies=true

    for obj in all(game_objects) do
        if obj.name=="enemy" then
            no_enemies=false
        elseif obj.name=="player" then
            temp_player=obj
        end
    end

    if no_enemies==true then
        stages_cleared+=1
        del(game_objects, temp_player)
        return true
    else
        return false
    end
end

-- checks lives left
-- if 0, end game (restart)?
function game_over()
    return lives<0
end




__gfx__
000000006766660067666600bb330000000ddd0000007f00111111110000000000000b0000000b00000000000000080000000800000000000000000000000000
000000006766660067666600b939000000ecdc000007fbf0100000d107bbb00007bbbb0007bbbb0007ddd0000788880007888800000000000000000000000000
0070070067a6a60067a6a600b333000000eddd00000fbfb0100ddd01b7bbbb00b7bbbb00b7bbbb00d7dddd008788880087888800000000000000000000000000
0007700067666600676666000b3000000edd50000000fff01dd00001b00ee000b00ee000b00ee000d00ee000800ee000800ee000000000000000000000000000
000770000076000000760000300300000e0d0500007ff1181000ddd107bbbb0007bbbb0007bbbb0007dddd000788880007888800000000000000000000000000
00700700060060000066000030030000e0d0d0d00ffff10010dd000100731190007311900b733b00007511900072119008722800000000000000000000000000
00000000000000000000000000000000d0d0d0d0000000001d000001007b1000007b10000b7bbb00007d10000078100008788800000000000000000000000000
0000000000000000000000000000000000000000000000001111111100b0b00000b0b00000b0b00000d0d0000080800000808000000000000000000000000000
666666656766660000000000bb330000000ddd0000007f000000000d0000000000000b0000000b00000000000000080000000800000000000000000000000000
655555516766660067666600b939000000ecdc000007fbf000000dd007bbb00007bbbb0007bbbb0007ddd0000788880007888800000000000000000000000000
6555555167a6a60067666600b333000000eddd00000fbfb000ddd000b7bbbb00b7bbbb00b7bbbb00d7dddd008788880087888800000000000000000000000000
655555516766660067a6a6000b3000000edd50000000fff00d000000b00ee000b00ee000b00ee000d00ee000800ee000800ee000000000000000000000000000
65555551007600006766660000000000e0d05000077ff118d00000dd07bbbb0007bbbb0007bbbb0007dddd000788880007888800000000000000000000000000
655555510000000006766000300300000d0d0500fffff1000000dd000073119000731190b0733b00007511900072119080722800000000000000000000000000
65555551000000000000000030030000d0d0d0d000000000000d0000007b1000007b1000b0bbb0b0007d10000078100080888080000000000000000000000000
511111110600600000000000000000000000000000000000ddd0000000bb000000bb0000000bb00000dd00000088000000088000000000000000000000000000
080800006766660067660000bb330000000ddd0000000000111111110000000000000b0000000b00000000000000080000000800000000000000000000000000
878880006766660067665500b939000000ecdc00000000001111111107bbb00007bbbb0007bbbb0007ddd0000788880007888800000000000000000000000000
8888800067a6a60066060600b333000000eddd000000000000ddd000b7bbbb00b7bbbb00b7bbbb00d7dddd008788880087888800000000000000000000000000
0888000067666600056666003b3300000edd5000000000000d000000b00ee000b00ee000b00ee000d00ee000800ee000800ee000000000000000000000000000
008000000076000005556000300300000e0d050000000000d00000dd07bbbb0007bbbb0007bbbb0007dddd000788880007888800000000000000000000000000
00000000000000000000000000000000d0d0d0d0000000000000dd000073119000731190b0733b00007511900072119080722800000000000000000000000000
000000000600600000000000000000000d0d0d0d00000000000d000000bb100000bb1000b07bb0b000dd10000088100080788080000000000000000000000000
000000000000000000000000000000000000000000000000ddd00000000bb000000bb00000bb0000000dd0000008800000880000000000000000000000000000
00000000000000006766660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006766660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006706060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006766660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
__gff__
0000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000101010101000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000101010101000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000001000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000010000000000000000000000000101000001010100000000000000000000000000000000000000000000000000010
1000000000000000100000000000000000000000000000000000000000000010100000001010101010000000000000000000000000000000101010100000001010000000000000000000000000000000100000000000000000000000000000101000000000001010101010100000000000000000000000000000000000000010
1000101010101010101010100000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000100000000000000000000000000000101000000000000000000000101010101010101010100000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000010100000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000000010000000000000000000000000000000000010100000000000000000000000000000000000000010101010000000000000001010000000000000000000000000000010000000000000000000000000000000101000000000000000000000000000000000000000000010000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000010101010100000000010000000000010100000000000001010000000000000000000000000001000000000000000000000101000000000101000000000000000000000000000000000000000000000001010100000000010
1000000000000000000000000000100000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000101010101000000000000000000010001000000000101000000000000000000000000000001010101010101010100000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000010000000001000000000000000000000001010000000000000001010100000000000000000000000000000001000000000101000000000000010101010101010101000000000000000000000000000000010
1000000000000000000000001000001010101000000000001010101000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000101000000000101000000000001010000000000000000000000000000000000000000000000010
1000000000000000000000100000000000001010101010100000000000000010100000000000000000000000000000000010101010000000000000000000001010000000101010000000000000000000000000000000000010100000000000101000000010000000000000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000101010100000000000000000000000101010000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000001010101010101000000000000000000000000000000010100000000000000000000000000000001000000000000000000000000000001010000000000000000000101000000000000000000010100000000000000000101000101010000000000000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000010000000000000000000000000000000001010000000000000000000001010000000000000001010000000000000000000101000000010101010101000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000010100000000000000000000000000000000000001010000010101000000000000010100000000010000000000000101000000000101000000000000000001010101010100000000000000000000000000000000010
1000000000101010100000000000000000000000000000000000000000000010100000000000000000000000101010100000000000000000000000000000001010000000000010101000000000000000100000000000001010100000000000101000000000000000000000000000001010101010000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000001010100000000000000000000000101000000000000000101000000000000000000000000000000000000010101010101010000000000010
1000000000000000000010101010000000000000000000000000000000000010100000000000101010100000000000000010000000000000000000000000001010000000000000000000101010101000000000101010100000000000000000101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000100000000000000000000000000010101010100000000000001010000000000000000000000000000000001010100000000000000000000000101000000000000000000000000000000000000000000000000000100000000010
1000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
__sfx__
000100001075007720047200372000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000030630306302f6302e6302d6302b6302a63029630276202562023620216201e6101b610176101361000000000000000000000000000000000000000000000000000000000000000000000000000000000
01020000174300e430174300e430174200e420174100e410004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000000
0001000010750137401c7401e74000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000d6401d45015450125300e520095500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200000b2300b2300b2300b23000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
