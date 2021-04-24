local sizing = 0.9
return function (e)
	love.graphics.setColor(properties.color.level_end)
	local x, y, w, h = getScene().bump:getRect(e)
	-- love.graphics.rectangle('fill', x, y, w, h, 4, nil, 50)
	local tw, th = getScene().level.tilewidth, getScene().level.tileheight
	local hc, vc = 2, 2
	local mc = math.max(hc, vc)
	for dy = 1, vc do
		for dx = 1, hc do
			love.graphics.rectangle(
				'fill',
				x + w * (dx - 1 + (1 - sizing) / 2) / hc, y + h * (dy - 1 + (1 - sizing) / 2) / vc,
				tw / mc * sizing,
				th / mc * sizing,
				4, nil, 50
			)
		end
	end
end