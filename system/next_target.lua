return function()
	local targetSystem = tiny.processingSystem()
	targetSystem.nocache = true
	targetSystem.filter = tiny.requireAll(isPhysical, hasInput, tiny.rejectAll('tween'))

	function targetSystem:process(e, dt)
		local scene = getEntityScene(e)
		
		local tx, ty = rectToTile(scene.bump:getRect(e))
		local mx, my = e.move.x, e.move.y
		if mx ~= 0 then
			my = 0
			mx = lume.sign(mx)
		elseif my ~= 0 then
			my = lume.sign(my)
		end
		assert(mx ~= 0 or my ~= 0)
		local nx, ny
		if     mx > 0 then -- right
			nx, ny = scene.level.width, ty
		elseif mx < 0 then -- left
			nx, ny = -1, ty
		elseif my > 0 then -- down
			nx, ny = tx, scene.level.height
		elseif my < 0 then -- up
			nx, ny = tx, -1
		end
		local other
		local syst = lume.match(scene.tiny.systems, function(s) return s.physical end)
		for _, o in ipairs(syst.entities) do
			local ox, oy = rectToTile(scene.bump:getRect(o))
			if     mx > 0 then -- right
				if ox > tx and oy == ty and (ox - tx < nx - tx) then
					nx, ny = ox, oy
					other = o
				end
			elseif mx < 0 then -- left
				if ox < tx and oy == ty and (ox - tx > nx - tx) then
					nx, ny = ox, oy
					other = o
				end
			elseif my > 0 then -- down
				if oy > ty and ox == tx and (oy - ty < ny - ty) then
					nx, ny = ox, oy
					other = o
				end
			elseif my < 0 then -- up
				if oy < ty and ox == tx and (oy - ty > ny - ty) then
					nx, ny = ox, oy
					other = o
				end
			end
		end
		
		if other then
			if other.redirector then
				e.redirect = vector(unpack(properties.direction_mapping[other.direction], 1, 2))
			elseif other.block then
				nx, ny = nx - mx, ny - my
			end
		end
		
		if tx ~= nx or ty ~= ny then
			-- local position = {tx, ty}
			local time = {value = 0, x = nx, y = ny}
			if e.input and other and other.level then
				e.finishLevel = time
			end
			local dist = math.max(math.abs(tx - nx), math.abs(ty - ny))
			e.tween = scene.tween:to(time, 0.2 * math.sqrt(dist), {value = 1})
			:onupdate(function()
				local t = time.value
				local x, y = tileToRect(tx * (1 - t) + nx * t, ty * (1 - t) + ny * t)
				scene.bump:move(e, x, y, function(e, o)
					return 'cross'
				end)
			end)
			:oncomplete(function()
				log.trace('move finished')
				e.move = vector(0)
				if other and other.level then
					-- manager:push(scene.newScene, other.level)
					-- manager:pop(scene.newScene)
					scene.newLevel = other.level
					scene.newLevelTween = {value = 0}
					scene.newLevelTween.reference = scene.tween:to(scene.newLevelTween, 0.7, {value = 1})
					:delay(0.1)
					:ease('quadinout')
					:after(empty, 0.5, empty)
					:oncomplete(function()
						scene.newLevelTween = nil
					end)
					scene.newScene = newScene('scene.game')
					scene.newScene.transitionTween = scene.newLevelTween
					scene.newScene:enter(scene, other.level)
				end
				if not other then
					scene.newLevel = "pop"
				end
				e.travelTime = nil
				e.tween = nil
				scene.tiny:addEntity(e)
			end)
			:ease('quadin')
			scene.tiny:addEntity(e)
		end
	end

	return targetSystem
end