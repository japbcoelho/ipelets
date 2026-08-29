----------------------------------------------------------------------
-- Circles 1.0.0
-- Copyright (C) 2026 japbcoelho
-- SPDX-License-Identifier: GPL-3.0-or-later
----------------------------------------------------------------------

label = "Circles"

about = [[
Circles 1.0.0

Circle, tangency, inversion, and radical constructions with live preview.
This standalone ipelet requires no other user ipelets.

Copyright (C) 2026 japbcoelho
License: GPL-3.0-or-later
]]

local _G = _G
local ipe = ipe
local ipeui = ipeui
local ipairs = _G.ipairs
local pairs = _G.pairs
local error = _G.error
local math = _G.math
local pcall = _G.pcall
local setmetatable = _G.setmetatable
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local unpack = table.unpack

local V = ipe.Vector
local EPS = 1e-9
local MACHINE_EPSILON = 2.220446049250313e-16

----------------------------------------------------------------------
-- Numeric and analytic circle geometry
----------------------------------------------------------------------

local M = (function()
  local api = {}

  local function number_value(value, fallback)
    if value == nil or value == "" then return fallback end
    if type(value) == "number" then return value end
    local ok, number = pcall(tonumber, value)
    if ok and number ~= nil then return number end
    return fallback
  end

  local function finite_number(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  local function options_table(options)
    if options == nil then return {} end
    if type(options) ~= "table" then error("options must be a table") end
    return options
  end

  local function finite_number_option(value, fallback, name)
    if value == nil or value == "" then value = fallback end
    local ok, number = true, value
    if type(value) ~= "number" then ok, number = pcall(tonumber, value) end
    if not ok or not finite_number(number) then
      error((name or "value") .. " must be a finite number")
    end
    return number
  end

  local function positive_number_option(value, fallback, name)
    local number = finite_number_option(value, fallback, name)
    if number <= 0 then error((name or "value") .. " must be positive") end
    return number
  end

  local function positive_integer_option(value, fallback, name, maximum)
    local number = finite_number_option(value, fallback, name)
    if number < 1 or number ~= math.floor(number) then
      error((name or "value") .. " must be an integer greater than or equal to 1")
    end
    if maximum and number > maximum then
      error((name or "value") .. " must be an integer between 1 and " .. tostring(maximum))
    end
    return number
  end

  local function bool_value(value, fallback)
    if value == nil then return fallback end
    if value == false or value == "false" or value == "0" or value == 0 then return false end
    return true
  end

  local function format_number(value, precision)
    precision = precision or 4
    if type(value) ~= "number" then value = number_value(value, 0) end
    if math.abs(value) < EPS then value = 0 end
    local text = string.format("%." .. tostring(precision) .. "f", value)
    text = text:gsub("0+$", ""):gsub("%.$", "")
    if text == "-0" then text = "0" end
    return text
  end

  local function point_from_table(point, name)
    name = name or "point"
    local function coordinate_value(key, fallback_key)
      local ok, value = pcall(function() return point[key] end)
      if ok and value ~= nil then return value end
      if fallback_key ~= nil then
        local ok_fallback, fallback = pcall(function() return point[fallback_key] end)
        if ok_fallback then return fallback end
      end
      return nil
    end
    if point == nil then error(name .. " must be a point table or vector") end
    local x = number_value(coordinate_value("x", 1), nil)
    local y = number_value(coordinate_value("y", 2), nil)
    if x == nil or y == nil then error(name .. " must contain x/y numbers") end
    if not finite_number(x) or not finite_number(y) then
      error(name .. " must contain finite x/y numbers")
    end
    return V(x, y)
  end

  local function clean_error_message(message)
    message = tostring(message or "")
    local cleaned = message:match("^%[string [^%]]+%]:%d+:%s*(.*)$")
    if cleaned and cleaned ~= "" then return cleaned end
    cleaned = message:match("^[^:]+:%d+:%s*(.*)$")
    if cleaned and cleaned ~= "" then return cleaned end
    return message
  end

  local function add(a, b) return V(a.x + b.x, a.y + b.y) end
  local function sub(a, b) return V(a.x - b.x, a.y - b.y) end
  local function scale(a, scalar) return V(a.x * scalar, a.y * scalar) end
  local function dot(a, b) return a.x * b.x + a.y * b.y end
  local function cross(a, b) return a.x * b.y - a.y * b.x end
  local function length(a) return math.sqrt(dot(a, a)) end
  local function distance(a, b) return length(sub(a, b)) end
  local function midpoint(a, b) return scale(add(a, b), 0.5) end
  local function perpendicular(a) return V(-a.y, a.x) end

  local function unit(a, context)
    local magnitude = length(a)
    if magnitude < EPS then error((context or "direction") .. " must be nonzero") end
    return scale(a, 1 / magnitude)
  end

  local function circle_from_table(circle, name)
    name = name or "circle"
    if type(circle) ~= "table" then error(name .. " must be a circle table") end
    local center = circle.center and point_from_table(circle.center, name .. ".center")
      or point_from_table(circle, name .. ".center")
    local radius = number_value(circle.radius or circle.r, nil)
    if radius == nil and circle.point then
      radius = distance(center, point_from_table(circle.point, name .. ".point"))
    end
    if not finite_number(radius) then error(name .. " must have a finite radius") end
    if radius <= EPS then error(name .. " must have a positive radius") end
    return { center = center, radius = radius }
  end

  local function line_from_table(line, name)
    name = name or "line"
    if type(line) ~= "table" then error(name .. " must be a line table") end
    local p1 = line.p1 or line.a or line[1]
    local p2 = line.p2 or line.b or line[2]
    if type(line.points) == "table" then
      p1 = p1 or line.points[1]
      p2 = p2 or line.points[2]
    end
    p1 = point_from_table(p1, name .. ".p1")
    p2 = point_from_table(p2, name .. ".p2")
    if distance(p1, p2) < EPS then error(name .. " endpoints must be distinct") end
    return { p1 = p1, p2 = p2 }
  end

  local function point_record(point) return { x = point.x, y = point.y } end

  local function image_record(image)
    if image.type == "circle" then
      return { type = "circle", center = point_record(image.center), radius = image.radius }
    end
    if image.type == "line" then
      return {
        type = "line",
        point = point_record(image.point),
        direction = point_record(unit(image.direction, "line direction")),
      }
    end
    return image
  end

  local function project_point_to_line(point, line)
    local direction = sub(line.p2, line.p1)
    local denominator = dot(direction, direction)
    if math.sqrt(denominator) < EPS then error("line endpoints must be distinct") end
    local t = dot(sub(point, line.p1), direction) / denominator
    return add(line.p1, scale(direction, t))
  end

  local function line_segment_from_infinite(point, direction, requested_length)
    requested_length = positive_number_option(requested_length, 192, "line length")
    local direction_unit = unit(direction, "line direction")
    local half = scale(direction_unit, requested_length / 2)
    return { p1 = sub(point, half), p2 = add(point, half) }
  end

  local function invert_point(point, inversion_circle)
    point = point_from_table(point, "point")
    inversion_circle = circle_from_table(inversion_circle, "inversion_circle")
    local from_center = sub(point, inversion_circle.center)
    local distance2 = dot(from_center, from_center)
    if math.sqrt(distance2) < EPS then error("the inversion center cannot be inverted") end
    local factor = (inversion_circle.radius * inversion_circle.radius) / distance2
    return add(inversion_circle.center, scale(from_center, factor))
  end

  local function invert_line(line, inversion_circle)
    line = line_from_table(line, "line")
    inversion_circle = circle_from_table(inversion_circle, "inversion_circle")
    local foot = project_point_to_line(inversion_circle.center, line)
    if distance(foot, inversion_circle.center) < EPS then
      return { type = "line", point = inversion_circle.center, direction = sub(line.p2, line.p1) }
    end
    local inverted_foot = invert_point(foot, inversion_circle)
    return {
      type = "circle",
      center = midpoint(inversion_circle.center, inverted_foot),
      radius = distance(inversion_circle.center, inverted_foot) / 2,
    }
  end

  local function invert_circle(source_circle, inversion_circle)
    source_circle = circle_from_table(source_circle, "source_circle")
    inversion_circle = circle_from_table(inversion_circle, "inversion_circle")
    local offset = sub(source_circle.center, inversion_circle.center)
    local distance2 = dot(offset, offset)
    local radius2 = source_circle.radius * source_circle.radius
    local inversion_power = inversion_circle.radius * inversion_circle.radius
    local denominator = distance2 - radius2
    if math.abs(denominator) < EPS * math.max(distance2, radius2) then
      local foot = add(inversion_circle.center, scale(offset, inversion_power / (2 * distance2)))
      return { type = "line", point = foot, direction = perpendicular(offset) }
    end
    local factor = inversion_power / denominator
    return {
      type = "circle",
      center = add(inversion_circle.center, scale(offset, factor)),
      radius = math.abs(factor) * source_circle.radius,
    }
  end

  local function radical_axis(circle_a, circle_b)
    circle_a = circle_from_table(circle_a, "circle_a")
    circle_b = circle_from_table(circle_b, "circle_b")
    local offset = sub(circle_b.center, circle_a.center)
    local distance2 = dot(offset, offset)
    if math.sqrt(distance2) < EPS then error("radical axis is undefined for concentric circles") end
    local t = (distance2 + circle_a.radius * circle_a.radius - circle_b.radius * circle_b.radius)
      / (2 * distance2)
    return {
      point = add(circle_a.center, scale(offset, t)),
      direction = unit(perpendicular(offset), "radical axis direction"),
    }
  end

  local function radical_center(circle_a, circle_b, circle_c)
    circle_a = circle_from_table(circle_a, "circle_a")
    circle_b = circle_from_table(circle_b, "circle_b")
    circle_c = circle_from_table(circle_c, "circle_c")
    local offset_b = sub(circle_b.center, circle_a.center)
    local offset_c = sub(circle_c.center, circle_a.center)
    local a1, b1 = 2 * offset_b.x, 2 * offset_b.y
    local c1 = dot(offset_b, offset_b) + circle_a.radius ^ 2 - circle_b.radius ^ 2
    local a2, b2 = 2 * offset_c.x, 2 * offset_c.y
    local c2 = dot(offset_c, offset_c) + circle_a.radius ^ 2 - circle_c.radius ^ 2
    local determinant = a1 * b2 - a2 * b1
    local row1_length = math.sqrt(a1 * a1 + b1 * b1)
    local row2_length = math.sqrt(a2 * a2 + b2 * b2)
    if row1_length < EPS or row2_length < EPS
      or math.abs(determinant) <= EPS * row1_length * row2_length then
      error("radical center is undefined for dependent radical axes")
    end
    return add(circle_a.center, V(
      (c1 * b2 - c2 * b1) / determinant,
      (a1 * c2 - a2 * c1) / determinant
    ))
  end

  local function orthogonal_circle(center, reference_circle)
    center = point_from_table(center, "center")
    reference_circle = circle_from_table(reference_circle, "reference_circle")
    local center_distance = distance(center, reference_circle.center)
    local boundary_tolerance = EPS * math.max(center_distance, reference_circle.radius)
    if center_distance <= reference_circle.radius + boundary_tolerance then
      error("orthogonal circle center must be outside the reference circle")
    end
    return {
      center = center,
      radius = math.sqrt(center_distance ^ 2 - reference_circle.radius ^ 2),
    }
  end

  local function tangent_record(tangent)
    local direction = tangent.direction or sub(tangent.to, tangent.from)
    local result = {
      kind = tangent.kind,
      from = point_record(tangent.from),
      to = point_record(tangent.to),
      direction = point_record(unit(direction, "tangent direction")),
    }
    if tangent.point then result.point = point_record(tangent.point) end
    return result
  end

  local function point_circle_tangents(point, circle)
    point = point_from_table(point, "point")
    circle = circle_from_table(circle, "circle")
    local offset = sub(point, circle.center)
    local distance2 = dot(offset, offset)
    local radius2 = circle.radius ^ 2
    local gap = distance2 - radius2
    local boundary_tolerance = EPS * math.max(distance2, radius2)
    if gap < -boundary_tolerance then error("point is inside the circle") end
    local base = add(circle.center, scale(offset, radius2 / distance2))
    local tangent_scale = math.max(circle.radius, math.sqrt(distance2))
    if math.abs(gap) <= boundary_tolerance then
      return {{
        kind = "point",
        from = point,
        to = base,
        point = base,
        direction = unit(perpendicular(offset), "tangent direction"),
        scale = tangent_scale,
      }}
    end
    local h = math.sqrt(radius2 * gap / (distance2 * distance2))
    local normal = perpendicular(offset)
    local first = add(base, scale(normal, h))
    local second = sub(base, scale(normal, h))
    return {
      {
        kind = "point", from = point, to = first, point = first,
        direction = unit(sub(first, point), "tangent direction"), scale = tangent_scale,
      },
      {
        kind = "point", from = point, to = second, point = second,
        direction = unit(sub(second, point), "tangent direction"), scale = tangent_scale,
      },
    }
  end

  local function circle_circle_tangents(circle_a, circle_b, options)
    circle_a = circle_from_table(circle_a, "circle_a")
    circle_b = circle_from_table(circle_b, "circle_b")
    options = options or {}
    local mode = tostring(options.mode or "all"):lower()
    local signs
    if mode == "external" then
      signs = { 1 }
    elseif mode == "internal" then
      signs = { -1 }
    elseif mode == "all" then
      signs = { 1, -1 }
    else
      error("unsupported circle-circle tangent mode: " .. mode)
    end
    local offset = sub(circle_b.center, circle_a.center)
    local distance2 = dot(offset, offset)
    local center_distance = math.sqrt(distance2)
    if center_distance < EPS then error("circle centers must be distinct") end
    local tangent_scale = math.max(center_distance, circle_a.radius, circle_b.radius)
    local tangents = {}
    for _, sign in ipairs(signs) do
      local radius_delta = circle_a.radius - sign * circle_b.radius
      local radius_delta2 = radius_delta ^ 2
      local h2 = distance2 - radius_delta2
      local h2_tolerance = EPS * math.max(distance2, radius_delta2)
      if h2 >= -h2_tolerance then
        local degenerate = math.abs(h2) <= h2_tolerance
        local h = degenerate and 0 or math.sqrt(h2)
        for _, side in ipairs({ -1, 1 }) do
          if not degenerate or side == 1 then
            local normal = scale(
              add(scale(offset, radius_delta), scale(perpendicular(offset), h * side)),
              1 / distance2
            )
            local from = add(circle_a.center, scale(normal, circle_a.radius))
            local to = add(circle_b.center, scale(normal, sign * circle_b.radius))
            local direction = degenerate and perpendicular(offset) or sub(to, from)
            tangents[#tangents + 1] = {
              kind = sign == 1 and "external" or "internal",
              from = from,
              to = to,
              direction = unit(direction, "tangent direction"),
              scale = tangent_scale,
            }
          end
        end
      end
    end
    if #tangents == 0 then error("the requested circle tangents do not exist") end
    return tangents
  end

  local function circle_line_tangents(circle, line, options)
    circle = circle_from_table(circle, "circle")
    line = line_from_table(line, "line")
    options = options or {}
    local mode = tostring(options.mode or "parallel"):lower()
    if mode ~= "parallel" and mode ~= "perpendicular" then
      error("unsupported circle-line tangent mode: " .. mode)
    end
    local requested_length = positive_number_option(options.length or options.line_length, 192, "line_length")
    local base_direction = unit(sub(line.p2, line.p1), "reference line direction")
    local tangent_direction = base_direction
    local normal = perpendicular(base_direction)
    local kind = "parallel"
    if mode == "perpendicular" then
      tangent_direction = perpendicular(base_direction)
      normal = base_direction
      kind = "perpendicular"
    end
    local tangents = {}
    for _, side in ipairs({ 1, -1 }) do
      local point = add(circle.center, scale(normal, circle.radius * side))
      local segment = line_segment_from_infinite(point, tangent_direction, requested_length)
      tangents[#tangents + 1] = {
        kind = kind,
        from = segment.p1,
        to = segment.p2,
        point = point,
        direction = tangent_direction,
        scale = math.max(circle.radius, requested_length),
      }
    end
    return tangents
  end

  local function line_normal(line)
    return perpendicular(unit(sub(line.p2, line.p1), "line direction"))
  end

  local function determinant3(matrix)
    return matrix[1][1] * (matrix[2][2] * matrix[3][3] - matrix[2][3] * matrix[3][2])
      - matrix[1][2] * (matrix[2][1] * matrix[3][3] - matrix[2][3] * matrix[3][1])
      + matrix[1][3] * (matrix[2][1] * matrix[3][2] - matrix[2][2] * matrix[3][1])
  end

  local function solve_3x3(matrix, rhs)
    local normalized, normalized_rhs = {}, {}
    for row = 1, 3 do
      local row_scale = math.max(math.abs(matrix[row][1]), math.abs(matrix[row][2]), math.abs(matrix[row][3]))
      if not finite_number(row_scale) or row_scale == 0 then return nil end
      normalized[row] = {
        matrix[row][1] / row_scale,
        matrix[row][2] / row_scale,
        matrix[row][3] / row_scale,
      }
      normalized_rhs[row] = rhs[row] / row_scale
    end
    local determinant = determinant3(normalized)
    if not finite_number(determinant) or math.abs(determinant) < 1e-12 then return nil end
    local mx = {
      { normalized_rhs[1], normalized[1][2], normalized[1][3] },
      { normalized_rhs[2], normalized[2][2], normalized[2][3] },
      { normalized_rhs[3], normalized[3][2], normalized[3][3] },
    }
    local my = {
      { normalized[1][1], normalized_rhs[1], normalized[1][3] },
      { normalized[2][1], normalized_rhs[2], normalized[2][3] },
      { normalized[3][1], normalized_rhs[3], normalized[3][3] },
    }
    local mr = {
      { normalized[1][1], normalized[1][2], normalized_rhs[1] },
      { normalized[2][1], normalized[2][2], normalized_rhs[2] },
      { normalized[3][1], normalized[3][2], normalized_rhs[3] },
    }
    return { determinant3(mx) / determinant, determinant3(my) / determinant, determinant3(mr) / determinant }
  end

  local function normalize_tangent_circle_constraint(constraint, index)
    if type(constraint) ~= "table" then error("constraint " .. tostring(index) .. " must be a table") end
    local constraint_type = tostring(constraint.type or constraint.kind or ""):lower()
    if constraint_type == "point" then
      return {
        type = "point",
        point = point_from_table(constraint.point or constraint, "constraint[" .. tostring(index) .. "].point"),
      }
    end
    if constraint_type == "line" then
      local line = line_from_table(constraint.line or constraint, "constraint[" .. tostring(index) .. "].line")
      return {
        type = "line", line = line, normal = line_normal(line),
        side = number_value(constraint.side, 1) < 0 and -1 or 1,
      }
    end
    if constraint_type == "circle" or constraint.center or constraint.radius or constraint.r then
      return {
        type = "circle",
        circle = circle_from_table(constraint.circle or constraint, "constraint[" .. tostring(index) .. "].circle"),
        sign = number_value(constraint.sign, 1) < 0 and -1 or 1,
      }
    end
    error("unsupported tangent-circle constraint type")
  end

  local function tangent_circle_constraint_value(constraint, x, y, radius)
    if constraint.type == "point" then
      local dx, dy = x - constraint.point.x, y - constraint.point.y
      return dx * dx + dy * dy - radius * radius, { 2 * dx, 2 * dy, -2 * radius }
    end
    if constraint.type == "circle" then
      local circle = constraint.circle
      local dx, dy = x - circle.center.x, y - circle.center.y
      local signed_radius = radius + constraint.sign * circle.radius
      return dx * dx + dy * dy - signed_radius * signed_radius,
        { 2 * dx, 2 * dy, -2 * signed_radius }
    end
    local normal = constraint.normal
    local signed_distance = normal.x * (x - constraint.line.p1.x)
      + normal.y * (y - constraint.line.p1.y)
    return signed_distance - constraint.side * radius,
      { normal.x, normal.y, -constraint.side }
  end

  local function tangent_circle_residuals(constraints, x, y, radius)
    local values, jacobian = {}, {}
    local max_residual = 0
    for index, constraint in ipairs(constraints) do
      local value, derivative = tangent_circle_constraint_value(constraint, x, y, radius)
      values[index], jacobian[index] = -value, derivative
      local residual_scale = 1
      if constraint.type == "point" then
        residual_scale = math.max(
          math.sqrt((x - constraint.point.x) ^ 2 + (y - constraint.point.y) ^ 2) + math.abs(radius), EPS)
      elseif constraint.type == "circle" then
        local circle = constraint.circle
        residual_scale = math.max(
          math.sqrt((x - circle.center.x) ^ 2 + (y - circle.center.y) ^ 2)
            + math.abs(radius + constraint.sign * circle.radius), EPS)
      end
      max_residual = math.max(max_residual, math.abs(value) / residual_scale)
    end
    return values, jacobian, max_residual
  end

  local function tangent_circle_anchor_bounds(constraints)
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    local radius_sum, count, max_coordinate = 0, 0, 1
    local function add_point(point)
      min_x, min_y = math.min(min_x, point.x), math.min(min_y, point.y)
      max_x, max_y = math.max(max_x, point.x), math.max(max_y, point.y)
      max_coordinate = math.max(max_coordinate, math.abs(point.x), math.abs(point.y))
      count = count + 1
    end
    for _, constraint in ipairs(constraints) do
      if constraint.type == "point" then
        add_point(constraint.point)
      elseif constraint.type == "circle" then
        add_point(constraint.circle.center)
        radius_sum = radius_sum + constraint.circle.radius
      elseif constraint.type == "line" then
        add_point(constraint.line.p1)
        add_point(constraint.line.p2)
      end
    end
    if count == 0 then min_x, min_y, max_x, max_y = -1, -1, 1, 1 end
    local span = math.max(max_x - min_x, max_y - min_y, radius_sum)
    if not finite_number(span) or span <= 0 then span = 1 end
    return {
      min_x = min_x, min_y = min_y, max_x = max_x, max_y = max_y,
      center = V(min_x + (max_x - min_x) / 2, min_y + (max_y - min_y) / 2),
      span = span, max_coordinate = max_coordinate,
    }
  end

  local function tangent_circle_normalized_constraints(constraints)
    local bounds = tangent_circle_anchor_bounds(constraints)
    local origin, normalization_scale = bounds.center, bounds.span
    local function normalized_point(point)
      return V((point.x - origin.x) / normalization_scale, (point.y - origin.y) / normalization_scale)
    end
    local normalized = {}
    for index, constraint in ipairs(constraints) do
      if constraint.type == "point" then
        normalized[index] = { type = "point", point = normalized_point(constraint.point) }
      elseif constraint.type == "circle" then
        normalized[index] = {
          type = "circle",
          circle = { center = normalized_point(constraint.circle.center), radius = constraint.circle.radius / normalization_scale },
          sign = constraint.sign,
        }
      else
        normalized[index] = {
          type = "line",
          line = { p1 = normalized_point(constraint.line.p1), p2 = normalized_point(constraint.line.p2) },
          side = constraint.side,
        }
        normalized[index].normal = line_normal(normalized[index].line)
      end
    end
    local coordinate_tolerance = math.max(1e-15, 4 * MACHINE_EPSILON * bounds.max_coordinate / normalization_scale)
    return normalized, origin, normalization_scale, coordinate_tolerance
  end

  local function tangent_circle_seed_list(constraints)
    local bounds, seeds = tangent_circle_anchor_bounds(constraints), {}
    local offsets = { -1.5, -0.5, 0, 0.5, 1.5 }
    local radii = { bounds.span / 6, bounds.span / 3, bounds.span / 2, bounds.span, bounds.span * 1.5 }
    for _, ox in ipairs(offsets) do
      for _, oy in ipairs(offsets) do
        for _, radius in ipairs(radii) do
          seeds[#seeds + 1] = {
            x = bounds.center.x + ox * bounds.span,
            y = bounds.center.y + oy * bounds.span,
            radius = radius,
          }
        end
      end
    end
    return seeds
  end

  local function tangent_circle_solve_from_seed(constraints, seed, options)
    local x, y, radius = seed.x, seed.y, seed.radius
    local tolerance = positive_number_option(options.tolerance, 1e-7, "tolerance")
    local solver_scale = math.max(1, tangent_circle_anchor_bounds(constraints).span)
    -- The constraints have already been translated and scaled.  Absolute
    -- coordinate uncertainty belongs to output validation, not to Newton's
    -- stopping rule; using it here would accept several nearby seed states as
    -- different solutions for small geometry far from the origin.
    local effective_tolerance = tolerance * solver_scale
    local max_iterations = positive_integer_option(options.max_iterations, 50, "max_iterations", 200)
    for _ = 1, max_iterations do
      if radius <= EPS then radius = math.abs(radius) + 1 end
      local rhs, jacobian, residual = tangent_circle_residuals(constraints, x, y, radius)
      if residual < effective_tolerance then
        return { center = V(x, y), radius = radius, residual = residual }
      end
      local delta = solve_3x3(jacobian, rhs)
      if not delta then return nil end
      x, y, radius = x + delta[1], y + delta[2], radius + delta[3]
      if not finite_number(x) or not finite_number(y) or not finite_number(radius) then return nil end
      if math.abs(delta[1]) + math.abs(delta[2]) + math.abs(delta[3]) < effective_tolerance then
        local _, _, final_residual = tangent_circle_residuals(constraints, x, y, radius)
        if final_residual < effective_tolerance and radius > EPS then
          return { center = V(x, y), radius = radius, residual = final_residual }
        end
      end
    end
    return nil
  end

  local function tangent_circle_is_duplicate(circles, circle, tolerance)
    for _, existing in ipairs(circles) do
      if distance(existing.center, circle.center) < tolerance
        and math.abs(existing.radius - circle.radius) < tolerance then return true end
    end
    return false
  end

  local function tangent_circle_solution_is_valid(circle, constraints, tolerance)
    for _, constraint in ipairs(constraints) do
      if constraint.type == "circle" and constraint.sign < 0
        and distance(circle.center, constraint.circle.center) <= tolerance
        and math.abs(circle.radius - constraint.circle.radius) <= tolerance then return false end
    end
    return true
  end

  local function tangent_circles_from_constraints(constraints, options)
    options = options or {}
    if type(constraints) ~= "table" or #constraints ~= 3 then
      error("exactly three tangent-circle constraints are required")
    end
    local normalized = {}
    for index, constraint in ipairs(constraints) do
      normalized[index] = normalize_tangent_circle_constraint(constraint, index)
    end
    local solver_constraints, origin, normalization_scale, coordinate_tolerance =
      tangent_circle_normalized_constraints(normalized)
    local solver_options = {}
    for key, value in pairs(options) do solver_options[key] = value end
    solver_options.coordinate_tolerance = math.max(
      coordinate_tolerance,
      finite_number(options.coordinate_tolerance) and options.coordinate_tolerance or 0)
    local validation_tolerance = math.max(
      10 * positive_number_option(options.tolerance, 1e-7, "tolerance"),
      10 * solver_options.coordinate_tolerance)
    local duplicate_tolerance = positive_number_option(options.duplicate_tolerance, 1e-4, "duplicate_tolerance")
    local max_solutions = positive_integer_option(options.max_solutions, 16, "max_solutions", 128)
    local solutions = {}
    for _, seed in ipairs(tangent_circle_seed_list(solver_constraints)) do
      local solution = tangent_circle_solve_from_seed(solver_constraints, seed, solver_options)
      if solution and solution.radius > EPS
        and tangent_circle_solution_is_valid(solution, solver_constraints, validation_tolerance)
        and not tangent_circle_is_duplicate(solutions, solution, duplicate_tolerance) then
        solutions[#solutions + 1] = solution
        if #solutions >= max_solutions then break end
      end
    end
    if #solutions == 0 then error("no tangent circle satisfies the requested constraints") end
    local result = {}
    for index, solution in ipairs(solutions) do
      result[index] = {
        center = add(origin, scale(solution.center, normalization_scale)),
        radius = solution.radius * normalization_scale,
        residual = solution.residual * normalization_scale,
      }
    end
    return result
  end

  local function tangent_circle_constraint_tangency_point(tangent_circle, constraint)
    tangent_circle = circle_from_table(tangent_circle, "tangent_circle")
    constraint = normalize_tangent_circle_constraint(constraint, 1)
    if constraint.type == "point" then return constraint.point end
    if constraint.type == "line" then return project_point_to_line(tangent_circle.center, constraint.line) end
    local reference = constraint.circle
    local center_offset = sub(reference.center, tangent_circle.center)
    local center_distance = length(center_offset)
    if center_distance < EPS then return nil end
    local direction = scale(center_offset, 1 / center_distance)
    if constraint.sign < 0 and tangent_circle.radius < reference.radius then direction = scale(direction, -1) end
    return add(tangent_circle.center, scale(direction, tangent_circle.radius))
  end

  local function point_is_duplicate(points, point, tolerance)
    tolerance = tolerance or 1e-6
    for _, existing in ipairs(points) do
      if distance(existing, point) < tolerance then return true end
    end
    return false
  end

  local function tangent_circle_tangency_points(tangent_circle, constraints, options)
    options = options or {}
    local points = {}
    local relative_tolerance = positive_number_option(options.duplicate_tolerance, 1e-6, "duplicate_tolerance")
    local tolerance = relative_tolerance * tangent_circle_anchor_bounds(constraints or {}).span
    for _, constraint in ipairs(constraints or {}) do
      local ok, point = pcall(tangent_circle_constraint_tangency_point, tangent_circle, constraint)
      if ok and point and not point_is_duplicate(points, point, tolerance) then points[#points + 1] = point end
    end
    return points
  end

  local function tangent_circle_mark_option(options, fallback)
    options = options or {}
    local value = options.tangent_points
    if value == nil then value = options.tangency_marks end
    return bool_value(value, fallback)
  end

  local function circumcenter(a, b, c)
    local ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
    local signed_area2 = cross(ab, ac)
    local scale2 = math.max(dot(ab, ab), dot(ac, ac), dot(bc, bc))
    if scale2 == 0 or math.abs(signed_area2) <= EPS * scale2 then return nil end
    local ab2, ac2 = dot(ab, ab), dot(ac, ac)
    local denominator = 2 * signed_area2
    return add(a, V(
      (ab2 * ac.y - ac2 * ab.y) / denominator,
      (ab.x * ac2 - ac.x * ab2) / denominator))
  end

  local function circle_from_center_point(center, point)
    center, point = point_from_table(center, "center"), point_from_table(point, "point")
    local radius = distance(center, point)
    if radius < EPS then error("center and point must be distinct") end
    return { center = center, radius = radius }
  end

  local function circle_from_diameter(p1, p2)
    p1, p2 = point_from_table(p1, "p1"), point_from_table(p2, "p2")
    if distance(p1, p2) < EPS then error("diameter endpoints must be distinct") end
    return { center = midpoint(p1, p2), radius = distance(p1, p2) / 2 }
  end

  local function circles_through_two_points_radius(p1, p2, radius)
    p1, p2 = point_from_table(p1, "p1"), point_from_table(p2, "p2")
    radius = positive_number_option(radius, nil, "radius")
    local offset, point_distance = sub(p2, p1), distance(p1, p2)
    if point_distance < EPS then error("circle points must be distinct") end
    local tolerance = EPS * math.max(point_distance, 2 * radius)
    if point_distance > 2 * radius + tolerance then return {} end
    local center = midpoint(p1, p2)
    if math.abs(point_distance - 2 * radius) <= tolerance then return {{ center = center, radius = radius }} end
    local height = math.sqrt(math.max(0, radius ^ 2 - point_distance ^ 2 / 4))
    local normal = unit(perpendicular(offset), "circle center direction")
    return {
      { center = add(center, scale(normal, height)), radius = radius },
      { center = sub(center, scale(normal, height)), radius = radius },
    }
  end

  local function circle_power_polar(circle, point)
    circle, point = circle_from_table(circle, "circle"), point_from_table(point, "point")
    local radial, distance2 = sub(point, circle.center), nil
    distance2 = dot(radial, radial)
    local result = { power = distance2 - circle.radius ^ 2 }
    if math.sqrt(distance2) >= EPS then
      result.polar = {
        point = add(circle.center, scale(radial, circle.radius ^ 2 / distance2)),
        direction = unit(perpendicular(radial), "polar direction"),
      }
    end
    return result
  end

  local function circle_pole_of_line(circle, line)
    circle, line = circle_from_table(circle, "circle"), line_from_table(line, "line")
    local foot = project_point_to_line(circle.center, line)
    local normal = sub(foot, circle.center)
    local distance2 = dot(normal, normal)
    local center_tolerance = EPS * math.max(1, circle.radius)
    if distance2 <= center_tolerance ^ 2 then
      error("pole is undefined for a line through the circle center")
    end
    return {
      point = add(circle.center, scale(normal, circle.radius ^ 2 / distance2)),
      foot = foot,
    }
  end

  local function circle_homothety_centers(circle_a, circle_b)
    circle_a, circle_b = circle_from_table(circle_a, "circle_a"), circle_from_table(circle_b, "circle_b")
    local offset = sub(circle_b.center, circle_a.center)
    local result = { internal = add(circle_a.center, scale(offset, circle_a.radius / (circle_a.radius + circle_b.radius))) }
    local radius_difference = circle_a.radius - circle_b.radius
    if math.abs(radius_difference) > EPS * math.max(circle_a.radius, circle_b.radius) then
      result.external = add(circle_a.center, scale(offset, circle_a.radius / radius_difference))
    end
    return result
  end

  local function circle_through_three_points(a, b, c)
    a, b, c = point_from_table(a, "a"), point_from_table(b, "b"), point_from_table(c, "c")
    local center = circumcenter(a, b, c)
    if not center then error("three points must not be collinear") end
    return { center = center, radius = distance(center, a) }
  end

  local TWO_PI = 2 * math.pi
  local function vector_angle(vector) return math.atan(vector.y, vector.x) end
  local function normalize_angle(value, reference)
    while value < reference do value = value + TWO_PI end
    while value >= reference + TWO_PI do value = value - TWO_PI end
    return value
  end

  local function arc_through_three_points(a, b, c)
    a, b, c = point_from_table(a, "a"), point_from_table(b, "b"), point_from_table(c, "c")
    local circle = circle_through_three_points(a, b, c)
    local ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
    local side = cross(ab, ac)
    local scale2 = math.max(dot(ab, ab), dot(ac, ac), dot(bc, bc))
    if scale2 == 0 or math.abs(side) <= EPS * scale2 then error("arc points must not be collinear") end
    local sign = side < 0 and -1 or 1
    local alpha = sign * vector_angle(sub(a, circle.center))
    local beta = sign * normalize_angle(vector_angle(sub(c, circle.center)), alpha)
    return {
      center = circle.center, radius = circle.radius, start = a, through = b, finish = c,
      alpha = alpha, beta = beta,
      orientation = sign < 0 and "clockwise" or "counterclockwise",
    }
  end

  local function normalized_option_name(value)
    return tostring(value or ""):lower():gsub("[%s%-]+", "_")
  end

  api.number_value = number_value
  api.finite_number = finite_number
  api.options_table = options_table
  api.finite_number_option = finite_number_option
  api.positive_number_option = positive_number_option
  api.positive_integer_option = positive_integer_option
  api.bool_value = bool_value
  api.format_number = format_number
  api.point_from_table = point_from_table
  api.clean_error_message = clean_error_message
  api.add, api.sub, api.scale = add, sub, scale
  api.dot, api.cross = dot, cross
  api.length, api.distance, api.midpoint = length, distance, midpoint
  api.perpendicular, api.unit = perpendicular, unit
  api.circle_from_table, api.line_from_table = circle_from_table, line_from_table
  api.point_record, api.image_record = point_record, image_record
  api.project_point_to_line, api.line_segment_from_infinite = project_point_to_line, line_segment_from_infinite
  api.invert_point, api.invert_line, api.invert_circle = invert_point, invert_line, invert_circle
  api.radical_axis, api.radical_center, api.orthogonal_circle = radical_axis, radical_center, orthogonal_circle
  api.tangent_record = tangent_record
  api.point_circle_tangents = point_circle_tangents
  api.circle_circle_tangents = circle_circle_tangents
  api.circle_line_tangents = circle_line_tangents
  api.tangent_circle_anchor_bounds = tangent_circle_anchor_bounds
  api.tangent_circle_normalized_constraints = tangent_circle_normalized_constraints
  api.tangent_circle_is_duplicate = tangent_circle_is_duplicate
  api.tangent_circle_solution_is_valid = tangent_circle_solution_is_valid
  api.tangent_circles_from_constraints = tangent_circles_from_constraints
  api.tangent_circle_tangency_points = tangent_circle_tangency_points
  api.tangent_circle_mark_option = tangent_circle_mark_option
  api.circle_from_center_point = circle_from_center_point
  api.circle_from_diameter = circle_from_diameter
  api.circles_through_two_points_radius = circles_through_two_points_radius
  api.circle_power_polar = circle_power_polar
  api.circle_pole_of_line = circle_pole_of_line
  api.circle_homothety_centers = circle_homothety_centers
  api.circle_through_three_points = circle_through_three_points
  api.arc_through_three_points = arc_through_three_points
  api.normalized_option_name = normalized_option_name
  return api
end)()

----------------------------------------------------------------------
-- Ipe selection, object creation, and circle construction workflows
----------------------------------------------------------------------

local R = (function(M)
  local api = {}

  local DEFAULT_PATH_ATTRIBUTES = {
    stroke = "black",
    pen = "normal",
    linecap = "normal",
    linejoin = "miter",
  }
  local DEFAULT_MARK_ATTRIBUTES = {
    stroke = "black",
    fill = "white",
    symbolsize = "normal",
    markshape = "mark/disk(sx)",
  }
  local DEFAULT_TEXT_ATTRIBUTES = {
    stroke = "black",
    textsize = "normal",
    horizontalalignment = "left",
    verticalalignment = "baseline",
  }

  local function clone_attributes(attributes)
    local cloned = {}
    for key, value in pairs(attributes or {}) do cloned[key] = value end
    return cloned
  end

  local function active_attributes(model, fallback, overrides)
    local source = model and type(model.attributes) == "table" and model.attributes or fallback
    local attributes = clone_attributes(source)
    for key, value in pairs(overrides or {}) do attributes[key] = value end
    return attributes
  end

  local function construction_styles(model)
    local path = active_attributes(model, DEFAULT_PATH_ATTRIBUTES)
    return {
      path = path,
      dashed = active_attributes(model, DEFAULT_PATH_ATTRIBUTES, { dashstyle = "dashed" }),
      dotted = active_attributes(model, DEFAULT_PATH_ATTRIBUTES, { dashstyle = "dotted" }),
      mark = active_attributes(model, DEFAULT_MARK_ATTRIBUTES),
      text = active_attributes(model, DEFAULT_TEXT_ATTRIBUTES),
      markshape = path.markshape or DEFAULT_MARK_ATTRIBUTES.markshape,
    }
  end

  local function selected_objects(model)
    local page = model:page()
    local objects = {}
    for index, object, selected, layer in page:objects() do
      if selected and page:visible(model.vno, index) then
        objects[#objects + 1] = { index = index, object = object, layer = layer }
      end
    end
    return objects
  end

  local function object_type(object)
    local ok, value = pcall(function() return object:type() end)
    return ok and value or nil
  end

  local function reference_position(object)
    if object_type(object) ~= "reference" then return nil end
    local ok_symbol, symbol = pcall(function() return object:symbol() end)
    if not ok_symbol or type(symbol) ~= "string" or symbol:sub(1, 5) ~= "mark/" then return nil end
    local ok, position = pcall(function() return object:position() end)
    if not ok or not position then return nil end
    local ok_transformed, transformed = pcall(function() return object:matrix() * position end)
    if ok_transformed and transformed then return transformed end
    return position
  end

  local function path_shape(object)
    if object_type(object) ~= "path" then return nil end
    local ok, shape = pcall(function() return object:shape() end)
    return ok and shape or nil
  end

  local function single_segment_from_path(object)
    local shape = path_shape(object)
    if not shape or #shape ~= 1 then return nil end
    local curve = shape[1]
    if curve.type ~= "curve" or curve.closed or #curve ~= 1 then return nil end
    local segment = curve[1]
    if segment.type ~= "segment" then return nil end
    local matrix = object:matrix()
    return matrix * segment[1], matrix * segment[2]
  end

  local function circle_from_path(object)
    local shape = path_shape(object)
    if not shape or #shape ~= 1 then return nil end
    local ellipse = shape[1]
    if ellipse.type ~= "ellipse" then return nil end
    local matrix = object:matrix() * ellipse[1]
    local a, c, b, d, tx, ty = unpack(matrix:coeff())
    local x_axis, y_axis = V(a, c), V(b, d)
    local rx, ry = M.length(x_axis), M.length(y_axis)
    if rx < EPS or ry < EPS then return nil end
    local relative_tolerance = 1e-6
    if math.abs(rx - ry) > relative_tolerance * math.max(rx, ry) then return nil end
    if math.abs(M.dot(x_axis, y_axis)) > relative_tolerance * rx * ry then return nil end
    return { center = V(tx, ty), radius = (rx + ry) / 2 }
  end

  local function matrix_translation(matrix)
    local ok_translation, translation = pcall(function() return matrix:translation() end)
    if ok_translation and translation then return translation end
    local ok_coefficients, a, b, c, d, tx, ty = pcall(function() return matrix:coeff() end)
    if ok_coefficients and tx ~= nil and ty ~= nil then return V(tx, ty) end
    return nil
  end

  local function circle_ellipse_or_arc_center(object)
    local shape = path_shape(object)
    if not shape or #shape ~= 1 then return nil end
    local component = shape[1]
    local local_matrix
    if component.type == "ellipse" then
      local_matrix = component[1]
    elseif component.type == "curve" and #component == 1 and component[1].type == "arc" then
      local ok_arc_matrix, arc_matrix = pcall(function() return component[1].arc:matrix() end)
      if ok_arc_matrix then local_matrix = arc_matrix end
    end
    if not local_matrix then return nil end
    local local_center = matrix_translation(local_matrix)
    if not local_center then return nil end
    local ok_matrix, object_matrix = pcall(function() return object:matrix() end)
    if not ok_matrix or not object_matrix then object_matrix = ipe.Matrix() end
    local ok_center, center = pcall(function() return object_matrix * local_center end)
    return ok_center and center or nil
  end

  local function selection_inputs(model)
    local summary = {
      points = {},
      circles = {},
      segments = {},
      invalid = {},
      primary_point = nil,
    }
    local primary_index = model:page():primarySelection()
    for _, entry in ipairs(selected_objects(model)) do
      local point = reference_position(entry.object)
      if point then
        summary.points[#summary.points + 1] = point
        if entry.index == primary_index then summary.primary_point = point end
      else
        local circle = circle_from_path(entry.object)
        if circle then
          circle.layer = entry.layer
          circle.primary = entry.index == primary_index
          summary.circles[#summary.circles + 1] = circle
        else
          local p1, p2 = single_segment_from_path(entry.object)
          if p1 and p2 then
            summary.segments[#summary.segments + 1] = { p1 = p1, p2 = p2, layer = entry.layer }
          else
            summary.invalid[#summary.invalid + 1] = entry
          end
        end
      end
    end
    return summary
  end

  local function selection_matches(summary, point_count, circle_count, segment_count)
    return #summary.invalid == 0
      and #summary.points == (point_count or 0)
      and #summary.circles == (circle_count or 0)
      and #summary.segments == (segment_count or 0)
  end

  local function require_selection(summary, point_count, circle_count, segment_count, message)
    if not selection_matches(summary, point_count, circle_count, segment_count) then error(message) end
  end

  local function primary_first_points(summary)
    if not summary.primary_point then return summary.points end
    local points = { summary.primary_point }
    for _, point in ipairs(summary.points) do
      if point ~= summary.primary_point then points[#points + 1] = point end
    end
    return points
  end

  local function arc_selection_points(summary)
    if not summary.primary_point then
      error("The primary selection must be the through-point mark of the arc.")
    end
    local endpoints = {}
    for _, point in ipairs(summary.points) do
      if point ~= summary.primary_point then endpoints[#endpoints + 1] = point end
    end
    if #endpoints ~= 2 then error("Select exactly three marks, with the through-point as the primary selection.") end
    return { endpoints[1], summary.primary_point, endpoints[2] }
  end

  local function selected_points(model)
    return selection_inputs(model).points
  end

  local function selected_points_primary_first(model)
    return primary_first_points(selection_inputs(model))
  end

  local function selected_circles(model)
    return selection_inputs(model).circles
  end

  local function selected_segments(model)
    return selection_inputs(model).segments
  end

  local function active_layer(model)
    return model:page():active(model.vno)
  end

  local function points_from_options(options)
    if type(options) ~= "table" then return nil end
    if type(options.points) == "table" then
      local points = {}
      for index, point in ipairs(options.points) do
        points[#points + 1] = M.point_from_table(point, "points[" .. tostring(index) .. "]")
      end
      return points
    end
    if options.p1 and options.p2 then
      return { M.point_from_table(options.p1, "p1"), M.point_from_table(options.p2, "p2") }
    end
    if options.a and options.b and options.c then
      return {
        M.point_from_table(options.a, "a"),
        M.point_from_table(options.b, "b"),
        M.point_from_table(options.c, "c"),
      }
    end
    return nil
  end

  local function circles_from_options(options)
    if type(options) ~= "table" or type(options.circles) ~= "table" then return nil end
    local circles = {}
    for index, circle in ipairs(options.circles) do
      circles[#circles + 1] = M.circle_from_table(circle, "circles[" .. tostring(index) .. "]")
    end
    return circles
  end

  local function point_from_options(options, key)
    if type(options) ~= "table" then return nil end
    local value = options[key or "point"]
    if value then return M.point_from_table(value, key or "point") end
    local points = points_from_options(options)
    return points and points[1] or nil
  end

  local function line_from_options(options)
    if type(options) ~= "table" then return nil end
    if options.line then return M.line_from_table(options.line, "line") end
    if options.p1 and options.p2 then
      return M.line_from_table({ p1 = options.p1, p2 = options.p2 }, "line")
    end
    local points = points_from_options(options)
    if points and #points >= 2 then return { p1 = points[1], p2 = points[2] } end
    return nil
  end

  local function lines_from_options(options)
    if type(options) ~= "table" then return nil end
    if type(options.lines) == "table" then
      local lines = {}
      for index, line in ipairs(options.lines) do
        lines[#lines + 1] = M.line_from_table(line, "lines[" .. tostring(index) .. "]")
      end
      return lines
    end
    local lines = {}
    if options.line1 then lines[#lines + 1] = M.line_from_table(options.line1, "line1") end
    if options.line2 then lines[#lines + 1] = M.line_from_table(options.line2, "line2") end
    return #lines > 0 and lines or nil
  end

  local function segment_shape(p1, p2)
    return { type = "curve", closed = false; { type = "segment"; p1, p2 } }
  end

  local function make_segment(p1, p2, attributes)
    return ipe.Path(clone_attributes(attributes), { segment_shape(p1, p2) }, true)
  end

  local function make_circle(center, radius, attributes)
    return ipe.Path(clone_attributes(attributes), {
      { type = "ellipse"; ipe.Matrix(radius, 0, 0, radius, center.x, center.y) },
    }, false)
  end

  local function make_arc(arc, attributes)
    local matrix = ipe.Matrix(
      arc.radius,
      0,
      0,
      arc.orientation == "clockwise" and -arc.radius or arc.radius,
      arc.center.x,
      arc.center.y
    )
    local ipe_arc = ipe.Arc(matrix, arc.alpha, arc.beta)
    return ipe.Path(clone_attributes(attributes), {
      { type = "curve", closed = false; { type = "arc", arc = ipe_arc; arc.start, arc.finish } },
    }, true)
  end

  local function circle_shape(center, radius)
    return { type = "ellipse"; ipe.Matrix(radius, 0, 0, radius, center.x, center.y) }
  end

  local function make_mark(point, label_text, styles)
    local mark = ipe.Reference(clone_attributes(styles.mark), styles.markshape, point)
    if label_text then mark:setCustom("geometry:mark-label=" .. label_text) end
    return mark
  end

  local function make_text(text, point, styles)
    return ipe.Text(clone_attributes(styles.text), text, point)
  end

  local function add_optional_mark_and_label(elements, point, label_text, marks, labels, styles)
    if marks then elements[#elements + 1] = make_mark(point, label_text, styles) end
    if labels then
      elements[#elements + 1] = make_text("$" .. label_text .. "$", M.add(point, V(4, 4)), styles)
    end
  end

  local function add_constructed_line(elements, line, requested_length, attributes)
    local segment = M.line_segment_from_infinite(line.point, line.direction, requested_length)
    elements[#elements + 1] = make_segment(segment.p1, segment.p2, attributes)
  end

  local function add_radius_guide(elements, center, point, attributes)
    if M.distance(center, point) > EPS then
      elements[#elements + 1] = make_segment(center, point, attributes)
    end
  end

  local function add_perpendicular_bisector(elements, p1, p2, requested_length, attributes)
    add_constructed_line(elements, {
      point = M.midpoint(p1, p2),
      direction = M.perpendicular(M.sub(p2, p1)),
    }, requested_length, attributes)
  end

  local function object_custom_value(object)
    if not object then return "" end
    local ok, value = pcall(function() return object:getCustom() end)
    if ok and value ~= nil then
      local text = tostring(value)
      return text == "undefined" and "" or text
    end
    if type(object) == "table" and object.custom ~= nil then
      local text = tostring(object.custom)
      return text == "undefined" and "" or text
    end
    return ""
  end

  local function set_object_custom_value(object, value)
    if not object then return end
    local ok = pcall(function() object:setCustom(value) end)
    if not ok and type(object) == "table" then object.custom = value end
  end

  local function append_object_custom_value(object, value)
    if value == nil or value == "" then return end
    local existing = object_custom_value(object)
    if existing ~= "" then
      if existing:find(value, 1, true) then return end
      value = existing .. ";" .. value
    end
    set_object_custom_value(object, value)
  end

  local function warn_for_invisible_layer(model, layer)
    if model._circles_preview then return end
    local page = model:page()
    local ok, visible = pcall(function() return page:visible(model.vno, layer) end)
    if ok and visible == false then
      model:warning(
        "Active layer is invisible",
        "You have just created an object in layer '" .. layer .. "'.\n\n"
          .. "This layer is currently not visible, so don't be surprised that you can't see your new object!"
      )
    end
  end

  local function register_creation(model, label_value, objects, layer, metadata)
    if type(objects) ~= "table" or objects[1] == nil then objects = { objects } end
    for _, object in ipairs(objects) do append_object_custom_value(object, metadata) end
    warn_for_invisible_layer(model, layer)
    local transaction = {
      label = label_value,
      pno = model.pno,
      vno = model.vno,
      object = objects[1],
      objects = objects,
      layer = layer,
    }
    transaction.undo = function(record, doc)
      local page = doc[record.pno]
      for _ = 1, #record.objects do page:remove(#page) end
    end
    transaction.redo = function(record, doc)
      local page = doc[record.pno]
      page:deselectAll()
      for _, object in ipairs(record.objects) do page:insert(nil, object, 1, record.layer) end
    end
    model:register(transaction)
  end

  local function warn_and_return(model, title, message)
    if model and type(model.warning) == "function" then model:warning(title, message) end
    return { created = false, error = message }
  end

  local function mark_circle_center(model)
    local page = model:page()
    local primary = page:primarySelection()
    if not primary then
      if model.ui and type(model.ui.explain) == "function" then model.ui:explain("no selection") end
      return false
    end
    local center = circle_ellipse_or_arc_center(page[primary])
    if not center then
      model:warning("Primary selection is not an arc, a circle, or an ellipse")
      return false
    end
    local styles = construction_styles(model)
    local mark = make_mark(center, nil, styles)
    local layer = active_layer(model)
    register_creation(model, "mark circle center", { mark }, layer, "geometry:circle-center")
    return {
      created = true,
      point = M.point_record(center),
      element_count = 1,
      metadata = "geometry:circle-center",
      object_count = #page,
    }
  end

  local function explicit_circle_pair(options)
    local circles = circles_from_options(options)
    local first = options.source_circle and M.circle_from_table(options.source_circle, "source_circle") or nil
    local second = options.inversion_circle and M.circle_from_table(options.inversion_circle, "inversion_circle") or nil
    if circles then first, second = first or circles[1], second or circles[2] end
    return first, second
  end

  local function explicit_radical_circles(options, count)
    local circles = circles_from_options(options)
    local result = {}
    if circles then for index = 1, #circles do result[index] = circles[index] end end
    result[1] = options.circle_a and M.circle_from_table(options.circle_a, "circle_a")
      or options.circle1 and M.circle_from_table(options.circle1, "circle1") or result[1]
    result[2] = options.circle_b and M.circle_from_table(options.circle_b, "circle_b")
      or options.circle2 and M.circle_from_table(options.circle2, "circle2") or result[2]
    result[3] = options.circle_c and M.circle_from_table(options.circle_c, "circle_c")
      or options.circle3 and M.circle_from_table(options.circle3, "circle3") or result[3]
    for index = 1, count do if not result[index] then return nil end end
    return result
  end

  local function create_circle_construction(model, options)
    options = M.options_table(options)
    local operation = M.normalized_option_name(options.operation or options.construction or "through_three_points")
    local summary = selection_inputs(model)
    local explicit_points = points_from_options(options)
    local marks = M.bool_value(options.marks, true)
    local labels = M.bool_value(options.labels, false)
    local auxiliary_value = options.auxiliaries
    if auxiliary_value == nil then auxiliary_value = options.construction_guides end
    local auxiliaries = M.bool_value(auxiliary_value, false)
    local layer = active_layer(model)
    local styles = construction_styles(model)

    local ok, result_or_error = pcall(function()
      local elements, result = {}, nil
      local function guide_line_length()
        return M.positive_number_option(options.line_length, 192, "line_length")
      end
      if operation == "center_point" or operation == "center_and_point" then
        local has_center, has_point = options.center ~= nil, options.point ~= nil
        if has_center ~= has_point then error("Pass center and point, or select two marks.") end
        local center, point
        if has_center then
          center = M.point_from_table(options.center, "center")
          point = M.point_from_table(options.point, "point")
        else
          require_selection(summary, 2, 0, 0, "Pass center and point, or select two marks.")
          local points = primary_first_points(summary)
          center, point = points[1], points[2]
        end
        local circle = M.circle_from_center_point(center, point)
        elements[#elements + 1] = make_circle(circle.center, circle.radius, styles.path)
        if auxiliaries then add_radius_guide(elements, center, point, styles.dotted) end
        result = M.image_record({ type = "circle", center = circle.center, radius = circle.radius })
      elseif operation == "center_radius" then
        local center
        if options.center then
          center = M.point_from_table(options.center, "center")
        else
          require_selection(summary, 1, 0, 0, "Pass center={x,y}, or select one mark.")
          center = summary.points[1]
        end
        local radius = M.number_value(options.radius, nil)
        if radius ~= nil and not M.finite_number(radius) then error("radius must be a finite number") end
        if not radius or radius <= EPS then error("radius must be positive") end
        elements[#elements + 1] = make_circle(center, radius, styles.path)
        if auxiliaries then add_radius_guide(elements, center, M.add(center, V(radius, 0)), styles.dotted) end
        result = M.image_record({ type = "circle", center = center, radius = radius })
      elseif operation == "diameter" or operation == "diameter_circle" then
        local points = explicit_points
        if points then
          if #points ~= 2 then error("Select two marks, or pass two points.") end
        else
          require_selection(summary, 2, 0, 0, "Select two marks, or pass two points.")
          points = summary.points
        end
        local circle = M.circle_from_diameter(points[1], points[2])
        elements[#elements + 1] = make_circle(circle.center, circle.radius, styles.path)
        if auxiliaries then add_radius_guide(elements, points[1], points[2], styles.dotted) end
        result = M.image_record({ type = "circle", center = circle.center, radius = circle.radius })
      elseif operation == "through_three_points" or operation == "circumcircle" then
        local points = explicit_points
        if points then
          if #points ~= 3 then error("Select three marks, or pass three points.") end
        else
          require_selection(summary, 3, 0, 0, "Select three marks, or pass three points.")
          points = summary.points
        end
        local circle = M.circle_through_three_points(points[1], points[2], points[3])
        elements[#elements + 1] = make_circle(circle.center, circle.radius, styles.path)
        if auxiliaries then
          local length = guide_line_length()
          add_perpendicular_bisector(elements, points[1], points[2], length, styles.dashed)
          add_perpendicular_bisector(elements, points[1], points[3], length, styles.dashed)
        end
        result = M.image_record({ type = "circle", center = circle.center, radius = circle.radius })
      elseif operation == "arc_three_points" or operation == "arc_through_three_points" then
        local points = explicit_points
        if points then
          if #points ~= 3 then error("Select three marks, or pass three points.") end
        else
          require_selection(summary, 3, 0, 0, "Select three marks, or pass three points.")
          points = arc_selection_points(summary)
        end
        local arc = M.arc_through_three_points(points[1], points[2], points[3])
        elements[#elements + 1] = make_arc(arc, styles.path)
        if auxiliaries then
          for _, point in ipairs(points) do add_radius_guide(elements, arc.center, point, styles.dotted) end
        end
        result = {
          type = "arc",
          center = M.point_record(arc.center),
          radius = arc.radius,
          orientation = arc.orientation,
        }
      elseif operation == "two_points_radius" then
        local points = explicit_points
        if points then
          if #points ~= 2 then error("Select two marks, or pass two points.") end
        else
          require_selection(summary, 2, 0, 0, "Select two marks, or pass two points.")
          points = summary.points
        end
        local candidates = M.circles_through_two_points_radius(points[1], points[2], options.radius)
        if #candidates == 0 then error("no circle with the requested radius passes through both points") end
        local records = {}
        for index, circle in ipairs(candidates) do
          elements[#elements + 1] = make_circle(circle.center, circle.radius, styles.path)
          if auxiliaries then
            add_radius_guide(elements, circle.center, points[1], styles.dotted)
            add_radius_guide(elements, circle.center, points[2], styles.dotted)
          end
          add_optional_mark_and_label(elements, circle.center, "O_" .. tostring(index), marks, labels, styles)
          records[index] = M.image_record({ type = "circle", center = circle.center, radius = circle.radius })
        end
        result = { type = "circles", circles = records }
      elseif operation == "power_polar" then
        local has_point, has_circle = options.point ~= nil, options.circle ~= nil
        if not has_point or not has_circle then
          require_selection(summary, has_point and 0 or 1, has_circle and 0 or 1, 0,
            "Select one mark and one circle, or pass point={x,y} and circle={center,radius}.")
        end
        local point = has_point and M.point_from_table(options.point, "point") or summary.points[1]
        local circle = has_circle and M.circle_from_table(options.circle, "circle") or summary.circles[1]
        local construction = M.circle_power_polar(circle, point)
        if not construction.polar then error("polar line is undefined at the circle center") end
        local line_length = M.positive_number_option(options.line_length, 192, "line_length")
        add_constructed_line(elements, construction.polar, line_length, styles.path)
        if auxiliaries then add_radius_guide(elements, circle.center, point, styles.dotted) end
        if labels then
          elements[#elements + 1] = make_text(
            "$\\operatorname{Pow}=" .. M.format_number(construction.power) .. "$",
            M.add(point, V(4, 4)),
            styles
          )
        end
        result = {
          type = "power_polar",
          power = construction.power,
          polar = {
            point = M.point_record(construction.polar.point),
            direction = M.point_record(construction.polar.direction),
          },
        }
      elseif operation == "pole_of_line" or operation == "line_pole" then
        local explicit_line = line_from_options(options)
        local explicit_circles = circles_from_options(options)
        local circle_value = options.circle or (explicit_circles and explicit_circles[1])
        local has_circle = circle_value ~= nil
        if not explicit_line or not has_circle then
          require_selection(summary, 0, has_circle and 0 or 1, explicit_line and 0 or 1,
            "Select one segment and one circle, or pass line={p1,p2} and circle={center,radius}.")
        end
        local line = explicit_line or summary.segments[1]
        local circle = has_circle and M.circle_from_table(circle_value, "circle") or summary.circles[1]
        local construction = M.circle_pole_of_line(circle, line)
        if not marks and not labels then error("Enable point marks or labels to show the pole.") end
        add_optional_mark_and_label(elements, construction.point, "P", marks, labels, styles)
        if auxiliaries then add_radius_guide(elements, circle.center, construction.point, styles.dotted) end
        result = {
          type = "point",
          point = M.point_record(construction.point),
          foot = M.point_record(construction.foot),
        }
      elseif operation == "homothety_centers" then
        local circles = circles_from_options(options)
        if circles then
          if #circles ~= 2 then error("Select two circles, or pass circles={...}.") end
        else
          require_selection(summary, 0, 2, 0, "Select two circles, or pass circles={...}.")
          circles = summary.circles
        end
        local centers = M.circle_homothety_centers(circles[1], circles[2])
        if auxiliaries then
          add_radius_guide(elements, circles[1].center, circles[2].center, styles.dotted)
        end
        local center_scale = math.max(circles[1].radius, circles[2].radius)
        local coincident = centers.external
          and M.distance(centers.internal, centers.external) <= EPS * center_scale
        if coincident then
          if not marks and not labels then
            error("The homothety centers coincide; enable center marks or labels to show the result.")
          end
          add_optional_mark_and_label(elements, centers.internal, "H_i=H_e", marks, labels, styles)
        elseif marks or labels then
          add_optional_mark_and_label(elements, centers.internal, "H_i", marks, labels, styles)
          if centers.external then
            add_optional_mark_and_label(elements, centers.external, "H_e", marks, labels, styles)
          end
        else
          local first = centers.external and centers.internal or circles[1].center
          local second = centers.external or circles[2].center
          elements[#elements + 1] = make_segment(first, second, styles.dashed)
        end
        result = {
          type = "points",
          internal = M.point_record(centers.internal),
          external = centers.external and M.point_record(centers.external) or nil,
        }
      else
        error("unsupported circle construction: " .. operation)
      end

      if result and result.center then
        add_optional_mark_and_label(
          elements,
          M.point_from_table(result.center, "center"),
          "O",
          marks,
          labels,
          styles
        )
      end
      local metadata = table.concat({
        "geometry:circle-construction",
        "operation=" .. operation,
        "auxiliaries=" .. tostring(auxiliaries),
        "elements=" .. tostring(#elements),
      }, ";")
      register_creation(model, "create circle construction", elements, layer, metadata)
      return {
        created = true,
        operation = operation,
        result = result,
        element_count = #elements,
        metadata = metadata,
        object_count = #model:page(),
      }
    end)
    if not ok then
      return warn_and_return(model, "Cannot create circle construction", M.clean_error_message(result_or_error))
    end
    return result_or_error
  end

  local function normalize_inversion_operation(operation)
    operation = tostring(operation or "invert_point"):lower():gsub("[%s%-]+", "_")
    if operation == "point" then return "invert_point" end
    if operation == "line" then return "invert_line" end
    if operation == "circle" then return "invert_circle" end
    if operation == "axis" then return "radical_axis" end
    if operation == "center" then return "radical_center" end
    if operation == "orthogonal" then return "orthogonal_circle" end
    return operation
  end

  local function add_image_element(elements, image, line_length, attributes)
    if image.type == "circle" then
      elements[#elements + 1] = make_circle(image.center, image.radius, attributes)
    elseif image.type == "line" then
      local segment = M.line_segment_from_infinite(image.point, image.direction, line_length)
      elements[#elements + 1] = make_segment(segment.p1, segment.p2, attributes)
    else
      error("unsupported inversion image type")
    end
  end

  local function create_inversion_radical(model, options)
    options = M.options_table(options)
    local operation = normalize_inversion_operation(options.operation or options.op)
    local labels = M.bool_value(options.labels, true)
    local summary = selection_inputs(model)
    local styles = construction_styles(model)
    local layer = active_layer(model)

    local ok, result_or_error = pcall(function()
      local line_length = M.positive_number_option(options.line_length, 192, "line_length")
      local elements, result = {}, nil
      if operation == "invert_point" then
        local has_point = options.point ~= nil
        local circle_value = options.inversion_circle or options.circle
        local has_circle = circle_value ~= nil
        if not has_point or not has_circle then
          require_selection(summary, has_point and 0 or 1, has_circle and 0 or 1, 0,
            "Select one mark and one circle, or pass point and inversion_circle.")
        end
        local point = has_point and M.point_from_table(options.point, "point") or summary.points[1]
        local inversion_circle = has_circle and M.circle_from_table(circle_value, "inversion_circle") or summary.circles[1]
        local image = M.invert_point(point, inversion_circle)
        elements[#elements + 1] = make_mark(image, "P'", styles)
        if labels then elements[#elements + 1] = make_text("$P'$", M.add(image, V(4, 4)), styles) end
        result = { type = "point", point = M.point_record(image) }
      elseif operation == "invert_line" then
        local explicit_line = line_from_options(options)
        local circle_value = options.inversion_circle or options.circle
        local has_circle = circle_value ~= nil
        if not explicit_line or not has_circle then
          require_selection(summary, 0, has_circle and 0 or 1, explicit_line and 0 or 1,
            "Select one segment and one circle, or pass line and inversion_circle.")
        end
        local line = explicit_line or summary.segments[1]
        local inversion_circle = has_circle and M.circle_from_table(circle_value, "inversion_circle") or summary.circles[1]
        local image = M.invert_line(line, inversion_circle)
        add_image_element(elements, image, line_length, styles.path)
        result = M.image_record(image)
      elseif operation == "invert_circle" then
        local source_circle, inversion_circle = explicit_circle_pair(options)
        local has_explicit_pair = source_circle ~= nil and inversion_circle ~= nil
        if not has_explicit_pair then
          require_selection(summary, 0, 2, 0, "Select two circles, or pass source_circle and inversion_circle.")
          for _, circle in ipairs(summary.circles) do
            if circle.primary then inversion_circle = circle else source_circle = circle end
          end
          if not inversion_circle then error("The primary selection must be the inversion circle.") end
        end
        local image = M.invert_circle(source_circle, inversion_circle)
        add_image_element(elements, image, line_length, styles.path)
        result = M.image_record(image)
      elseif operation == "radical_axis" then
        local explicit = explicit_radical_circles(options, 2)
        if not explicit then
          require_selection(summary, 0, 2, 0, "Select two circles, or pass circles={...}.")
          explicit = summary.circles
        end
        local axis = M.radical_axis(explicit[1], explicit[2])
        add_image_element(elements, { type = "line", point = axis.point, direction = axis.direction },
          line_length, styles.dashed)
        result = { type = "line", point = M.point_record(axis.point), direction = M.point_record(axis.direction) }
      elseif operation == "radical_center" then
        local explicit = explicit_radical_circles(options, 3)
        if not explicit then
          require_selection(summary, 0, 3, 0, "Select three circles, or pass circles={...}.")
          explicit = summary.circles
        end
        local center = M.radical_center(explicit[1], explicit[2], explicit[3])
        elements[#elements + 1] = make_mark(center, "R", styles)
        if labels then elements[#elements + 1] = make_text("$R$", M.add(center, V(4, 4)), styles) end
        if M.bool_value(options.axes, true) then
          local axis_ab = M.radical_axis(explicit[1], explicit[2])
          local axis_ac = M.radical_axis(explicit[1], explicit[3])
          add_image_element(elements, { type = "line", point = axis_ab.point, direction = axis_ab.direction },
            line_length, styles.dashed)
          add_image_element(elements, { type = "line", point = axis_ac.point, direction = axis_ac.direction },
            line_length, styles.dashed)
        end
        result = { type = "point", point = M.point_record(center) }
      elseif operation == "orthogonal_circle" then
        local has_center = options.center ~= nil
        local circle_value = options.reference_circle or options.circle
        local has_circle = circle_value ~= nil
        if not has_center or not has_circle then
          require_selection(summary, has_center and 0 or 1, has_circle and 0 or 1, 0,
            "Select one mark and one circle, or pass center and reference_circle.")
        end
        local center = has_center and M.point_from_table(options.center, "center") or summary.points[1]
        local reference_circle = has_circle and M.circle_from_table(circle_value, "reference_circle") or summary.circles[1]
        local circle = M.orthogonal_circle(center, reference_circle)
        elements[#elements + 1] = make_circle(circle.center, circle.radius, styles.path)
        elements[#elements + 1] = make_mark(circle.center, "O", styles)
        if labels then elements[#elements + 1] = make_text("$O$", M.add(circle.center, V(4, 4)), styles) end
        result = M.image_record({ type = "circle", center = circle.center, radius = circle.radius })
      else
        error("unsupported inversion/radical operation: " .. operation)
      end

      local metadata = table.concat({
        "geometry:inversion-radical",
        "operation=" .. operation,
        "line_length=" .. M.format_number(line_length),
      }, ";")
      register_creation(model, "create inversion/radical construction", elements, layer, metadata)
      return {
        created = true,
        operation = operation,
        result = result,
        element_count = #elements,
        metadata = metadata,
        object_count = #model:page(),
      }
    end)
    if not ok then
      return warn_and_return(model, "Cannot create inversion/radical construction", M.clean_error_message(result_or_error))
    end
    return result_or_error
  end

  api.clone_attributes = clone_attributes
  api.construction_styles = construction_styles
  api.selected_objects = selected_objects
  api.reference_position = reference_position
  api.single_segment_from_path = single_segment_from_path
  api.circle_from_path = circle_from_path
  api.circle_ellipse_or_arc_center = circle_ellipse_or_arc_center
  api.selection_inputs = selection_inputs
  api.selected_points = selected_points
  api.selected_points_primary_first = selected_points_primary_first
  api.selected_circles = selected_circles
  api.selected_segments = selected_segments
  api.active_layer = active_layer
  api.points_from_options = points_from_options
  api.circles_from_options = circles_from_options
  api.point_from_options = point_from_options
  api.line_from_options = line_from_options
  api.lines_from_options = lines_from_options
  api.make_segment = make_segment
  api.make_circle = make_circle
  api.make_arc = make_arc
  api.circle_shape = circle_shape
  api.make_mark = make_mark
  api.make_text = make_text
  api.add_radius_guide = add_radius_guide
  api.add_perpendicular_bisector = add_perpendicular_bisector
  api.register_creation = register_creation
  api.warn_and_return = warn_and_return
  api.mark_circle_center = mark_circle_center
  api.explicit_radical_circles = explicit_radical_circles
  api.create_circle_construction = create_circle_construction
  api.create_inversion_radical = create_inversion_radical
  return api
end)(M)

----------------------------------------------------------------------
-- Tangent lines and tangent circles
----------------------------------------------------------------------

local T = (function(M, R)
  local api = {}

  local function normalize_tangent_operation(options, circles, points, segments)
    local operation = tostring(options.operation or options.construction or ""):lower():gsub("[%s%-]+", "_")
    if operation == "point" then return "point_circle" end
    if operation == "circle" or operation == "common" then return "circle_circle" end
    if operation == "parallel" or operation == "perpendicular" then return "circle_line" end
    if operation ~= "" then return operation end
    if #circles >= 2 then return "circle_circle" end
    if #circles >= 1 and #points >= 1 then return "point_circle" end
    if #circles >= 1 and #segments >= 1 then return "circle_line" end
    return "point_circle"
  end

  local function selected_or_explicit_inputs(model, options, line_endpoints)
    local summary = R.selection_inputs(model)
    local circles = R.circles_from_options(options)
    local explicit_circles = circles ~= nil
    if options.circle then
      circles = { M.circle_from_table(options.circle, "circle") }
      explicit_circles = true
    end
    local first_circle = options.circle_a or options.circle1
    local second_circle = options.circle_b or options.circle2
    if first_circle ~= nil or second_circle ~= nil then
      circles = {}
      if first_circle ~= nil then
        circles[#circles + 1] = M.circle_from_table(first_circle, "circle_a")
      end
      if second_circle ~= nil then
        circles[#circles + 1] = M.circle_from_table(second_circle, "circle_b")
      end
      explicit_circles = true
    end
    local p1_p2_line = line_endpoints and options.p1 ~= nil and options.p2 ~= nil
    local points = nil
    if not p1_p2_line or type(options.points) == "table" then
      points = R.points_from_options(options)
    end
    local explicit_points = points ~= nil
    if options.point then
      points = { M.point_from_table(options.point, "point") }
      explicit_points = true
    end
    local segments = R.lines_from_options(options)
    local explicit_segments = segments ~= nil
    if options.line then
      segments = { M.line_from_table(options.line, "line") }
      explicit_segments = true
    elseif p1_p2_line then
      segments = { M.line_from_table({ p1 = options.p1, p2 = options.p2 }, "line") }
      explicit_segments = true
    end
    return {
      summary = summary,
      circles = circles or summary.circles,
      points = points or summary.points,
      segments = segments or summary.segments,
      explicit_circles = explicit_circles,
      explicit_points = explicit_points,
      explicit_segments = explicit_segments,
    }
  end

  local INPUT_KINDS = {
    { values = "points", explicit = "explicit_points" },
    { values = "circles", explicit = "explicit_circles" },
    { values = "segments", explicit = "explicit_segments" },
  }

  local function complete_explicit_inputs(inputs, required)
    local has_explicit = false
    for _, kind in ipairs(INPUT_KINDS) do
      local expected = required[kind.values] or 0
      if inputs[kind.explicit] then
        has_explicit = true
        if #inputs[kind.values] ~= expected then return false end
      elseif expected ~= 0 then
        return false
      end
    end
    return has_explicit
  end

  local function isolate_complete_explicit_inputs(inputs, required)
    if not complete_explicit_inputs(inputs, required) then return false end
    for _, kind in ipairs(INPUT_KINDS) do
      if not inputs[kind.explicit] then inputs[kind.values] = {} end
    end
    return true
  end

  local function inferred_explicit_operation(inputs, requirements, order)
    for _, operation in ipairs(order) do
      if complete_explicit_inputs(inputs, requirements[operation]) then return operation end
    end
    return nil
  end

  local function has_requested_operation(options)
    local value = tostring(options.operation or options.construction or "")
    return value:match("%S") ~= nil
  end

  local function require_missing_selection(inputs, required, message)
    local point_count = inputs.explicit_points and 0 or (required.points or 0)
    local circle_count = inputs.explicit_circles and 0 or (required.circles or 0)
    local segment_count = inputs.explicit_segments and 0 or (required.segments or 0)
    if point_count + circle_count + segment_count == 0 then return end
    local summary = inputs.summary
    if #summary.invalid ~= 0
      or #summary.points ~= point_count
      or #summary.circles ~= circle_count
      or #summary.segments ~= segment_count then
      error(message)
    end
  end

  local function tangent_line_element(tangent, options, attributes, line_length)
    line_length = M.positive_number_option(line_length or options.line_length, 192, "line_length")
    local offset = M.sub(tangent.to, tangent.from)
    local original_length = M.length(offset)
    local has_distinct_endpoints = original_length >= EPS
    local direction = M.unit(tangent.direction or offset, "tangent direction")
    if M.bool_value(options.extend, false) then
      local extended_length = math.max(line_length, original_length)
      if tangent.kind == "point" and has_distinct_endpoints then
        return R.make_segment(tangent.from, M.add(tangent.from, M.scale(direction, extended_length)), attributes)
      end
      local center = has_distinct_endpoints and M.midpoint(tangent.from, tangent.to) or tangent.from
      local segment = M.line_segment_from_infinite(center, direction, extended_length)
      return R.make_segment(segment.p1, segment.p2, attributes)
    end
    if not has_distinct_endpoints then
      local segment = M.line_segment_from_infinite(tangent.from, direction, line_length)
      return R.make_segment(segment.p1, segment.p2, attributes)
    end
    return R.make_segment(tangent.from, tangent.to, attributes)
  end

  local function tangent_line_mark_points(tangent)
    if tangent.point then return {{ point = tangent.point, label = "T" }} end
    if tangent.kind ~= "external" and tangent.kind ~= "internal" then return {} end
    local points = {}
    if tangent.from then points[#points + 1] = { point = tangent.from, label = "A" } end
    local endpoint_distance = tangent.from and tangent.to and M.distance(tangent.from, tangent.to) or 0
    local local_scale = math.max(tangent.scale or endpoint_distance, EPS)
    local tolerance = 1e-6 * local_scale
    if tangent.to and (not tangent.from or endpoint_distance > tolerance) then
      points[#points + 1] = { point = tangent.to, label = "B" }
    end
    return points
  end

  local function explicit_circle_pair(options)
    local circles = R.circles_from_options(options)
    local first = options.circle_a and M.circle_from_table(options.circle_a, "circle_a")
      or options.circle1 and M.circle_from_table(options.circle1, "circle1") or nil
    local second = options.circle_b and M.circle_from_table(options.circle_b, "circle_b")
      or options.circle2 and M.circle_from_table(options.circle2, "circle2") or nil
    if circles then first, second = first or circles[1], second or circles[2] end
    return first, second, (first ~= nil or second ~= nil or circles ~= nil)
  end

  local TANGENT_LINE_REQUIREMENTS = {
    point_circle = { points = 1, circles = 1 },
    circle_circle = { circles = 2 },
    circle_line = { circles = 1, segments = 1 },
  }

  local TANGENT_LINE_OPERATION_ORDER = {
    "point_circle",
    "circle_circle",
    "circle_line",
  }

  local function create_tangent_lines(model, options)
    options = M.options_table(options)
    local inputs = selected_or_explicit_inputs(model, options, true)
    local operation = nil
    local tangent_type = nil
    local tangent_marks = M.bool_value(options.tangent_points, true)
    local labels = M.bool_value(options.labels, false)
    local auxiliary_value = options.auxiliaries
    if auxiliary_value == nil then auxiliary_value = options.construction_guides end
    local auxiliaries = M.bool_value(auxiliary_value, false)
    local styles = R.construction_styles(model)

    local ok, result_or_error = pcall(function()
      local explicit_operation = inferred_explicit_operation(
        inputs,
        TANGENT_LINE_REQUIREMENTS,
        TANGENT_LINE_OPERATION_ORDER
      )
      operation = not has_requested_operation(options) and explicit_operation
        or normalize_tangent_operation(options, inputs.circles, inputs.points, inputs.segments)
      isolate_complete_explicit_inputs(inputs, TANGENT_LINE_REQUIREMENTS[operation] or {})
      local default_mode = operation == "circle_line" and "parallel" or "all"
      tangent_type = tostring(options.tangent_type or options.mode or default_mode):lower()
      local line_length = M.positive_number_option(options.line_length, 192, "line_length")
      local tangents, guide_circles
      if operation == "point_circle" then
        require_missing_selection(inputs, { points = 1, circles = 1 },
          "Select one mark and one circle, or pass point={x,y} and circle={center,radius}.")
        if #inputs.points ~= 1 or #inputs.circles ~= 1 then
          error("Select one mark and one circle, or pass point={x,y} and circle={center,radius}.")
        end
        tangents = M.point_circle_tangents(inputs.points[1], inputs.circles[1])
        guide_circles = { inputs.circles[1] }
      elseif operation == "circle_circle" then
        local circle_a, circle_b, explicit_pair = explicit_circle_pair(options)
        if explicit_pair then
          if not circle_a or not circle_b then error("Select two circles, or pass circles={...}.") end
        else
          require_missing_selection(inputs, { circles = 2 }, "Select two circles, or pass circles={...}.")
          if #inputs.circles ~= 2 then error("Select two circles, or pass circles={...}.") end
          circle_a, circle_b = inputs.circles[1], inputs.circles[2]
        end
        tangents = M.circle_circle_tangents(circle_a, circle_b, { mode = tangent_type })
        guide_circles = { circle_a, circle_b }
      elseif operation == "circle_line" then
        require_missing_selection(inputs, { circles = 1, segments = 1 },
          "Select one circle and one segment, or pass circle={center,radius} and line={p1,p2}.")
        if #inputs.circles ~= 1 or #inputs.segments ~= 1 then
          error("Select one circle and one segment, or pass circle={center,radius} and line={p1,p2}.")
        end
        local mode = tangent_type
        local alias = M.normalized_option_name(options.operation)
        if alias == "perpendicular" or alias == "parallel" then mode = alias end
        tangent_type = mode
        tangents = M.circle_line_tangents(inputs.circles[1], inputs.segments[1], {
          mode = mode,
          length = line_length,
        })
        guide_circles = { inputs.circles[1] }
      else
        error("unsupported tangent construction: " .. operation)
      end

      local elements = {}
      for index, tangent in ipairs(tangents) do
        elements[#elements + 1] = tangent_line_element(tangent, options, styles.path, line_length)
        if auxiliaries then
          if operation == "circle_circle" then
            R.add_radius_guide(elements, guide_circles[1].center, tangent.from, styles.dotted)
            R.add_radius_guide(elements, guide_circles[2].center, tangent.to, styles.dotted)
          elseif tangent.point then
            R.add_radius_guide(elements, guide_circles[1].center, tangent.point, styles.dotted)
          end
        end
        local mark_points = tangent_line_mark_points(tangent)
        for _, mark in ipairs(mark_points) do
          local label_text = #mark_points == 1
            and "T" .. tostring(index)
            or "T" .. tostring(index) .. mark.label
          if tangent_marks then elements[#elements + 1] = R.make_mark(mark.point, label_text, styles) end
          if labels then
            local math_label = #mark_points == 1
              and "$T_" .. tostring(index) .. "$"
              or "$T_{" .. tostring(index) .. mark.label .. "}$"
            elements[#elements + 1] = R.make_text(math_label, M.add(mark.point, V(4, 4)), styles)
          end
        end
      end

      local metadata = table.concat({
        "geometry:tangent-lines",
        "operation=" .. operation,
        "mode=" .. tangent_type,
        "auxiliaries=" .. tostring(auxiliaries),
        "count=" .. tostring(#tangents),
      }, ";")
      R.register_creation(model, "create tangent lines", elements, R.active_layer(model), metadata)
      local records = {}
      for index, tangent in ipairs(tangents) do records[index] = M.tangent_record(tangent) end
      return {
        created = true,
        operation = operation,
        mode = tangent_type,
        tangent_count = #tangents,
        tangents = records,
        element_count = #elements,
        metadata = metadata,
        object_count = #model:page(),
      }
    end)
    if not ok then
      return R.warn_and_return(model, "Cannot create tangent lines", M.clean_error_message(result_or_error))
    end
    return result_or_error
  end

  local function normalize_tangent_circle_operation(options, circles, points, segments)
    local operation = tostring(options.operation or options.construction or ""):lower():gsub("[%s%-]+", "_")
    if operation == "3_circles" or operation == "circles" then return "three_circles" end
    if operation == "2_circles_point" then return "two_circles_point" end
    if operation == "2_circles_line" then return "two_circles_line" end
    if operation == "2_points_circle" then return "two_points_circle" end
    if operation == "point_circle_line" or operation == "line_point_circle"
      or operation == "circle_point_line" or operation == "circle_line_point"
      or operation == "line_circle_point" then return "point_line_circle" end
    if operation == "2_lines_circle" then return "two_lines_circle" end
    if operation == "2_points_line" then return "two_points_line" end
    if operation == "2_lines_point" then return "two_lines_point" end
    if operation == "3_lines" or operation == "lines" then return "three_lines" end
    if operation ~= "" then return operation end
    if #circles >= 3 then return "three_circles" end
    if #circles >= 2 and #points >= 1 then return "two_circles_point" end
    if #circles >= 2 and #segments >= 1 then return "two_circles_line" end
    if #points >= 2 and #circles >= 1 then return "two_points_circle" end
    if #points >= 1 and #segments >= 1 and #circles >= 1 then return "point_line_circle" end
    if #segments >= 2 and #circles >= 1 then return "two_lines_circle" end
    if #points >= 2 and #segments >= 1 then return "two_points_line" end
    if #segments >= 2 and #points >= 1 then return "two_lines_point" end
    if #segments >= 3 then return "three_lines" end
    return "three_circles"
  end

  local function circle_constraint_signs(options)
    local mode = tostring(options.circle_mode or options.tangent_type or options.mode or "external"):lower()
    if mode == "internal" then return { -1 } end
    if mode == "all" then return { 1, -1 } end
    if mode == "external" then return { 1 } end
    error("unsupported circle tangency mode: " .. mode)
  end

  local function line_constraint_sides(options)
    local side = tostring(options.line_side or options.side or "both"):lower()
    if side == "left" or side == "positive" or side == "1" then return { 1 } end
    if side == "right" or side == "negative" or side == "-1" then return { -1 } end
    if side == "both" then return { 1, -1 } end
    error("unsupported line side: " .. side)
  end

  local function expand_tangent_circle_constraints(base_constraints, options)
    local variants = { {} }
    for _, constraint in ipairs(base_constraints) do
      local choices = { constraint }
      if constraint.type == "circle" and constraint.sign == nil then
        choices = {}
        for _, sign in ipairs(circle_constraint_signs(options)) do
          choices[#choices + 1] = { type = "circle", circle = constraint.circle, sign = sign }
        end
      elseif constraint.type == "line" and constraint.side == nil then
        choices = {}
        for _, side in ipairs(line_constraint_sides(options)) do
          choices[#choices + 1] = { type = "line", line = constraint.line, side = side }
        end
      end
      local expanded = {}
      for _, variant in ipairs(variants) do
        for _, choice in ipairs(choices) do
          local next_variant = {}
          for index, item in ipairs(variant) do next_variant[index] = item end
          next_variant[#next_variant + 1] = choice
          expanded[#expanded + 1] = next_variant
        end
      end
      variants = expanded
    end
    return variants
  end

  local TANGENT_CIRCLE_REQUIREMENTS = {
    three_circles = { circles = 3 },
    two_circles_point = { circles = 2, points = 1 },
    two_circles_line = { circles = 2, segments = 1 },
    two_points_circle = { points = 2, circles = 1 },
    point_line_circle = { points = 1, segments = 1, circles = 1 },
    two_lines_circle = { segments = 2, circles = 1 },
    two_points_line = { points = 2, segments = 1 },
    two_lines_point = { segments = 2, points = 1 },
    three_lines = { segments = 3 },
  }

  local TANGENT_CIRCLE_OPERATION_ORDER = {
    "three_circles",
    "two_circles_point",
    "two_circles_line",
    "two_points_circle",
    "point_line_circle",
    "two_lines_circle",
    "two_points_line",
    "two_lines_point",
    "three_lines",
  }

  local TANGENT_CIRCLE_MESSAGES = {
    three_circles = "Select three circles, or pass circles={...}.",
    two_circles_point = "Select two circles and one mark, or pass circles={...} and point={x,y}.",
    two_circles_line = "Select two circles and one segment, or pass circles={...} and line={p1,p2}.",
    two_points_circle = "Select two marks and one circle, or pass points={...} and circles={...}.",
    point_line_circle = "Select one mark, one segment, and one circle, or pass point, line, and circle.",
    two_lines_circle = "Select two segments and one circle, or pass lines={...} and circles={...}.",
    two_points_line = "Select two marks and one segment, or pass points={...} and line={p1,p2}.",
    two_lines_point = "Select two segments and one mark, or pass lines={...} and point={x,y}.",
    three_lines = "Select three segments, or pass lines={...}.",
  }

  local function create_tangent_circle_constraints(options, inputs)
    local explicit_operation = inferred_explicit_operation(
      inputs,
      TANGENT_CIRCLE_REQUIREMENTS,
      TANGENT_CIRCLE_OPERATION_ORDER
    )
    local operation = not has_requested_operation(options) and explicit_operation
      or normalize_tangent_circle_operation(options, inputs.circles, inputs.points, inputs.segments)
    local required = TANGENT_CIRCLE_REQUIREMENTS[operation]
    if not required then error("unsupported tangent-circle construction: " .. operation) end
    isolate_complete_explicit_inputs(inputs, required)
    local message = TANGENT_CIRCLE_MESSAGES[operation]
    require_missing_selection(inputs, required, message)
    if #inputs.points ~= (required.points or 0)
      or #inputs.circles ~= (required.circles or 0)
      or #inputs.segments ~= (required.segments or 0) then error(message) end
    local constraints = {}
    local function add_points(count)
      for index = 1, count do constraints[#constraints + 1] = { type = "point", point = inputs.points[index] } end
    end
    local function add_circles(count)
      for index = 1, count do constraints[#constraints + 1] = { type = "circle", circle = inputs.circles[index] } end
    end
    local function add_lines(count)
      for index = 1, count do constraints[#constraints + 1] = { type = "line", line = inputs.segments[index] } end
    end
    if operation == "three_circles" then
      add_circles(3)
    elseif operation == "two_circles_point" then
      add_circles(2); add_points(1)
    elseif operation == "two_circles_line" then
      add_circles(2); add_lines(1)
    elseif operation == "two_points_circle" then
      add_points(2); add_circles(1)
    elseif operation == "point_line_circle" then
      add_points(1); add_lines(1); add_circles(1)
    elseif operation == "two_lines_circle" then
      add_lines(2); add_circles(1)
    elseif operation == "two_points_line" then
      add_points(2); add_lines(1)
    elseif operation == "two_lines_point" then
      add_lines(2); add_points(1)
    elseif operation == "three_lines" then
      add_lines(3)
    end
    return operation, constraints
  end

  local function tangent_circle_candidates(model, options)
    options = M.options_table(options)
    local inputs = selected_or_explicit_inputs(model, options)
    local operation, constraints = create_tangent_circle_constraints(options, inputs)
    M.positive_number_option(options.tolerance, 1e-7, "tolerance")
    M.positive_integer_option(options.max_iterations, 50, "max_iterations", 200)
    local duplicate_tolerance = M.positive_number_option(options.duplicate_tolerance, 1e-4, "duplicate_tolerance")
    local duplicate_distance = duplicate_tolerance * M.tangent_circle_anchor_bounds(constraints).span
    local max_solutions = M.positive_integer_option(options.max_solutions, 16, "max_solutions", 128)
    local solver_options = {}
    for key, value in pairs(options) do solver_options[key] = value end
    -- Enumerate every root before applying the user-facing display limit, so
    -- the candidate count and truncation notice remain truthful.
    solver_options.max_solutions = 128
    local solutions = {}
    for _, variant in ipairs(expand_tangent_circle_constraints(constraints, options)) do
      local ok_variant, variant_solutions = pcall(M.tangent_circles_from_constraints, variant, solver_options)
      if ok_variant then
        for _, solution in ipairs(variant_solutions) do
          if not M.tangent_circle_is_duplicate(solutions, solution, duplicate_distance) then
            solution.constraints = variant
            solutions[#solutions + 1] = solution
          end
        end
      end
    end
    if #solutions == 0 then error("no tangent circle satisfies the requested constraints") end
    local limited = {}
    for index, circle in ipairs(solutions) do
      if index > max_solutions then break end
      limited[#limited + 1] = circle
    end
    return operation, limited, R.active_layer(model), {
      total_count = #solutions,
      shown_count = #limited,
      truncated = #solutions > #limited,
      max_solutions = max_solutions,
    }
  end

  local function nearest_tangent_circle(circles, point)
    point = M.point_from_table(point, "point")
    local best_index, best_distance = nil, math.huge
    for index, circle in ipairs(circles or {}) do
      local center_distance = M.distance(point, circle.center)
      local candidate_distance = math.min(math.abs(center_distance - circle.radius), center_distance)
      if candidate_distance < best_distance then
        best_index, best_distance = index, candidate_distance
      end
    end
    return best_index, best_distance
  end

  local CHOICE_TOOL = {}
  CHOICE_TOOL.__index = CHOICE_TOOL

  local function append_tangent_circle_elements(elements, circle, index, options, styles)
    elements[#elements + 1] = R.make_circle(circle.center, circle.radius, styles.path)
    if M.bool_value(options.center_marks, false) then
      elements[#elements + 1] = R.make_mark(circle.center, "C" .. tostring(index), styles)
    end
    if M.bool_value(options.labels, false) then
      elements[#elements + 1] = R.make_text(
        "$C_" .. tostring(index) .. "$",
        M.add(circle.center, V(4, 4)),
        styles
      )
    end
    local tangency_points = M.tangent_circle_tangency_points(circle, circle.constraints)
    local auxiliary_value = options.auxiliaries
    if auxiliary_value == nil then auxiliary_value = options.construction_guides end
    if M.bool_value(auxiliary_value, false) then
      for _, point in ipairs(tangency_points) do
        R.add_radius_guide(elements, circle.center, point, styles.dotted)
      end
    end
    if M.tangent_circle_mark_option(options, false) then
      for _, point in ipairs(tangency_points) do elements[#elements + 1] = R.make_mark(point, nil, styles) end
    end
    return tangency_points
  end

  function CHOICE_TOOL:new(model, circles, metadata, layer, options, candidate_info)
    if not circles or #circles == 0 then return nil end
    local tool = {
      model = model,
      circles = circles,
      metadata = metadata,
      layer = layer,
      options = options,
      candidate_info = candidate_info or { total_count = #circles, shown_count = #circles, truncated = false },
      current_index = 1,
    }
    setmetatable(tool, CHOICE_TOOL)
    model.ui:shapeTool(tool)
    if tool.setColor then tool.setColor(1.0, 0, 0) end
    tool:update_preview()
    return tool
  end

  function CHOICE_TOOL:finish()
    self.model.ui:finishTool()
  end

  function CHOICE_TOOL:preview_shapes()
    local shapes = {}
    local zoom = self.model.ui:zoom()
    local offset = zoom and zoom > 0 and 2 / zoom or 2
    for index, circle in ipairs(self.circles) do
      shapes[#shapes + 1] = R.circle_shape(circle.center, circle.radius)
      if index == self.current_index then
        shapes[#shapes + 1] = R.circle_shape(circle.center, circle.radius + offset)
        if circle.radius > offset then shapes[#shapes + 1] = R.circle_shape(circle.center, circle.radius - offset) end
      end
    end
    return shapes
  end

  function CHOICE_TOOL:explanation()
    local info = self.candidate_info
    local count = tostring(self.current_index) .. " of " .. tostring(#self.circles)
    if info.truncated then
      count = count .. "; showing " .. tostring(info.shown_count) .. " of " .. tostring(info.total_count)
    end
    return "Tangent-circle candidate " .. count
      .. " | J/K: previous/next | Space or left click: create | A: create all shown | Esc: cancel"
  end

  function CHOICE_TOOL:update_explanation()
    if self.model.ui and self.model.ui.explain then self.model.ui:explain(self:explanation()) end
  end

  function CHOICE_TOOL:update_preview()
    if self.setShape then
      self.setShape(self:preview_shapes())
      self.model.ui:update(false)
    end
    self:update_explanation()
  end

  function CHOICE_TOOL:select_relative(delta)
    self.current_index = ((self.current_index - 1 + delta) % #self.circles) + 1
    self:update_preview()
  end

  function CHOICE_TOOL:create_indexes(indexes, label_value, selection_metadata)
    local styles = R.construction_styles(self.model)
    local elements = {}
    for _, index in ipairs(indexes) do
      append_tangent_circle_elements(elements, self.circles[index], index, self.options, styles)
    end
    R.register_creation(
      self.model,
      label_value,
      elements,
      self.layer or R.active_layer(self.model),
      self.metadata .. ";selected=" .. selection_metadata
    )
  end

  function CHOICE_TOOL:create_current()
    if not self.current_index then return end
    self:create_indexes({ self.current_index }, "create tangent circle", tostring(self.current_index))
  end

  function CHOICE_TOOL:create_all()
    local indexes = {}
    for index = 1, #self.circles do indexes[index] = index end
    self:create_indexes(indexes, "create tangent circles", "all-shown")
  end

  function CHOICE_TOOL:show_menu()
    if not ipeui or not ipeui.Menu then return end
    local menu = ipeui.Menu(self.model.ui:win())
    menu:add("previous", "Previous candidate")
    menu:add("next", "Next candidate")
    menu:add("create", "Create selected candidate")
    menu:add("create_all", "Create all shown candidates")
    menu:add("cancel", "Cancel")
    local position = self.model.ui:globalPos()
    local item = menu:execute(position.x, position.y)
    if item == "previous" then
      self:select_relative(-1)
    elseif item == "next" then
      self:select_relative(1)
    elseif item == "create" then
      self:create_current()
      self:finish()
    elseif item == "create_all" then
      self:create_all()
      self:finish()
    elseif item == "cancel" then
      self:finish()
    end
  end

  function CHOICE_TOOL:mouseMove()
    local position = self.model.ui:pos()
    if not position then return end
    local index = nearest_tangent_circle(self.circles, position)
    if index and index ~= self.current_index then self.current_index = index; self:update_preview() end
  end

  function CHOICE_TOOL:mouseButton(button, modifiers, press)
    if not press then return end
    if button == 1 and self.current_index then
      self:create_current()
      self:finish()
    elseif button == 2 then
      self:show_menu()
    end
  end

  function CHOICE_TOOL:key(text, modifiers)
    if text == "\027" then self:finish(); return true end
    if text == "j" or text == "J" or text == "[" or text == "<" then
      self:select_relative(-1)
      return true
    end
    if text == "k" or text == "K" or text == "]" or text == ">" then
      self:select_relative(1)
      return true
    end
    if text == " " or text == "\r" or text == "\n" then
      self:create_current()
      self:finish()
      return true
    end
    if text == "a" or text == "A" then
      self:create_all()
      self:finish()
      return true
    end
    return false
  end

  local function choose_tangent_circle_interactively(model, options)
    options = M.options_table(options)
    local ok, result_or_error = pcall(function()
      local operation, solutions, layer, candidate_info = tangent_circle_candidates(model, options)
      local metadata = table.concat({
        "geometry:tangent-circles",
        "operation=" .. operation,
        "count=" .. tostring(#solutions),
        "total=" .. tostring(candidate_info.total_count),
        "truncated=" .. tostring(candidate_info.truncated),
        "interactive=true",
      }, ";")
      local tool = CHOICE_TOOL:new(model, solutions, metadata, layer, options, candidate_info)
      if not tool then error("no tangent circle satisfies the requested constraints") end
      return {
        created = false,
        interactive = true,
        operation = operation,
        candidate_count = #solutions,
        total_candidate_count = candidate_info.total_count,
        truncated = candidate_info.truncated,
        metadata = metadata,
      }
    end)
    if not ok then
      return R.warn_and_return(model, "Cannot choose tangent circle", M.clean_error_message(result_or_error))
    end
    return result_or_error
  end

  local function create_tangent_circles(model, options)
    options = M.options_table(options)
    local styles = R.construction_styles(model)
    local ok, result_or_error = pcall(function()
      local operation, solutions, layer, candidate_info = tangent_circle_candidates(model, options)
      local creation_options = {}
      for key, value in pairs(options) do creation_options[key] = value end
      if creation_options.center_marks == nil then creation_options.center_marks = true end
      local elements, records = {}, {}
      for index, circle in ipairs(solutions) do
        local tangency_points = append_tangent_circle_elements(elements, circle, index, creation_options, styles)
        local tangency_records = {}
        for _, point in ipairs(tangency_points) do tangency_records[#tangency_records + 1] = M.point_record(point) end
        records[#records + 1] = {
          center = M.point_record(circle.center),
          radius = circle.radius,
          residual = circle.residual,
          tangency_points = tangency_records,
        }
      end
      local metadata = table.concat({
        "geometry:tangent-circles",
        "operation=" .. operation,
        "count=" .. tostring(#records),
        "total=" .. tostring(candidate_info.total_count),
        "truncated=" .. tostring(candidate_info.truncated),
      }, ";")
      R.register_creation(model, "create tangent circles", elements, layer, metadata)
      local notice
      if candidate_info.truncated then
        notice = "Created " .. tostring(candidate_info.shown_count) .. " of "
          .. tostring(candidate_info.total_count)
          .. " tangent-circle candidates; increase Max candidate circles to include more."
        if model.ui and type(model.ui.explain) == "function" then model.ui:explain(notice) end
      end
      return {
        created = true,
        operation = operation,
        circle_count = #records,
        total_circle_count = candidate_info.total_count,
        truncated = candidate_info.truncated,
        circles = records,
        element_count = #elements,
        metadata = metadata,
        notice = notice,
        object_count = #model:page(),
      }
    end)
    if not ok then
      return R.warn_and_return(model, "Cannot create tangent circles", M.clean_error_message(result_or_error))
    end
    return result_or_error
  end

  api.normalize_tangent_operation = normalize_tangent_operation
  api.tangent_line_element = tangent_line_element
  api.tangent_line_mark_points = tangent_line_mark_points
  api.create_tangent_lines = create_tangent_lines
  api.normalize_tangent_circle_operation = normalize_tangent_circle_operation
  api.expand_tangent_circle_constraints = expand_tangent_circle_constraints
  api.create_tangent_circle_constraints = create_tangent_circle_constraints
  api.tangent_circle_candidates = tangent_circle_candidates
  api.nearest_tangent_circle = nearest_tangent_circle
  api.append_tangent_circle_elements = append_tangent_circle_elements
  api.choose_tangent_circle_interactively = choose_tangent_circle_interactively
  api.create_tangent_circles = create_tangent_circles
  return api
end)(M, R)

----------------------------------------------------------------------
-- Live and manual previews
----------------------------------------------------------------------

local P = (function(M, R, T)
  local api = {}

  local function object_type(object)
    if not object then return nil end
    local ok, value = pcall(function() return object:type() end)
    if ok then return value end
    return object.type_value or object.type
  end

  local function object_shape(object)
    if not object then return nil end
    local ok, shape = pcall(function() return object:shape() end)
    if ok and type(shape) == "table" then return shape end
    return object.shape_value or object.shape
  end

  local function object_elements(object)
    if not object then return nil end
    local ok, elements = pcall(function() return object:elements() end)
    if ok and type(elements) == "table" then return elements end
    return object.elements_value or object.elements
  end

  local function object_matrix(object)
    local ok, matrix = pcall(function() return object:matrix() end)
    if ok and matrix then return matrix end
    if type(object) == "table" and object.matrix_value then return object.matrix_value end
    return ipe.Matrix()
  end

  local function object_local_position(object)
    local ok, position = pcall(function() return object:position() end)
    if ok and position then return position end
    if type(object) == "table" then return object.position_value or object.position end
    return nil
  end

  local function append_shapes(target, shapes)
    for _, shape in ipairs(shapes or {}) do target[#target + 1] = shape end
  end

  local function clone_preview_value(value)
    if type(value) ~= "table" then return value end
    local cloned = {}
    for key, item in pairs(value) do cloned[clone_preview_value(key)] = clone_preview_value(item) end
    return setmetatable(cloned, _G.getmetatable(value))
  end

  local function transform_preview_shapes(matrix, shapes)
    local transformed = clone_preview_value(shapes or {})
    if type(_G.transformShape) == "function" then
      _G.transformShape(matrix, transformed)
      return transformed
    end
    for _, path in ipairs(transformed) do
      if path.type == "ellipse" or path.type == "closedspline" then
        for index = 1, #path do path[index] = matrix * path[index] end
      else
        for _, segment in ipairs(path) do
          for index = 1, #segment do segment[index] = matrix * segment[index] end
          if segment.type == "arc" and segment.arc then segment.arc = matrix * segment.arc end
        end
      end
    end
    return transformed
  end

  local function point_preview_shapes(point)
    local size = 3
    return {
      { type = "curve", closed = false, { type = "segment", V(point.x - size, point.y), V(point.x + size, point.y) } },
      { type = "curve", closed = false, { type = "segment", V(point.x, point.y - size), V(point.x, point.y + size) } },
    }
  end

  local function label_preview_shape(point)
    if not point then return nil end
    local left, bottom = point.x + 4, point.y + 2
    local right, top = left + 12, bottom + 8
    return {
      type = "curve",
      closed = true,
      { type = "segment", V(left, bottom), V(right, bottom) },
      { type = "segment", V(right, bottom), V(right, top) },
      { type = "segment", V(right, top), V(left, top) },
      { type = "segment", V(left, top), V(left, bottom) },
    }
  end

  local function preview_rect_shape(rect, matrix)
    if not rect or rect:isEmpty() then return nil end
    local bottom_left, top_right = rect:bottomLeft(), rect:topRight()
    local points = {
      bottom_left,
      V(top_right.x, bottom_left.y),
      top_right,
      V(bottom_left.x, top_right.y),
    }
    if matrix then for index, point in ipairs(points) do points[index] = matrix * point end end
    return {
      type = "curve",
      closed = true,
      { type = "segment", points[1], points[2] },
      { type = "segment", points[2], points[3] },
      { type = "segment", points[3], points[4] },
      { type = "segment", points[4], points[1] },
    }
  end

  local function bbox_preview_shapes(object, matrix)
    if type(ipe.Rect) ~= "function" then return {} end
    local rect = ipe.Rect()
    local ok = pcall(function() object:addToBBox(rect, ipe.Matrix(), false) end)
    if not ok or rect:isEmpty() then return {} end
    local shape = preview_rect_shape(rect, matrix)
    return shape and { shape } or {}
  end

  local function object_preview_shapes(object, parent_matrix)
    parent_matrix = parent_matrix or ipe.Matrix()
    local kind = object_type(object)
    local matrix = parent_matrix * object_matrix(object)
    if kind == "path" then
      local shape = object_shape(object)
      if shape then return transform_preview_shapes(matrix, shape) end
    elseif kind == "group" then
      local shapes = {}
      for _, child in ipairs(object_elements(object) or {}) do
        append_shapes(shapes, object_preview_shapes(child, matrix))
      end
      return shapes
    elseif kind == "reference" then
      local position = object_local_position(object)
      return position and point_preview_shapes(matrix * position) or {}
    elseif kind == "text" then
      local position = object_local_position(object)
      local shape = position and label_preview_shape(matrix * position) or nil
      return shape and { shape } or {}
    end
    return bbox_preview_shapes(object, parent_matrix)
  end

  local function default_preview_page()
    local page = {}
    function page:active() return "alpha" end
    function page:visible() return true end
    function page:primarySelection() return nil end
    function page:objects() return function() return nil end end
    setmetatable(page, { __len = function() return 0 end })
    return page
  end

  local function preview_page(page)
    if not page then return default_preview_page() end
    local wrapper = {}
    setmetatable(wrapper, {
      __len = function()
        local ok, count = pcall(function() return #page end)
        return ok and count or 0
      end,
      __index = page,
    })
    function wrapper:active(vno)
      if type(page.active) == "function" then
        local ok, value = pcall(function() return page:active(vno) end)
        if ok and value then return value end
      end
      return "alpha"
    end
    function wrapper:visible(vno, index)
      if type(page.visible) == "function" then
        local ok, value = pcall(function() return page:visible(vno, index) end)
        if ok then return value end
      end
      return true
    end
    function wrapper:primarySelection()
      if type(page.primarySelection) == "function" then
        local ok, value = pcall(function() return page:primarySelection() end)
        if ok then return value end
      end
      return nil
    end
    function wrapper:objects()
      if type(page.objects) == "function" then
        local ok, iterator, state, initial = pcall(function() return page:objects() end)
        if ok and iterator then return iterator, state, initial end
      end
      return function() return nil end
    end
    return wrapper
  end

  local function preview_capture_model(model)
    local captured = {}
    local preview_model = {
      pno = model and model.pno or 1,
      vno = model and model.vno or 1,
      attributes = model and model.attributes or {},
      captured_objects = captured,
      _circles_preview = true,
    }
    function preview_model:page()
      if model and type(model.page) == "function" then
        local ok, page = pcall(function() return model:page() end)
        if ok and page then return preview_page(page) end
      end
      return default_preview_page()
    end
    function preview_model:register(record)
      if not record then return end
      if type(record.objects) == "table" then
        for _, object in ipairs(record.objects) do captured[#captured + 1] = object end
      elseif record.object then
        captured[#captured + 1] = record.object
      end
    end
    function preview_model:creation(label_value, object)
      if object then captured[#captured + 1] = object end
    end
    function preview_model:warning(title, message)
      error(tostring(title or "Preview") .. ": " .. tostring(message or "failed"))
    end
    return preview_model
  end

  local function action_options(action, options)
    action = M.normalized_option_name(action or "")
    options = M.options_table(options)
    local cloned = {}
    for key, value in pairs(options) do cloned[key] = value end
    return cloned
  end

  local PREVIEW_CREATORS = {
    circle_construct = R.create_circle_construction,
    circle = R.create_circle_construction,
    inversion_radical = R.create_inversion_radical,
    inversion = R.create_inversion_radical,
    radical = R.create_inversion_radical,
    tangent_lines = T.create_tangent_lines,
    tangent = T.create_tangent_lines,
    tangent_circles = T.create_tangent_circles,
    tangent_circle = T.create_tangent_circles,
  }

  local function preview_shape_data(model, action, options)
    action = M.normalized_option_name(action or "")
    local creator = PREVIEW_CREATORS[action]
    if not creator then error("unsupported Circles preview action: " .. tostring(action)) end
    local preview_model = preview_capture_model(model)
    local ok, result_or_error = pcall(creator, preview_model, action_options(action, options))
    if not ok then error(M.clean_error_message(result_or_error)) end
    if type(result_or_error) ~= "table" or result_or_error.created == false then
      error(M.clean_error_message(result_or_error and result_or_error.error or "preview produced no construction"))
    end
    local shapes = {}
    for _, object in ipairs(preview_model.captured_objects or {}) do
      append_shapes(shapes, object_preview_shapes(object))
    end
    if #shapes == 0 then error("preview produced no visible shapes") end
    return {
      action = action,
      created = true,
      shapes = shapes,
      shape_count = #shapes,
      captured_count = #(preview_model.captured_objects or {}),
      metadata = result_or_error.metadata,
      result = result_or_error,
    }
  end

  local function preview_shapes(model, action, options)
    return preview_shape_data(model, action, options).shapes
  end

  local PREVIEW_COLOR = { 0.1, 0.35, 0.95 }
  local PREVIEW_TOOL = {}
  PREVIEW_TOOL.__index = PREVIEW_TOOL

  function PREVIEW_TOOL:new(model)
    local tool = { model = model, active = true }
    setmetatable(tool, PREVIEW_TOOL)
    model.ui:shapeTool(tool)
    if tool.setColor then tool.setColor(unpack(PREVIEW_COLOR)) end
    return tool
  end

  function PREVIEW_TOOL:update(shapes)
    if not self.active or not self.setShape then return end
    self.setShape(shapes or {})
    if self.model.ui and self.model.ui.update then self.model.ui:update(false) end
  end

  function PREVIEW_TOOL:finish()
    if not self.active then return end
    self.active = false
    self.model.ui:finishTool()
    if self.model.ui and self.model.ui.update then self.model.ui:update(false) end
  end

  function PREVIEW_TOOL:mouseButton() return true end
  function PREVIEW_TOOL:key(text) return text == "\027" end

  local function add_preview_controls(dialog, row, columns, initial_value)
    dialog:add("live_preview", "checkbox", { label = "Live preview" }, row, 1, 1, columns or 2)
    dialog:set("live_preview", initial_value ~= false)
    return row + 1
  end

  local function signature_value(parts, prefix, value, depth)
    depth = depth or 0
    if type(value) ~= "table" or depth > 3 then
      parts[#parts + 1] = prefix .. "=" .. tostring(value)
      return
    end
    for index, item in ipairs(value) do
      signature_value(parts, prefix .. "[" .. tostring(index) .. "]", item, depth + 1)
    end
    local keys = {}
    for key, _ in pairs(value) do if type(key) ~= "number" then keys[#keys + 1] = key end end
    table.sort(keys)
    for _, key in ipairs(keys) do signature_value(parts, prefix .. "." .. tostring(key), value[key], depth + 1) end
  end

  local function preview_signature(action, options)
    local parts, keys = { tostring(action) }, {}
    for key, _ in pairs(options or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do signature_value(parts, tostring(key), options[key]) end
    return table.concat(parts, "|")
  end

  local function start_dialog_preview(model, dialog, action, read_options)
    if not model.ui or not model.ui.shapeTool then return nil end
    local preview = {
      active = true,
      live = true,
      last_signature = nil,
      tool = PREVIEW_TOOL:new(model),
    }
    local function update(force)
      if not preview.active then return end
      local ok_live, live = pcall(function() return dialog:get("live_preview") end)
      local live_enabled = ok_live and live == true
      if not force and not live_enabled then
        if preview.live then preview.tool:update({}); preview.last_signature = nil end
        preview.live = false
        return
      end
      preview.live = live_enabled
      local ok_options, options_or_error = pcall(read_options)
      if not ok_options then
        preview.tool:update({})
        if model.ui.explain then model.ui:explain("Circles preview: " .. M.clean_error_message(options_or_error)) end
        return
      end
      local signature = preview_signature(action, options_or_error)
      if not force and signature == preview.last_signature then return end
      preview.last_signature = signature
      local ok_shapes, data_or_error = pcall(preview_shape_data, model, action, options_or_error)
      if ok_shapes and type(data_or_error) == "table" then
        preview.tool:update(data_or_error.shapes)
      else
        preview.tool:update({})
        if model.ui.explain then model.ui:explain("Circles preview: " .. M.clean_error_message(data_or_error)) end
      end
    end
    preview.update = update
    preview.stop = function()
      if not preview.active then return end
      preview.active = false
      if preview.timer then pcall(function() preview.timer:stop() end) end
      if preview.tool then preview.tool:finish() end
    end
    preview.tick = function() update(false) end
    if ipeui and ipeui.Timer then
      preview.timer = ipeui.Timer(preview, "tick")
      preview.timer:setInterval(150)
      preview.timer:start()
    end
    update(false)
    return preview
  end

  api.action_options = action_options
  api.preview_shape_data = preview_shape_data
  api.preview_shapes = preview_shapes
  api.add_preview_controls = add_preview_controls
  api.preview_signature = preview_signature
  api.start_dialog_preview = start_dialog_preview
  api.object_preview_shapes = object_preview_shapes
  api.default_preview_page = default_preview_page
  api.preview_page = preview_page
  return api
end)(M, R, T)

----------------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------------

local function persistent_dialog_state()
  local state = _G.CIRCLES_DIALOG_STATE
  if type(state) ~= "table" then
    state = {}
    _G.CIRCLES_DIALOG_STATE = state
  end
  for _, name in ipairs({ "circle", "inversion", "tangent_lines", "tangent_circles" }) do
    if type(state[name]) ~= "table" then state[name] = {} end
  end
  return state
end

local DIALOG_STATE = persistent_dialog_state()

local function operation_index(entries, operation, fallback)
  for index, entry in ipairs(entries) do
    if entry.operation == operation then return index end
  end
  return fallback or 1
end

local function value_index(values, value, fallback)
  for index, item in ipairs(values) do if item == value then return index end end
  return fallback or 1
end

local function operation_combo(entries, action)
  local labels = { action = action }
  for index, entry in ipairs(entries) do labels[index] = entry.label end
  return labels
end

local function set_enabled_pair(dialog, label_name, control_name, enabled)
  dialog:setEnabled(label_name, enabled)
  dialog:setEnabled(control_name, enabled)
end

local function remember_dialog_state(state, options, dialog, fields)
  for _, field in ipairs(fields) do state[field] = options[field] end
  state.live_preview = dialog:get("live_preview") == true
end

local function successful_dialog_result(result)
  return type(result) == "table" and (result.created == true or result.interactive == true)
end

local CIRCLE_DIALOG_OPERATIONS = {
  { label = "Center and point", operation = "center_point", selection = "2 marks (primary: center)", guides = true },
  { label = "Center and radius", operation = "center_radius", selection = "1 mark", radius = true, guides = true },
  { label = "Diameter endpoints", operation = "diameter", selection = "2 marks", guides = true },
  { label = "Through three points", operation = "through_three_points", selection = "3 marks", guide_length = true, guides = true },
  { label = "Arc through three points", operation = "arc_three_points", selection = "3 marks (primary: through-point)", guides = true },
  { label = "Two points and radius", operation = "two_points_radius", selection = "2 marks", radius = true, guides = true },
  {
    label = "Power and polar line", operation = "power_polar", selection = "1 mark + 1 circle",
    line_length = true, guides = true, marks = false,
  },
  { label = "Pole of line", operation = "pole_of_line", selection = "1 segment + 1 circle", guides = true },
  { label = "Homothety centers", operation = "homothety_centers", selection = "2 circles", guides = true },
}

local function update_circle_dialog(dialog)
  local entry = CIRCLE_DIALOG_OPERATIONS[dialog:get("operation")] or CIRCLE_DIALOG_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  set_enabled_pair(dialog, "radius_label", "radius", entry.radius == true)
  local guides = dialog:get("auxiliaries") == true
  set_enabled_pair(dialog, "length_label", "length", entry.line_length == true or (guides and entry.guide_length == true))
  dialog:setEnabled("marks", entry.marks ~= false)
  dialog:setEnabled("auxiliaries", entry.guides == true)
end

local function circle_construct_dialog(model)
  local state = DIALOG_STATE.circle
  local dialog = ipeui.Dialog(model.ui:win(), "Circle construction")
  dialog:add("operation_label", "label", { label = "Construction" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(CIRCLE_DIALOG_OPERATIONS, update_circle_dialog), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("radius_label", "label", { label = "Radius" }, 3, 1)
  dialog:add("radius", "input", {}, 3, 2)
  dialog:add("length_label", "label", { label = "Line length" }, 4, 1)
  dialog:add("length", "input", {}, 4, 2)
  dialog:add("marks", "checkbox", { label = "Point and center marks" }, 5, 1, 1, 2)
  dialog:add("labels", "checkbox", { label = "Labels" }, 6, 1, 1, 2)
  dialog:add("auxiliaries", "checkbox", { label = "Construction guides", action = update_circle_dialog }, 7, 1, 1, 2)
  dialog:set("operation", operation_index(CIRCLE_DIALOG_OPERATIONS, state.operation, 1))
  dialog:set("radius", state.radius or "48")
  dialog:set("length", state.line_length or "192")
  dialog:set("marks", state.marks ~= false)
  dialog:set("labels", state.labels ~= false)
  dialog:set("auxiliaries", state.auxiliaries == true)
  P.add_preview_controls(dialog, 8, 2, state.live_preview)
  update_circle_dialog(dialog)
  local function read_options()
    return {
      operation = CIRCLE_DIALOG_OPERATIONS[dialog:get("operation")].operation,
      radius = dialog:get("radius"),
      line_length = dialog:get("length"),
      marks = dialog:get("marks"),
      labels = dialog:get("labels"),
      auxiliaries = dialog:get("auxiliaries"),
    }
  end
  local preview = P.start_dialog_preview(model, dialog, "circle_construct", read_options)
  dialog:addButton("cancel", "&Cancel", "reject")
  dialog:addButton("preview", "&Preview", function() if preview then preview.update(true) end end)
  dialog:addButton("ok", "&Create", "accept")
  local accepted = dialog:execute()
  if preview then preview.stop() end
  if not accepted then return false end
  local options = read_options()
  local result = R.create_circle_construction(model, options)
  if successful_dialog_result(result) then
    remember_dialog_state(state, options, dialog, { "operation", "radius", "line_length", "marks", "labels", "auxiliaries" })
  end
  return result
end

local INVERSION_DIALOG_OPERATIONS = {
  { label = "Invert point", operation = "invert_point", selection = "1 mark + 1 circle", labels = true },
  { label = "Invert line", operation = "invert_line", selection = "1 segment + 1 circle", line_length = true },
  { label = "Invert circle", operation = "invert_circle", selection = "2 circles (primary: inversion circle)", line_length = true },
  { label = "Radical axis", operation = "radical_axis", selection = "2 circles", line_length = true },
  { label = "Radical center", operation = "radical_center", selection = "3 circles", labels = true, axes = true },
  { label = "Orthogonal circle", operation = "orthogonal_circle", selection = "1 mark + 1 circle", labels = true },
}

local function update_inversion_dialog(dialog)
  local entry = INVERSION_DIALOG_OPERATIONS[dialog:get("operation")] or INVERSION_DIALOG_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  local axes = entry.axes == true and dialog:get("axes") == true
  set_enabled_pair(dialog, "length_label", "length", entry.line_length == true or axes)
  dialog:setEnabled("labels", entry.labels == true)
  dialog:setEnabled("axes", entry.axes == true)
end

local function inversion_radical_dialog(model)
  local state = DIALOG_STATE.inversion
  local dialog = ipeui.Dialog(model.ui:win(), "Inversion and radical constructions")
  dialog:add("operation_label", "label", { label = "Operation" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(INVERSION_DIALOG_OPERATIONS, update_inversion_dialog), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("length_label", "label", { label = "Line length" }, 3, 1)
  dialog:add("length", "input", {}, 3, 2)
  dialog:add("labels", "checkbox", { label = "Labels" }, 4, 1, 1, 2)
  dialog:add("axes", "checkbox", { label = "Auxiliary radical axes", action = update_inversion_dialog }, 5, 1, 1, 2)
  dialog:set("operation", operation_index(INVERSION_DIALOG_OPERATIONS, state.operation, 1))
  dialog:set("length", state.line_length or "192")
  dialog:set("labels", state.labels ~= false)
  dialog:set("axes", state.axes ~= false)
  P.add_preview_controls(dialog, 6, 2, state.live_preview)
  update_inversion_dialog(dialog)
  local function read_options()
    return {
      operation = INVERSION_DIALOG_OPERATIONS[dialog:get("operation")].operation,
      line_length = dialog:get("length"),
      labels = dialog:get("labels"),
      axes = dialog:get("axes"),
    }
  end
  local preview = P.start_dialog_preview(model, dialog, "inversion_radical", read_options)
  dialog:addButton("cancel", "&Cancel", "reject")
  dialog:addButton("preview", "&Preview", function() if preview then preview.update(true) end end)
  dialog:addButton("ok", "&Create", "accept")
  local accepted = dialog:execute()
  if preview then preview.stop() end
  if not accepted then return false end
  local options = read_options()
  local result = R.create_inversion_radical(model, options)
  if successful_dialog_result(result) then
    remember_dialog_state(state, options, dialog, { "operation", "line_length", "labels", "axes" })
  end
  return result
end

local TANGENT_DIALOG_OPERATIONS = {
  { label = "Point to circle", operation = "point_circle", mode = "all", selection = "1 mark + 1 circle" },
  { label = "Circle-circle: all", operation = "circle_circle", mode = "all", selection = "2 circles" },
  { label = "Circle-circle: external", operation = "circle_circle", mode = "external", selection = "2 circles" },
  { label = "Circle-circle: internal", operation = "circle_circle", mode = "internal", selection = "2 circles" },
  { label = "Circle: parallel to line", operation = "circle_line", mode = "parallel", selection = "1 circle + 1 segment" },
  { label = "Circle: perpendicular to line", operation = "circle_line", mode = "perpendicular", selection = "1 circle + 1 segment" },
}

local function tangent_line_operation_index(operation, mode)
  for index, entry in ipairs(TANGENT_DIALOG_OPERATIONS) do
    if entry.operation == operation and entry.mode == mode then return index end
  end
  return 1
end

local function update_tangent_lines_dialog(dialog)
  local entry = TANGENT_DIALOG_OPERATIONS[dialog:get("operation")] or TANGENT_DIALOG_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
end

local function tangent_lines_dialog(model)
  local state = DIALOG_STATE.tangent_lines
  local dialog = ipeui.Dialog(model.ui:win(), "Tangent lines")
  dialog:add("operation_label", "label", { label = "Construction" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(TANGENT_DIALOG_OPERATIONS, update_tangent_lines_dialog), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("length_label", "label", { label = "Extended line length" }, 3, 1)
  dialog:add("length", "input", {}, 3, 2)
  dialog:add("extend", "checkbox", { label = "Extend tangent lines" }, 4, 1, 1, 2)
  dialog:add("points", "checkbox", { label = "Tangent point marks" }, 5, 1, 1, 2)
  dialog:add("labels", "checkbox", { label = "Labels" }, 6, 1, 1, 2)
  dialog:add("auxiliaries", "checkbox", { label = "Radii to tangency points" }, 7, 1, 1, 2)
  dialog:set("operation", tangent_line_operation_index(state.operation, state.mode))
  dialog:set("length", state.line_length or "192")
  dialog:set("extend", state.extend == true)
  dialog:set("points", state.tangent_points ~= false)
  dialog:set("labels", state.labels == true)
  dialog:set("auxiliaries", state.auxiliaries == true)
  P.add_preview_controls(dialog, 8, 2, state.live_preview)
  update_tangent_lines_dialog(dialog)
  local function read_options()
    local selected = TANGENT_DIALOG_OPERATIONS[dialog:get("operation")]
    return {
      operation = selected.operation,
      mode = selected.mode,
      line_length = dialog:get("length"),
      extend = dialog:get("extend"),
      tangent_points = dialog:get("points"),
      labels = dialog:get("labels"),
      auxiliaries = dialog:get("auxiliaries"),
    }
  end
  local preview = P.start_dialog_preview(model, dialog, "tangent_lines", read_options)
  dialog:addButton("cancel", "&Cancel", "reject")
  dialog:addButton("preview", "&Preview", function() if preview then preview.update(true) end end)
  dialog:addButton("ok", "&Create", "accept")
  local accepted = dialog:execute()
  if preview then preview.stop() end
  if not accepted then return false end
  local options = read_options()
  local result = T.create_tangent_lines(model, options)
  if successful_dialog_result(result) then
    remember_dialog_state(state, options, dialog,
      { "operation", "mode", "line_length", "extend", "tangent_points", "labels", "auxiliaries" })
  end
  return result
end

local TANGENT_CIRCLE_DIALOG_OPERATIONS = {
  { label = "Three circles", operation = "three_circles", selection = "3 circles", circles = true },
  { label = "Two circles and point", operation = "two_circles_point", selection = "2 circles + 1 mark", circles = true },
  { label = "Two circles and line", operation = "two_circles_line", selection = "2 circles + 1 segment", circles = true, lines = true },
  { label = "Two points and circle", operation = "two_points_circle", selection = "2 marks + 1 circle", circles = true },
  {
    label = "Point, line and circle", operation = "point_line_circle",
    selection = "1 mark + 1 segment + 1 circle", circles = true, lines = true,
  },
  { label = "Two lines and circle", operation = "two_lines_circle", selection = "2 segments + 1 circle", circles = true, lines = true },
  { label = "Two points and line", operation = "two_points_line", selection = "2 marks + 1 segment", lines = true },
  { label = "Two lines and point", operation = "two_lines_point", selection = "2 segments + 1 mark", lines = true },
  { label = "Three lines", operation = "three_lines", selection = "3 segments", lines = true },
}

local CIRCLE_MODES = { "external", "internal", "all" }
local LINE_SIDES = { "both", "left", "right" }

local function update_tangent_circles_dialog(dialog)
  local entry = TANGENT_CIRCLE_DIALOG_OPERATIONS[dialog:get("operation")] or TANGENT_CIRCLE_DIALOG_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  set_enabled_pair(dialog, "circle_mode_label", "circle_mode", entry.circles == true)
  set_enabled_pair(dialog, "line_side_label", "line_side", entry.lines == true)
end

local function tangent_circles_dialog(model)
  local state = DIALOG_STATE.tangent_circles
  local dialog = ipeui.Dialog(model.ui:win(), "Tangent circles")
  dialog:add("operation_label", "label", { label = "Construction" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(TANGENT_CIRCLE_DIALOG_OPERATIONS, update_tangent_circles_dialog), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("circle_mode_label", "label", { label = "Circle tangency" }, 3, 1)
  dialog:add("circle_mode", "combo", { "External", "Internal", "All" }, 3, 2)
  dialog:add("line_side_label", "label", { label = "Line side" }, 4, 1)
  dialog:add("line_side", "combo", { "Both", "Left", "Right" }, 4, 2)
  dialog:add("limit_label", "label", { label = "Max candidate circles" }, 5, 1)
  dialog:add("limit", "input", {}, 5, 2)
  dialog:add("marks", "checkbox", { label = "Tangency point marks" }, 6, 1, 1, 2)
  dialog:add("auxiliaries", "checkbox", { label = "Radii to tangency points" }, 7, 1, 1, 2)
  dialog:add("create_all", "checkbox", { label = "Create all shown candidates" }, 8, 1, 1, 2)
  dialog:set("operation", operation_index(TANGENT_CIRCLE_DIALOG_OPERATIONS, state.operation, 1))
  dialog:set("circle_mode", value_index(CIRCLE_MODES, state.circle_mode, 1))
  dialog:set("line_side", value_index(LINE_SIDES, state.line_side, 1))
  dialog:set("limit", state.max_solutions or "16")
  dialog:set("marks", state.tangent_points ~= false)
  dialog:set("auxiliaries", state.auxiliaries == true)
  dialog:set("create_all", state.create_all == true)
  P.add_preview_controls(dialog, 9, 2, state.live_preview)
  update_tangent_circles_dialog(dialog)
  local function read_options()
    return {
      operation = TANGENT_CIRCLE_DIALOG_OPERATIONS[dialog:get("operation")].operation,
      circle_mode = CIRCLE_MODES[dialog:get("circle_mode")],
      line_side = LINE_SIDES[dialog:get("line_side")],
      max_solutions = dialog:get("limit"),
      tangent_points = dialog:get("marks"),
      auxiliaries = dialog:get("auxiliaries"),
      create_all = dialog:get("create_all"),
      center_marks = false,
    }
  end
  local preview = P.start_dialog_preview(model, dialog, "tangent_circles", read_options)
  dialog:addButton("cancel", "&Cancel", "reject")
  dialog:addButton("preview", "&Preview", function() if preview then preview.update(true) end end)
  dialog:addButton("ok", "&Create", "accept")
  local accepted = dialog:execute()
  if preview then preview.stop() end
  if not accepted then return false end
  local options = read_options()
  local result = options.create_all
    and T.create_tangent_circles(model, options)
    or T.choose_tangent_circle_interactively(model, options)
  if successful_dialog_result(result) then
    remember_dialog_state(state, options, dialog,
      { "operation", "circle_mode", "line_side", "max_solutions", "tangent_points", "auxiliaries", "create_all" })
  end
  return result
end

----------------------------------------------------------------------
-- Standalone public API and menu
----------------------------------------------------------------------

local CIRCLES_API = {}
for name, value in pairs(M) do CIRCLES_API[name] = value end
for name, value in pairs(R) do CIRCLES_API[name] = value end
for name, value in pairs(T) do CIRCLES_API[name] = value end
for name, value in pairs(P) do CIRCLES_API[name] = value end

local CIRCLES_DIALOGS = {
  circle_construct = circle_construct_dialog,
  inversion_radical = inversion_radical_dialog,
  tangent_circles = tangent_circles_dialog,
  tangent_lines = tangent_lines_dialog,
}

_G.CIRCLES = CIRCLES_API
_G.CIRCLES_DIALOGS = CIRCLES_DIALOGS

methods = {
  { label = "Construct: circle", run = circle_construct_dialog },
  { label = "Construct: tangent circle", run = tangent_circles_dialog },
  { label = "Construct: tangent lines", run = tangent_lines_dialog },
  { label = "Inversion/radicals: operations", run = inversion_radical_dialog },
  { label = "Mark center: circle/ellipse/arc", run = R.mark_circle_center },
}

if type(shortcuts) == "table" then
  shortcuts.ipelet_3_circles = "Alt+T"
  shortcuts.ipelet_4_circles = nil
  shortcuts.ipelet_5_circles = nil
end
