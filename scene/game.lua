return function()
	local game = {}

	function game:enter(_, level)
		log.trace('entered scene.game with level ', (''..level))
		self.tween = flux.group()
		self.level = json.decode(assert(love.filesystem.read(('asset/map_export/%d.json'):format(level))))
		self.level.id = level
		
		self.bump = bump.newWorld(200)
		self.tiny = tiny.world()
		for _, s in ipairs {
			'system.physical',
			'system.input_player',
			'system.next_target',
			'system.draw',
		} do
			self.tiny:addSystem(require(s)())
		end
		
		for _, object in ipairs(lume.match(self.level.layers, function(l) return l.name == 'Objects' end).objects) do
			if object.name:match('^level%d+$') then
				local tile = {
					level = tonumber((object.name:match('^level(%d+)$'))),
					draw = require 'draw.level_end',
					z = 1
				}
				assert(tile.level)
				self.tiny:addEntity(tile)
				self.bump:add(tile, snapRectToTile(object.x, object.y, object.width, object.height))
			elseif object.name:match('^lock%d+$') then
				local tile = {
					id = tonumber((object.name:match('^lock(%d+)$'))),
					draw = require 'draw.lock'
				}
				assert(tile.id)
				self.tiny:addEntity(tile)
				self.bump:add(tile, snapRectToTile(object.x, object.y, object.width, object.height))
			elseif object.name:match('^key%d+$') then
				local tile = {
					id = tonumber((object.name:match('^key(%d+)$'))),
					draw = require 'draw.key'
				}
				assert(tile.id)
				self.tiny:addEntity(tile)
				self.bump:add(tile, snapRectToTile(object.x, object.y, object.width, object.height))
			end
		end
		
		local player
		for i, id in ipairs(lume.match(self.level.layers, function(l) return l.name == 'Tiles' end).data) do
			local type = properties.tiles[id] or 'undefined'
			local x, y = (i - 1) % self.level.width, math.floor((i - 1) / self.level.width)
			if type == 'player' then
				assert(not player, 'only one player per level allowed')
				player = {
					input = true,
					move = vector(),
					speed = properties.player.speed,
					draw = require 'draw.player',
					z = 2
				}
				self.tiny:addEntity(player)
				self.bump:add(player, tileToRect(x, y))
			elseif type:match('^redirect_') then
				local redirect = {
					redirector = true,
					direction = type:match('_([^_]+)$'),
					draw = require 'draw.redirect'
				}
				assert(redirect.direction)
				self.tiny:addEntity(redirect)
				self.bump:add(redirect, tileToRect(x, y))
			elseif type == 'stop' then
				local stop = {
					stop = true,
					draw = require 'draw.stop'
				}
				self.tiny:addEntity(stop)
				self.bump:add(stop, tileToRect(x, y))
			elseif type == 'block' then
				local block = {
					block = true,
					draw = require 'draw.block'
				}
				self.tiny:addEntity(block)
				self.bump:add(block, tileToRect(x, y))
			elseif type == 'checkpoint' then
				local checkpoint = {
					checkpoint = true,
					draw = require 'draw.checkpoint'
				}
				self.tiny:addEntity(checkpoint)
				self.bump:add(checkpoint, tileToRect(x, y))
			elseif type:match('^spike_') then
				local spike = {
					spike = true,
					direction = type:match('_([^_]+)$'),
					draw = require 'draw.spike'
				}
				assert(spike.direction)
				self.tiny:addEntity(spike)
				self.bump:add(spike, tileToRect(x, y))
			end
		end
		self.player = assert(player)
		
		self.camera = require 'hump.camera' (0, 0)
		updateCamera(self)
		self.tiny:refresh()
		
		-- print(#self.tiny.entities)
		
		-- print(#self.tiny.entities)
		-- local stream = io.open('scene' .. self.level.id .. '.txt', 'wb')
		-- stream:write(inspect(self))
		-- stream:close()
		
		-- print(#lume.match(self.tiny.systems, function(s)
		-- 	return s.draw
		-- end).entities)
	end

	function game:update(dt)
		self.tween:update(love.timer.getDelta() / 1)
		self.tiny:update(love.timer.getDelta(), function(_, s) return not s.draw end)
		if self.newLevel and not self.newLevelTween then
			if self.newLevel == 'pop' then
				popLevel()
			else
				pushLevel(self.newLevel)
			end
			self.newLevel = nil
			return
		end
	end

	local function drawHUD(self)
		if cli.debug then
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(string.format('%0.1fms, %d entities, %d systems', love.timer.getAverageDelta() * 1000, self.tiny:getEntityCount(), self.tiny:getSystemCount()), 4, 4)
		end
	end

	local function drawGame(self)
		local prevFont = love.graphics.getFont()
		
		local scale = getLevelZoom(self, 1, 1)
		scale = scale / getTransitionMultiplier(self)
		local fontSize = math.floor(properties.font.size * scale + 0.5)
		local font = getFont(properties.font.main, fontSize)
		love.graphics.setFont(font)
		
		local text = getLevelLabel(self.level.id)
		local tw, th = font:getWidth(text), font:getHeight()
		
		love.graphics.push()
		love.graphics.translate(
			math.floor(self.level.tilewidth  / 2 * self.level.width  * scale + 0.5) / scale,
			math.floor(self.level.tileheight / 2 * self.level.height * scale + 0.5) / scale
		)
		love.graphics.scale(1 / scale * math.min(self.level.width, self.level.height))
		love.graphics.translate(-tw / 2, -th / 2)
		
		local l, a, b = vivid.RGBtoLab(properties.color.background)
		local r, g, b = vivid.LabtoRGB(l + 3.5, a, b)
		love.graphics.setColor(r, g, b, 1 - getExitTween(self))
		love.graphics.print(text)
		
		love.graphics.pop()
		love.graphics.setColor(1, 1, 1, 1)
		
		love.graphics.setFont(prevFont)
		
		self.tiny:update(love.timer.getDelta(), function(_, s) return s.draw end)
	end

	function game:draw()
		updateCamera(self)
		local ww, wh = love.graphics.getDimensions()
		if getLevelTween(self) <= 0 then
			love.graphics.setColor(properties.color.background)
			love.graphics.rectangle('fill', 0, 0, ww, wh)
		end
		if self.newScene then
			self.newScene:draw()
		end
		self.camera:attach()
		drawGame(self)
		self.camera:detach()
		drawHUD(self, ww, wh)
	end

	return game
end