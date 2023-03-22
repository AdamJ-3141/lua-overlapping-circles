function find_intersections(circ1, circ2)
	local pos1 = circ1["pos"]
	local pos2 = circ2["pos"]
	local r1 = circ1["radius"]
	local r2 = circ2["radius"]
	local dist = (pos2 - pos1).Magnitude
	if dist * dist < (r1 - r2) ^ 2 or dist * dist > (r1 + r2) ^ 2 then
		return {nil, nil}
	end
	local v = (pos2 - pos1) / dist
	local a = 0.5 * (dist * dist + r1 * r1 - r2 * r2) / dist
	local h = math.sqrt(r1 * r1 - a * a)
	local pt1 = pos1 + v * a + Vector2.new(v.Y, -v.X) * h
	local pt2 = pos1 + v * a - Vector2.new(v.Y, -v.X) * h
	if pt1 == pt2 then
		return {nil, nil}
	end
	return {pt1, pt2}
end

function validate_point(circs, p, c1, c2)
	for index, circ in ipairs(circs) do
		if (circ["pos"] - p).Magnitude < circ["radius"] and index ~= c1 and index ~= c2 then
			return true
		end
	end
	return false
end

local function contains(tbl, val)
	for i=1,#tbl do
		if tbl[i] == val then 
			return true
		end
	end
	return false
end

function arc_angle(v2)
	return math.fmod(math.atan2(v2.Y, v2.X) + 2 * math.pi, 2 * math.pi)
end

function arrays_are_equal(array1, array2)
	local array1_copy = table.clone(array1)
	local array2_copy = table.clone(array2)
	table.sort(array1_copy)
	table.sort(array2_copy)

	if #array1_copy ~= #array2_copy then
		return false
	end

	for i = 1, #array1_copy do
		if array1_copy[i] ~= array2_copy[i] then
			return false
		end
	end

	return true
end


function connected_components(graph)
	local components = {}
	local visited = {}
	for node, _ in pairs(graph) do
		if not visited[node] then
			local component = {}
			local queue = {node}
			while #queue > 0 do
				local current = table.remove(queue, 1)
				if not visited[current] then
					visited[current] = true
					table.insert(component, current)
					for _, neighbor in pairs(graph[current]) do
						table.insert(queue, neighbor)
					end
				end
			end
			table.insert(components, component)
		end
	end
	return components
end


function get_subgraphs(graph)
	local subgraphs = {}
	local components = connected_components(graph)
	for _, component in pairs(components) do
		local subgraph = {}
		for _, node in pairs(component) do
			subgraph[node] = graph[node]
		end
		table.insert(subgraphs, subgraph)
	end
	return subgraphs
end


function generate_network(circles)
	local intersections = {}
	local int_points = {}
	local pops = 0

	for i = 1, #circles do
		intersections[i] = {}
	end

	for i = 1, #circles do
		for j = i + 1, #circles do
			local pts = {}
			for _, array in pairs(find_intersections(circles[i], circles[j])) do
				if not validate_point(circles, array, i, j) then
					table.insert(pts, array)
				end
			end
			for _, pt in pairs(pts) do
				table.insert(int_points, pt)
				table.insert(intersections[i], pt)
				table.insert(intersections[j], pt)
			end
		end
	end

	local node_value_dict = {}
	for ind, i in ipairs(circles) do
		node_value_dict[ind] = i["pos"]
	end
	for ind, i in ipairs(int_points) do
		node_value_dict[#circles + ind] = i
	end
	local value_node_dict = {}
	for k, v in pairs(node_value_dict) do
		value_node_dict[v] = k
	end

	local network = {}
	for k, v in pairs(intersections) do
		network[k] = {}
		for _, i in pairs(v) do
			table.insert(network[k], value_node_dict[i])
		end
	end

	for k, vlist in pairs(network) do
		for _, v in pairs(vlist) do
			if network[v] then
				if not contains(network[v], k) then
					table.insert(network[v], k)
				end
			else
				network[v] = {k}
			end
		end
	end


	local isolated_circles = {}
	for n, nbors in pairs(network) do
		if #nbors == 0 then
			table.insert(isolated_circles, n)
		end
	end


	local outer_isolated_circles = {}
	for _, k in pairs(isolated_circles) do
		if not validate_point(circles, circles[k]["pos"], k) then
			table.insert(outer_isolated_circles, k)
		end
	end
	return network, node_value_dict, outer_isolated_circles
end


function area_of_sectors(circles, network, node_value_dict, outer_isolated_circles)
	local total_sector_area = 0
	local outer_arcs = {}
	for ind, i in ipairs(circles) do
		
		local connections = {}
		for _, k in pairs(network[ind]) do
			table.insert(connections, {node_value_dict[k], k})
		end
		local center = i["pos"]
		local radius = i["radius"]
		local angles = {}
		for _, point in pairs(connections) do
			table.insert(angles, {arc_angle(point[1] - center), point[1], point[2]})
		end
		local function compare(a, b)
			return a[1] < b[1]
		end
		table.sort(angles, compare)
		local segments = {}
		for j = 1, #angles do
			table.insert(segments, {angles[j], angles[(j % #angles) + 1]})
		end

		local arc_midpoints = {}
		local exterior_arcs = {}
		for _, arc in pairs(segments) do
			local t1 = arc[1][1]
			local t2 = arc[2][1]
			local mp = (t1 + t2) / 2
			if t1 > t2 then
				mp += math.pi
			end
			if not validate_point(circles, Vector2.new(math.cos(mp), math.sin(mp)) * radius + center, ind) then
				outer_arcs[arc[1][3]] = {ind, arc[2][3]}
				total_sector_area = total_sector_area + 0.5 * radius ^ 2 * ((t2 - t1 + 2 * math.pi) % (2 * math.pi))
			end
		end
	end
	for _, node in pairs(outer_isolated_circles) do
		total_sector_area = total_sector_area + math.pi * circles[node]["radius"] ^ 2
	end
	return total_sector_area, outer_arcs
end


function area_of_polygons(circles, network, node_value_dict, outer_arcs)
	local subgraphs = get_subgraphs(network)
	local total_area = 0
	
	local function area(points)
		local n = #points
		local a = 0
		for i = 1, n do
			a = a + points[i].X * points[(i % n) + 1].Y - points[(i % n) + 1].X * points[i].Y
		end
		return math.abs(a / 2)
	end
	
	for _, graph in pairs(subgraphs) do

		local areas = {}
		local couples = {}
		local poly_crosses = {}
		local graphnodes = {}
		for node, nbors in pairs(graph) do
			table.insert(graphnodes, node)
			if #nbors > 2 then
				table.insert(poly_crosses, node)
			end
		end
		if #graphnodes <= 1 then
			continue
		end
		for start, couple in pairs(outer_arcs) do
			if contains(graphnodes, couple[2]) then
				couples[start] = couple
			end
		end
		local startnode
		local visited = {}
		for _, n in graphnodes do
			if n > #circles then
				startnode = n
				break
			end
		end
		--local startnode = graph[graphnodes[1]][1]
		while not arrays_are_equal(visited, graphnodes) do
			local path = {startnode}
			while path[#path] ~= startnode or #path == 1 do
				local c_from_dn = couples[path[#path]]
				for _, n in pairs(c_from_dn) do
					table.insert(path, n)
				end
			end
			table.remove(path, #path)
			local points = {}
			for _, n in pairs(path) do
				table.insert(points, node_value_dict[n])
				if not contains(visited, n) then
					table.insert(visited, n)
				end
			end
			table.insert(areas, area(points))
			for _, n in pairs(graphnodes) do
				if (not contains(visited, n)) and (n > #circles) then
					startnode = n
					break
				end
			end
		end
		local area_of_subgraph = math.max(table.unpack(areas))
		table.remove(areas, table.find(areas, area_of_subgraph))
		for _, a in pairs(areas) do
			area_of_subgraph -= a
		end
		total_area += area_of_subgraph
	end
	return total_area
end


function get_total_area(circles)
	local nw, nvd, oic = generate_network(circles)

	local A_s, arcs = area_of_sectors(circles, nw, nvd, oic)
	local A_p = area_of_polygons(circles, nw, nvd, arcs)
	return A_s + A_p
end

local circles = {
	{pos = Vector2.new(3560, -92), radius = 35},
	{pos = Vector2.new(3527, -80), radius = 37},
	{pos = Vector2.new(3495, -102), radius = 40},
	{pos = Vector2.new(3523, -132), radius = 43},
	{pos = Vector2.new(3563, -149), radius = 46},
	{pos = Vector2.new(3620, -209), radius = 50},
	{pos = Vector2.new(3682, -260), radius = 54},
	{pos = Vector2.new(3650, -92), radius = 30},
	{pos = Vector2.new(3610, -65), radius = 30},
	{pos = Vector2.new(3620, -125), radius = 20},
	{pos = Vector2.new(3200, -50), radius = 20},
	{pos = Vector2.new(3250, -40), radius = 20},
	{pos = Vector2.new(3230, -70), radius = 20},
	{pos = Vector2.new(3220, -20), radius = 20},
	{pos = Vector2.new(3370, -40), radius = 40},
	{pos = Vector2.new(3530, -110), radius = 20}
}


local time1 = tick()
local A = get_total_area(circles)
print("Time:", (tick()-time1)*1000, "ms")
print("Area:", A)


