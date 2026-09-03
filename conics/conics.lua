----------------------------------------------------------------------
-- Conics
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 japbcoelho
--
-- Standalone conic construction tools for Ipe 7.2.
-- Ellipse-from-foci and parabola construction formulas are adapted
-- from Ipe's GPL-licensed goodies.lua.
----------------------------------------------------------------------

label = "Conics"

about = [[
Conics 1.1.1

Standalone construction, inspection, and feature tools for ellipses,
parabolas, hyperbolas, circles, and general or degenerate conics.

Ellipse-from-foci and parabola formulas are adapted from Ipe's
GPL-licensed goodies.lua.

License: GPL-3.0-or-later.
]]

local _G = _G
local ipe = ipe
local ipeui = ipeui
local error = _G.error
local ipairs = _G.ipairs
local math = _G.math
local pairs = _G.pairs
local pcall = _G.pcall
local rawget = _G.rawget
local select = _G.select
local setmetatable = _G.setmetatable
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local unpack = table.unpack

local V = ipe.Vector
local API_VERSION = 1
local VERSION = "1.1.1"
local MACHINE_EPSILON = 2.220446049250313e-16
local MIN_NORMAL = 2.2250738585072014e-308
local LOG_TWO = 0.6931471805599453
local previous_api = rawget(_G, "CONICS")
local PERSISTED_DIALOG_STATE = type(previous_api) == "table"
  and type(previous_api.dialog_state) == "table"
  and previous_api.dialog_state or {}

----------------------------------------------------------------------
-- Pure numeric and analytic geometry
----------------------------------------------------------------------

local M = {}
local Advanced = {}

local function finite_number(value)
  return type(value) == "number"
    and value == value
    and value ~= math.huge
    and value ~= -math.huge
end

local function options_table(options)
  if options == nil then return {} end
  if type(options) ~= "table" then error("options must be a table") end
  return options
end

local function number_value(value, fallback)
  if value == nil or value == "" then return fallback end
  if type(value) == "number" then return value end
  local ok, converted = pcall(tonumber, value)
  if ok and converted ~= nil then return converted end
  return fallback
end

local function finite_number_option(value, fallback, name)
  if value == nil or value == "" then value = fallback end
  local converted = number_value(value, nil)
  if not finite_number(converted) then
    error((name or "value") .. " must be a finite number")
  end
  return converted
end

local function positive_number_option(value, fallback, name)
  local converted = finite_number_option(value, fallback, name)
  if converted <= 0 then error((name or "value") .. " must be positive") end
  return converted
end

local function nonnegative_number_option(value, fallback, name)
  local converted = finite_number_option(value, fallback, name)
  if converted < 0 then error((name or "value") .. " must be nonnegative") end
  return converted
end

local function positive_integer_option(value, fallback, name, maximum, minimum)
  local converted = finite_number_option(value, fallback, name)
  minimum = minimum or 1
  if converted < minimum or converted ~= math.floor(converted) then
    error((name or "value") .. " must be an integer greater than or equal to "
      .. tostring(minimum))
  end
  if maximum and converted > maximum then
    error((name or "value") .. " must be at most " .. tostring(maximum))
  end
  return converted
end

local function bool_value(value, fallback)
  if value == nil then return fallback end
  if value == false or value == 0 or value == "0" or value == "false" then return false end
  if value == true or value == 1 or value == "1" or value == "true" then return true end
  error("boolean option must be true or false")
end

function M.aliased_value(options, primary, legacy, context)
  local primary_value, legacy_value = options[primary], options[legacy]
  if primary_value ~= nil and legacy_value ~= nil then
    error((context or "options") .. " cannot contain both '" .. primary
      .. "' and its legacy alias '" .. legacy .. "'")
  end
  if primary_value ~= nil then return primary_value end
  return legacy_value
end

local function normalized_name(value)
  return tostring(value or ""):lower():gsub("[%s%-]+", "_")
end

local function clean_error_message(message)
  message = tostring(message or "")
  local cleaned = message:match("^%[string [^%]]+%]:%d+:%s*(.*)$")
    or message:match("^[^:]+:%d+:%s*(.*)$")
  return cleaned and cleaned ~= "" and cleaned or message
end

local function format_number(value, precision)
  precision = precision or 6
  if not finite_number(value) then return tostring(value) end
  local text = string.format("%." .. tostring(precision) .. "g", value)
  return text == "-0" and "0" or text
end

local function scaled_tolerance(scale_value, multiplier)
  return (multiplier or 128) * MACHINE_EPSILON
    * math.max(math.abs(scale_value or 0), MIN_NORMAL)
end

local function near_zero(value, scale_value, multiplier)
  return math.abs(value) <= scaled_tolerance(scale_value, multiplier)
end

local function hypot(x, y)
  x, y = math.abs(x), math.abs(y)
  local scale_value = math.max(x, y)
  if scale_value == math.huge then return math.huge end
  if scale_value == 0 then return 0 end
  return scale_value * math.sqrt((x / scale_value) ^ 2 + (y / scale_value) ^ 2)
end

local function add(a, b) return V(a.x + b.x, a.y + b.y) end
local function sub(a, b) return V(a.x - b.x, a.y - b.y) end
local function scale(vector, factor) return V(vector.x * factor, vector.y * factor) end
local function lerp(a, b, t) return add(scale(a, 1 - t), scale(b, t)) end
local function dot(a, b) return a.x * b.x + a.y * b.y end
local function cross(a, b) return a.x * b.y - a.y * b.x end
local function length(vector) return hypot(vector.x, vector.y) end
local function distance(a, b) return hypot(a.x - b.x, a.y - b.y) end
local function midpoint(a, b) return V(a.x * 0.5 + b.x * 0.5, a.y * 0.5 + b.y * 0.5) end
local function perpendicular(vector) return V(-vector.y, vector.x) end

local function vector_scale(...)
  local result = 0
  for index = 1, select("#", ...) do
    local vector = select(index, ...)
    if vector then result = math.max(result, math.abs(vector.x), math.abs(vector.y)) end
  end
  return result
end

local function unit(vector, context)
  local magnitude = length(vector)
  if not finite_number(magnitude) or near_zero(magnitude, vector_scale(vector), 4096) then
    error((context or "direction") .. " must be nonzero")
  end
  return scale(vector, 1 / magnitude)
end

local function coordinate_value(point, key, fallback_key)
  local ok, value = pcall(function() return point[key] end)
  if ok and value ~= nil then return value end
  if fallback_key ~= nil then
    local fallback_ok, fallback = pcall(function() return point[fallback_key] end)
    if fallback_ok then return fallback end
  end
  return nil
end

local function point_from_table(point, name)
  name = name or "point"
  if point == nil then error(name .. " must be a point table or vector") end
  local x = number_value(coordinate_value(point, "x", 1), nil)
  local y = number_value(coordinate_value(point, "y", 2), nil)
  if x == nil or y == nil then error(name .. " must contain x/y numbers") end
  if not finite_number(x) or not finite_number(y) then
    error(name .. " must contain finite x/y numbers")
  end
  return V(x, y)
end

local function point_record(point)
  if not finite_number(point.x) or not finite_number(point.y) then
    error("derived point is not finite")
  end
  return { x = point.x, y = point.y }
end

local function points_from_table(points, expected, name)
  name = name or "points"
  if type(points) ~= "table" then error(name .. " must be a point list") end
  if expected and #points ~= expected then
    error("exactly " .. tostring(expected) .. " points are required")
  end
  local result = {}
  for index, point in ipairs(points) do
    result[index] = point_from_table(point, name .. "[" .. tostring(index) .. "]")
  end
  return result
end

local function line_from_points(p1, p2, name)
  name = name or "line"
  p1 = point_from_table(p1, name .. ".p1")
  p2 = point_from_table(p2, name .. ".p2")
  local direction = sub(p2, p1)
  local magnitude = length(direction)
  if not finite_number(magnitude)
      or near_zero(magnitude, vector_scale(direction), 4096) then
    error(name .. " endpoints must be distinct")
  end
  local a, b = -direction.y / magnitude, direction.x / magnitude
  local c = -(a * p1.x + b * p1.y)
  if not finite_number(c) then error(name .. " equation is not finite") end
  return {
    p1 = p1, p2 = p2, point = p1, direction = scale(direction, 1 / magnitude),
    a = a, b = b, c = c,
  }
end

local function line_from_equation(a, b, c, preferred_point)
  a = finite_number_option(a, nil, "line.a")
  b = finite_number_option(b, nil, "line.b")
  c = finite_number_option(c, 0, "line.c")
  local norm = hypot(a, b)
  if not finite_number(norm) or norm == 0 then error("line equation has no direction") end
  a, b, c = a / norm, b / norm, c / norm
  local point
  if preferred_point then
    local preferred = point_from_table(preferred_point, "line.point")
    local offset = a * preferred.x + b * preferred.y + c
    point = V(preferred.x - a * offset, preferred.y - b * offset)
  elseif math.abs(a) >= math.abs(b) then
    point = V(-c / a, 0)
  else
    point = V(0, -c / b)
  end
  if not finite_number(point.x) or not finite_number(point.y) then
    error("line equation does not have a finite representable point")
  end
  local direction = V(-b, a)
  return {
    point = point, direction = direction, p1 = point, p2 = add(point, direction),
    a = a, b = b, c = c,
  }
end

local function line_from_table(line, name)
  name = name or "line"
  if type(line) ~= "table" then error(name .. " must be a line table") end
  local coefficient_a = rawget(line, "coefficient_a") or rawget(line, "A")
  local coefficient_b = rawget(line, "coefficient_b") or rawget(line, "B")
  local coefficient_c = rawget(line, "coefficient_c") or rawget(line, "C")
  if coefficient_a == nil and type(rawget(line, "a")) == "number"
      and type(rawget(line, "b")) == "number"
      and rawget(line, "p1") == nil and rawget(line, 1) == nil then
    coefficient_a, coefficient_b, coefficient_c = line.a, line.b, line.c
  end
  if coefficient_a ~= nil or coefficient_b ~= nil then
    return line_from_equation(coefficient_a, coefficient_b, coefficient_c, line.point)
  end
  local p1 = line.p1 or line.start or line.a or line[1]
  local p2 = line.p2 or line.finish or line.b or line[2]
  if type(line.points) == "table" then
    p1, p2 = p1 or line.points[1], p2 or line.points[2]
  end
  return line_from_points(p1, p2, name)
end

local function line_record(line)
  return {
    point = point_record(line.point or line.p1),
    direction = point_record(unit(line.direction or sub(line.p2, line.p1), "line direction")),
    equation = { a = line.a, b = line.b, c = line.c },
  }
end

function M.bounds_from_table(bounds)
  if type(bounds) ~= "table" then error("bounds must be a table") end
  local first = bounds.p1 or bounds.min or bounds[1]
  local second = bounds.p2 or bounds.max or bounds[2]
  local left = bounds.left or bounds.min_x or bounds.xmin
  local right = bounds.right or bounds.max_x or bounds.xmax
  local bottom = bounds.bottom or bounds.min_y or bounds.ymin
  local top = bounds.top or bounds.max_y or bounds.ymax
  if first ~= nil or second ~= nil then
    if first == nil or second == nil then error("bounds require both corner points") end
    first, second = point_from_table(first, "bounds.p1"), point_from_table(second, "bounds.p2")
    left, right = math.min(first.x, second.x), math.max(first.x, second.x)
    bottom, top = math.min(first.y, second.y), math.max(first.y, second.y)
  else
    left = finite_number_option(left, nil, "bounds.left")
    right = finite_number_option(right, nil, "bounds.right")
    bottom = finite_number_option(bottom, nil, "bounds.bottom")
    top = finite_number_option(top, nil, "bounds.top")
  end
  if not left or not right or not bottom or not top or left >= right or bottom >= top then
    error("bounds must have positive width and height")
  end
  return {
    left = left, right = right, bottom = bottom, top = top,
    corners = { V(left, bottom), V(right, bottom), V(right, top), V(left, top) },
  }
end

local function validate_keys(options, allowed, context)
  for key, _ in pairs(options) do
    if not allowed[key] then
      error((context or "options") .. " contains unsupported field '" .. tostring(key) .. "'")
    end
  end
end

local function normalize_coefficients(coefficients)
  if type(coefficients) ~= "table" or #coefficients ~= 6 then
    error("exactly six conic coefficients are required")
  end
  local result, scale_value = {}, 0
  for index = 1, 6 do
    local value = number_value(coefficients[index], nil)
    if not finite_number(value) then error("conic coefficients must be finite numbers") end
    result[index] = value
    scale_value = math.max(scale_value, math.abs(value))
  end
  if scale_value == 0 then error("conic coefficients must not all be zero") end
  for index = 1, 6 do result[index] = result[index] / scale_value end
  if coefficients.eccentricity ~= nil then result.eccentricity = coefficients.eccentricity end
  return result
end

local function conic_matrix_determinant(coefficients)
  local a, b, c, d, e, f = unpack(normalize_coefficients(coefficients))
  return a * c * f + b * d * e * 0.25
    - a * e * e * 0.25 - c * d * d * 0.25 - b * b * f * 0.25
end

local function is_degenerate_conic(coefficients)
  coefficients = normalize_coefficients(coefficients)
  local determinant = conic_matrix_determinant(coefficients)
  local term_scale = math.max(MIN_NORMAL,
    math.abs(coefficients[1] * coefficients[3] * coefficients[6])
      + math.abs(coefficients[2] * coefficients[4] * coefficients[5] * 0.25)
      + math.abs(coefficients[1] * coefficients[5] * coefficients[5] * 0.25)
      + math.abs(coefficients[3] * coefficients[4] * coefficients[4] * 0.25)
      + math.abs(coefficients[2] * coefficients[2] * coefficients[6] * 0.25)
  )
  return near_zero(determinant, term_scale, 8192), determinant
end

local function conic_terms(point)
  point = point_from_table(point, "point")
  return { point.x * point.x, point.x * point.y, point.y * point.y, point.x, point.y, 1 }
end

local function evaluate_conic(coefficients, point)
  coefficients = normalize_coefficients(coefficients)
  local terms = conic_terms(point)
  local value, magnitude = 0, 0
  for index = 1, 6 do
    local term = coefficients[index] * terms[index]
    if not finite_number(term) then error("conic evaluation exceeds numeric range") end
    value, magnitude = value + term, magnitude + math.abs(term)
  end
  if not finite_number(value) or not finite_number(magnitude) then
    error("conic evaluation exceeds numeric range")
  end
  return value, magnitude
end

function Advanced.conic_matrix(coefficients)
  local a, b, c, d, e, f = unpack(normalize_coefficients(coefficients))
  return {
    { a, 0.5 * b, 0.5 * d },
    { 0.5 * b, c, 0.5 * e },
    { 0.5 * d, 0.5 * e, f },
  }
end

function Advanced.matrix3_determinant(matrix)
  return matrix[1][1] * (matrix[2][2] * matrix[3][3] - matrix[2][3] * matrix[3][2])
    - matrix[1][2] * (matrix[2][1] * matrix[3][3] - matrix[2][3] * matrix[3][1])
    + matrix[1][3] * (matrix[2][1] * matrix[3][2] - matrix[2][2] * matrix[3][1])
end

function Advanced.matrix3_adjugate(matrix)
  return {
    {
      matrix[2][2] * matrix[3][3] - matrix[2][3] * matrix[3][2],
      matrix[1][3] * matrix[3][2] - matrix[1][2] * matrix[3][3],
      matrix[1][2] * matrix[2][3] - matrix[1][3] * matrix[2][2],
    },
    {
      matrix[2][3] * matrix[3][1] - matrix[2][1] * matrix[3][3],
      matrix[1][1] * matrix[3][3] - matrix[1][3] * matrix[3][1],
      matrix[1][3] * matrix[2][1] - matrix[1][1] * matrix[2][3],
    },
    {
      matrix[2][1] * matrix[3][2] - matrix[2][2] * matrix[3][1],
      matrix[1][2] * matrix[3][1] - matrix[1][1] * matrix[3][2],
      matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1],
    },
  }
end

function Advanced.matrix3_vector(matrix, vector)
  return {
    matrix[1][1] * vector[1] + matrix[1][2] * vector[2] + matrix[1][3] * vector[3],
    matrix[2][1] * vector[1] + matrix[2][2] * vector[2] + matrix[2][3] * vector[3],
    matrix[3][1] * vector[1] + matrix[3][2] * vector[2] + matrix[3][3] * vector[3],
  }
end

function Advanced.coefficients_from_symmetric_matrix(matrix)
  return normalize_coefficients({
    matrix[1][1],
    matrix[1][2] + matrix[2][1],
    matrix[2][2],
    matrix[1][3] + matrix[3][1],
    matrix[2][3] + matrix[3][2],
    matrix[3][3],
  })
end

function Advanced.normalized_line_coordinates(line)
  line = line_from_table(line, "line")
  return { line.a, line.b, line.c }, line
end

M.finite_number = finite_number
M.options_table = options_table
M.number_value = number_value
M.finite_number_option = finite_number_option
M.positive_number_option = positive_number_option
M.nonnegative_number_option = nonnegative_number_option
M.positive_integer_option = positive_integer_option
M.bool_value = bool_value
M.normalized_name = normalized_name
M.clean_error_message = clean_error_message
M.format_number = format_number
M.scaled_tolerance = scaled_tolerance
M.near_zero = near_zero
M.hypot = hypot
M.add = add
M.sub = sub
M.scale = scale
M.lerp = lerp
M.dot = dot
M.cross = cross
M.length = length
M.distance = distance
M.midpoint = midpoint
M.perpendicular = perpendicular
M.unit = unit
M.vector_scale = vector_scale
M.point_from_table = point_from_table
M.point_record = point_record
M.points_from_table = points_from_table
M.line_from_equation = line_from_equation
M.line_from_table = line_from_table
M.line_record = line_record
M.validate_keys = validate_keys
M.normalize_conic_coefficients = normalize_coefficients
M.conic_matrix_determinant = conic_matrix_determinant
M.is_degenerate_conic = is_degenerate_conic
M.evaluate_conic = evaluate_conic
M.conic_matrix = Advanced.conic_matrix
M.matrix3_determinant = Advanced.matrix3_determinant
M.matrix3_adjugate = Advanced.matrix3_adjugate
M.matrix3_vector = Advanced.matrix3_vector
M.coefficients_from_symmetric_matrix = Advanced.coefficients_from_symmetric_matrix

local function jacobi_null_vector(rows)
  local row_count, column_count = #rows, #rows[1]
  local values, vectors = {}, {}
  for row = 1, row_count do
    values[row] = {}
    for column = 1, column_count do values[row][column] = rows[row][column] end
  end
  for row = 1, column_count do
    vectors[row] = {}
    for column = 1, column_count do
      vectors[row][column] = row == column and 1 or 0
    end
  end

  for _ = 1, 160 do
    local changed = false
    for first = 1, column_count - 1 do
      for second = first + 1, column_count do
        local alpha, beta, gamma = 0, 0, 0
        for row = 1, row_count do
          local left, right = values[row][first], values[row][second]
          alpha = alpha + left * left
          beta = beta + right * right
          gamma = gamma + left * right
        end
        local pair_scale = math.sqrt(math.max(alpha * beta, 0))
        if math.abs(gamma) > scaled_tolerance(math.max(pair_scale, MIN_NORMAL), 256) then
          local tau = (beta - alpha) / (2 * gamma)
          local tangent
          if tau >= 0 then
            tangent = 1 / (tau + hypot(1, tau))
          else
            tangent = -1 / (-tau + hypot(1, tau))
          end
          local cosine = 1 / math.sqrt(1 + tangent * tangent)
          local sine = cosine * tangent
          for row = 1, row_count do
            local left, right = values[row][first], values[row][second]
            values[row][first] = cosine * left - sine * right
            values[row][second] = sine * left + cosine * right
          end
          for row = 1, column_count do
            local left, right = vectors[row][first], vectors[row][second]
            vectors[row][first] = cosine * left - sine * right
            vectors[row][second] = sine * left + cosine * right
          end
          changed = true
        end
      end
    end
    if not changed then break end
  end

  local singular_values, order = {}, {}
  for column = 1, column_count do
    local norm_squared = 0
    for row = 1, row_count do
      norm_squared = norm_squared + values[row][column] * values[row][column]
    end
    singular_values[column] = math.sqrt(math.max(norm_squared, 0))
    order[column] = column
  end
  table.sort(order, function(left, right)
    return singular_values[left] < singular_values[right]
  end)
  local null_vector = {}
  for row = 1, column_count do null_vector[row] = vectors[row][order[1]] end
  return null_vector, singular_values[order[1]], singular_values[order[2]],
    singular_values[order[#order]]
end

local function conic_coefficients_from_five_points(input_points)
  local points = points_from_table(input_points, 5, "points")
  local center = V(0, 0)
  for _, point in ipairs(points) do center = add(center, scale(point, 0.2)) end
  local coordinate_scale = 0
  for _, point in ipairs(points) do
    coordinate_scale = math.max(
      coordinate_scale,
      math.abs(point.x - center.x),
      math.abs(point.y - center.y)
    )
  end
  if coordinate_scale == 0 or not finite_number(coordinate_scale) then
    error("five points do not determine a stable conic")
  end
  for first = 1, 4 do
    for second = first + 1, 5 do
      if near_zero(distance(points[first], points[second]), coordinate_scale, 2048) then
        error("five distinct points are required")
      end
    end
  end

  local rows = {}
  for index, point in ipairs(points) do
    local x = (point.x - center.x) / coordinate_scale
    local y = (point.y - center.y) / coordinate_scale
    rows[index] = { x * x, x * y, y * y, x, y, 1 }
  end
  local normalized, smallest, second_smallest, largest = jacobi_null_vector(rows)
  if largest == 0 or second_smallest <= scaled_tolerance(largest, 32768) then
    error("five points do not determine a unique stable conic")
  end
  if smallest > scaled_tolerance(largest, 32768) then
    error("five-point conic has no reliable homogeneous nullspace")
  end
  normalized = normalize_coefficients(normalized)
  -- At this point the sample coordinates are centered and scaled to order one.
  -- Test the determinant in that conditioned coordinate system: doing it only
  -- after translating back can either hide a pair of lines in round-off or
  -- reject an otherwise valid conic merely because its coordinates are large.
  if near_zero(conic_matrix_determinant(normalized), 1, 8192) then
    error("five points define a degenerate conic")
  end
  local maximum_residual = 0
  for sample = 1, 5 do
    local residual = 0
    for column = 1, 6 do
      residual = residual + rows[sample][column] * normalized[column]
    end
    maximum_residual = math.max(maximum_residual, math.abs(residual))
  end
  if maximum_residual > 1e-7 then
    error("five-point conic is numerically ill-conditioned")
  end

  local a, b, c, d, e, f = unpack(normalized)
  local coordinate_scale2 = coordinate_scale * coordinate_scale
  if coordinate_scale2 == 0 or not finite_number(coordinate_scale2) then
    error("five-point coordinate scale exceeds numeric range")
  end
  local qx, qy = center.x / coordinate_scale, center.y / coordinate_scale
  local coefficients = normalize_coefficients({
    a / coordinate_scale2,
    b / coordinate_scale2,
    c / coordinate_scale2,
    (d - 2 * a * qx - b * qy) / coordinate_scale,
    (e - b * qx - 2 * c * qy) / coordinate_scale,
    f - d * qx - e * qy + a * qx * qx + b * qx * qy + c * qy * qy,
  })
  if is_degenerate_conic(coefficients) then
    error("five points define a degenerate conic")
  end
  return coefficients
end

local function eigenvectors_2x2(a, b_half, c)
  local trace = 0.5 * (a + c)
  local difference = 0.5 * (a - c)
  local root = hypot(difference, b_half)
  local lambda1, lambda2 = trace + root, trace - root
  local direction1
  if math.abs(b_half) > scaled_tolerance(math.max(math.abs(a), math.abs(c)), 1024) then
    direction1 = unit(V(b_half, lambda1 - a), "conic axis")
  elseif a >= c then
    direction1 = V(1, 0)
  else
    direction1 = V(0, 1)
  end
  return lambda1, lambda2, direction1, perpendicular(direction1)
end

local function classify_conic(coefficients)
  coefficients = normalize_coefficients(coefficients)
  if is_degenerate_conic(coefficients) then
    return { kind = "degenerate", classification = "degenerate", degenerate = true,
      coefficients = coefficients }
  end
  local a, b, c = coefficients[1], coefficients[2], coefficients[3]
  local discriminant = b * b - 4 * a * c
  local discriminant_scale = math.abs(b * b) + math.abs(4 * a * c)
  local tolerance = scaled_tolerance(discriminant_scale, 4096)
  local kind
  if discriminant > tolerance then
    kind = "hyperbola"
  elseif discriminant < -tolerance then
    local circular_scale = math.max(math.abs(a), math.abs(c), MIN_NORMAL)
    kind = math.abs(a - c) <= scaled_tolerance(circular_scale, 4096)
      and math.abs(b) <= scaled_tolerance(circular_scale, 4096)
      and "circle" or "ellipse"
  else
    kind = "parabola"
  end
  return {
    kind = kind,
    classification = kind,
    degenerate = false,
    discriminant = discriminant,
    coefficients = coefficients,
  }
end

local function point_records(points)
  local result = {}
  for index, point in ipairs(points or {}) do result[index] = point_record(point) end
  return result
end

function Advanced.degenerate_conic_properties(coefficients)
  coefficients = normalize_coefficients(coefficients)
  local a, b, c, d, e, f = unpack(coefficients)
  local quadratic_scale = math.max(math.abs(a), math.abs(b), math.abs(c), MIN_NORMAL)
  local linear_scale = math.max(math.abs(d), math.abs(e), MIN_NORMAL)
  local h_determinant = a * c - 0.25 * b * b
  local h_scale = math.abs(a * c) + math.abs(0.25 * b * b)
  local result = {
    kind = "degenerate",
    classification = "degenerate",
    degenerate = true,
    coefficients = coefficients,
    lines = {},
    points = {},
  }

  if not near_zero(h_determinant, math.max(h_scale, MIN_NORMAL), 8192) then
    local center = V(
      (b * e - 2 * c * d) / (4 * h_determinant),
      (b * d - 2 * a * e) / (4 * h_determinant)
    )
    local lambda1, lambda2, direction1, direction2 = eigenvectors_2x2(a, 0.5 * b, c)
    local value, magnitude = evaluate_conic(coefficients, center)
    result.center = center
    if lambda1 * lambda2 < 0
        and math.abs(value) <= scaled_tolerance(math.max(magnitude, MIN_NORMAL), 32768) then
      local positive_value, positive_direction, negative_value, negative_direction
      if lambda1 > 0 then
        positive_value, positive_direction = lambda1, direction1
        negative_value, negative_direction = lambda2, direction2
      else
        positive_value, positive_direction = lambda2, direction2
        negative_value, negative_direction = lambda1, direction1
      end
      local positive_root, negative_root = math.sqrt(positive_value), math.sqrt(-negative_value)
      for _, sign in ipairs({ -1, 1 }) do
        local normal = add(
          scale(positive_direction, positive_root),
          scale(negative_direction, sign * negative_root)
        )
        result.lines[#result.lines + 1] = line_from_equation(
          normal.x, normal.y, -dot(normal, center), center
        )
      end
      result.subtype = "intersecting_lines"
    elseif lambda1 * lambda2 > 0
        and math.abs(value) <= scaled_tolerance(math.max(magnitude, MIN_NORMAL), 32768) then
      result.subtype = "point"
      result.point = center
      result.points[1] = center
    else
      result.subtype = "empty"
    end
    return result
  end

  if quadratic_scale > scaled_tolerance(
      math.max(quadratic_scale, linear_scale, math.abs(f), MIN_NORMAL), 8192) then
    local lambda1, lambda2, direction1, direction2 = eigenvectors_2x2(a, 0.5 * b, c)
    local lambda, normal_direction
    if math.abs(lambda1) >= math.abs(lambda2) then
      lambda, normal_direction = lambda1, direction1
    else
      lambda, normal_direction = lambda2, direction2
    end
    local null_direction = perpendicular(normal_direction)
    local linear_normal = d * normal_direction.x + e * normal_direction.y
    local linear_null = d * null_direction.x + e * null_direction.y
    if not near_zero(linear_null, math.max(linear_scale, MIN_NORMAL), 8192) then
      result.subtype = "unstable"
      result.message = "near-degenerate parabola cannot be factored reliably"
      return result
    end
    local center_coordinate = -linear_normal / (2 * lambda)
    local completed_constant = f - linear_normal * linear_normal / (4 * lambda)
    local separation_squared = -completed_constant / lambda
    local separation_scale = math.max(
      math.abs(completed_constant / lambda),
      math.abs(center_coordinate * center_coordinate),
      MIN_NORMAL
    )
    if separation_squared > scaled_tolerance(separation_scale, 8192) then
      local separation = math.sqrt(separation_squared)
      for _, sign in ipairs({ -1, 1 }) do
        local coordinate = center_coordinate + sign * separation
        result.lines[#result.lines + 1] = line_from_equation(
          normal_direction.x, normal_direction.y, -coordinate
        )
      end
      result.subtype = "parallel_lines"
    elseif math.abs(separation_squared) <= scaled_tolerance(separation_scale, 8192) then
      result.lines[1] = line_from_equation(
        normal_direction.x, normal_direction.y, -center_coordinate
      )
      result.subtype = "double_line"
      result.multiplicity = 2
    else
      result.subtype = "empty"
    end
    return result
  end

  if linear_scale > scaled_tolerance(math.max(linear_scale, math.abs(f), MIN_NORMAL), 8192) then
    result.lines[1] = line_from_equation(d, e, f)
    result.subtype = "single_line"
    return result
  end
  result.subtype = "empty"
  return result
end

local function conic_properties(coefficients)
  local classification = classify_conic(coefficients)
  if classification.degenerate then
    return Advanced.degenerate_conic_properties(classification.coefficients)
  end
  coefficients = classification.coefficients
  local a, b, c, d, e, f = unpack(coefficients)
  local result = {
    kind = classification.kind,
    classification = classification.kind,
    coefficients = coefficients,
    degenerate = false,
  }

  if classification.kind ~= "parabola" then
    local center_determinant = 4 * a * c - b * b
    local center_scale = math.abs(4 * a * c) + math.abs(b * b)
    if near_zero(center_determinant, center_scale, 4096) then
      error("central conic has an unstable center")
    end
    local center = V(
      (b * e - 2 * c * d) / center_determinant,
      (b * d - 2 * a * e) / center_determinant
    )
    local value_at_center = evaluate_conic(coefficients, center)
    local lambda1, lambda2, direction1, direction2 = eigenvectors_2x2(a, b * 0.5, c)
    result.center, result.center_record = center, point_record(center)

    if classification.kind == "ellipse" or classification.kind == "circle" then
      local radius1_squared = -value_at_center / lambda1
      local radius2_squared = -value_at_center / lambda2
      if radius1_squared <= 0 or radius2_squared <= 0
          or not finite_number(radius1_squared) or not finite_number(radius2_squared) then
        error("ellipse has no real nondegenerate locus")
      end
      local radius1, radius2 = math.sqrt(radius1_squared), math.sqrt(radius2_squared)
      local major_radius, minor_radius, major_direction, minor_direction
      if radius1 >= radius2 then
        major_radius, minor_radius = radius1, radius2
        major_direction, minor_direction = direction1, direction2
      else
        major_radius, minor_radius = radius2, radius1
        major_direction, minor_direction = direction2, direction1
      end
      local focal_radius = math.sqrt(math.max(
        0, (major_radius - minor_radius) * (major_radius + minor_radius)
      ))
      local eccentricity = focal_radius / major_radius
      result.major_radius, result.minor_radius = major_radius, minor_radius
      result.major_direction, result.minor_direction = major_direction, minor_direction
      result.axis1, result.axis2 = scale(major_direction, major_radius),
        scale(minor_direction, minor_radius)
      result.vertices = {
        add(center, scale(major_direction, major_radius)),
        sub(center, scale(major_direction, major_radius)),
      }
      result.co_vertices = {
        add(center, scale(minor_direction, minor_radius)),
        sub(center, scale(minor_direction, minor_radius)),
      }
      result.foci = {
        add(center, scale(major_direction, focal_radius)),
        sub(center, scale(major_direction, focal_radius)),
      }
      result.eccentricity = eccentricity
      result.focal_radius = focal_radius
      result.semi_latus_rectum = minor_radius * minor_radius / major_radius
      result.area = math.pi * major_radius * minor_radius
      result.auxiliary_circles = {
        { center = center, radius = major_radius },
      }
      if math.abs(major_radius - minor_radius)
          > scaled_tolerance(math.max(major_radius, minor_radius), 4096) then
        result.auxiliary_circles[2] = { center = center, radius = minor_radius }
      end
      result.director_circle = {
        center = center,
        radius = hypot(major_radius, minor_radius),
      }
      result.latus_recta = {}
      if classification.kind ~= "circle" then
        for _, focus in ipairs(result.foci) do
          result.latus_recta[#result.latus_recta + 1] = {
            line = { point = focus, direction = minor_direction },
            endpoints = {
              add(focus, scale(minor_direction, result.semi_latus_rectum)),
              sub(focus, scale(minor_direction, result.semi_latus_rectum)),
            },
          }
        end
      end
      result.directrices = {}
      if eccentricity > scaled_tolerance(1, 1024) then
        local directrix_distance = major_radius / eccentricity
        result.directrices = {
          { point = add(center, scale(major_direction, directrix_distance)),
            direction = minor_direction },
          { point = sub(center, scale(major_direction, directrix_distance)),
            direction = minor_direction },
        }
      end
    else
      local candidate1, candidate2 = -value_at_center / lambda1, -value_at_center / lambda2
      local transverse_direction, conjugate_direction, a_squared, b_squared
      if candidate1 > 0 and candidate2 < 0 then
        transverse_direction, conjugate_direction = direction1, direction2
        a_squared, b_squared = candidate1, -candidate2
      elseif candidate2 > 0 and candidate1 < 0 then
        transverse_direction, conjugate_direction = direction2, direction1
        a_squared, b_squared = candidate2, -candidate1
      else
        error("hyperbola has no real nondegenerate locus")
      end
      local a_radius, b_radius = math.sqrt(a_squared), math.sqrt(b_squared)
      local focal_radius = hypot(a_radius, b_radius)
      local eccentricity = focal_radius / a_radius
      result.a, result.b = a_radius, b_radius
      result.focal_radius = focal_radius
      result.u, result.v = transverse_direction, conjugate_direction
      result.vertices = {
        add(center, scale(transverse_direction, a_radius)),
        sub(center, scale(transverse_direction, a_radius)),
      }
      result.foci = {
        add(center, scale(transverse_direction, focal_radius)),
        sub(center, scale(transverse_direction, focal_radius)),
      }
      result.eccentricity = eccentricity
      result.semi_latus_rectum = b_radius * b_radius / a_radius
      result.auxiliary_circles = {
        { center = center, radius = a_radius },
      }
      result.latus_recta = {}
      for _, focus in ipairs(result.foci) do
        result.latus_recta[#result.latus_recta + 1] = {
          line = { point = focus, direction = conjugate_direction },
          endpoints = {
            add(focus, scale(conjugate_direction, result.semi_latus_rectum)),
            sub(focus, scale(conjugate_direction, result.semi_latus_rectum)),
          },
        }
      end
      local director_radius_squared = a_radius * a_radius - b_radius * b_radius
      if director_radius_squared > scaled_tolerance(
          math.abs(a_radius * a_radius) + math.abs(b_radius * b_radius), 4096) then
        result.director_circle = {
          center = center,
          radius = math.sqrt(director_radius_squared),
        }
      end
      local directrix_distance = a_radius / eccentricity
      result.directrices = {
        { point = add(center, scale(transverse_direction, directrix_distance)),
          direction = conjugate_direction },
        { point = sub(center, scale(transverse_direction, directrix_distance)),
          direction = conjugate_direction },
      }
      result.asymptotes = {
        { point = center,
          direction = add(scale(transverse_direction, a_radius), scale(conjugate_direction, b_radius)) },
        { point = center,
          direction = sub(scale(transverse_direction, a_radius), scale(conjugate_direction, b_radius)) },
      }
    end
  else
    local lambda1, lambda2, direction1, direction2 = eigenvectors_2x2(a, b * 0.5, c)
    local lambda, normal_direction, axis_direction
    if math.abs(lambda1) >= math.abs(lambda2) then
      lambda, normal_direction, axis_direction = lambda1, direction1, direction2
    else
      lambda, normal_direction, axis_direction = lambda2, direction2, direction1
    end
    local linear_normal = d * normal_direction.x + e * normal_direction.y
    local linear_axis = d * axis_direction.x + e * axis_direction.y
    if near_zero(lambda, math.max(math.abs(a), math.abs(b), math.abs(c)), 4096)
        or near_zero(linear_axis, hypot(d, e), 4096) then
      error("parabola is numerically degenerate")
    end
    local normal_coordinate = -linear_normal / (2 * lambda)
    local constant_after_square = f - linear_normal * linear_normal / (4 * lambda)
    local axis_coordinate = -constant_after_square / linear_axis
    local vertex = add(scale(normal_direction, normal_coordinate),
      scale(axis_direction, axis_coordinate))
    local focal_parameter = -linear_axis / (4 * lambda)
    if near_zero(focal_parameter, math.max(vector_scale(vertex), MIN_NORMAL), 4096) then
      error("parabola focal parameter is numerically zero")
    end
    local focus = add(vertex, scale(axis_direction, focal_parameter))
    result.vertex, result.vertices = vertex, { vertex }
    result.focus, result.foci = focus, { focus }
    result.axis_direction, result.normal_direction = axis_direction, normal_direction
    result.focal_parameter, result.eccentricity = focal_parameter, 1
    result.semi_latus_rectum = 2 * math.abs(focal_parameter)
    result.latus_recta = {
      {
        line = { point = focus, direction = normal_direction },
        endpoints = {
          add(focus, scale(normal_direction, 2 * math.abs(focal_parameter))),
          sub(focus, scale(normal_direction, 2 * math.abs(focal_parameter))),
        },
      },
    }
    result.directrices = {
      { point = sub(vertex, scale(axis_direction, focal_parameter)),
        direction = normal_direction },
    }
  end
  result.vertex_records = point_records(result.vertices)
  result.focus_records = point_records(result.foci)
  return result
end

M.conic_coefficients_from_five_points = conic_coefficients_from_five_points
M.classify_conic = classify_conic
M.degenerate_conic_properties = Advanced.degenerate_conic_properties
M.conic_properties = conic_properties

local function ellipse_coefficients(ellipse)
  local center = point_from_table(ellipse.center, "ellipse.center")
  local axis1 = point_from_table(ellipse.axis1, "ellipse.axis1")
  local axis2 = point_from_table(ellipse.axis2, "ellipse.axis2")
  local radius1, radius2 = length(axis1), length(axis2)
  if radius1 == 0 or radius2 == 0 then error("ellipse axes must be nonzero") end
  local unit1, unit2 = scale(axis1, 1 / radius1), scale(axis2, 1 / radius2)
  if math.abs(dot(unit1, unit2)) > 8192 * MACHINE_EPSILON then
    error("ellipse axes must be perpendicular")
  end
  local inverse1, inverse2 = 1 / radius1, 1 / radius2
  local inverse1_squared, inverse2_squared = inverse1 * inverse1, inverse2 * inverse2
  if inverse1_squared == 0 or inverse2_squared == 0 then
    error("ellipse world coefficients exceed numeric range")
  end
  local q11 = unit1.x * unit1.x * inverse1_squared
    + unit2.x * unit2.x * inverse2_squared
  local q12 = unit1.x * unit1.y * inverse1_squared
    + unit2.x * unit2.y * inverse2_squared
  local q22 = unit1.y * unit1.y * inverse1_squared
    + unit2.y * unit2.y * inverse2_squared
  return normalize_coefficients({
    q11,
    2 * q12,
    q22,
    -2 * (q11 * center.x + q12 * center.y),
    -2 * (q12 * center.x + q22 * center.y),
    q11 * center.x * center.x + 2 * q12 * center.x * center.y
      + q22 * center.y * center.y - 1,
  })
end

local function ellipse_from_center_quadratic(center, m11, m12, m22, scale_factor)
  center = point_from_table(center, "center")
  scale_factor = scale_factor or 1
  local coefficient_scale = math.max(math.abs(m11), math.abs(m12), math.abs(m22))
  if coefficient_scale == 0 then error("ellipse quadratic form must be positive definite") end
  local determinant = m11 * m22 - m12 * m12
  if determinant <= scaled_tolerance(coefficient_scale * coefficient_scale, 4096) then
    error("ellipse quadratic form must be positive definite")
  end
  local c11, c12, c22 = m22 / determinant, -m12 / determinant, m11 / determinant
  local lambda1, lambda2, direction1, direction2 = eigenvectors_2x2(c11, c12, c22)
  if lambda1 <= 0 or lambda2 <= 0 then error("ellipse axes must be positive") end
  return {
    center = center,
    axis1 = scale(direction1, math.sqrt(lambda1) * scale_factor),
    axis2 = scale(direction2, math.sqrt(lambda2) * scale_factor),
  }
end

local function solve_3x3(matrix, rhs)
  local function determinant3(value)
    return value[1][1] * (value[2][2] * value[3][3] - value[2][3] * value[3][2])
      - value[1][2] * (value[2][1] * value[3][3] - value[2][3] * value[3][1])
      + value[1][3] * (value[2][1] * value[3][2] - value[2][2] * value[3][1])
  end
  local determinant = determinant3(matrix)
  local scale_value = 0
  for row = 1, 3 do
    for column = 1, 3 do
      scale_value = math.max(scale_value, math.abs(matrix[row][column]))
    end
  end
  if near_zero(determinant, scale_value ^ 3, 4096) then return nil end
  local result = {}
  for column = 1, 3 do
    local replaced = {}
    for row = 1, 3 do
      replaced[row] = {}
      for inner = 1, 3 do
        replaced[row][inner] = inner == column and rhs[row] or matrix[row][inner]
      end
    end
    result[column] = determinant3(replaced) / determinant
    if not finite_number(result[column]) then return nil end
  end
  return result
end

local function steiner_ellipses(a, b, c)
  a, b, c = point_from_table(a, "a"), point_from_table(b, "b"), point_from_table(c, "c")
  local center = V(a.x / 3 + b.x / 3 + c.x / 3, a.y / 3 + b.y / 3 + c.y / 3)
  local points, coordinate_scale = { a, b, c }, 0
  for _, point in ipairs(points) do
    coordinate_scale = math.max(
      coordinate_scale, math.abs(point.x - center.x), math.abs(point.y - center.y)
    )
  end
  if coordinate_scale == 0 or not finite_number(coordinate_scale) then
    error("Steiner ellipse is undefined for a degenerate triangle")
  end
  local matrix = {}
  for index, point in ipairs(points) do
    local x = (point.x - center.x) / coordinate_scale
    local y = (point.y - center.y) / coordinate_scale
    matrix[index] = { x * x, 2 * x * y, y * y }
  end
  local solution = solve_3x3(matrix, { 1, 1, 1 })
  if not solution then error("Steiner ellipse is undefined for a degenerate triangle") end
  local circumellipse = ellipse_from_center_quadratic(
    center, solution[1], solution[2], solution[3], coordinate_scale
  )
  return {
    circumellipse = circumellipse,
    inellipse = {
      center = center,
      axis1 = scale(circumellipse.axis1, 0.5),
      axis2 = scale(circumellipse.axis2, 0.5),
    },
  }
end

local function cyclically_ordered_points(input_points)
  local points = points_from_table(input_points, 4, "points")
  local center = V(0, 0)
  for _, point in ipairs(points) do center = add(center, scale(point, 0.25)) end
  table.sort(points, function(left, right)
    return math.atan(left.y - center.y, left.x - center.x)
      < math.atan(right.y - center.y, right.x - center.x)
  end)
  local frame_scale, edges = 0, {}
  for index = 1, 4 do
    local next_index = index == 4 and 1 or index + 1
    local edge = distance(points[index], points[next_index])
    edges[index] = edge
    frame_scale = math.max(frame_scale, edge)
  end
  if frame_scale == 0 or not finite_number(frame_scale) then
    error("quadrilateral vertices must be distinct")
  end
  for _, edge in ipairs(edges) do
    if near_zero(edge, frame_scale, 4096) then
      error("quadrilateral vertices must be distinct")
    end
  end
  local area = 0
  for index = 1, 4 do
    local next_index = index == 4 and 1 or index + 1
    area = area + cross(
      scale(sub(points[index], center), 1 / frame_scale),
      scale(sub(points[next_index], center), 1 / frame_scale)
    )
  end
  if near_zero(area, 1, 16384) then
    error("quadrilateral is excessively ill-conditioned")
  end
  return points, center
end

function M.ellipse_from_conjugate_diameters(center, u, v)
  local coordinate_scale = math.max(vector_scale(u, v), MIN_NORMAL)
  if not finite_number(coordinate_scale) then
    error("quadrilateral side-midpoint frame exceeds numeric range")
  end
  local normalized_u, normalized_v = scale(u, 1 / coordinate_scale),
    scale(v, 1 / coordinate_scale)
  local determinant = cross(normalized_u, normalized_v)
  if near_zero(determinant, 1, 16384) then
    error("quadrilateral side-midpoint frame is degenerate")
  end
  local c11 = normalized_u.x * normalized_u.x + normalized_v.x * normalized_v.x
  local c12 = normalized_u.x * normalized_u.y + normalized_v.x * normalized_v.y
  local c22 = normalized_u.y * normalized_u.y + normalized_v.y * normalized_v.y
  local lambda1, lambda2, direction1, direction2 = eigenvectors_2x2(c11, c12, c22)
  if lambda1 <= 0 or lambda2 <= 0 then
    error("quadrilateral side-midpoint frame is degenerate")
  end
  local radius1 = coordinate_scale * math.sqrt(lambda1)
  local radius2 = coordinate_scale * math.sqrt(lambda2)
  if not finite_number(radius1) or not finite_number(radius2) then
    error("quadrilateral midpoint ellipse exceeds numeric range")
  end
  return {
    center = center,
    axis1 = scale(direction1, radius1),
    axis2 = scale(direction2, radius2),
  }
end

local function quadrilateral_midpoint_ellipse(input_points)
  local points, center = cyclically_ordered_points(input_points)
  local u = sub(midpoint(points[1], points[2]), center)
  local v = sub(midpoint(points[2], points[3]), center)
  return M.ellipse_from_conjugate_diameters(center, u, v), points
end

local function ellipse_from_foci_point(focus_a, focus_b, point)
  focus_a = point_from_table(focus_a, "focus_a")
  focus_b = point_from_table(focus_b, "focus_b")
  point = point_from_table(point, "point")
  local center = midpoint(focus_a, focus_b)
  local focal_radius = distance(focus_a, focus_b) * 0.5
  local distance_a, distance_b = distance(point, focus_a), distance(point, focus_b)
  local major_radius = distance_a * 0.5 + distance_b * 0.5
  local input_scale = math.max(focal_radius, major_radius, distance_a, distance_b, MIN_NORMAL)
  if not finite_number(major_radius)
      or major_radius <= focal_radius + scaled_tolerance(input_scale, 4096) then
    error("third point must define a nondegenerate ellipse")
  end
  local ratio = focal_radius / major_radius
  local minor_radius = major_radius * math.sqrt(math.max(0, 1 - ratio * ratio))
  if not finite_number(minor_radius) or near_zero(minor_radius, major_radius, 4096) then
    error("third point must define a nondegenerate ellipse")
  end
  local major_direction = not near_zero(focal_radius, input_scale, 4096)
    and unit(sub(focus_b, focus_a), "ellipse focal axis")
    or unit(sub(point, center), "ellipse major axis")
  return {
    center = center,
    axis1 = scale(major_direction, major_radius),
    axis2 = scale(perpendicular(major_direction), minor_radius),
    focus_a = focus_a,
    focus_b = focus_b,
    defining_point = point,
    major_radius = major_radius,
    minor_radius = minor_radius,
  }
end

local function line_signed_distance(line, point)
  line, point = line_from_table(line, "line"), point_from_table(point, "point")
  return line.a * point.x + line.b * point.y + line.c
end

local function conic_coefficients_for_focus_directrix(focus, directrix, eccentricity)
  focus = point_from_table(focus, "focus")
  directrix = line_from_table(directrix, "directrix")
  eccentricity = positive_number_option(eccentricity, 1, "eccentricity")
  local a, b, c = directrix.a, directrix.b, directrix.c
  local focus_distance = math.abs(a * focus.x + b * focus.y + c)
  local input_scale = math.max(
    distance(directrix.p1, directrix.p2),
    distance(focus, directrix.p1),
    distance(focus, directrix.p2),
    MIN_NORMAL
  )
  if near_zero(focus_distance, input_scale, 4096) then
    error("focus must not lie on the directrix or numerically too close to it")
  end
  local eccentricity_squared = eccentricity * eccentricity
  if not finite_number(eccentricity_squared) then error("eccentricity exceeds numeric range") end
  local coefficients = normalize_coefficients({
    1 - eccentricity_squared * a * a,
    -2 * eccentricity_squared * a * b,
    1 - eccentricity_squared * b * b,
    -2 * focus.x - 2 * eccentricity_squared * a * c,
    -2 * focus.y - 2 * eccentricity_squared * b * c,
    focus.x * focus.x + focus.y * focus.y - eccentricity_squared * c * c,
  })
  coefficients.eccentricity = eccentricity
  return coefficients
end

local function focus_directrix_conic_coefficients(focus, directrix, point)
  focus = point_from_table(focus, "focus")
  directrix = line_from_table(directrix, "directrix")
  point = point_from_table(point, "point")
  local distance_to_line = math.abs(line_signed_distance(directrix, point))
  local distance_to_focus = distance(point, focus)
  local input_scale = math.max(
    distance_to_focus,
    distance(directrix.p1, directrix.p2),
    math.abs(line_signed_distance(directrix, focus)),
    MIN_NORMAL
  )
  if near_zero(distance_to_line, input_scale, 4096) then
    error("point must not lie on or numerically too close to the directrix")
  end
  if near_zero(distance_to_focus, input_scale, 4096) then
    error("focus and point must be distinct")
  end
  return conic_coefficients_for_focus_directrix(
    focus, directrix, distance_to_focus / distance_to_line
  )
end

local function stable_asinh(value)
  local sign = value < 0 and -1 or 1
  value = math.abs(value)
  if value < 1e-8 then return sign * value end
  if value > 1e150 then return sign * (math.log(value) + LOG_TWO) end
  return sign * math.log(value + hypot(value, 1))
end

function M.stable_acosh(value)
  value = finite_number_option(value, nil, "acosh argument")
  if value < 1 then error("acosh argument must be at least one") end
  if value == 1 then return 0 end
  if value > 1e150 then return math.log(value) + LOG_TWO end
  return math.log(value + math.sqrt(value - 1) * math.sqrt(value + 1))
end

local function hyperbola_from_parameters(center, axis, a_radius, b_radius)
  center = point_from_table(center, "center")
  local direction = axis and line_from_table(axis, "axis").direction or V(1, 0)
  local u = unit(direction, "hyperbola axis")
  a_radius = positive_number_option(a_radius, 32, "a")
  b_radius = positive_number_option(b_radius, a_radius * 0.6, "b")
  return {
    center = center, u = u, v = perpendicular(u), a = a_radius, b = b_radius,
  }
end

local function stable_distance_difference(point, focus_a, focus_b, center, u, focal_radius)
  local distance_a, distance_b = distance(point, focus_a), distance(point, focus_b)
  local projection = dot(sub(point, center), u)
  local scale_value = math.max(
    math.abs(projection), focal_radius, distance_a, distance_b, MIN_NORMAL
  )
  local denominator = distance_a / scale_value + distance_b / scale_value
  if denominator == 0 then return 0 end
  return (4 * (focal_radius / scale_value) * (projection / scale_value)
    / denominator) * scale_value
end

local function hyperbola_from_foci_point(focus_a, focus_b, point)
  focus_a = point_from_table(focus_a, "focus_a")
  focus_b = point_from_table(focus_b, "focus_b")
  point = point_from_table(point, "point")
  local center = midpoint(focus_a, focus_b)
  local focal_distance = distance(focus_a, focus_b) * 0.5
  local input_scale = math.max(focal_distance, distance(focus_a, focus_b), MIN_NORMAL)
  if near_zero(focal_distance, input_scale, 4096) then error("hyperbola foci must be distinct") end
  local u, v = unit(sub(focus_b, focus_a), "hyperbola focal axis"), nil
  v = perpendicular(u)
  local difference = stable_distance_difference(
    point, focus_a, focus_b, center, u, focal_distance
  )
  local a_radius = math.abs(difference) * 0.5
  if a_radius <= scaled_tolerance(focal_distance, 4096)
      or a_radius >= focal_distance - scaled_tolerance(focal_distance, 4096) then
    error("point must define a nondegenerate hyperbola branch")
  end
  local ratio = a_radius / focal_distance
  local b_radius = focal_distance * math.sqrt(math.max(0, 1 - ratio * ratio))
  local relative = sub(point, center)
  return {
    center = center,
    u = u,
    v = v,
    a = a_radius,
    b = b_radius,
    point_parameter = math.abs(stable_asinh(dot(relative, v) / b_radius)),
    point_branch = dot(relative, u) < 0 and -1 or 1,
    defining_point = point,
  }
end

local function hyperbola_coefficients(hyperbola)
  local inverse_a, inverse_b = 1 / hyperbola.a, 1 / hyperbola.b
  local inverse_a_squared, inverse_b_squared = inverse_a * inverse_a, inverse_b * inverse_b
  if inverse_a_squared == 0 or inverse_b_squared == 0 then
    error("hyperbola world coefficients exceed numeric range")
  end
  local u, v, center = hyperbola.u, hyperbola.v, hyperbola.center
  local q11 = u.x * u.x * inverse_a_squared - v.x * v.x * inverse_b_squared
  local q12 = u.x * u.y * inverse_a_squared - v.x * v.y * inverse_b_squared
  local q22 = u.y * u.y * inverse_a_squared - v.y * v.y * inverse_b_squared
  return normalize_coefficients({
    q11,
    2 * q12,
    q22,
    -2 * (q11 * center.x + q12 * center.y),
    -2 * (q12 * center.x + q22 * center.y),
    q11 * center.x * center.x + 2 * q12 * center.x * center.y
      + q22 * center.y * center.y - 1,
  })
end

local function hyperbola_values(parameter)
  local exponential = math.exp(math.abs(parameter))
  if not finite_number(exponential) then error("hyperbola extent exceeds finite coordinate range") end
  local inverse = 1 / exponential
  local cosine_hyperbolic = 0.5 * (exponential + inverse)
  local sine_hyperbolic = 0.5 * (exponential - inverse)
  if parameter < 0 then sine_hyperbolic = -sine_hyperbolic end
  return cosine_hyperbolic, sine_hyperbolic
end

local function hyperbola_point(hyperbola, branch, parameter)
  local cosine_hyperbolic, sine_hyperbolic = hyperbola_values(parameter)
  local point = add(
    hyperbola.center,
    add(
      scale(hyperbola.u, branch * hyperbola.a * cosine_hyperbolic),
      scale(hyperbola.v, hyperbola.b * sine_hyperbolic)
    )
  )
  if not finite_number(point.x) or not finite_number(point.y) then
    error("hyperbola extent exceeds finite coordinate range")
  end
  return point
end

local function hyperbola_derivative(hyperbola, branch, parameter)
  local cosine_hyperbolic, sine_hyperbolic = hyperbola_values(parameter)
  return add(
    scale(hyperbola.u, branch * hyperbola.a * sine_hyperbolic),
    scale(hyperbola.v, hyperbola.b * cosine_hyperbolic)
  )
end

local function cubic_point(control, t)
  local one_minus = 1 - t
  return add(
    add(
      scale(control[1], one_minus ^ 3),
      scale(control[2], 3 * one_minus * one_minus * t)
    ),
    add(
      scale(control[3], 3 * one_minus * t * t),
      scale(control[4], t ^ 3)
    )
  )
end

local function hyperbola_cubic(hyperbola, branch, start_parameter, finish_parameter)
  local start_point = hyperbola_point(hyperbola, branch, start_parameter)
  local finish_point = hyperbola_point(hyperbola, branch, finish_parameter)
  local interval = finish_parameter - start_parameter
  return {
    start_point,
    add(start_point, scale(hyperbola_derivative(hyperbola, branch, start_parameter), interval / 3)),
    sub(finish_point, scale(hyperbola_derivative(hyperbola, branch, finish_parameter), interval / 3)),
    finish_point,
  }
end

local function adaptive_hyperbola_cubics(hyperbola, branch, t_max, tolerance, maximum_segments)
  t_max = positive_number_option(
    t_max, math.max(2.2, hyperbola.point_parameter or 0), "t_max"
  )
  tolerance = positive_number_option(tolerance, 0.25, "tolerance")
  maximum_segments = positive_integer_option(maximum_segments, 256, "max_segments", 4096)
  local cubics = {}
  local function subdivide(start_parameter, finish_parameter, depth)
    if #cubics >= maximum_segments then error("hyperbola approximation exceeded max_segments") end
    local control = hyperbola_cubic(hyperbola, branch, start_parameter, finish_parameter)
    local interval, error_value = finish_parameter - start_parameter, 0
    for _, fraction in ipairs({ 0.25, 0.5, 0.75 }) do
      local parameter = start_parameter + interval * fraction
      error_value = math.max(error_value, distance(
        hyperbola_point(hyperbola, branch, parameter),
        cubic_point(control, fraction)
      ))
    end
    if not finite_number(error_value) then
      error("hyperbola approximation error is not finite")
    end
    if error_value <= tolerance then
      cubics[#cubics + 1] = control
    else
      if depth >= 20 then
        error("hyperbola approximation could not satisfy the requested tolerance")
      end
      local middle_parameter = start_parameter * 0.5 + finish_parameter * 0.5
      subdivide(start_parameter, middle_parameter, depth + 1)
      subdivide(middle_parameter, finish_parameter, depth + 1)
    end
  end
  subdivide(-t_max, t_max, 0)
  return cubics, t_max
end

local function parabola_spline(properties, negative_extent, positive_extent)
  if properties.kind ~= "parabola" then error("parabola properties are required") end
  negative_extent = positive_number_option(negative_extent, 96, "negative_extent")
  positive_extent = positive_number_option(positive_extent, negative_extent, "positive_extent")
  local start_parameter, finish_parameter = -negative_extent, positive_extent
  local function point(parameter)
    return add(
      properties.vertex,
      add(
        scale(properties.normal_direction, parameter),
        scale(properties.axis_direction,
          parameter * parameter / (4 * properties.focal_parameter))
      )
    )
  end
  local start_point = point(start_parameter)
  local finish_point = point(finish_parameter)
  local middle_point = point(start_parameter * 0.5 + finish_parameter * 0.5)
  local control = sub(scale(middle_point, 2), scale(add(start_point, finish_point), 0.5))
  for _, point_value in ipairs({ start_point, control, finish_point }) do
    if not finite_number(point_value.x) or not finite_number(point_value.y) then
      error("parabola extent exceeds finite coordinate range")
    end
  end
  return { start_point, control, finish_point }
end

M.ellipse_coefficients = ellipse_coefficients
M.ellipse_from_center_quadratic = ellipse_from_center_quadratic
M.steiner_ellipses = steiner_ellipses
M.cyclically_ordered_points = cyclically_ordered_points
M.quadrilateral_midpoint_ellipse = quadrilateral_midpoint_ellipse
M.ellipse_from_foci_point = ellipse_from_foci_point
M.conic_coefficients_for_focus_directrix = conic_coefficients_for_focus_directrix
M.focus_directrix_conic_coefficients = focus_directrix_conic_coefficients
M.stable_asinh = stable_asinh
M.hyperbola_from_parameters = hyperbola_from_parameters
M.hyperbola_from_foci_point = hyperbola_from_foci_point
M.hyperbola_coefficients = hyperbola_coefficients
M.hyperbola_point = hyperbola_point
M.hyperbola_derivative = hyperbola_derivative
M.adaptive_hyperbola_cubics = adaptive_hyperbola_cubics
M.parabola_spline = parabola_spline

local function conic_gradient(coefficients, point)
  coefficients = normalize_coefficients(coefficients)
  point = point_from_table(point, "point")
  local a, b, c, d, e = unpack(coefficients)
  local gradient = V(
    2 * a * point.x + b * point.y + d,
    b * point.x + 2 * c * point.y + e
  )
  if not finite_number(gradient.x) or not finite_number(gradient.y) then
    error("conic gradient is not finite")
  end
  return gradient
end

local function conic_tangent_normal(coefficients, point)
  coefficients = normalize_coefficients(coefficients)
  point = point_from_table(point, "point")
  local value, magnitude = evaluate_conic(coefficients, point)
  if math.abs(value) > scaled_tolerance(math.max(magnitude, MIN_NORMAL), 32768) then
    error("point must lie on the conic")
  end
  local normal_direction = conic_gradient(coefficients, point)
  local gradient_scale = math.max(
    math.max(math.abs(coefficients[1]), math.abs(coefficients[2]), math.abs(coefficients[3]))
      * math.max(math.abs(point.x), math.abs(point.y)),
    math.abs(coefficients[4]),
    math.abs(coefficients[5]),
    MIN_NORMAL
  )
  if near_zero(length(normal_direction), gradient_scale, 4096) then
    error("conic tangent is undefined at a singular point")
  end
  return {
    tangent = { point = point, direction = perpendicular(normal_direction) },
    normal = { point = point, direction = normal_direction },
  }
end

local function conic_polar_line(coefficients, point)
  coefficients = normalize_coefficients(coefficients)
  point = point_from_table(point, "point")
  local a, b, c, d, e, f = unpack(coefficients)
  return line_from_equation(
    a * point.x + 0.5 * b * point.y + 0.5 * d,
    0.5 * b * point.x + c * point.y + 0.5 * e,
    0.5 * d * point.x + 0.5 * e * point.y + f,
    point
  )
end

local function roots_are_close(left, right)
  return math.abs(left - right)
    <= 32 * math.sqrt(MACHINE_EPSILON)
      * math.max(1, math.abs(left), math.abs(right))
end

local function conic_line_intersections(coefficients, input_line)
  coefficients = normalize_coefficients(coefficients)
  local line = line_from_table(input_line, "line")
  local point, direction = line.point, unit(line.direction, "line direction")
  local a, b, c, d, e, f = unpack(coefficients)
  local px, py, dx, dy = point.x, point.y, direction.x, direction.y
  local q2 = a * dx * dx + b * dx * dy + c * dy * dy
  local q1 = 2 * a * px * dx + b * (px * dy + py * dx)
    + 2 * c * py * dy + d * dx + e * dy
  local q0 = a * px * px + b * px * py + c * py * py + d * px + e * py + f
  if not finite_number(q2) or not finite_number(q1) or not finite_number(q0) then
    error("line-intersection polynomial is not finite")
  end
  local q2_scale = math.abs(a * dx * dx) + math.abs(b * dx * dy) + math.abs(c * dy * dy)
  local q1_scale = math.abs(2 * a * px * dx) + math.abs(b * (px * dy + py * dx))
    + math.abs(2 * c * py * dy) + math.abs(d * dx) + math.abs(e * dy)
  local q0_scale = math.abs(a * px * px) + math.abs(b * px * py) + math.abs(c * py * py)
    + math.abs(d * px) + math.abs(e * py) + math.abs(f)
  local q2_is_zero = near_zero(q2, math.max(q2_scale, MIN_NORMAL), 8192)
  local q1_is_zero = near_zero(q1, math.max(q1_scale, MIN_NORMAL), 8192)
  local q0_is_zero = near_zero(q0, math.max(q0_scale, MIN_NORMAL), 8192)
  local polynomial_scale = math.max(math.abs(q2), math.abs(q1), math.abs(q0), MIN_NORMAL)
  q2, q1, q0 = q2 / polynomial_scale, q1 / polynomial_scale, q0 / polynomial_scale
  local roots = {}
  if q2_is_zero then
    if q1_is_zero then
      if q0_is_zero then
        roots.infinite, roots.count = true, math.huge
        return roots
      end
      roots.count = 0
      return roots
    end
    roots[1] = -q0 / q1
  else
    local discriminant = q1 * q1 - 4 * q2 * q0
    local discriminant_scale = math.max(
      math.abs(q1 * q1) + math.abs(4 * q2 * q0),
      math.max(math.abs(q2), math.abs(q1), math.abs(q0)) ^ 2
    )
    local tolerance = scaled_tolerance(math.max(discriminant_scale, MIN_NORMAL), 16384)
    if discriminant < -tolerance then
      roots.count = 0
      return roots
    end
    discriminant = math.max(0, discriminant)
    local square_root = math.sqrt(discriminant)
    if square_root == 0 then
      roots[1] = -q1 / (2 * q2)
    else
      local signed_root = q1 >= 0 and square_root or -square_root
      local q = -0.5 * (q1 + signed_root)
      if q == 0 then
        roots[1] = -q1 / (2 * q2)
      else
        roots[1], roots[2] = q / q2, q0 / q
        if roots_are_close(roots[1], roots[2]) then roots[2] = nil end
      end
    end
  end
  table.sort(roots)
  local points = {}
  for _, root in ipairs(roots) do
    if not finite_number(root) then error("line-intersection root is not finite") end
    local intersection = add(point, scale(direction, root))
    if not finite_number(intersection.x) or not finite_number(intersection.y) then
      error("line intersection is not finite")
    end
    if #points == 0 or distance(points[#points], intersection)
        > scaled_tolerance(math.max(vector_scale(points[#points], intersection), MIN_NORMAL), 8192) then
      points[#points + 1] = intersection
    end
  end
  points.count = #points
  return points
end

local function transformed_conic_coefficients(coefficients, matrix)
  coefficients = normalize_coefficients(coefficients)
  local values = { matrix:coeff() }
  if #values == 1 and type(values[1]) == "table" then values = values[1] end
  local ma, mc, mb, md, tx, ty = unpack(values)
  for _, value in ipairs({ ma, mc, mb, md, tx, ty }) do
    if not finite_number(value) then error("conic object matrix must contain finite numbers") end
  end
  local determinant = ma * md - mb * mc
  local matrix_scale = math.max(math.abs(ma), math.abs(mc), math.abs(mb), math.abs(md))
  if matrix_scale == 0
      or near_zero(determinant, matrix_scale * matrix_scale, 8192) then
    error("conic object matrix must be nonsingular")
  end
  local alpha, beta = md / determinant, -mb / determinant
  local gamma = (mb * ty - md * tx) / determinant
  local delta, epsilon = -mc / determinant, ma / determinant
  local zeta = (mc * tx - ma * ty) / determinant
  local a, b, c, d, e, f = unpack(coefficients)
  return normalize_coefficients({
    a * alpha * alpha + b * alpha * delta + c * delta * delta,
    2 * a * alpha * beta + b * (alpha * epsilon + beta * delta)
      + 2 * c * delta * epsilon,
    a * beta * beta + b * beta * epsilon + c * epsilon * epsilon,
    2 * a * alpha * gamma + b * (alpha * zeta + gamma * delta)
      + 2 * c * delta * zeta + d * alpha + e * delta,
    2 * a * beta * gamma + b * (beta * zeta + gamma * epsilon)
      + 2 * c * epsilon * zeta + d * beta + e * epsilon,
    a * gamma * gamma + b * gamma * zeta + c * zeta * zeta
      + d * gamma + e * zeta + f,
  })
end

function Advanced.flexible_points(input_points, minimum, maximum, name)
  name = name or "points"
  if type(input_points) ~= "table" then error(name .. " must be a point array") end
  if #input_points < minimum then
    error(name .. " must contain at least " .. tostring(minimum) .. " points")
  end
  if maximum and #input_points > maximum then
    error(name .. " must contain at most " .. tostring(maximum) .. " points")
  end
  local points = {}
  for index, point in ipairs(input_points) do
    points[index] = point_from_table(point, name .. "[" .. tostring(index) .. "]")
  end
  return points
end

function Advanced.point_normalization(points)
  local center = V(0, 0)
  for _, point in ipairs(points) do center = add(center, point) end
  center = scale(center, 1 / #points)
  local coordinate_scale = 0
  for _, point in ipairs(points) do
    coordinate_scale = math.max(
      coordinate_scale,
      math.abs(point.x - center.x),
      math.abs(point.y - center.y)
    )
  end
  if coordinate_scale == 0 or not finite_number(coordinate_scale) then
    error("points do not span a finite two-dimensional scale")
  end
  return center, coordinate_scale
end

function Advanced.denormalize_conic(coefficients, center, coordinate_scale)
  return transformed_conic_coefficients(
    coefficients,
    ipe.Matrix(coordinate_scale, 0, 0, coordinate_scale, center.x, center.y)
  )
end

function Advanced.conic_coefficients_from_points(input_points, raw_options)
  local options = options_table(raw_options)
  validate_keys(options, {
    allow_degenerate = true, expected_kind = true, maximum_points = true,
  }, "point-fit options")
  local maximum_points = positive_integer_option(
    options.maximum_points, 512, "maximum_points", 4096, 5
  )
  local input = Advanced.flexible_points(input_points, 5, maximum_points, "points")
  local center, coordinate_scale = Advanced.point_normalization(input)
  local points = {}
  for _, point in ipairs(input) do
    local duplicate = false
    for _, existing in ipairs(points) do
      if near_zero(distance(existing, point), coordinate_scale, 2048) then
        duplicate = true
        break
      end
    end
    if not duplicate then points[#points + 1] = point end
  end
  if #points < 5 then error("point fit requires at least five distinct sample points") end
  center, coordinate_scale = Advanced.point_normalization(points)
  local rows = {}
  for index, point in ipairs(points) do
    local x = (point.x - center.x) / coordinate_scale
    local y = (point.y - center.y) / coordinate_scale
    rows[index] = { x * x, x * y, y * y, x, y, 1 }
  end
  local normalized, smallest, second_smallest, largest = jacobi_null_vector(rows)
  if largest == 0 or second_smallest <= scaled_tolerance(largest, 32768) then
    error("sample points do not determine a unique stable conic")
  end
  if #points == 5 and smallest > scaled_tolerance(largest, 32768) then
    error("five sample points have no reliable homogeneous nullspace")
  end
  if #points > 5 and smallest >= second_smallest * 0.98 then
    error("sample points do not identify one conic reliably")
  end
  normalized = normalize_coefficients(normalized)
  local coefficients = Advanced.denormalize_conic(normalized, center, coordinate_scale)
  local degenerate = is_degenerate_conic(coefficients)
  if degenerate and not bool_value(options.allow_degenerate, false) then
    error("sample points fit a degenerate conic")
  end
  local classification = classify_conic(coefficients)
  local expected = normalized_name(options.expected_kind or "auto")
  if expected ~= "auto" and expected ~= "any" then
    local accepted = classification.kind == expected
      or (expected == "ellipse" and classification.kind == "circle")
      or (expected == "central" and (classification.kind == "ellipse"
        or classification.kind == "circle" or classification.kind == "hyperbola"))
    if not accepted then
      error("best-fit conic is " .. classification.kind .. ", not " .. expected)
    end
  end
  local residual_sum, maximum_residual = 0, 0
  for _, row in ipairs(rows) do
    local value, magnitude = 0, 0
    for column = 1, 6 do
      local term = normalized[column] * row[column]
      value, magnitude = value + term, magnitude + math.abs(term)
    end
    local residual = math.abs(value) / math.max(magnitude, MIN_NORMAL)
    residual_sum = residual_sum + residual * residual
    maximum_residual = math.max(maximum_residual, residual)
  end
  return coefficients, {
    input_count = #input,
    sample_count = #points,
    rms_residual = math.sqrt(residual_sum / #points),
    maximum_residual = maximum_residual,
    singular_ratio = smallest / math.max(second_smallest, MIN_NORMAL),
    kind = classification.kind,
  }
end

function Advanced.line_intersection(left, right)
  left, right = line_from_table(left, "left line"), line_from_table(right, "right line")
  local determinant = left.a * right.b - right.a * left.b
  if near_zero(determinant, 1, 8192) then return nil end
  local point = V(
    (left.b * right.c - right.b * left.c) / determinant,
    (left.c * right.a - right.c * left.a) / determinant
  )
  if not finite_number(point.x) or not finite_number(point.y) then return nil end
  return point
end

function Advanced.dual_conic_coefficients(coefficients)
  local matrix = Advanced.conic_matrix(coefficients)
  local determinant = Advanced.matrix3_determinant(matrix)
  if near_zero(determinant, 1, 8192) then error("degenerate conic has no invertible dual") end
  return Advanced.coefficients_from_symmetric_matrix(Advanced.matrix3_adjugate(matrix))
end

function Advanced.conic_coefficients_from_five_lines(input_lines, raw_options)
  local options = options_table(raw_options)
  validate_keys(options, { allow_degenerate = true }, "five-tangent options")
  if type(input_lines) ~= "table" or #input_lines ~= 5 then
    error("exactly five tangent lines are required")
  end
  local lines, intersections = {}, {}
  for index, input in ipairs(input_lines) do
    lines[index] = line_from_table(input, "lines[" .. tostring(index) .. "]")
  end
  for first = 1, 4 do
    for second = first + 1, 5 do
      local point = Advanced.line_intersection(lines[first], lines[second])
      if point then intersections[#intersections + 1] = point end
    end
  end
  if #intersections < 2 then error("five tangent lines do not span a stable finite frame") end
  local center, coordinate_scale = Advanced.point_normalization(intersections)
  local rows = {}
  for index, line in ipairs(lines) do
    local values = {
      line.a * coordinate_scale,
      line.b * coordinate_scale,
      line.a * center.x + line.b * center.y + line.c,
    }
    local norm = hypot(hypot(values[1], values[2]), values[3])
    if norm == 0 or not finite_number(norm) then error("tangent line normalization failed") end
    for component = 1, 3 do values[component] = values[component] / norm end
    rows[index] = {
      values[1] * values[1], values[1] * values[2], values[2] * values[2],
      values[1] * values[3], values[2] * values[3], values[3] * values[3],
    }
  end
  local dual, smallest, second_smallest, largest = jacobi_null_vector(rows)
  if largest == 0 or second_smallest <= scaled_tolerance(largest, 32768)
      or smallest > scaled_tolerance(largest, 32768) then
    error("five tangent lines do not determine a unique stable conic")
  end
  dual = normalize_coefficients(dual)
  if is_degenerate_conic(dual) then error("five tangent lines determine a singular dual conic") end
  local normalized = Advanced.coefficients_from_symmetric_matrix(
    Advanced.matrix3_adjugate(Advanced.conic_matrix(dual))
  )
  local coefficients = Advanced.denormalize_conic(normalized, center, coordinate_scale)
  if is_degenerate_conic(coefficients) and not bool_value(options.allow_degenerate, false) then
    error("five tangent lines determine a degenerate conic")
  end
  return coefficients
end

function Advanced.constraint_rows(constraints, center, coordinate_scale)
  local rows, weight = {}, 0
  for index, constraint in ipairs(constraints) do
    if type(constraint) ~= "table" then
      error("constraints[" .. tostring(index) .. "] must be a table")
    end
    local kind = normalized_name(constraint.type or constraint.kind or "point")
    local point = point_from_table(constraint.point or constraint, "constraints["
      .. tostring(index) .. "].point")
    local normalized_point = V(
      (point.x - center.x) / coordinate_scale,
      (point.y - center.y) / coordinate_scale
    )
    rows[#rows + 1] = conic_terms(normalized_point)
    weight = weight + 1
    if kind == "tangent" or kind == "tangent_at_point" then
      local line = line_from_table(constraint.line or constraint.tangent,
        "constraints[" .. tostring(index) .. "].line")
      local signed_distance = line.a * point.x + line.b * point.y + line.c
      if math.abs(signed_distance) > scaled_tolerance(
          math.max(vector_scale(point), math.abs(line.c), MIN_NORMAL), 16384) then
        error("a tangent constraint line must pass through its point")
      end
      local line_a = line.a * coordinate_scale
      local line_b = line.b * coordinate_scale
      local x, y = normalized_point.x, normalized_point.y
      rows[#rows + 1] = {
        2 * line_b * x,
        line_b * y - line_a * x,
        -2 * line_a * y,
        line_b,
        -line_a,
        0,
      }
      weight = weight + 1
    elseif kind ~= "point" then
      error("unsupported conic constraint type: " .. kind)
    end
  end
  return rows, weight
end

function Advanced.conic_coefficients_from_constraints(constraints, raw_options)
  local options = options_table(raw_options)
  validate_keys(options, { allow_degenerate = true }, "constraint options")
  if type(constraints) ~= "table" or #constraints == 0 then
    error("constraints must be a nonempty array")
  end
  local points = {}
  for index, constraint in ipairs(constraints) do
    if type(constraint) ~= "table" then
      error("constraints[" .. tostring(index) .. "] must be a table")
    end
    points[index] = point_from_table(constraint.point or constraint,
      "constraints[" .. tostring(index) .. "].point")
  end
  local center, coordinate_scale = Advanced.point_normalization(points)
  local rows, weight = Advanced.constraint_rows(constraints, center, coordinate_scale)
  if weight ~= 5 or #rows ~= 5 then
    error("mixed conic construction requires exactly five weighted conditions")
  end
  local normalized, smallest, second_smallest, largest = jacobi_null_vector(rows)
  if largest == 0 or second_smallest <= scaled_tolerance(largest, 32768)
      or smallest > scaled_tolerance(largest, 32768) then
    error("the five conditions do not determine a unique stable conic")
  end
  normalized = normalize_coefficients(normalized)
  local coefficients = Advanced.denormalize_conic(normalized, center, coordinate_scale)
  if is_degenerate_conic(coefficients) and not bool_value(options.allow_degenerate, false) then
    error("the five conditions determine a degenerate conic")
  end
  return coefficients
end

function Advanced.ellipse_from_center_axes(center, first_endpoint, second_endpoint)
  center = point_from_table(center, "center")
  first_endpoint = point_from_table(first_endpoint, "first_endpoint")
  second_endpoint = point_from_table(second_endpoint, "second_endpoint")
  local first_axis, second_axis = sub(first_endpoint, center), sub(second_endpoint, center)
  local first_length, second_length = length(first_axis), length(second_axis)
  local input_scale = math.max(first_length, second_length, MIN_NORMAL)
  if near_zero(first_length, input_scale, 4096)
      or near_zero(second_length, input_scale, 4096) then
    error("ellipse semiaxes must be nonzero")
  end
  if math.abs(dot(first_axis, second_axis)) > scaled_tolerance(
      first_length * second_length, 16384) then
    error("ellipse semiaxes must be perpendicular")
  end
  return {
    center = center,
    axis1 = first_axis,
    axis2 = second_axis,
    major_radius = math.max(first_length, second_length),
    minor_radius = math.min(first_length, second_length),
  }
end

function Advanced.parabola_from_vertex_focus(vertex, focus)
  vertex = point_from_table(vertex, "vertex")
  focus = point_from_table(focus, "focus")
  local axis = sub(focus, vertex)
  local focal_distance = length(axis)
  if near_zero(focal_distance, vector_scale(vertex, focus), 4096) then
    error("parabola vertex and focus must be distinct")
  end
  local axis_direction = scale(axis, 1 / focal_distance)
  local directrix_point = sub(vertex, scale(axis_direction, focal_distance))
  local directrix = line_from_equation(
    axis_direction.x, axis_direction.y, -dot(axis_direction, directrix_point),
    directrix_point
  )
  return conic_coefficients_for_focus_directrix(focus, directrix, 1), directrix
end

function Advanced.hyperbola_from_asymptotes_point(first_line, second_line, point)
  first_line = line_from_table(first_line, "first asymptote")
  second_line = line_from_table(second_line, "second asymptote")
  point = point_from_table(point, "point")
  local center = Advanced.line_intersection(first_line, second_line)
  if not center then error("hyperbola asymptotes must intersect") end
  local first_value = first_line.a * point.x + first_line.b * point.y + first_line.c
  local second_value = second_line.a * point.x + second_line.b * point.y + second_line.c
  local product = first_value * second_value
  local input_scale = math.max(
    math.abs(first_value * second_value),
    distance(center, point) * distance(center, point),
    MIN_NORMAL
  )
  if near_zero(product, input_scale, 8192) then
    error("the defining point must not lie on either asymptote")
  end
  local coefficients = normalize_coefficients({
    first_line.a * second_line.a,
    first_line.a * second_line.b + first_line.b * second_line.a,
    first_line.b * second_line.b,
    first_line.a * second_line.c + first_line.c * second_line.a,
    first_line.b * second_line.c + first_line.c * second_line.b,
    first_line.c * second_line.c - product,
  })
  if classify_conic(coefficients).kind ~= "hyperbola" then
    error("asymptotes and point did not produce a stable hyperbola")
  end
  return coefficients, center
end

function Advanced.degenerate_conic_from_lines(input_lines)
  if type(input_lines) ~= "table" or (#input_lines ~= 1 and #input_lines ~= 2) then
    error("one or two lines are required for a degenerate line conic")
  end
  local first = line_from_table(input_lines[1], "first line")
  local second = #input_lines == 2
    and line_from_table(input_lines[2], "second line") or first
  return normalize_coefficients({
    first.a * second.a,
    first.a * second.b + first.b * second.a,
    first.b * second.b,
    first.a * second.c + first.c * second.a,
    first.b * second.c + first.c * second.b,
    first.c * second.c,
  })
end

function Advanced.degenerate_point_conic(point)
  point = point_from_table(point, "point")
  return normalize_coefficients({ 1, 0, 1, -2 * point.x, -2 * point.y,
    point.x * point.x + point.y * point.y })
end

function Advanced.polynomial_trim(coefficients)
  local result, coefficient_scale = {}, 0
  for index = 1, #coefficients do
    local value = finite_number_option(coefficients[index], 0,
      "polynomial coefficient")
    result[index] = value
    coefficient_scale = math.max(coefficient_scale, math.abs(value))
  end
  local tolerance = scaled_tolerance(math.max(coefficient_scale, MIN_NORMAL), 65536)
  while #result > 1 and math.abs(result[#result]) <= tolerance do
    result[#result] = nil
  end
  if #result == 0 then result[1] = 0 end
  return result
end

function Advanced.polynomial_add(left, right, right_scale)
  right_scale = right_scale or 1
  local result = {}
  for index = 1, math.max(#left, #right) do
    result[index] = (left[index] or 0) + right_scale * (right[index] or 0)
  end
  return Advanced.polynomial_trim(result)
end

function Advanced.polynomial_multiply(left, right)
  local result = {}
  for index = 1, #left + #right - 1 do result[index] = 0 end
  for left_index, left_value in ipairs(left) do
    for right_index, right_value in ipairs(right) do
      result[left_index + right_index - 1] = result[left_index + right_index - 1]
        + left_value * right_value
    end
  end
  return Advanced.polynomial_trim(result)
end

function Advanced.polynomial_value_scale(coefficients, value)
  local result, magnitude = 0, 0
  for index = #coefficients, 1, -1 do
    result = result * value + coefficients[index]
    magnitude = magnitude * math.abs(value) + math.abs(coefficients[index])
  end
  return result, magnitude
end

function Advanced.polynomial_root_is_close(left, right)
  return math.abs(left - right) <= 1e-9 * math.max(1, math.abs(left), math.abs(right))
end

function Advanced.polynomial_append_root(roots, root)
  if not finite_number(root) then return end
  for _, existing in ipairs(roots) do
    if Advanced.polynomial_root_is_close(existing, root) then return end
  end
  roots[#roots + 1] = root
end

function Advanced.polynomial_real_roots(input_coefficients)
  local coefficients = Advanced.polynomial_trim(input_coefficients)
  local degree = #coefficients - 1
  if degree == 0 then return {} end
  if degree == 1 then
    local root = -coefficients[1] / coefficients[2]
    if not finite_number(root) then error("polynomial root is not finite") end
    return { root }
  end
  if degree > 4 then error("real-root solver supports degree four or less") end
  local derivative = {}
  for index = 2, #coefficients do derivative[index - 1] = (index - 1) * coefficients[index] end
  local critical = Advanced.polynomial_real_roots(derivative)
  local leading = math.abs(coefficients[#coefficients])
  local root_bound = 1
  for index = 1, #coefficients - 1 do
    root_bound = math.max(root_bound, 1 + math.abs(coefficients[index]) / leading)
  end
  if not finite_number(root_bound) then error("polynomial root bound is not finite") end
  local partitions = { -root_bound }
  for _, root in ipairs(critical) do
    if root > -root_bound and root < root_bound then partitions[#partitions + 1] = root end
  end
  partitions[#partitions + 1] = root_bound
  table.sort(partitions)
  local roots = {}
  for _, point in ipairs(partitions) do
    local value, magnitude = Advanced.polynomial_value_scale(coefficients, point)
    if finite_number(value) and finite_number(magnitude)
        and math.abs(value) <= 1e-8 * math.max(magnitude, MIN_NORMAL) then
      Advanced.polynomial_append_root(roots, point)
    end
  end
  for index = 1, #partitions - 1 do
    local left, right = partitions[index], partitions[index + 1]
    local left_value = Advanced.polynomial_value_scale(coefficients, left)
    local right_value = Advanced.polynomial_value_scale(coefficients, right)
    if finite_number(left_value) and finite_number(right_value)
        and left_value * right_value < 0 then
      for _ = 1, 96 do
        local middle = left * 0.5 + right * 0.5
        local middle_value = Advanced.polynomial_value_scale(coefficients, middle)
        if not finite_number(middle_value) then
          error("polynomial evaluation exceeded finite numeric range")
        end
        if middle_value == 0 then
          left, right = middle, middle
          break
        elseif left_value * middle_value < 0 then
          right, right_value = middle, middle_value
        else
          left, left_value = middle, middle_value
        end
        if math.abs(right - left) <= 1e-12 * math.max(1, math.abs(left), math.abs(right)) then
          break
        end
      end
      Advanced.polynomial_append_root(roots, left * 0.5 + right * 0.5)
    end
  end
  table.sort(roots)
  return roots
end

function Advanced.quadratic_real_roots(quadratic, linear, constant)
  local scale_value = math.max(math.abs(quadratic), math.abs(linear),
    math.abs(constant), MIN_NORMAL)
  if near_zero(quadratic, scale_value, 65536) then
    if near_zero(linear, scale_value, 65536) then return {} end
    return { -constant / linear }
  end
  local discriminant = linear * linear - 4 * quadratic * constant
  local discriminant_scale = math.max(
    math.abs(linear * linear) + math.abs(4 * quadratic * constant),
    scale_value * scale_value
  )
  local tolerance = scaled_tolerance(math.max(discriminant_scale, MIN_NORMAL), 131072)
  if discriminant < -tolerance then return {} end
  local square_root = math.sqrt(math.max(0, discriminant))
  if square_root == 0 then return { -linear / (2 * quadratic) } end
  local signed_root = linear >= 0 and square_root or -square_root
  local q = -0.5 * (linear + signed_root)
  if q == 0 then return { -linear / (2 * quadratic) } end
  local roots = { q / quadratic, constant / q }
  if Advanced.polynomial_root_is_close(roots[1], roots[2]) then roots[2] = nil end
  table.sort(roots)
  return roots
end

function Advanced.conic_resultant_in_x(left, right)
  local left_values = {
    { left[6], left[4], left[1] },
    { left[5], left[2] },
    { left[3] },
  }
  local right_values = {
    { right[6], right[4], right[1] },
    { right[5], right[2] },
    { right[3] },
  }
  local function polynomial_is_zero(value)
    value = Advanced.polynomial_trim(value)
    return #value == 1 and near_zero(value[1], 1, 262144)
  end
  local left_degree, right_degree = 2, 2
  while left_degree > 0 and polynomial_is_zero(left_values[left_degree + 1]) do
    left_degree = left_degree - 1
  end
  while right_degree > 0 and polynomial_is_zero(right_values[right_degree + 1]) do
    right_degree = right_degree - 1
  end
  local left0, left1, left2 = left_values[1], left_values[2], left_values[3]
  local right0, right1, right2 = right_values[1], right_values[2], right_values[3]
  if left_degree == 0 then
    local result = { 1 }
    for _ = 1, right_degree do result = Advanced.polynomial_multiply(result, left0) end
    return result
  elseif right_degree == 0 then
    local result = { 1 }
    for _ = 1, left_degree do result = Advanced.polynomial_multiply(result, right0) end
    return result
  elseif left_degree == 1 and right_degree == 1 then
    return Advanced.polynomial_add(
      Advanced.polynomial_multiply(left1, right0),
      Advanced.polynomial_multiply(left0, right1), -1
    )
  elseif left_degree == 2 and right_degree == 1 then
    return Advanced.polynomial_add(Advanced.polynomial_add(
      Advanced.polynomial_multiply(left2,
        Advanced.polynomial_multiply(right0, right0)),
      Advanced.polynomial_multiply(left1,
        Advanced.polynomial_multiply(right1, right0)), -1
    ), Advanced.polynomial_multiply(left0,
      Advanced.polynomial_multiply(right1, right1)))
  elseif left_degree == 1 and right_degree == 2 then
    return Advanced.polynomial_add(Advanced.polynomial_add(
      Advanced.polynomial_multiply(right2,
        Advanced.polynomial_multiply(left0, left0)),
      Advanced.polynomial_multiply(right1,
        Advanced.polynomial_multiply(left1, left0)), -1
    ), Advanced.polynomial_multiply(right0,
      Advanced.polynomial_multiply(left1, left1)))
  end
  local first = Advanced.polynomial_add(
    Advanced.polynomial_multiply(left2, right0),
    Advanced.polynomial_multiply(left0, right2), -1
  )
  local second = Advanced.polynomial_add(
    Advanced.polynomial_multiply(left2, right1),
    Advanced.polynomial_multiply(left1, right2), -1
  )
  local third = Advanced.polynomial_add(
    Advanced.polynomial_multiply(left1, right0),
    Advanced.polynomial_multiply(left0, right1), -1
  )
  return Advanced.polynomial_add(
    Advanced.polynomial_multiply(first, first),
    Advanced.polynomial_multiply(second, third), -1
  )
end

function Advanced.coefficients_are_proportional(left, right)
  left, right = normalize_coefficients(left), normalize_coefficients(right)
  local same, opposite = 0, 0
  for index = 1, 6 do
    same = math.max(same, math.abs(left[index] - right[index]))
    opposite = math.max(opposite, math.abs(left[index] + right[index]))
  end
  return math.min(same, opposite) <= scaled_tolerance(1, 4096)
end

function Advanced.refine_conic_intersection(left, right, input_point)
  local point = point_from_table(input_point, "intersection candidate")
  for _ = 1, 12 do
    local left_value = evaluate_conic(left, point)
    local right_value = evaluate_conic(right, point)
    local left_gradient = conic_gradient(left, point)
    local right_gradient = conic_gradient(right, point)
    local determinant = cross(left_gradient, right_gradient)
    local gradient_scale = length(left_gradient) * length(right_gradient)
    if near_zero(determinant, math.max(gradient_scale, MIN_NORMAL), 65536) then break end
    local delta = V(
      (-left_value * right_gradient.y + right_value * left_gradient.y) / determinant,
      (-right_value * left_gradient.x + left_value * right_gradient.x) / determinant
    )
    if not finite_number(delta.x) or not finite_number(delta.y) then break end
    point = add(point, delta)
    if length(delta) <= 1e-12 * math.max(1, vector_scale(point)) then break end
  end
  return point
end

function Advanced.conic_intersection_candidates_at_x(left, right, x)
  local candidates = {}
  local left0 = left[1] * x * x + left[4] * x + left[6]
  local left1 = left[2] * x + left[5]
  local right0 = right[1] * x * x + right[4] * x + right[6]
  local right1 = right[2] * x + right[5]
  local eliminator = right[3] * left1 - left[3] * right1
  local eliminated_constant = right[3] * left0 - left[3] * right0
  local elimination_scale = math.abs(right[3] * left1) + math.abs(left[3] * right1)
    + math.abs(right[3] * left0) + math.abs(left[3] * right0)
  if not near_zero(eliminator, math.max(elimination_scale, MIN_NORMAL), 131072) then
    candidates[1] = -eliminated_constant / eliminator
  else
    for _, root in ipairs(Advanced.quadratic_real_roots(left[3], left1, left0)) do
      Advanced.polynomial_append_root(candidates, root)
    end
    for _, root in ipairs(Advanced.quadratic_real_roots(right[3], right1, right0)) do
      Advanced.polynomial_append_root(candidates, root)
    end
  end
  return candidates
end

function Advanced.conic_conic_intersections(left, right)
  left, right = normalize_coefficients(left), normalize_coefficients(right)
  if is_degenerate_conic(left) or is_degenerate_conic(right) then
    error("conic-conic intersections require two nondegenerate conics")
  end
  if Advanced.coefficients_are_proportional(left, right) then
    return { count = math.huge, infinite = true, coincident = true }
  end
  local left_properties, right_properties = conic_properties(left), conic_properties(right)
  local left_origin = left_properties.center or left_properties.vertex
  local right_origin = right_properties.center or right_properties.vertex
  local origin = midpoint(left_origin, right_origin)
  local coordinate_scale = distance(left_origin, right_origin)
  for _, properties in ipairs({ left_properties, right_properties }) do
    coordinate_scale = math.max(
      coordinate_scale,
      properties.major_radius or 0,
      properties.minor_radius or 0,
      properties.a or 0,
      properties.b or 0,
      math.abs(properties.focal_parameter or 0) * 4
    )
  end
  if coordinate_scale == 0 or not finite_number(coordinate_scale) then
    error("conics do not provide a stable finite intersection frame")
  end
  local inverse_frame = ipe.Matrix(
    1 / coordinate_scale, 0, 0, 1 / coordinate_scale,
    -origin.x / coordinate_scale, -origin.y / coordinate_scale
  )
  local normalized_left = transformed_conic_coefficients(left, inverse_frame)
  local normalized_right = transformed_conic_coefficients(right, inverse_frame)
  local points = {}
  local indeterminate_passes = 0
  for pass = 1, 2 do
    local pass_left, pass_right = normalized_left, normalized_right
    if pass == 2 then
      pass_left = {
        normalized_left[3], normalized_left[2], normalized_left[1],
        normalized_left[5], normalized_left[4], normalized_left[6],
      }
      pass_right = {
        normalized_right[3], normalized_right[2], normalized_right[1],
        normalized_right[5], normalized_right[4], normalized_right[6],
      }
    end
    local resultant = Advanced.conic_resultant_in_x(pass_left, pass_right)
    if #resultant == 1 and near_zero(resultant[1], 1, 262144) then
      indeterminate_passes = indeterminate_passes + 1
    else
      for _, x in ipairs(Advanced.polynomial_real_roots(resultant)) do
        for _, y in ipairs(Advanced.conic_intersection_candidates_at_x(
            pass_left, pass_right, x)) do
          local candidate = pass == 1 and V(x, y) or V(y, x)
          local normalized_point = Advanced.refine_conic_intersection(
            normalized_left, normalized_right, candidate
          )
          local point = add(origin, scale(normalized_point, coordinate_scale))
          local left_value, left_magnitude = evaluate_conic(left, point)
          local right_value, right_magnitude = evaluate_conic(right, point)
          if math.abs(left_value) <= 1e-7 * math.max(left_magnitude, MIN_NORMAL)
              and math.abs(right_value) <= 1e-7 * math.max(right_magnitude, MIN_NORMAL) then
            local duplicate = false
            for _, existing in ipairs(points) do
              if distance(existing, point)
                  <= 1e-7 * math.max(1, vector_scale(existing, point)) then
                duplicate = true
                break
              end
            end
            if not duplicate then points[#points + 1] = point end
          end
        end
      end
    end
  end
  if indeterminate_passes == 2 then
    error("conic intersection resultants are numerically indeterminate")
  end
  table.sort(points, function(first, second)
    if first.x ~= second.x then return first.x < second.x end
    return first.y < second.y
  end)
  points.count = #points
  return points
end

function Advanced.conic_pole(coefficients, input_line)
  coefficients = normalize_coefficients(coefficients)
  if is_degenerate_conic(coefficients) then error("a degenerate conic has no unique pole map") end
  local line = line_from_table(input_line, "line")
  local homogeneous = Advanced.matrix3_vector(
    Advanced.matrix3_adjugate(Advanced.conic_matrix(coefficients)),
    { line.a, line.b, line.c }
  )
  local homogeneous_scale = math.max(math.abs(homogeneous[1]), math.abs(homogeneous[2]),
    math.abs(homogeneous[3]), MIN_NORMAL)
  if near_zero(homogeneous[3], homogeneous_scale, 32768) then
    return {
      finite = false,
      at_infinity = true,
      direction = unit(V(homogeneous[1], homogeneous[2]), "pole direction"),
    }
  end
  local point = V(homogeneous[1] / homogeneous[3], homogeneous[2] / homogeneous[3])
  if not finite_number(point.x) or not finite_number(point.y) then
    error("pole is not finitely representable")
  end
  return { finite = true, at_infinity = false, point = point }
end

function Advanced.tangents_from_point(coefficients, input_point)
  coefficients = normalize_coefficients(coefficients)
  if is_degenerate_conic(coefficients) then
    error("tangents from a point require a nondegenerate conic")
  end
  local point = point_from_table(input_point, "point")
  local value, magnitude = evaluate_conic(coefficients, point)
  local result = { point = point, tangents = {}, contact_points = {} }
  if math.abs(value) <= scaled_tolerance(math.max(magnitude, MIN_NORMAL), 32768) then
    local feature = conic_tangent_normal(coefficients, point)
    result.tangents[1], result.contact_points[1] = feature.tangent, point
    result.chord_of_contact, result.count = feature.tangent, 1
    return result
  end
  local a, b, c, d, e, f = unpack(coefficients)
  local polar_a = a * point.x + 0.5 * b * point.y + 0.5 * d
  local polar_b = 0.5 * b * point.x + c * point.y + 0.5 * e
  local polar_c = 0.5 * d * point.x + 0.5 * e * point.y + f
  local polar_scale = math.max(math.abs(polar_a), math.abs(polar_b),
    math.abs(polar_c), MIN_NORMAL)
  if near_zero(hypot(polar_a, polar_b), polar_scale, 32768) then
    result.count = 0
    result.polar_at_infinity = true
    return result
  end
  local polar = line_from_equation(polar_a, polar_b, polar_c, point)
  local contacts = conic_line_intersections(coefficients, polar)
  if contacts.infinite then error("polar unexpectedly lies in the conic") end
  for _, contact in ipairs(contacts) do
    local feature = conic_tangent_normal(coefficients, contact)
    result.contact_points[#result.contact_points + 1] = contact
    result.tangents[#result.tangents + 1] = feature.tangent
  end
  result.chord_of_contact = polar
  result.count = #result.tangents
  return result
end

function Advanced.focal_chord(coefficients, input_point, focus_index)
  coefficients = normalize_coefficients(coefficients)
  local properties = conic_properties(coefficients)
  if properties.degenerate or not properties.foci or #properties.foci == 0 then
    error("this conic has no real finite focus")
  end
  local point = point_from_table(input_point, "point")
  local index = focus_index and positive_integer_option(focus_index, nil,
    "focus_index", #properties.foci) or nil
  if not index then
    index = 1
    for candidate = 2, #properties.foci do
      if distance(point, properties.foci[candidate]) < distance(point, properties.foci[index]) then
        index = candidate
      end
    end
  end
  local focus = properties.foci[index]
  local line = line_from_points(focus, point, "focal chord")
  local intersections = conic_line_intersections(coefficients, line)
  if intersections.infinite or #intersections == 0 then
    error("the focal line has no finite real chord")
  end
  return {
    focus = focus,
    focus_index = index,
    line = line,
    endpoints = intersections,
    count = #intersections,
  }
end

function Advanced.general_equation_latex(coefficients)
  coefficients = normalize_coefficients(coefficients)
  local first_nonzero
  for index = 1, 6 do
    if not near_zero(coefficients[index], 1, 8192) then
      first_nonzero = coefficients[index]
      break
    end
  end
  if first_nonzero and first_nonzero < 0 then
    for index = 1, 6 do coefficients[index] = -coefficients[index] end
  end
  local variables = { "x^{2}", "xy", "y^{2}", "x", "y", "" }
  local parts = {}
  for index, coefficient in ipairs(coefficients) do
    if not near_zero(coefficient, 1, 8192) then
      local absolute = math.abs(coefficient)
      local magnitude = variables[index] ~= ""
          and math.abs(absolute - 1) <= scaled_tolerance(1, 8192)
        and "" or format_number(absolute, 7)
      local term = magnitude .. variables[index]
      if #parts == 0 then
        parts[1] = coefficient < 0 and ("-" .. term) or term
      else
        parts[#parts + 1] = (coefficient < 0 and "-" or "+") .. term
      end
    end
  end
  if #parts == 0 then parts[1] = "0" end
  return "$" .. table.concat(parts) .. "=0$"
end

function Advanced.shifted_variable_latex(variable, value)
  if near_zero(value, math.max(math.abs(value), 1), 8192) then return variable end
  return "(" .. variable .. (value < 0 and "+" or "-")
    .. format_number(math.abs(value), 6) .. ")"
end

function Advanced.local_coordinate_latex(direction, origin)
  local parts = {}
  for _, component in ipairs({
    { coefficient = direction.x, variable = "x", shift = origin.x },
    { coefficient = direction.y, variable = "y", shift = origin.y },
  }) do
    local coefficient = component.coefficient
    if not near_zero(coefficient, 1, 8192) then
      local absolute = math.abs(coefficient)
      local magnitude = math.abs(absolute - 1) <= scaled_tolerance(1, 8192)
          and "" or format_number(absolute, 6)
      local term = magnitude
        .. Advanced.shifted_variable_latex(component.variable, component.shift)
      if #parts == 0 then
        parts[1] = coefficient < 0 and ("-" .. term) or term
      else
        parts[#parts + 1] = (coefficient < 0 and "-" or "+") .. term
      end
    end
  end
  return #parts > 0 and table.concat(parts) or "0"
end

function Advanced.conic_equation_strings(coefficients)
  coefficients = normalize_coefficients(coefficients)
  local properties = conic_properties(coefficients)
  local result = {
    general = Advanced.general_equation_latex(coefficients),
    canonical = nil,
    parameters = nil,
  }
  if properties.degenerate then
    result.canonical = "$\\text{degenerate: }" .. tostring(properties.subtype) .. "$"
    return result
  end
  if properties.kind == "ellipse" or properties.kind == "circle" then
    local x_coordinate = Advanced.local_coordinate_latex(
      properties.major_direction, properties.center
    )
    local y_coordinate = Advanced.local_coordinate_latex(
      properties.minor_direction, properties.center
    )
    result.canonical = "$\\frac{X^{2}}{" .. format_number(
      properties.major_radius * properties.major_radius, 7
    ) .. "}+\\frac{Y^{2}}{" .. format_number(
      properties.minor_radius * properties.minor_radius, 7
    ) .. "}=1,\\quad X=" .. x_coordinate .. ",\\;Y=" .. y_coordinate .. "$"
    result.parameters = "$a=" .. format_number(properties.major_radius, 7)
      .. ",\\;b=" .. format_number(properties.minor_radius, 7)
      .. ",\\;c=" .. format_number(properties.focal_radius, 7)
      .. ",\\;e=" .. format_number(properties.eccentricity, 7)
      .. ",\\;\\mathcal{A}=" .. format_number(properties.area, 7) .. "$"
  elseif properties.kind == "hyperbola" then
    local x_coordinate = Advanced.local_coordinate_latex(properties.u, properties.center)
    local y_coordinate = Advanced.local_coordinate_latex(properties.v, properties.center)
    result.canonical = "$\\frac{X^{2}}{" .. format_number(properties.a ^ 2, 7)
      .. "}-\\frac{Y^{2}}{" .. format_number(properties.b ^ 2, 7)
      .. "}=1,\\quad X=" .. x_coordinate .. ",\\;Y=" .. y_coordinate .. "$"
    result.parameters = "$a=" .. format_number(properties.a, 7)
      .. ",\\;b=" .. format_number(properties.b, 7)
      .. ",\\;c=" .. format_number(properties.focal_radius, 7)
      .. ",\\;e=" .. format_number(properties.eccentricity, 7) .. "$"
  elseif properties.kind == "parabola" then
    local x_coordinate = Advanced.local_coordinate_latex(
      properties.axis_direction, properties.vertex
    )
    local y_coordinate = Advanced.local_coordinate_latex(
      properties.normal_direction, properties.vertex
    )
    result.canonical = "$Y^{2}=4pX,\\quad p="
      .. format_number(properties.focal_parameter, 7)
      .. ",\\quad X=" .. x_coordinate .. ",\\;Y=" .. y_coordinate .. "$"
    result.parameters = "$p=" .. format_number(properties.focal_parameter, 7)
      .. ",\\;e=1,\\;\\ell=" .. format_number(properties.semi_latus_rectum, 7)
      .. "$"
  end
  return result
end

function Advanced.point_on_conic(coefficients, input_point, name)
  local point = point_from_table(input_point, name or "point")
  local value, magnitude = evaluate_conic(coefficients, point)
  if math.abs(value) > scaled_tolerance(math.max(magnitude, MIN_NORMAL), 262144) then
    error((name or "point") .. " must lie on the conic")
  end
  return point
end

function Advanced.conic_arc_definition(coefficients, first_point, second_point, raw_mode)
  coefficients = normalize_coefficients(coefficients)
  local properties = conic_properties(coefficients)
  if properties.degenerate then error("a degenerate conic has no regular arc") end
  first_point = Advanced.point_on_conic(coefficients, first_point, "first trim point")
  second_point = Advanced.point_on_conic(coefficients, second_point, "second trim point")
  if distance(first_point, second_point) <= scaled_tolerance(
      math.max(vector_scale(first_point, second_point), MIN_NORMAL), 32768) then
    error("trim points must be distinct")
  end
  local mode = normalized_name(raw_mode or "shorter")
  if properties.kind == "ellipse" or properties.kind == "circle" then
    local function angle(point)
      local relative = sub(point, properties.center)
      return math.atan(
        dot(relative, properties.minor_direction) / properties.minor_radius,
        dot(relative, properties.major_direction) / properties.major_radius
      )
    end
    local first_angle, second_angle = angle(first_point), angle(second_point)
    local two_pi = 2 * math.pi
    local counterclockwise = (second_angle - first_angle) % two_pi
    local clockwise = two_pi - counterclockwise
    local orientation
    if mode == "counterclockwise" or mode == "ccw" then
      orientation = "counterclockwise"
    elseif mode == "clockwise" or mode == "cw" then
      orientation = "clockwise"
    elseif mode == "shorter" or mode == "short" then
      orientation = counterclockwise <= clockwise and "counterclockwise" or "clockwise"
    elseif mode == "longer" or mode == "long" then
      orientation = counterclockwise >= clockwise and "counterclockwise" or "clockwise"
    else
      error("unsupported ellipse arc mode: " .. mode)
    end
    local start_angle, finish_angle = first_angle, second_angle
    local axis2 = properties.axis2
    if orientation == "clockwise" then
      start_angle, finish_angle = -first_angle, -second_angle
      axis2 = scale(axis2, -1)
    end
    while finish_angle <= start_angle do finish_angle = finish_angle + two_pi end
    return {
      kind = properties.kind,
      properties = properties,
      first_point = first_point,
      second_point = second_point,
      orientation = orientation,
      start_parameter = start_angle,
      finish_parameter = finish_angle,
      axis1 = properties.axis1,
      axis2 = axis2,
    }
  elseif properties.kind == "parabola" then
    local first_parameter = dot(sub(first_point, properties.vertex), properties.normal_direction)
    local second_parameter = dot(sub(second_point, properties.vertex), properties.normal_direction)
    return {
      kind = "parabola",
      properties = properties,
      first_point = first_point,
      second_point = second_point,
      start_parameter = first_parameter,
      finish_parameter = second_parameter,
    }
  end
  local first_branch = dot(sub(first_point, properties.center), properties.u) < 0 and -1 or 1
  local second_branch = dot(sub(second_point, properties.center), properties.u) < 0 and -1 or 1
  if first_branch ~= second_branch then
    error("hyperbola trim points must lie on the same connected branch")
  end
  return {
    kind = "hyperbola",
    properties = properties,
    first_point = first_point,
    second_point = second_point,
    branch = first_branch,
    start_parameter = stable_asinh(
      dot(sub(first_point, properties.center), properties.v) / properties.b
    ),
    finish_parameter = stable_asinh(
      dot(sub(second_point, properties.center), properties.v) / properties.b
    ),
  }
end

function Advanced.parabola_interval_control(properties, start_parameter, finish_parameter)
  local function point(parameter)
    return add(properties.vertex, add(
      scale(properties.normal_direction, parameter),
      scale(properties.axis_direction,
        parameter * parameter / (4 * properties.focal_parameter))
    ))
  end
  local start_point, finish_point = point(start_parameter), point(finish_parameter)
  local derivative = add(
    properties.normal_direction,
    scale(properties.axis_direction,
      start_parameter / (2 * properties.focal_parameter))
  )
  local control = add(start_point,
    scale(derivative, (finish_parameter - start_parameter) * 0.5))
  return { start_point, control, finish_point }
end

function Advanced.adaptive_hyperbola_interval(
    properties, branch, start_parameter, finish_parameter, tolerance, maximum_segments)
  local hyperbola = {
    center = properties.center,
    u = properties.u,
    v = properties.v,
    a = properties.a,
    b = properties.b,
  }
  tolerance = positive_number_option(tolerance, 0.25, "tolerance")
  maximum_segments = positive_integer_option(
    maximum_segments, 256, "max_segments", 4096, 1
  )
  local cubics = {}
  local function subdivide(first, second, depth)
    if #cubics >= maximum_segments then error("conic arc exceeded max_segments") end
    local control = hyperbola_cubic(hyperbola, branch, first, second)
    local interval, error_value = second - first, 0
    for _, fraction in ipairs({ 0.25, 0.5, 0.75 }) do
      local parameter = first + interval * fraction
      error_value = math.max(error_value, distance(
        hyperbola_point(hyperbola, branch, parameter),
        cubic_point(control, fraction)
      ))
    end
    if error_value <= tolerance then
      cubics[#cubics + 1] = control
    elseif depth >= 20 then
      error("conic arc could not satisfy the requested tolerance")
    else
      local middle = first * 0.5 + second * 0.5
      subdivide(first, middle, depth + 1)
      subdivide(middle, second, depth + 1)
    end
  end
  subdivide(start_parameter, finish_parameter, 0)
  return cubics
end

M.conic_coefficients_from_points = Advanced.conic_coefficients_from_points
M.conic_coefficients_from_five_lines = Advanced.conic_coefficients_from_five_lines
M.conic_coefficients_from_constraints = Advanced.conic_coefficients_from_constraints
M.ellipse_from_center_axes = Advanced.ellipse_from_center_axes
M.parabola_from_vertex_focus = Advanced.parabola_from_vertex_focus
M.hyperbola_from_asymptotes_point = Advanced.hyperbola_from_asymptotes_point
M.degenerate_conic_from_lines = Advanced.degenerate_conic_from_lines
M.degenerate_point_conic = Advanced.degenerate_point_conic
M.conic_conic_intersections = Advanced.conic_conic_intersections
M.conic_pole = Advanced.conic_pole
M.tangents_from_point = Advanced.tangents_from_point
M.focal_chord = Advanced.focal_chord
M.conic_equation_strings = Advanced.conic_equation_strings
M.conic_arc_definition = Advanced.conic_arc_definition

local function line_segment_from_infinite(point, direction, requested_length)
  local line_length = positive_number_option(requested_length, 192, "line_length")
  local direction_unit = unit(direction, "line direction")
  local half = scale(direction_unit, line_length * 0.5)
  return { p1 = sub(point, half), p2 = add(point, half) }
end

M.conic_gradient = conic_gradient
M.conic_tangent_normal = conic_tangent_normal
M.conic_polar_line = conic_polar_line
M.conic_line_intersections = conic_line_intersections
M.transformed_conic_coefficients = transformed_conic_coefficients
M.line_segment_from_infinite = line_segment_from_infinite

----------------------------------------------------------------------
-- Ipe selection, object creation, metadata, and transactions
----------------------------------------------------------------------

local R = {}

local DEFAULT_PATH_ATTRIBUTES = {
  stroke = "black",
  pen = "normal",
  dashstyle = "normal",
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
local PATH_ATTRIBUTE_FIELDS = {
  "stroke", "pen", "dashstyle", "linecap", "linejoin", "strokeopacity", "opacity",
}
local MARK_ATTRIBUTE_FIELDS = {
  "stroke", "fill", "symbolsize", "markshape", "strokeopacity", "fillopacity", "opacity",
}
local TEXT_ATTRIBUTE_FIELDS = {
  "stroke", "textsize", "textstyle", "labelstyle", "horizontalalignment",
  "verticalalignment", "opacity",
}

local function clone_table(source)
  local result = {}
  for key, value in pairs(source or {}) do result[key] = value end
  return result
end

local function filtered_attributes(source, fallback, fields, overrides)
  local result = clone_table(fallback)
  if type(source) == "table" then
    for _, field in ipairs(fields) do
      if source[field] ~= nil then result[field] = source[field] end
    end
  end
  for key, value in pairs(overrides or {}) do result[key] = value end
  return result
end

local function construction_styles(model)
  local source = model and model.attributes or nil
  local path = filtered_attributes(source, DEFAULT_PATH_ATTRIBUTES, PATH_ATTRIBUTE_FIELDS)
  path.fill = nil
  path.farrow, path.rarrow, path.decoration = nil, nil, nil
  return {
    path = path,
    dashed = filtered_attributes(path, DEFAULT_PATH_ATTRIBUTES, PATH_ATTRIBUTE_FIELDS,
      { dashstyle = "dashed" }),
    dotted = filtered_attributes(path, DEFAULT_PATH_ATTRIBUTES, PATH_ATTRIBUTE_FIELDS,
      { dashstyle = "dotted" }),
    mark = filtered_attributes(source, DEFAULT_MARK_ATTRIBUTES, MARK_ATTRIBUTE_FIELDS),
    text = filtered_attributes(source, DEFAULT_TEXT_ATTRIBUTES, TEXT_ATTRIBUTE_FIELDS),
    markshape = type(source) == "table" and source.markshape or DEFAULT_MARK_ATTRIBUTES.markshape,
  }
end

local function object_type(object)
  if not object then return nil end
  local ok, value = pcall(function() return object:type() end)
  if ok then return value end
  return type(object) == "table" and (object.type_value or object.kind or object.type) or nil
end

local function object_matrix(object)
  local ok, matrix = pcall(function() return object:matrix() end)
  if ok and matrix then return matrix end
  if type(object) == "table" and object.matrix_value then return object.matrix_value end
  return ipe.Matrix()
end

local function path_shape(object)
  if object_type(object) ~= "path" then return nil end
  local ok, shape = pcall(function() return object:shape() end)
  if ok and type(shape) == "table" then return shape end
  return type(object) == "table" and (object.shape_value or object.data) or nil
end

local function object_elements(object)
  if object_type(object) ~= "group" then return nil end
  local ok, elements = pcall(function() return object:elements() end)
  if ok and type(elements) == "table" then return elements end
  return type(object) == "table" and (object.elements_value or object.elements) or nil
end

local function object_custom_value(object)
  if not object then return "" end
  local ok, value = pcall(function() return object:getCustom() end)
  if ok and value ~= nil then
    local text = tostring(value)
    return text == "undefined" and "" or text
  end
  if type(object) == "table" and object.custom ~= nil then return tostring(object.custom) end
  return ""
end

local function set_object_custom_value(object, value)
  local ok = pcall(function() object:setCustom(value) end)
  if not ok and type(object) == "table" then object.custom = value end
end

local function append_object_custom_value(object, value)
  if value == nil or value == "" then return end
  local existing = object_custom_value(object)
  if existing ~= "" then value = existing .. ";" .. value end
  set_object_custom_value(object, value)
end

local function reference_position(object)
  if object_type(object) ~= "reference" then return nil end
  local ok_symbol, symbol = pcall(function() return object:symbol() end)
  if not ok_symbol or type(symbol) ~= "string" or symbol:sub(1, 5) ~= "mark/" then
    return nil
  end
  local ok_position, position = pcall(function() return object:position() end)
  if not ok_position or not position then return nil end
  local ok_transformed, transformed = pcall(function() return object_matrix(object) * position end)
  return ok_transformed and transformed or position
end

local function single_segment_from_path(object)
  local shape = path_shape(object)
  if not shape or #shape ~= 1 then return nil end
  local curve = shape[1]
  if curve.type ~= "curve" or curve.closed or #curve ~= 1 then return nil end
  local segment = curve[1]
  if segment.type ~= "segment" then return nil end
  local matrix = object_matrix(object)
  return matrix * segment[1], matrix * segment[2]
end

local function selected_objects(model)
  local page, result = model:page(), {}
  for index, object, selected, layer in page:objects() do
    if selected and page:visible(model.vno, index) then
      result[#result + 1] = {
        index = index,
        object = object,
        selection = selected,
        layer = layer,
        primary = selected == 1,
      }
    end
  end
  return result
end

local function selection_inputs(model)
  local summary = {
    entries = selected_objects(model),
    points = {},
    segments = {},
    conic_entries = {},
    invalid = {},
    primary_point = nil,
    primary_segment = nil,
    primary_entry = nil,
  }
  for _, entry in ipairs(summary.entries) do
    if entry.primary then summary.primary_entry = entry end
    local point = reference_position(entry.object)
    if point then
      local record = { point = point, entry = entry }
      summary.points[#summary.points + 1] = record
      if entry.primary then summary.primary_point = record end
    else
      local p1, p2 = single_segment_from_path(entry.object)
      if p1 and p2 then
        local record = { line = line_from_points(p1, p2, "selected segment"), entry = entry }
        summary.segments[#summary.segments + 1] = record
        if entry.primary then summary.primary_segment = record end
      elseif object_type(entry.object) == "path" or object_type(entry.object) == "group" then
        summary.conic_entries[#summary.conic_entries + 1] = entry
      else
        summary.invalid[#summary.invalid + 1] = entry
      end
    end
  end
  return summary
end

local function require_exact_construction_selection(summary, point_count, segment_count, message)
  if #summary.invalid ~= 0 or #summary.conic_entries ~= 0
      or #summary.points ~= point_count or #summary.segments ~= segment_count
      or #summary.entries ~= point_count + segment_count then
    error(message)
  end
end

local function primary_first_point_values(summary)
  local result = {}
  if summary.primary_point then result[#result + 1] = summary.primary_point.point end
  for _, record in ipairs(summary.points) do
    if record ~= summary.primary_point then result[#result + 1] = record.point end
  end
  return result
end

local function active_layer(model)
  return model:page():active(model.vno)
end

local function points_option(options, expected)
  if options.points == nil then return nil end
  return points_from_table(options.points, expected, "points")
end

local function segment_shape(p1, p2)
  return { type = "curve", closed = false; { type = "segment"; p1, p2 } }
end

function M.require_finite_point(point, context)
  if not point or not finite_number(point.x) or not finite_number(point.y) then
    error((context or "geometry") .. " contains a non-finite point")
  end
  return point
end

local function make_segment(p1, p2, attributes)
  M.require_finite_point(p1, "segment")
  M.require_finite_point(p2, "segment")
  return ipe.Path(clone_table(attributes), { segment_shape(p1, p2) }, false)
end

local function make_ellipse(ellipse, attributes)
  M.require_finite_point(ellipse.center, "ellipse")
  M.require_finite_point(ellipse.axis1, "ellipse")
  M.require_finite_point(ellipse.axis2, "ellipse")
  return ipe.Path(clone_table(attributes), {
    {
      type = "ellipse";
      ipe.Matrix(
        ellipse.axis1.x, ellipse.axis1.y,
        ellipse.axis2.x, ellipse.axis2.y,
        ellipse.center.x, ellipse.center.y
      ),
    },
  }, false)
end

local function make_spline(control_points, attributes)
  local spline = { type = "spline" }
  for index, point in ipairs(control_points) do
    spline[index] = M.require_finite_point(point, "spline")
  end
  return ipe.Path(clone_table(attributes), {
    { type = "curve", closed = false; spline },
  }, false)
end

local function make_cubic_curve(cubics, attributes)
  local curve = { type = "curve", closed = false }
  for _, control in ipairs(cubics) do
    local spline = { type = "spline" }
    for index, point in ipairs(control) do
      spline[index] = M.require_finite_point(point, "hyperbola spline")
    end
    curve[#curve + 1] = spline
  end
  return ipe.Path(clone_table(attributes), { curve }, false)
end

function R.make_conic_arc(definition, attributes, options)
  options = options or {}
  if definition.kind == "ellipse" or definition.kind == "circle" then
    if type(ipe.Arc) ~= "function" then error("this Ipe runtime does not support exact arcs") end
    local properties = definition.properties
    local matrix = ipe.Matrix(
      definition.axis1.x, definition.axis1.y,
      definition.axis2.x, definition.axis2.y,
      properties.center.x, properties.center.y
    )
    local arc = ipe.Arc(matrix, definition.start_parameter, definition.finish_parameter)
    return ipe.Path(clone_table(attributes), {
      { type = "curve", closed = false;
        { type = "arc", arc = arc; definition.first_point, definition.second_point } },
    }, false)
  elseif definition.kind == "parabola" then
    return make_spline(Advanced.parabola_interval_control(
      definition.properties, definition.start_parameter, definition.finish_parameter
    ), attributes)
  end
  return make_cubic_curve(Advanced.adaptive_hyperbola_interval(
    definition.properties,
    definition.branch,
    definition.start_parameter,
    definition.finish_parameter,
    options.tolerance,
    options.max_segments
  ), attributes)
end

local function make_mark(point, styles)
  M.require_finite_point(point, "mark")
  return ipe.Reference(clone_table(styles.mark), styles.markshape, point)
end

local function make_text(text, point, styles)
  M.require_finite_point(point, "label")
  return ipe.Text(clone_table(styles.text), text, point)
end

local function add_line_object(entries, line, line_length, attributes, role)
  local segment = line_segment_from_infinite(line.point, line.direction, line_length)
  entries[#entries + 1] = {
    object = make_segment(segment.p1, segment.p2, attributes),
    role = role or "guide",
  }
end

local function matrix_values(matrix)
  local values = { matrix:coeff() }
  if #values == 1 and type(values[1]) == "table" then values = values[1] end
  return values
end

local function serialize_shape_value(parts, value, depth)
  depth = depth or 0
  if depth > 8 then return end
  if type(value) == "number" then
    parts[#parts + 1] = string.format("%.17g", value)
  elseif type(value) == "string" or type(value) == "boolean" then
    parts[#parts + 1] = tostring(value)
  elseif type(value) == "table" then
    if finite_number(value.x) and finite_number(value.y) then
      parts[#parts + 1] = string.format("%.17g,%.17g", value.x, value.y)
    else
      for index, item in ipairs(value) do serialize_shape_value(parts, item, depth + 1) end
      local keys = {}
      for key, _ in pairs(value) do
        if type(key) ~= "number" then keys[#keys + 1] = key end
      end
      table.sort(keys)
      for _, key in ipairs(keys) do
        parts[#parts + 1] = tostring(key)
        serialize_shape_value(parts, value[key], depth + 1)
      end
    end
  else
    local ok, values = pcall(function() return matrix_values(value) end)
    if ok and type(values) == "table" and #values >= 6 then
      for index = 1, 6 do parts[#parts + 1] = string.format("%.17g", values[index]) end
    else
      local ok_arc, alpha, beta = pcall(function() return value:angles() end)
      local ok_matrix, arc_matrix = pcall(function() return value:matrix() end)
      if ok_arc and ok_matrix and arc_matrix then
        parts[#parts + 1] = string.format("%.17g", alpha)
        parts[#parts + 1] = string.format("%.17g", beta)
        local arc_values = matrix_values(arc_matrix)
        for index = 1, math.min(6, #arc_values) do
          parts[#parts + 1] = string.format("%.17g", arc_values[index])
        end
      end
    end
  end
end

local function fnv1a(text)
  local hash = 2166136261
  for index = 1, #text do
    hash = ((hash ~ text:byte(index)) * 16777619) & 0xffffffff
  end
  return string.format("%08x", hash)
end

local function shape_fingerprint(object)
  local shape = path_shape(object)
  local parts = {}
  if shape then
    serialize_shape_value(parts, shape, 0)
  elseif object_type(object) == "reference" then
    local ok_position, position = pcall(function() return object:position() end)
    local ok_symbol, symbol = pcall(function() return object:symbol() end)
    if not ok_position or not position or not ok_symbol then return nil end
    parts[#parts + 1] = tostring(symbol)
    serialize_shape_value(parts, position, 0)
    serialize_shape_value(parts, object_matrix(object), 0)
  else
    return nil
  end
  return fnv1a(table.concat(parts, "|"))
end

local function coefficients_text(coefficients)
  coefficients = normalize_coefficients(coefficients)
  local values = {}
  for index = 1, 6 do values[index] = string.format("%.17g", coefficients[index]) end
  return table.concat(values, ",")
end

local CONIC_ID_COUNTER = 0
local function next_conic_id()
  CONIC_ID_COUNTER = CONIC_ID_COUNTER + 1
  return string.format("c%08x", CONIC_ID_COUNTER)
end

local function metadata_string(fields)
  local parts = { "conics:v1" }
  local order = {
    "role", "id", "kind", "source", "coordinate_space", "coefficients",
    "fingerprint", "trusted", "count",
  }
  for _, key in ipairs(order) do
    if fields[key] ~= nil then parts[#parts + 1] = key .. "=" .. tostring(fields[key]) end
  end
  return table.concat(parts, ";")
end

local function curve_metadata(object, id, kind, coefficients, source, role)
  local coordinate_space = "object"
  if coefficients == nil then
    coefficients = { 1, 0, 1, 0, 0, -1 }
    coordinate_space = "ellipse_shape"
  end
  return metadata_string({
    role = role or "curve",
    id = id,
    kind = kind,
    source = source,
    coordinate_space = coordinate_space,
    coefficients = coefficients_text(coefficients),
    fingerprint = shape_fingerprint(object),
    trusted = "true",
  })
end

local function auxiliary_metadata(id, role, kind, source)
  return metadata_string({
    role = role,
    id = id,
    kind = kind,
    source = source,
    trusted = "true",
  })
end

local function split_metadata(custom)
  local tokens = {}
  for token in tostring(custom or ""):gmatch("[^;]+") do tokens[#tokens + 1] = token end
  return tokens
end

local function metadata_fields(tokens, namespace_index)
  local fields = {}
  for index = namespace_index + 1, #tokens do
    if tokens[index]:find(":", 1, true) and not tokens[index]:find("=", 1, true) then break end
    local key, value = tokens[index]:match("^([^=]+)=(.*)$")
    if key then fields[key] = value end
  end
  return fields
end

local function strict_metadata_fields(tokens, namespace_index)
  local allowed = {
    role = true, id = true, kind = true, source = true,
    coordinate_space = true, coefficients = true, fingerprint = true,
    trusted = true, count = true,
  }
  local fields = {}
  for index = namespace_index + 1, #tokens do
    local token = tokens[index]
    if token:find(":", 1, true) and not token:find("=", 1, true) then break end
    local key, value = token:match("^([^=]+)=(.*)$")
    if not key then error("Conics metadata contains a malformed field") end
    if not allowed[key] then error("Conics metadata contains an unknown field: " .. key) end
    if fields[key] ~= nil then error("Conics metadata repeats the field: " .. key) end
    fields[key] = value
  end
  return fields
end

local function parse_coefficients_text(encoded)
  if type(encoded) ~= "string" then error("Conics metadata is missing coefficients") end
  local coefficients = {}
  for value in encoded:gmatch("[^,]+") do coefficients[#coefficients + 1] = value end
  if #coefficients ~= 6 then error("Conics metadata must contain exactly six coefficients") end
  return normalize_coefficients(coefficients)
end

local function parse_conic_metadata(object)
  local custom, tokens = object_custom_value(object), nil
  tokens = split_metadata(custom)
  local roles = {
    curve = true, branch = true, asymptote = true, guide = true,
    mark = true, label = true, group = true, axis = true,
    directrix = true, tangent = true, normal = true, polar = true,
    intersection = true, center = true, vertex = true, focus = true,
    pole = true, chord = true, latus_rectum = true,
    auxiliary_circle = true, director_circle = true, equation = true,
    degenerate = true,
  }
  local namespace_count = 0
  for _, token in ipairs(tokens) do
    if token:match("^conics:") then
      if token ~= "conics:v1" then
        error("Unsupported Conics metadata version: " .. token)
      end
      namespace_count = namespace_count + 1
    end
  end
  if namespace_count > 1 then error("Conics metadata namespace is repeated") end
  for index, token in ipairs(tokens) do
    if token == "conics:v1" then
      local fields = strict_metadata_fields(tokens, index)
      if not fields.role or fields.role == "" then
        error("Conics metadata is missing its object role")
      end
      if not roles[fields.role] then
        error("Conics metadata has an unsupported object role: " .. fields.role)
      end
      if fields.role ~= "group" and (not fields.id or fields.id == "") then
        error("Conics metadata is missing its conic identifier")
      end
      if not fields.kind or fields.kind == "" or not fields.source or fields.source == "" then
        error("Conics metadata is missing kind or construction source")
      end
      if fields.trusted ~= "true" then
        error("Conics metadata is not marked as trusted")
      end
      if fields.role == "group" then
        local count = tonumber(fields.count)
        if not finite_number(count) or count < 1 or count ~= math.floor(count) then
          error("Conics group metadata must contain a positive integer count")
        end
        if fields.coefficients or fields.coordinate_space or fields.fingerprint then
          error("Conics group metadata contains curve-only fields")
        end
        return nil, { status = "auxiliary", role = fields.role, fields = fields }
      end
      if fields.role ~= "curve" and fields.role ~= "branch"
          and fields.role ~= "degenerate" then
        if fields.coefficients or fields.coordinate_space or fields.fingerprint then
          error("Conics auxiliary metadata contains curve-only fields")
        end
        return nil, { status = "auxiliary", role = fields.role, fields = fields }
      end
      if fields.kind ~= "circle" and fields.kind ~= "ellipse"
          and fields.kind ~= "parabola" and fields.kind ~= "hyperbola"
          and fields.kind ~= "degenerate" then
        error("Conics metadata has an unsupported conic kind: " .. fields.kind)
      end
      if fields.coordinate_space ~= "object"
          and fields.coordinate_space ~= "ellipse_shape" then
        error("Conics metadata has an unsupported coordinate space")
      end
      if not fields.fingerprint or fields.fingerprint == "" then
        error("Conics metadata is missing its geometry fingerprint")
      end
      local expected_fingerprint = fields.fingerprint
      local current_fingerprint = shape_fingerprint(object)
      if expected_fingerprint and current_fingerprint
          and expected_fingerprint ~= current_fingerprint then
        error("Conics metadata is stale because the path geometry was edited")
      end
      return parse_coefficients_text(fields.coefficients), {
        status = "current",
        fields = fields,
        id = fields.id,
        kind = fields.kind,
      }
    end
  end
  local legacy = false
  for _, token in ipairs(tokens) do
    if token == "geometry:conic" or token == "geometry:hyperbola" then legacy = true end
  end
  if legacy then
    local encoded
    for _, token in ipairs(tokens) do
      encoded = encoded or token:match("^coefficients=(.*)$")
    end
    if not encoded then error("Legacy conic metadata is present but has no coefficients") end
    return parse_coefficients_text(encoded), {
      status = "legacy",
      id = "legacy:" .. fnv1a(custom),
      kind = "legacy",
    }
  end
  return nil, { status = "absent" }
end

local function ellipse_coefficients_from_object(object, parent_matrix)
  local shape = path_shape(object)
  if not shape or #shape ~= 1 or shape[1].type ~= "ellipse" or not shape[1][1] then return nil end
  local matrix = (parent_matrix or ipe.Matrix()) * object_matrix(object) * shape[1][1]
  local a, c, b, d, tx, ty = unpack(matrix_values(matrix))
  return ellipse_coefficients({
    center = V(tx, ty),
    axis1 = V(a, c),
    axis2 = V(b, d),
  })
end

local function collect_conic_definitions(object, parent_matrix, definitions, errors)
  parent_matrix = parent_matrix or ipe.Matrix()
  definitions, errors = definitions or {}, errors or {}
  local matrix = parent_matrix * object_matrix(object)
  local ok_metadata, coefficients, information = pcall(parse_conic_metadata, object)
  if not ok_metadata then
    errors[#errors + 1] = clean_error_message(coefficients)
  elseif coefficients then
    local ok_transform, transformed
    if information.fields and information.fields.coordinate_space == "ellipse_shape" then
      ok_transform, transformed = pcall(ellipse_coefficients_from_object, object, parent_matrix)
    else
      ok_transform, transformed = pcall(
        transformed_conic_coefficients, coefficients, matrix
      )
    end
    if ok_transform then
      definitions[#definitions + 1] = {
        id = information.id,
        kind = information.kind,
        coefficients = transformed,
        metadata_status = information.status,
        object = object,
      }
    else
      errors[#errors + 1] = clean_error_message(transformed)
    end
  elseif object_type(object) == "path" and information.status == "absent" then
    local ok_ellipse, ellipse_result = pcall(
      ellipse_coefficients_from_object, object, parent_matrix
    )
    if ok_ellipse and ellipse_result then
      definitions[#definitions + 1] = {
        id = "native:" .. tostring(object),
        kind = classify_conic(ellipse_result).kind,
        coefficients = ellipse_result,
        metadata_status = "native",
        object = object,
      }
    end
  end
  if object_type(object) == "group" then
    for _, child in ipairs(object_elements(object) or {}) do
      collect_conic_definitions(child, matrix, definitions, errors)
    end
  end
  return definitions, errors
end

local function primary_conic_definition(model)
  local page, primary = model:page(), model:page():primarySelection()
  if not primary then error("Select a conic as the primary object.") end
  local object = page[primary]
  if not object then error("Primary conic object is unavailable.") end
  local definitions, errors = collect_conic_definitions(object)
  if #errors > 0 then error(errors[1]) end
  local unique = {}
  for _, definition in ipairs(definitions) do
    local existing = unique[definition.id]
    if not existing then
      unique[definition.id] = definition
    else
      for index = 1, 6 do
        if math.abs(existing.coefficients[index] - definition.coefficients[index])
            > scaled_tolerance(1, 16384) then
          error("Selected group contains inconsistent conic branches.")
        end
      end
    end
  end
  local selected
  for _, definition in pairs(unique) do
    if selected then error("Selected group contains more than one distinct conic.") end
    selected = definition
  end
  if not selected then
    error("Primary selection is not a conic curve; auxiliary lines are not accepted.")
  end
  return selected
end

local function warn_for_invisible_layer(model, layer)
  if model._conics_preview then return end
  local ok, visible = pcall(function() return model:page():visible(model.vno, layer) end)
  if ok and visible == false then
    model:warning(
      "Active layer is invisible",
      "You have just created an object in layer '" .. tostring(layer) .. "'.\n\n"
        .. "This layer is currently not visible, so the new object is hidden."
    )
  end
end

local function register_creation(model, label_value, entries, layer, group_output, group_metadata)
  if #entries == 0 then error("construction produced no visible elements") end
  for _, entry in ipairs(entries) do
    if entry.metadata then append_object_custom_value(entry.object, entry.metadata) end
  end
  local objects = {}
  if group_output and #entries > 1 and type(ipe.Group) == "function" then
    local children = {}
    for _, entry in ipairs(entries) do children[#children + 1] = entry.object end
    local group = ipe.Group(children)
    if group_metadata then append_object_custom_value(group, group_metadata) end
    objects[1] = group
  else
    for _, entry in ipairs(entries) do objects[#objects + 1] = entry.object end
  end
  warn_for_invisible_layer(model, layer)
  local transaction = {
    label = label_value,
    pno = model.pno,
    vno = model.vno,
    object = objects[1],
    objects = objects,
    layer = layer,
  }
  transaction.undo = function(record, document)
    local page = document[record.pno]
    for _ = 1, #record.objects do page:remove(#page) end
  end
  transaction.redo = function(record, document)
    local page = document[record.pno]
    page:deselectAll()
    for index, object in ipairs(record.objects) do
      page:insert(nil, object, index == 1 and 1 or 2, record.layer)
    end
  end
  model:register(transaction)
  return objects
end

function R.register_replacement(model, label_value, index, entries, group_metadata)
  if #entries == 0 then error("replacement produced no visible conic") end
  for _, entry in ipairs(entries) do
    if entry.metadata then append_object_custom_value(entry.object, entry.metadata) end
  end
  local replacement
  if #entries == 1 then
    replacement = entries[1].object
  elseif type(ipe.Group) == "function" then
    local children = {}
    for _, entry in ipairs(entries) do children[#children + 1] = entry.object end
    replacement = ipe.Group(children)
    if group_metadata then append_object_custom_value(replacement, group_metadata) end
  else
    error("multiple replacement branches require group support")
  end
  local original = model:page()[index]
  if not original then error("replacement target is unavailable") end
  local transaction = {
    label = label_value,
    pno = model.pno,
    vno = model.vno,
    index = index,
    original = original,
    replacement = replacement,
    object = replacement,
    objects = { replacement },
  }
  transaction.undo = function(record, document)
    local page = document[record.pno]
    page:replace(record.index, record.original)
    pcall(function() page:setSelect(record.index, 1) end)
  end
  transaction.redo = function(record, document)
    local page = document[record.pno]
    page:replace(record.index, record.replacement)
    pcall(function() page:setSelect(record.index, 1) end)
  end
  model:register(transaction)
  return { replacement }
end

local function warn_and_return(model, title, message)
  message = clean_error_message(message)
  if model and type(model.warning) == "function" then model:warning(title, message) end
  return {
    created = false,
    status = "error",
    operation = nil,
    element_count = 0,
    object_count = model and model.page and #model:page() or 0,
    metadata = nil,
    result = nil,
    error = message,
  }
end

local function creator_call(model, title, callback)
  local ok, result = pcall(callback)
  if not ok then return warn_and_return(model, title, result) end
  return result
end

local function success_result(model, operation, entries, objects, metadata, result)
  return {
    created = true,
    status = "created",
    operation = operation,
    element_count = #entries,
    object_count = #model:page(),
    created_object_count = #objects,
    metadata = metadata,
    result = result or {},
  }
end

R.clone_table = clone_table
R.construction_styles = construction_styles
R.object_type = object_type
R.object_matrix = object_matrix
R.path_shape = path_shape
R.object_elements = object_elements
R.object_custom_value = object_custom_value
R.set_object_custom_value = set_object_custom_value
R.append_object_custom_value = append_object_custom_value
R.reference_position = reference_position
R.single_segment_from_path = single_segment_from_path
R.selected_objects = selected_objects
R.selection_inputs = selection_inputs
R.primary_first_point_values = primary_first_point_values
R.active_layer = active_layer
R.points_option = points_option
R.make_segment = make_segment
R.make_ellipse = make_ellipse
R.make_spline = make_spline
R.make_cubic_curve = make_cubic_curve
R.make_mark = make_mark
R.make_text = make_text
R.add_line_object = add_line_object
R.shape_fingerprint = shape_fingerprint
R.curve_metadata = curve_metadata
R.auxiliary_metadata = auxiliary_metadata
R.parse_conic_metadata = parse_conic_metadata
R.collect_conic_definitions = collect_conic_definitions
R.primary_conic_definition = primary_conic_definition
R.register_creation = register_creation
R.warn_and_return = warn_and_return
R.creator_call = creator_call
R.success_result = success_result

----------------------------------------------------------------------
-- Conic rendering and construction workflows
----------------------------------------------------------------------

local CREATE_CONIC_ALLOWED = {
  operation = true, construction = true, definition = true, points = true,
  lines = true, constraints = true,
  focus = true, directrix = true, line = true, point_on_conic = true, point = true,
  eccentricity = true, expected_kind = true, maximum_points = true,
  allow_degenerate = true, degenerate = true, subtype = true, line_length = true,
  steiner = true, mode = true, padding = true, extent = true, tolerance = true,
  samples = true, max_segments = true, branch = true, group_output = true,
  group = true, bounds = true,
}
local HYPERBOLA_ALLOWED = {
  operation = true, construction = true, definition = true,
  focus_a = true, focus_b = true, point = true, center = true,
  asymptote_a = true, asymptote_b = true, lines = true,
  axis = true, line = true, a = true, b = true, radius = true,
  branch = true, t_max = true, extent = true, tolerance = true,
  samples = true, max_segments = true, asymptotes = true,
  asymptote_length = true, group_output = true, group = true,
}
local ELLIPSE_ALLOWED = {
  operation = true, construction = true, definition = true,
  focus_a = true, focus_b = true, point = true, center = true,
  first_endpoint = true, second_endpoint = true, points = true,
}
local PARABOLA_ALLOWED = {
  operation = true, construction = true,
  definition = true, directrix = true, line = true, focus = true, foci = true,
  vertex = true,
  extent = true, padding = true, group_output = true, group = true,
}
local DEFINITION_ALLOWED = {
  conic = {
    lines = true, constraints = true,
    points = true, focus = true, directrix = true, line = true,
    point_on_conic = true, point = true, eccentricity = true,
    expected_kind = true, maximum_points = true, allow_degenerate = true,
    degenerate = true, subtype = true,
  },
  ellipse = {
    focus_a = true, focus_b = true, point = true, center = true,
    first_endpoint = true, second_endpoint = true, points = true,
  },
  hyperbola = {
    focus_a = true, focus_b = true, point = true, center = true,
    asymptote_a = true, asymptote_b = true, lines = true,
    axis = true, line = true, a = true, b = true, radius = true,
  },
  parabola = {
    directrix = true, line = true, focus = true, foci = true,
    vertex = true,
  },
}

function M.reject_nested_aliases(options, keys, context)
  if options.definition == nil then return end
  for _, key in ipairs(keys) do
    if options[key] ~= nil then
      error((context or "options") .. " cannot mix nested 'definition' with legacy field '"
        .. key .. "'")
    end
  end
end

local function definition_options(options, allowed, context)
  if options.definition == nil then return options end
  if type(options.definition) ~= "table" then error("definition must be a table") end
  if allowed then
    validate_keys(options.definition, allowed, context or "definition")
  end
  return options.definition
end

local function serializable_line(line)
  local direction = unit(line.direction or sub(line.p2, line.p1), "line direction")
  return {
    point = point_record(line.point or line.p1),
    direction = point_record(direction),
  }
end

local function serializable_properties(properties)
  local result = {
    kind = properties.kind,
    classification = properties.classification,
    degenerate = properties.degenerate == true,
    subtype = properties.subtype,
    coefficients = properties.coefficients,
    eccentricity = properties.eccentricity,
    focal_radius = properties.focal_radius,
    semi_latus_rectum = properties.semi_latus_rectum,
    area = properties.area,
    vertices = point_records(properties.vertices),
    foci = point_records(properties.foci),
    points = point_records(properties.points),
    directrices = {},
    asymptotes = {},
    lines = {},
    latus_recta = {},
    auxiliary_circles = {},
  }
  if properties.center then result.center = point_record(properties.center) end
  if properties.vertex then result.vertex = point_record(properties.vertex) end
  if properties.major_radius then
    result.major_radius, result.minor_radius = properties.major_radius, properties.minor_radius
  end
  if properties.a then result.a, result.b = properties.a, properties.b end
  if properties.t_max then result.t_max = properties.t_max end
  if properties.render_extent then result.render_extent = properties.render_extent end
  if properties.axis_direction then
    result.axis_direction = point_record(properties.axis_direction)
    result.normal_direction = point_record(properties.normal_direction)
    result.focal_parameter = properties.focal_parameter
  end
  if properties.major_direction then
    result.major_direction = point_record(properties.major_direction)
    result.minor_direction = point_record(properties.minor_direction)
  end
  if properties.u then
    result.transverse_direction = point_record(properties.u)
    result.conjugate_direction = point_record(properties.v)
  end
  for index, line in ipairs(properties.directrices or {}) do
    result.directrices[index] = serializable_line(line)
  end
  for index, line in ipairs(properties.asymptotes or {}) do
    result.asymptotes[index] = serializable_line(line)
  end
  for index, line in ipairs(properties.lines or {}) do
    result.lines[index] = serializable_line(line)
  end
  for index, record in ipairs(properties.latus_recta or {}) do
    result.latus_recta[index] = {
      line = serializable_line(record.line),
      endpoints = point_records(record.endpoints),
    }
  end
  for index, circle in ipairs(properties.auxiliary_circles or {}) do
    result.auxiliary_circles[index] = {
      center = point_record(circle.center),
      radius = circle.radius,
    }
  end
  if properties.director_circle then
    result.director_circle = {
      center = point_record(properties.director_circle.center),
      radius = properties.director_circle.radius,
    }
  end
  result.equations = Advanced.conic_equation_strings(properties.coefficients)
  return result
end

function M.serializable_ellipse_geometry(ellipse)
  local radius1, radius2 = length(ellipse.axis1), length(ellipse.axis2)
  if not finite_number(radius1) or not finite_number(radius2)
      or radius1 <= 0 or radius2 <= 0 then
    error("ellipse axes must be finite and nonzero")
  end
  local major_radius, minor_radius, major_axis
  if radius1 >= radius2 then
    major_radius, minor_radius, major_axis = radius1, radius2, ellipse.axis1
  else
    major_radius, minor_radius, major_axis = radius2, radius1, ellipse.axis2
  end
  local major_direction = unit(major_axis, "ellipse major axis")
  local ratio = minor_radius / major_radius
  local focal_radius = major_radius * math.sqrt(math.max(0, 1 - ratio * ratio))
  local center = point_from_table(ellipse.center, "ellipse.center")
  return {
    kind = math.abs(major_radius - minor_radius)
        <= scaled_tolerance(major_radius, 4096) and "circle" or "ellipse",
    classification = math.abs(major_radius - minor_radius)
        <= scaled_tolerance(major_radius, 4096) and "circle" or "ellipse",
    center = point_record(center),
    major_radius = major_radius,
    minor_radius = minor_radius,
    eccentricity = focal_radius / major_radius,
    vertices = {
      point_record(add(center, scale(major_direction, major_radius))),
      point_record(sub(center, scale(major_direction, major_radius))),
    },
    foci = {
      point_record(add(center, scale(major_direction, focal_radius))),
      point_record(sub(center, scale(major_direction, focal_radius))),
    },
    directrices = {},
    asymptotes = {},
  }
end

local function conic_curve_extent(properties, options, source_points)
  local requested = options.extent
  if requested ~= nil and options.bounds ~= nil then
    error("conic options cannot contain both 'extent' and 'bounds'")
  end
  if requested ~= nil then return positive_number_option(requested, nil, "extent") end
  local bounds = options.bounds and M.bounds_from_table(options.bounds) or nil
  local extent = bounds and 0 or 96
  local center = properties.vertex or properties.center or V(0, 0)
  local direction = properties.normal_direction or properties.u or V(1, 0)
  for _, point in ipairs(bounds and bounds.corners or {}) do
    local projection = math.abs(dot(sub(point, center), direction))
    if not finite_number(projection) then error("bounds projection exceeds numeric range") end
    extent = math.max(extent, projection)
  end
  for _, point in ipairs(source_points or {}) do
    local projection = math.abs(dot(sub(point, center), direction))
    if not finite_number(projection) then error("source-point projection exceeds numeric range") end
    extent = math.max(extent, projection)
  end
  local padding = nonnegative_number_option(options.padding, bounds and 0 or 24, "padding")
  return extent + padding
end

function M.hyperbola_parameter_from_extent(hyperbola, extent)
  extent = positive_number_option(extent, nil, "extent")
  if extent <= hyperbola.a then error("hyperbola extent must be greater than a") end
  return M.stable_acosh(extent / hyperbola.a)
end

function M.automatic_hyperbola_parameter(
    hyperbola, coefficients, options, source_points)
  if options.extent ~= nil and options.bounds ~= nil then
    error("conic options cannot contain both 'extent' and 'bounds'")
  end
  if options.extent ~= nil then
    return M.hyperbola_parameter_from_extent(hyperbola, options.extent)
  end
  local maximum_conjugate = 0
  if options.bounds ~= nil then
    for _, point in ipairs(M.bounds_from_table(options.bounds).corners) do
      local projection = math.abs(dot(sub(point, hyperbola.center), hyperbola.v))
      if not finite_number(projection) then error("bounds projection exceeds numeric range") end
      maximum_conjugate = math.max(maximum_conjugate, projection)
    end
  end
  for _, point in ipairs(source_points or {}) do
    local value, magnitude = evaluate_conic(coefficients, point)
    if math.abs(value) <= scaled_tolerance(math.max(magnitude, MIN_NORMAL), 32768) then
      local projection = math.abs(dot(sub(point, hyperbola.center), hyperbola.v))
      if not finite_number(projection) then
        error("source-point projection exceeds numeric range")
      end
      maximum_conjugate = math.max(maximum_conjugate, projection)
    end
  end
  local default_padding = options.bounds ~= nil and 0 or 24
  local padding = nonnegative_number_option(options.padding, default_padding, "padding")
  local parameter = stable_asinh((maximum_conjugate + padding) / hyperbola.b)
  if parameter > 0 then
    parameter = parameter + scaled_tolerance(parameter, 64)
  end
  return math.max(2.2, parameter)
end

local function render_conic_entries(coefficients, options, styles, source, source_points)
  local properties = conic_properties(coefficients)
  local entries, id = {}, next_conic_id()
  if properties.kind == "ellipse" or properties.kind == "circle" then
    local ellipse = {
      center = properties.center,
      axis1 = properties.axis1,
      axis2 = properties.axis2,
    }
    local object = make_ellipse(ellipse, styles.path)
    entries[1] = {
      object = object,
      role = "curve",
      metadata = curve_metadata(object, id, properties.kind, coefficients, source, "curve"),
    }
  elseif properties.kind == "parabola" then
    local extent = conic_curve_extent(properties, options, source_points)
    local object = make_spline(parabola_spline(properties, extent, extent), styles.path)
    entries[1] = {
      object = object,
      role = "curve",
      metadata = curve_metadata(object, id, "parabola", coefficients, source, "curve"),
    }
    properties.render_extent = extent
  elseif properties.kind == "hyperbola" then
    local legacy_segment_budget
    if options.samples ~= nil then
      legacy_segment_budget = positive_integer_option(
        options.samples, 80, "samples", 4096, 4
      )
    end
    local branch = normalized_name(options.branch or "both")
    if branch ~= "both" and branch ~= "right" and branch ~= "positive"
        and branch ~= "left" and branch ~= "negative" then
      error("unsupported hyperbola branch: " .. branch)
    end
    local hyperbola = {
      center = properties.center,
      u = properties.u,
      v = properties.v,
      a = properties.a,
      b = properties.b,
    }
    local t_max = M.automatic_hyperbola_parameter(
      hyperbola, coefficients, options, source_points
    )
    local tolerance = positive_number_option(options.tolerance, 0.25, "tolerance")
    local maximum_segments = positive_integer_option(
      options.max_segments or legacy_segment_budget, 256, "max_segments", 4096, 4
    )
    local rendered_t_max
    local function append_branch(branch_value)
      local cubics, used_t_max = adaptive_hyperbola_cubics(
        hyperbola, branch_value, t_max, tolerance, maximum_segments
      )
      rendered_t_max = used_t_max
      local object = make_cubic_curve(cubics, styles.path)
      entries[#entries + 1] = {
        object = object,
        role = "branch",
        metadata = curve_metadata(object, id, "hyperbola", coefficients, source, "branch"),
      }
    end
    if branch == "both" or branch == "right" or branch == "positive" then append_branch(1) end
    if branch == "both" or branch == "left" or branch == "negative" then append_branch(-1) end
    properties.t_max = rendered_t_max
  elseif properties.kind == "degenerate" then
    local allow_degenerate = options.allow_degenerate
    if allow_degenerate == nil and type(options.definition) == "table" then
      allow_degenerate = options.definition.allow_degenerate
    end
    if not bool_value(allow_degenerate, false) then
      error("degenerate conics require allow_degenerate=true")
    end
    local line_length = positive_number_option(options.line_length, 192, "line_length")
    for _, line in ipairs(properties.lines or {}) do
      add_line_object(entries, line, line_length, styles.path, "degenerate")
      entries[#entries].metadata = curve_metadata(
        entries[#entries].object, id, "degenerate", coefficients, source, "degenerate"
      )
    end
    for _, point in ipairs(properties.points or {}) do
      local object = make_mark(point, styles)
      entries[#entries + 1] = {
        object = object,
        role = "degenerate",
        metadata = curve_metadata(
          object, id, "degenerate", coefficients, source, "degenerate"
        ),
      }
    end
  else
    error("unsupported conic classification: " .. tostring(properties.kind))
  end
  return entries, properties, id
end

local function explicit_or_selected_points(model, options, expected, message)
  local explicit = points_option(options, expected)
  if explicit then return explicit end
  local summary = selection_inputs(model)
  require_exact_construction_selection(summary, expected, 0, message)
  local values = {}
  for index, record in ipairs(summary.points) do values[index] = record.point end
  return values
end

function R.explicit_or_selected_flexible_points(model, options, minimum, maximum, message)
  if options.points ~= nil then
    return Advanced.flexible_points(options.points, minimum, maximum, "points")
  end
  local summary = selection_inputs(model)
  if #summary.invalid ~= 0 or #summary.segments ~= 0 or #summary.conic_entries ~= 0
      or #summary.points < minimum or #summary.points > maximum
      or #summary.entries ~= #summary.points then
    error(message)
  end
  local values = {}
  for index, record in ipairs(summary.points) do values[index] = record.point end
  return values
end

function R.explicit_or_selected_lines(model, options, expected, message)
  if options.lines ~= nil then
    if type(options.lines) ~= "table" or #options.lines ~= expected then error(message) end
    local lines = {}
    for index, line in ipairs(options.lines) do
      lines[index] = line_from_table(line, "lines[" .. tostring(index) .. "]")
    end
    return lines
  end
  local summary = selection_inputs(model)
  require_exact_construction_selection(summary, 0, expected, message)
  local lines = {}
  for index, record in ipairs(summary.segments) do lines[index] = record.line end
  return lines
end

function R.selected_mixed_constraints(model, message)
  local summary = selection_inputs(model)
  local segment_count = #summary.segments
  if #summary.invalid ~= 0 or #summary.conic_entries ~= 0
      or segment_count > 2 or #summary.points + segment_count ~= 5
      or #summary.entries ~= #summary.points + segment_count then
    error(message)
  end
  local constraints, used = {}, {}
  for index, record in ipairs(summary.points) do
    constraints[index] = { type = "point", point = record.point }
  end
  for segment_index, segment in ipairs(summary.segments) do
    local matches = {}
    for point_index, record in ipairs(summary.points) do
      local point = record.point
      local signed_distance = math.abs(
        segment.line.a * point.x + segment.line.b * point.y + segment.line.c
      )
      local scale_value = math.max(1, vector_scale(point, segment.line.p1, segment.line.p2))
      if signed_distance <= 1e-7 * scale_value then matches[#matches + 1] = point_index end
    end
    if #matches ~= 1 then
      error("Each tangent segment must pass through exactly one selected mark.")
    end
    local point_index = matches[1]
    if used[point_index] then
      error("Two tangent segments cannot reuse the same tangent-point mark.")
    end
    used[point_index] = true
    constraints[point_index] = {
      type = "tangent",
      point = summary.points[point_index].point,
      line = segment.line,
    }
  end
  return constraints
end

local function create_conic(model, raw_options)
  return creator_call(model, "Cannot create conic", function()
    local options = options_table(raw_options)
    validate_keys(options, CREATE_CONIC_ALLOWED, "conic options")
    M.reject_nested_aliases(options,
      { "points", "lines", "constraints", "focus", "directrix", "line",
        "point_on_conic", "point", "eccentricity", "expected_kind",
        "maximum_points", "allow_degenerate", "degenerate", "subtype" },
      "conic options")
    local definition = definition_options(
      options, DEFINITION_ALLOWED.conic, "conic definition"
    )
    local operation = normalized_name(
      M.aliased_value(options, "operation", "construction", "conic options") or "steiner"
    )
    local styles, entries, result = construction_styles(model), {}, {}
    local source, group_default = operation, false

    if operation == "steiner" or operation == "steiner_ellipses" then
      local points = explicit_or_selected_points(
        model, definition, 3, "Select exactly three marks, or pass exactly three points."
      )
      local ellipses = steiner_ellipses(points[1], points[2], points[3])
      local mode = normalized_name(
        M.aliased_value(options, "steiner", "mode", "conic options") or "both"
      )
      if mode == "circum" then mode = "circumellipse" end
      if mode == "in" then mode = "inellipse" end
      if mode ~= "both" and mode ~= "circumellipse" and mode ~= "inellipse" then
        error("unsupported Steiner mode: " .. mode)
      end
      local records = {}
      local function append_ellipse(ellipse, attributes, construction_kind)
        local ok_coefficients, coefficients = pcall(ellipse_coefficients, ellipse)
        if not ok_coefficients then coefficients = nil end
        local properties = coefficients
            and serializable_properties(conic_properties(coefficients))
            or M.serializable_ellipse_geometry(ellipse)
        local object, id = make_ellipse(ellipse, attributes), next_conic_id()
        entries[#entries + 1] = {
          object = object,
          role = "curve",
          metadata = curve_metadata(
            object, id, properties.kind, coefficients, construction_kind, "curve"
          ),
        }
        records[#records + 1] = {
          kind = properties.kind,
          source = construction_kind,
          coefficients = coefficients,
          coefficients_available = coefficients ~= nil,
          properties = properties,
        }
      end
      if mode == "both" or mode == "circumellipse" then
        append_ellipse(ellipses.circumellipse, styles.path, "steiner_circumellipse")
      end
      if mode == "both" or mode == "inellipse" then
        append_ellipse(ellipses.inellipse, styles.dashed, "steiner_inellipse")
      end
      result = {
        type = "steiner",
        center = point_record(ellipses.circumellipse.center),
        conics = records,
      }
      group_default = #entries > 1
    elseif operation == "five_points" then
      local points = explicit_or_selected_points(
        model, definition, 5, "Select exactly five marks, or pass exactly five points."
      )
      local coefficients = Advanced.conic_coefficients_from_points(points, {
        allow_degenerate = bool_value(definition.allow_degenerate, false),
      })
      entries, result.properties, result.id = render_conic_entries(
        coefficients, options, styles, "five_points", points
      )
      result.type = "conic"
      result.coefficients = coefficients
      result.properties = serializable_properties(result.properties)
    elseif operation == "fit_points" or operation == "best_fit" then
      local maximum_points = positive_integer_option(
        definition.maximum_points, 512, "maximum_points", 4096, 6
      )
      local points = R.explicit_or_selected_flexible_points(
        model, definition, 6, maximum_points,
        "Select between six and the configured maximum number of marks."
      )
      local coefficients, diagnostics = Advanced.conic_coefficients_from_points(points, {
        allow_degenerate = bool_value(definition.allow_degenerate, false),
        expected_kind = definition.expected_kind,
        maximum_points = maximum_points,
      })
      entries, result.properties, result.id = render_conic_entries(
        coefficients, options, styles, "fit_points", points
      )
      result.type = "best-fit-conic"
      result.coefficients = coefficients
      result.fit = diagnostics
      result.properties = serializable_properties(result.properties)
    elseif operation == "five_tangents" or operation == "tangent_to_five_lines" then
      local lines = R.explicit_or_selected_lines(
        model, definition, 5,
        "Select exactly five segments, or pass exactly five tangent lines."
      )
      local coefficients = Advanced.conic_coefficients_from_five_lines(lines, {
        allow_degenerate = bool_value(definition.allow_degenerate, false),
      })
      entries, result.properties, result.id = render_conic_entries(
        coefficients, options, styles, "five_tangents", nil
      )
      result.type = "five-tangent-conic"
      result.coefficients = coefficients
      result.tangent_lines = {}
      for index, line in ipairs(lines) do result.tangent_lines[index] = serializable_line(line) end
      result.properties = serializable_properties(result.properties)
    elseif operation == "five_conditions" or operation == "mixed_conditions" then
      local constraints
      if definition.constraints ~= nil then
        if type(definition.constraints) ~= "table" then
          error("constraints must be an array")
        end
        constraints = definition.constraints
      else
        constraints = R.selected_mixed_constraints(
          model,
          "Select five marks, four marks plus one tangent segment, or three marks plus two tangent segments."
        )
      end
      local coefficients = Advanced.conic_coefficients_from_constraints(constraints, {
        allow_degenerate = bool_value(definition.allow_degenerate, false),
      })
      local source_points = {}
      for _, constraint in ipairs(constraints) do
        source_points[#source_points + 1] = point_from_table(
          constraint.point or constraint, "constraint point"
        )
      end
      entries, result.properties, result.id = render_conic_entries(
        coefficients, options, styles, "five_conditions", source_points
      )
      result.type = "mixed-condition-conic"
      result.constraint_count = #constraints
      result.coefficients = coefficients
      result.properties = serializable_properties(result.properties)
    elseif operation == "focus_directrix_point" or operation == "directrix_focus_point" then
      local focus_value = definition.focus
      local directrix_value = M.aliased_value(
        definition, "directrix", "line", "conic definition"
      )
      local point_value = M.aliased_value(
        definition, "point_on_conic", "point", "conic definition"
      )
      local focus, directrix, point
      local has_explicit = focus_value ~= nil or directrix_value ~= nil or point_value ~= nil
      if has_explicit then
        if focus_value == nil or directrix_value == nil or point_value == nil then
          error("focus, directrix, and point_on_conic are all required")
        end
        focus = point_from_table(focus_value, "focus")
        directrix = line_from_table(directrix_value, "directrix")
        point = point_from_table(point_value, "point_on_conic")
      else
        local summary = selection_inputs(model)
        require_exact_construction_selection(
          summary, 2, 1,
          "Select exactly two marks and one segment, with the point on the conic as primary."
        )
        if not summary.primary_point then
          error("The primary selection must be the point on the conic.")
        end
        point = summary.primary_point.point
        for _, record in ipairs(summary.points) do
          if record ~= summary.primary_point then focus = record.point end
        end
        directrix = summary.segments[1].line
      end
      local coefficients = focus_directrix_conic_coefficients(focus, directrix, point)
      local source_points = { focus, point, directrix.p1, directrix.p2 }
      entries, result.properties, result.id = render_conic_entries(
        coefficients, options, styles, "focus_directrix_point", source_points
      )
      result.type = "focus-directrix"
      result.eccentricity = coefficients.eccentricity
      result.coefficients = coefficients
      result.properties = serializable_properties(result.properties)
      group_default = #entries > 1
    elseif operation == "focus_directrix_eccentricity"
        or operation == "focus_directrix_e" then
      local focus_value = definition.focus
      local directrix_value = M.aliased_value(
        definition, "directrix", "line", "conic definition"
      )
      local focus, directrix
      if focus_value ~= nil or directrix_value ~= nil then
        if focus_value == nil or directrix_value == nil then
          error("focus and directrix are both required")
        end
        focus = point_from_table(focus_value, "focus")
        directrix = line_from_table(directrix_value, "directrix")
      else
        local summary = selection_inputs(model)
        require_exact_construction_selection(
          summary, 1, 1,
          "Select exactly one primary focus mark and one secondary directrix segment."
        )
        if not summary.primary_point then error("The primary selection must be the focus mark.") end
        focus, directrix = summary.primary_point.point, summary.segments[1].line
      end
      local eccentricity = positive_number_option(
        definition.eccentricity, nil, "eccentricity"
      )
      local coefficients = conic_coefficients_for_focus_directrix(
        focus, directrix, eccentricity
      )
      entries, result.properties, result.id = render_conic_entries(
        coefficients, options, styles, "focus_directrix_eccentricity",
        { focus, directrix.p1, directrix.p2 }
      )
      result.type = "focus-directrix-eccentricity"
      result.eccentricity = eccentricity
      result.coefficients = coefficients
      result.properties = serializable_properties(result.properties)
      group_default = #entries > 1
    elseif operation == "degenerate" or operation == "degenerate_locus"
        or operation == "degenerate_line_pair" or operation == "degenerate_double_line"
        or operation == "degenerate_single_line" or operation == "degenerate_point"
        or operation == "degenerate_empty" then
      local default_subtype = ({
        degenerate_line_pair = "lines",
        degenerate_double_line = "double_line",
        degenerate_single_line = "single_line",
        degenerate_point = "point",
        degenerate_empty = "empty",
      })[operation] or "lines"
      local subtype = normalized_name(
        definition.degenerate or definition.subtype or default_subtype
      )
      local coefficients
      if subtype == "lines" or subtype == "line_pair" or subtype == "double_line"
          or subtype == "single_line" then
        local expected = (subtype == "single_line" or subtype == "double_line") and 1 or 2
        local lines = R.explicit_or_selected_lines(
          model, definition, expected,
          expected == 1 and "Select exactly one segment."
            or "Select exactly two segments."
        )
        if subtype == "single_line" then
          coefficients = normalize_coefficients({
            0, 0, 0, lines[1].a, lines[1].b, lines[1].c,
          })
        else
          coefficients = Advanced.degenerate_conic_from_lines(lines)
        end
      elseif subtype == "point" then
        local point_definition = definition
        if definition.point ~= nil then
          if definition.points ~= nil then
            error("degenerate point cannot contain both point and points")
          end
          point_definition = clone_table(definition)
          point_definition.points = { definition.point }
        end
        local points = explicit_or_selected_points(
          model, point_definition, 1, "Select exactly one mark, or pass one point."
        )
        coefficients = Advanced.degenerate_point_conic(points[1])
      elseif subtype == "empty" then
        if definition.points ~= nil or definition.point ~= nil or definition.lines ~= nil then
          error("the empty degenerate locus takes no points or lines")
        end
        coefficients = { 0, 0, 0, 0, 0, 1 }
      else
        error("unsupported degenerate conic subtype: " .. subtype)
      end
      local render_options = clone_table(options)
      render_options.allow_degenerate = true
      entries, result.properties, result.id = render_conic_entries(
        coefficients, render_options, styles, "degenerate_locus", nil
      )
      result.type = "degenerate-conic"
      result.coefficients = normalize_coefficients(coefficients)
      result.properties = serializable_properties(result.properties)
    elseif operation == "quadrilateral_ellipse"
        or operation == "ellipse_through_side_midpoints" then
      local points = explicit_or_selected_points(
        model, definition, 4, "Select exactly four marks, or pass exactly four points."
      )
      local ellipse = quadrilateral_midpoint_ellipse(points)
      local ok_coefficients, coefficients = pcall(ellipse_coefficients, ellipse)
      if not ok_coefficients then coefficients = nil end
      local properties = coefficients
          and serializable_properties(conic_properties(coefficients))
          or M.serializable_ellipse_geometry(ellipse)
      local object, id = make_ellipse(ellipse, styles.path), next_conic_id()
      entries[1] = {
        object = object,
        role = "curve",
        metadata = curve_metadata(
          object, id, properties.kind, coefficients, "quadrilateral_midpoint_ellipse", "curve"
        ),
      }
      result = {
        type = "quadrilateral-midpoint-ellipse",
        mathematical_choice = "canonical conjugate-diameter central minimum-area member",
        coefficients = coefficients,
        coefficients_available = coefficients ~= nil,
        properties = properties,
      }
    else
      error("unsupported conic construction: " .. operation)
    end

    if #entries == 0 then
      local message = "The requested degenerate conic has an empty real locus."
      if model.ui and type(model.ui.explain) == "function" then model.ui:explain(message) end
      return {
        created = false, status = "empty", operation = operation,
        element_count = 0, object_count = #model:page(), metadata = nil,
        result = result, message = message,
      }
    end
    local group_value = M.aliased_value(
      options, "group_output", "group", "conic options"
    )
    local group_output = bool_value(group_value, group_default)
    local group_metadata = metadata_string({
      role = "group", kind = "conic-result", source = source,
      trusted = "true", count = #entries,
    })
    local objects = register_creation(
      model, "create conic", entries, active_layer(model), group_output, group_metadata
    )
    return success_result(model, operation, entries, objects, group_metadata, result)
  end)
end

local function selected_foci_and_point(model, message)
  local summary = selection_inputs(model)
  require_exact_construction_selection(summary, 3, 0, message)
  if not summary.primary_point then error("The primary selection must be the point on the conic.") end
  local foci = {}
  for _, record in ipairs(summary.points) do
    if record ~= summary.primary_point then foci[#foci + 1] = record.point end
  end
  return foci[1], foci[2], summary.primary_point.point
end

local function create_ellipse_from_foci(model, raw_options)
  return creator_call(model, "Cannot create ellipse", function()
    local options = options_table(raw_options)
    validate_keys(options, ELLIPSE_ALLOWED, "ellipse options")
    M.reject_nested_aliases(
      options,
      { "focus_a", "focus_b", "point", "center", "first_endpoint",
        "second_endpoint", "points" },
      "ellipse options"
    )
    local definition = definition_options(
      options, DEFINITION_ALLOWED.ellipse, "ellipse definition"
    )
    local operation = normalized_name(
      M.aliased_value(options, "operation", "construction", "ellipse options")
        or "foci_point"
    )
    local ellipse, defining = nil, {}
    if operation == "foci_point" or operation == "foci_and_point" then
      local focus_a, focus_b, point
      local has_explicit = definition.focus_a ~= nil
        or definition.focus_b ~= nil or definition.point ~= nil
      if has_explicit then
        if definition.focus_a == nil or definition.focus_b == nil or definition.point == nil then
          error("focus_a, focus_b, and point are all required")
        end
        focus_a = point_from_table(definition.focus_a, "focus_a")
        focus_b = point_from_table(definition.focus_b, "focus_b")
        point = point_from_table(definition.point, "point")
      else
        focus_a, focus_b, point = selected_foci_and_point(
          model,
          "Select exactly three marks, with the point on the ellipse as primary."
        )
      end
      ellipse = ellipse_from_foci_point(focus_a, focus_b, point)
      defining = {
        foci = { point_record(focus_a), point_record(focus_b) },
        defining_point = point_record(point),
      }
    elseif operation == "center_axes" or operation == "center_semiaxes" then
      local center, first_endpoint, second_endpoint
      if definition.points ~= nil then
        if definition.center ~= nil or definition.first_endpoint ~= nil
            or definition.second_endpoint ~= nil then
          error("center_axes cannot combine points with named endpoint fields")
        end
        local points = points_from_table(definition.points, 3, "points")
        center, first_endpoint, second_endpoint = points[1], points[2], points[3]
      elseif definition.center ~= nil or definition.first_endpoint ~= nil
          or definition.second_endpoint ~= nil then
        if definition.center == nil or definition.first_endpoint == nil
            or definition.second_endpoint == nil then
          error("center, first_endpoint, and second_endpoint are all required")
        end
        center = point_from_table(definition.center, "center")
        first_endpoint = point_from_table(definition.first_endpoint, "first_endpoint")
        second_endpoint = point_from_table(definition.second_endpoint, "second_endpoint")
      else
        local summary = selection_inputs(model)
        require_exact_construction_selection(
          summary, 3, 0,
          "Select exactly three marks, with the center as primary."
        )
        if not summary.primary_point then error("The primary selection must be the center mark.") end
        center = summary.primary_point.point
        local endpoints = {}
        for _, record in ipairs(summary.points) do
          if record ~= summary.primary_point then endpoints[#endpoints + 1] = record.point end
        end
        first_endpoint, second_endpoint = endpoints[1], endpoints[2]
      end
      ellipse = Advanced.ellipse_from_center_axes(center, first_endpoint, second_endpoint)
      defining = {
        center = point_record(center),
        semiaxis_endpoints = {
          point_record(first_endpoint), point_record(second_endpoint),
        },
      }
    else
      error("unsupported ellipse construction: " .. operation)
    end
    local styles, object, id = construction_styles(model),
      nil, next_conic_id()
    object = make_ellipse(ellipse, styles.path)
    local ok_coefficients, coefficients = pcall(ellipse_coefficients, ellipse)
    if not ok_coefficients then coefficients = nil end
    local serialized = coefficients
        and serializable_properties(conic_properties(coefficients))
        or M.serializable_ellipse_geometry(ellipse)
    local metadata = curve_metadata(
      object, id, serialized.kind, coefficients, operation, "curve"
    )
    local entries = { { object = object, role = "curve", metadata = metadata } }
    local objects = register_creation(
      model, "create ellipse", entries, active_layer(model), false
    )
    local properties = {
      kind = serialized.kind,
      center = point_record(ellipse.center),
      major_radius = ellipse.major_radius,
      minor_radius = ellipse.minor_radius,
      coefficients = coefficients,
      coefficients_available = coefficients ~= nil,
    }
    for key, value in pairs(defining) do properties[key] = value end
    properties.properties = serialized
    properties.conics = {
      {
        kind = serialized.kind,
        coefficients = coefficients,
        properties = properties.properties,
      },
    }
    return success_result(
      model, operation, entries, objects, metadata, properties
    )
  end)
end

local function create_hyperbola(model, raw_options)
  return creator_call(model, "Cannot create hyperbola", function()
    local options = options_table(raw_options)
    validate_keys(options, HYPERBOLA_ALLOWED, "hyperbola options")
    M.reject_nested_aliases(options,
      { "focus_a", "focus_b", "point", "center", "axis", "line", "a", "b",
        "radius", "asymptote_a", "asymptote_b", "lines" },
      "hyperbola options")
    local definition = definition_options(
      options, DEFINITION_ALLOWED.hyperbola, "hyperbola definition"
    )
    local operation = normalized_name(
      M.aliased_value(options, "operation", "construction", "hyperbola options")
        or "foci_point"
    )
    local hyperbola, coefficients
    if operation == "foci_point" or operation == "foci_and_point" then
      local has_explicit = definition.focus_a ~= nil
        or definition.focus_b ~= nil or definition.point ~= nil
      local focus_a, focus_b, point
      if has_explicit then
        if definition.focus_a == nil or definition.focus_b == nil or definition.point == nil then
          error("focus_a, focus_b, and point are all required")
        end
        focus_a = point_from_table(definition.focus_a, "focus_a")
        focus_b = point_from_table(definition.focus_b, "focus_b")
        point = point_from_table(definition.point, "point")
      else
        focus_a, focus_b, point = selected_foci_and_point(
          model,
          "Select exactly three marks, with the point on the hyperbola as primary."
        )
      end
      hyperbola = hyperbola_from_foci_point(focus_a, focus_b, point)
    elseif operation == "parameters" or operation == "rectangular" then
      local center, axis
      local axis_value = M.aliased_value(
        definition, "axis", "line", "hyperbola definition"
      )
      if definition.center ~= nil or axis_value ~= nil then
        if definition.center == nil then
          error("center is required when an explicit axis or line is supplied")
        end
        center = point_from_table(definition.center, "center")
        if axis_value ~= nil then axis = line_from_table(axis_value, "axis") end
      else
        local summary = selection_inputs(model)
        local expected_segments = #summary.segments
        if expected_segments > 1 then
          error("Select one center mark and at most one axis segment.")
        end
        require_exact_construction_selection(
          summary, 1, expected_segments,
          "Select exactly one center mark and optionally one axis segment."
        )
        if not summary.primary_point then error("The primary selection must be the center mark.") end
        center = summary.primary_point.point
        axis = summary.segments[1] and summary.segments[1].line or nil
      end
      local a_radius = positive_number_option(
        M.aliased_value(definition, "a", "radius", "hyperbola definition"), 32, "a"
      )
      local b_radius = operation == "rectangular" and a_radius
        or positive_number_option(definition.b, a_radius * 0.6, "b")
      hyperbola = hyperbola_from_parameters(center, axis, a_radius, b_radius)
    elseif operation == "asymptotes_point" or operation == "asymptotes_and_point" then
      local first_asymptote, second_asymptote, point
      if definition.lines ~= nil then
        if definition.asymptote_a ~= nil or definition.asymptote_b ~= nil then
          error("asymptotes_point cannot combine lines with named asymptote fields")
        end
        if type(definition.lines) ~= "table" or #definition.lines ~= 2 then
          error("lines must contain exactly two asymptotes")
        end
        first_asymptote = line_from_table(definition.lines[1], "first asymptote")
        second_asymptote = line_from_table(definition.lines[2], "second asymptote")
        if definition.point == nil then error("point is required with explicit asymptotes") end
        point = point_from_table(definition.point, "point")
      elseif definition.asymptote_a ~= nil or definition.asymptote_b ~= nil
          or definition.point ~= nil then
        if definition.asymptote_a == nil or definition.asymptote_b == nil
            or definition.point == nil then
          error("asymptote_a, asymptote_b, and point are all required")
        end
        first_asymptote = line_from_table(definition.asymptote_a, "first asymptote")
        second_asymptote = line_from_table(definition.asymptote_b, "second asymptote")
        point = point_from_table(definition.point, "point")
      else
        local summary = selection_inputs(model)
        require_exact_construction_selection(
          summary, 1, 2,
          "Select one primary point mark and two secondary asymptote segments."
        )
        if not summary.primary_point then
          error("The primary selection must be the point on the hyperbola.")
        end
        first_asymptote, second_asymptote = summary.segments[1].line,
          summary.segments[2].line
        point = summary.primary_point.point
      end
      coefficients = Advanced.hyperbola_from_asymptotes_point(
        first_asymptote, second_asymptote, point
      )
      local properties = conic_properties(coefficients)
      hyperbola = {
        center = properties.center,
        u = properties.u,
        v = properties.v,
        a = properties.a,
        b = properties.b,
        point_parameter = math.abs(stable_asinh(
          dot(sub(point, properties.center), properties.v) / properties.b
        )),
        point_branch = dot(sub(point, properties.center), properties.u) < 0 and -1 or 1,
      }
    else
      error("unsupported hyperbola construction: " .. operation)
    end

    coefficients = coefficients or hyperbola_coefficients(hyperbola)
    local styles, entries = construction_styles(model), {}
    local branch = normalized_name(options.branch or "both")
    if branch ~= "both" and branch ~= "right" and branch ~= "positive"
        and branch ~= "left" and branch ~= "negative" and branch ~= "defining" then
      error("unsupported hyperbola branch: " .. branch)
    end
    if branch == "defining" then branch = hyperbola.point_branch == -1 and "left" or "right" end
    local tolerance = positive_number_option(options.tolerance, 0.25, "tolerance")
    local legacy_segment_budget
    if options.samples ~= nil then
      legacy_segment_budget = positive_integer_option(
        options.samples, 80, "samples", 4096, 4
      )
    end
    local max_segments = positive_integer_option(
      options.max_segments or legacy_segment_budget, 256, "max_segments", 4096, 4
    )
    local requested_t_max = options.t_max
    if requested_t_max == nil and options.extent ~= nil then
      requested_t_max = M.hyperbola_parameter_from_extent(hyperbola, options.extent)
    end
    local id, rendered_t_max = next_conic_id(), nil
    local function append_branch(branch_value)
      local cubics, t_max = adaptive_hyperbola_cubics(
        hyperbola, branch_value, requested_t_max, tolerance, max_segments
      )
      rendered_t_max = t_max
      local object = make_cubic_curve(cubics, styles.path)
      entries[#entries + 1] = {
        object = object,
        role = "branch",
        metadata = curve_metadata(
          object, id, "hyperbola", coefficients, operation, "branch"
        ),
      }
    end
    if branch == "both" or branch == "right" or branch == "positive" then append_branch(1) end
    if branch == "both" or branch == "left" or branch == "negative" then append_branch(-1) end
    local asymptotes = bool_value(options.asymptotes, true)
    if asymptotes then
      local asymptote_length = positive_number_option(
        options.asymptote_length, 192, "asymptote_length"
      )
      for _, line in ipairs({
        { point = hyperbola.center,
          direction = add(scale(hyperbola.u, hyperbola.a), scale(hyperbola.v, hyperbola.b)) },
        { point = hyperbola.center,
          direction = sub(scale(hyperbola.u, hyperbola.a), scale(hyperbola.v, hyperbola.b)) },
      }) do
        add_line_object(entries, line, asymptote_length, styles.dashed, "asymptote")
        entries[#entries].metadata = auxiliary_metadata(
          id, "asymptote", "hyperbola", operation
        )
      end
    end
    local group_value = M.aliased_value(
      options, "group_output", "group", "hyperbola options"
    )
    local group_output = bool_value(group_value, #entries > 1)
    local group_metadata = metadata_string({
      role = "group", id = id, kind = "hyperbola", source = operation,
      trusted = "true", count = #entries,
    })
    local objects = register_creation(
      model, "create hyperbola", entries, active_layer(model), group_output, group_metadata
    )
    return success_result(model, operation, entries, objects, group_metadata, {
      kind = "hyperbola",
      center = point_record(hyperbola.center),
      a = hyperbola.a,
      b = hyperbola.b,
      t_max = rendered_t_max,
      coefficients = coefficients,
      properties = serializable_properties(conic_properties(coefficients)),
      branch = branch,
      asymptotes = asymptotes,
    })
  end)
end

local function parabola_inputs(model, options)
  M.reject_nested_aliases(
    options, { "directrix", "line", "focus", "foci", "vertex" }, "parabola options"
  )
  local definition = definition_options(
    options, DEFINITION_ALLOWED.parabola, "parabola definition"
  )
  local directrix_value = M.aliased_value(
    definition, "directrix", "line", "parabola definition"
  )
  if definition.focus ~= nil and definition.foci ~= nil then
    error("parabola definition cannot contain both 'focus' and 'foci'")
  end
  local raw_foci = definition.foci
  if raw_foci == nil and definition.focus ~= nil then raw_foci = { definition.focus } end
  local has_explicit = directrix_value ~= nil or raw_foci ~= nil
  if has_explicit then
    if directrix_value == nil or raw_foci == nil then
      error("directrix and at least one focus are required")
    end
    if type(raw_foci) ~= "table" or #raw_foci == 0 then
      error("directrix and at least one focus are required")
    end
    if #raw_foci > 64 then error("at most 64 foci are supported") end
    local foci = {}
    for index, focus in ipairs(raw_foci) do
      foci[index] = point_from_table(focus, "foci[" .. tostring(index) .. "]")
    end
    return line_from_table(directrix_value, "directrix"), foci
  end
  local summary = selection_inputs(model)
  if #summary.invalid ~= 0 or #summary.conic_entries ~= 0
      or #summary.segments ~= 1 or #summary.points == 0
      or #summary.entries ~= #summary.points + 1 then
    error("Select one primary segment and one or more secondary marks.")
  end
  if not summary.primary_segment then error("The primary selection must be the directrix segment.") end
  if #summary.points > 64 then error("at most 64 foci are supported") end
  local foci = {}
  for index, record in ipairs(summary.points) do foci[index] = record.point end
  return summary.primary_segment.line, foci
end

local function create_parabolas(model, raw_options)
  return creator_call(model, "Cannot create parabolas", function()
    local options = options_table(raw_options)
    validate_keys(options, PARABOLA_ALLOWED, "parabola options")
    local operation = normalized_name(
      M.aliased_value(options, "operation", "construction", "parabola options")
        or "directrix_foci"
    )
    local definitions = {}
    if operation == "directrix_foci" or operation == "directrix_and_foci" then
      local directrix, foci = parabola_inputs(model, options)
      local default_extent = distance(directrix.p1, directrix.p2) * 0.5
      for _, focus in ipairs(foci) do
        definitions[#definitions + 1] = {
          focus = focus,
          directrix = directrix,
          coefficients = conic_coefficients_for_focus_directrix(focus, directrix, 1),
          default_extent = default_extent,
          source = "directrix_foci",
        }
      end
    elseif operation == "vertex_focus" or operation == "vertex_and_focus" then
      M.reject_nested_aliases(
        options, { "directrix", "line", "focus", "foci", "vertex" },
        "parabola options"
      )
      local definition = definition_options(
        options, DEFINITION_ALLOWED.parabola, "parabola definition"
      )
      local vertex, focus
      if definition.vertex ~= nil or definition.focus ~= nil then
        if definition.vertex == nil or definition.focus == nil then
          error("vertex and focus are both required")
        end
        if definition.directrix ~= nil or definition.line ~= nil or definition.foci ~= nil then
          error("vertex_focus cannot contain directrix or foci")
        end
        vertex = point_from_table(definition.vertex, "vertex")
        focus = point_from_table(definition.focus, "focus")
      else
        local summary = selection_inputs(model)
        require_exact_construction_selection(
          summary, 2, 0,
          "Select exactly two marks, with the vertex as primary."
        )
        if not summary.primary_point then error("The primary selection must be the vertex mark.") end
        vertex = summary.primary_point.point
        for _, record in ipairs(summary.points) do
          if record ~= summary.primary_point then focus = record.point end
        end
      end
      local coefficients, directrix = Advanced.parabola_from_vertex_focus(vertex, focus)
      definitions[1] = {
        vertex = vertex,
        focus = focus,
        directrix = directrix,
        coefficients = coefficients,
        default_extent = math.max(48, 6 * distance(vertex, focus)),
        source = "vertex_focus",
      }
    else
      error("unsupported parabola construction: " .. operation)
    end
    local styles, entries, records = construction_styles(model), {}, {}
    local requested_extent = options.extent
    if requested_extent ~= nil then
      requested_extent = positive_number_option(requested_extent, nil, "extent")
    end
    local padding = nonnegative_number_option(options.padding, 0, "padding")
    for _, definition in ipairs(definitions) do
      local focus, coefficients = definition.focus, definition.coefficients
      local properties = conic_properties(coefficients)
      local extent = requested_extent or (definition.default_extent + padding)
      if extent <= 0 then error("parabola extent must be positive") end
      local object, id = make_spline(
        parabola_spline(properties, extent, extent), styles.path
      ), next_conic_id()
      entries[#entries + 1] = {
        object = object,
        role = "curve",
        metadata = curve_metadata(
          object, id, "parabola", coefficients, definition.source, "curve"
        ),
      }
      records[#records + 1] = {
        coefficients = coefficients,
        properties = serializable_properties(properties),
        focus = point_record(focus),
        extent = extent,
      }
    end
    local group_value = M.aliased_value(
      options, "group_output", "group", "parabola options"
    )
    local group_output = bool_value(group_value, #entries > 1)
    local group_metadata = metadata_string({
      role = "group", kind = "parabolas", source = operation,
      trusted = "true", count = #entries,
    })
    local objects = register_creation(
      model,
      #entries == 1 and "create parabola" or "create parabolas",
      entries,
      active_layer(model),
      group_output,
      group_metadata
    )
    return success_result(model, operation, entries, objects, group_metadata, {
      kind = "parabolas",
      parabola_count = #entries,
      conics = records,
    })
  end)
end

R.create_conic = create_conic
R.create_ellipse_from_foci = create_ellipse_from_foci
R.create_ellipse = create_ellipse_from_foci
R.create_hyperbola = create_hyperbola
R.create_parabolas = create_parabolas
R.create_parabola = create_parabolas

----------------------------------------------------------------------
-- Conic inspection, features, and metadata revalidation
----------------------------------------------------------------------

local FEATURE_ALLOWED = {
  operation = true, definition = true, feature_input = true,
  coefficients = true, points = true, focus = true, directrix = true,
  point_on_conic = true, point = true, line = true,
  line_length = true, marks = true, labels = true,
  chord = true, focus_index = true, second_coefficients = true,
  arc_mode = true, replace_original = true, expected_kind = true,
  maximum_points = true, tolerance = true, max_segments = true,
  tangent = true, normal = true, create_guides = true, guides = true,
  axes = true, vertices = true, foci = true, directrices = true,
  asymptotes = true, latus_recta = true, auxiliary_circles = true,
  director_circle = true, general_equation = true, canonical_equation = true,
  parameters = true, label_position = true,
  group_output = true, group = true,
}
local FEATURE_NESTED_ALLOWED = {
  definition = {
    coefficients = true, points = true, focus = true,
    directrix = true, point_on_conic = true,
  },
  input = {
    point = true, points = true, line = true, second_coefficients = true,
    focus_index = true, label_position = true,
  },
}

local function conic_coefficients_from_definition(model, options)
  M.reject_nested_aliases(options,
    { "coefficients", "points", "focus", "directrix", "point_on_conic" },
    "conic feature options")
  local definition = definition_options(
    options, FEATURE_NESTED_ALLOWED.definition, "conic feature definition"
  )
  local explicit = definition.coefficients ~= nil or definition.points ~= nil
    or definition.focus ~= nil or definition.directrix ~= nil
    or definition.point_on_conic ~= nil
  if explicit then
    if definition.coefficients ~= nil then
      if definition.points ~= nil or definition.focus ~= nil
          or definition.directrix ~= nil or definition.point_on_conic ~= nil then
        error("conic definition cannot combine coefficients with another definition form")
      end
      return normalize_coefficients(definition.coefficients), false, "coefficients"
    end
    if definition.points ~= nil then
      if definition.focus ~= nil or definition.directrix ~= nil
          or definition.point_on_conic ~= nil then
        error("conic definition cannot combine points with focus-directrix fields")
      end
      return conic_coefficients_from_five_points(
        points_from_table(definition.points, 5, "definition.points")
      ), false, "five_points"
    end
    if definition.focus == nil or definition.directrix == nil
        or definition.point_on_conic == nil then
      error("focus, directrix, and point_on_conic are all required in definition")
    end
    return focus_directrix_conic_coefficients(
      definition.focus, definition.directrix, definition.point_on_conic
    ), false, "focus_directrix_point"
  end
  local selected = primary_conic_definition(model)
  return selected.coefficients, true, selected.metadata_status
end

local function selected_feature_point(model, definition_from_selection)
  local summary = selection_inputs(model)
  local expected_conics = definition_from_selection and 1 or 0
  if #summary.invalid ~= 0 or #summary.points ~= 1 or #summary.segments ~= 0
      or #summary.conic_entries ~= expected_conics
      or #summary.entries ~= 1 + expected_conics then
    error(definition_from_selection
      and "Select one primary conic and exactly one secondary mark."
      or "Select exactly one mark for the feature input.")
  end
  if definition_from_selection
      and (not summary.primary_entry
        or summary.primary_entry ~= summary.conic_entries[1]) then
    error("The conic must be the primary selection.")
  end
  return summary.points[1].point
end

local function selected_feature_line(model, definition_from_selection)
  local summary = selection_inputs(model)
  local expected_conics = definition_from_selection and 1 or 0
  if #summary.invalid ~= 0 or #summary.points ~= 0 or #summary.segments ~= 1
      or #summary.conic_entries ~= expected_conics
      or #summary.entries ~= 1 + expected_conics then
    error(definition_from_selection
      and "Select one primary conic and exactly one secondary segment."
      or "Select exactly one segment for the feature input.")
  end
  if definition_from_selection
      and (not summary.primary_entry
        or summary.primary_entry ~= summary.conic_entries[1]) then
    error("The conic must be the primary selection.")
  end
  return summary.segments[1].line
end

function R.single_conic_from_entry(entry, context)
  local definitions, errors = collect_conic_definitions(entry.object)
  if #errors > 0 then error(errors[1]) end
  local unique, selected = {}, nil
  for _, definition in ipairs(definitions) do
    local key = definition.id or coefficients_text(definition.coefficients)
    if not unique[key] then unique[key] = definition end
  end
  for _, definition in pairs(unique) do
    if selected then
      error((context or "selection") .. " contains more than one distinct conic")
    end
    selected = definition
  end
  if not selected then error((context or "selection") .. " is not a conic") end
  return selected
end

function R.selected_second_conic(model)
  local entries = selected_objects(model)
  if #entries ~= 2 then error("Select exactly two conics, with the first conic as primary.") end
  local primary, secondary
  for _, entry in ipairs(entries) do
    if entry.primary then primary = entry else secondary = entry end
  end
  if not primary or not secondary then
    error("The first conic must be the primary selection.")
  end
  R.single_conic_from_entry(primary, "primary selection")
  return R.single_conic_from_entry(secondary, "secondary selection")
end

function R.selected_feature_points(model, definition_from_selection, expected)
  local summary = selection_inputs(model)
  local expected_conics = definition_from_selection and 1 or 0
  if #summary.invalid ~= 0 or #summary.points ~= expected or #summary.segments ~= 0
      or #summary.conic_entries ~= expected_conics
      or #summary.entries ~= expected + expected_conics then
    error(definition_from_selection
      and ("Select one primary conic and exactly " .. tostring(expected)
        .. " secondary marks.")
      or ("Select exactly " .. tostring(expected) .. " marks for the feature input."))
  end
  if definition_from_selection
      and (not summary.primary_entry or summary.primary_entry ~= summary.conic_entries[1]) then
    error("The conic must be the primary selection.")
  end
  local points = {}
  for index, record in ipairs(summary.points) do points[index] = record.point end
  return points
end

local function feature_input_options(options)
  if options.feature_input ~= nil and (options.point ~= nil or options.line ~= nil
      or options.second_coefficients ~= nil or options.focus_index ~= nil
      or options.label_position ~= nil) then
    error("conic feature options cannot mix nested 'feature_input' with legacy input fields")
  end
  if options.feature_input == nil then return options end
  if type(options.feature_input) ~= "table" then error("feature_input must be a table") end
  validate_keys(options.feature_input, FEATURE_NESTED_ALLOWED.input, "feature input")
  return options.feature_input
end

local function computed_result(model, operation, status, result, message)
  if message and model and model.ui and type(model.ui.explain) == "function" then
    model.ui:explain(message)
  end
  return {
    created = false,
    status = status,
    operation = operation,
    element_count = 0,
    object_count = #model:page(),
    metadata = nil,
    result = result,
    message = message,
  }
end

local function add_property_guides(entries, properties, options, styles, id)
  local marks = bool_value(options.marks, true)
  local labels = bool_value(options.labels, false)
  local line_length
  local function guide_length()
    if line_length == nil then
      line_length = positive_number_option(options.line_length, 192, "line_length")
    end
    return line_length
  end
  local function add_point(point, label_text, role)
    if marks then
      local object = make_mark(point, styles)
      entries[#entries + 1] = {
        object = object,
        role = role,
        metadata = auxiliary_metadata(id, role, properties.kind, "properties"),
      }
    end
    if labels then
      local object = make_text("$" .. label_text .. "$", add(point, V(4, 4)), styles)
      entries[#entries + 1] = {
        object = object,
        role = "label",
        metadata = auxiliary_metadata(id, "label", properties.kind, "properties"),
      }
    end
  end

  if properties.degenerate then
    for _, line in ipairs(properties.lines or {}) do
      add_line_object(entries, line, guide_length(), styles.path, "degenerate")
      entries[#entries].metadata = auxiliary_metadata(
        id, "degenerate", "degenerate", "properties"
      )
    end
    for index, point in ipairs(properties.points or {}) do
      add_point(point, "D_" .. tostring(index), "degenerate")
    end
    return
  end

  if properties.center then add_point(properties.center, "C", "center") end
  if bool_value(options.vertices, true) then
    for index, point in ipairs(properties.vertices or {}) do
      add_point(point, "V_" .. tostring(index), "vertex")
    end
  end
  -- A circle's two focal records coincide with its center.  Drawing all
  -- three marks and labels would stack C, F_1, and F_2 at the same point.
  if bool_value(options.foci, true) and properties.kind ~= "circle" then
    for index, point in ipairs(properties.foci or {}) do
      add_point(point, "F_" .. tostring(index), "focus")
    end
  end
  if bool_value(options.axes, true) then
    if properties.center and properties.vertices and #properties.vertices == 2 then
      entries[#entries + 1] = {
        object = make_segment(properties.vertices[1], properties.vertices[2], styles.dotted),
        role = "axis",
        metadata = auxiliary_metadata(id, "axis", properties.kind, "properties"),
      }
    end
    if properties.center and properties.co_vertices and #properties.co_vertices == 2 then
      entries[#entries + 1] = {
        object = make_segment(properties.co_vertices[1], properties.co_vertices[2], styles.dotted),
        role = "axis",
        metadata = auxiliary_metadata(id, "axis", properties.kind, "properties"),
      }
    elseif properties.kind == "hyperbola" then
      local p1 = add(properties.center, scale(properties.v, properties.b))
      local p2 = sub(properties.center, scale(properties.v, properties.b))
      entries[#entries + 1] = {
        object = make_segment(p1, p2, styles.dotted),
        role = "axis",
        metadata = auxiliary_metadata(id, "axis", properties.kind, "properties"),
      }
    elseif properties.kind == "parabola" then
      add_line_object(entries, {
        point = properties.vertex,
        direction = properties.axis_direction,
      }, guide_length(), styles.dotted, "axis")
      entries[#entries].metadata = auxiliary_metadata(
        id, "axis", properties.kind, "properties"
      )
    end
  end
  if bool_value(options.directrices, true) then
    for _, line in ipairs(properties.directrices or {}) do
      add_line_object(entries, line, guide_length(), styles.dashed, "directrix")
      entries[#entries].metadata = auxiliary_metadata(
        id, "directrix", properties.kind, "properties"
      )
    end
  end
  if bool_value(options.asymptotes, true) then
    for _, line in ipairs(properties.asymptotes or {}) do
      add_line_object(entries, line, guide_length(), styles.dashed, "asymptote")
      entries[#entries].metadata = auxiliary_metadata(
        id, "asymptote", properties.kind, "properties"
      )
    end
  end
  if bool_value(options.latus_recta, false) then
    for _, record in ipairs(properties.latus_recta or {}) do
      entries[#entries + 1] = {
        object = make_segment(record.endpoints[1], record.endpoints[2], styles.dotted),
        role = "latus_rectum",
        metadata = auxiliary_metadata(
          id, "latus_rectum", properties.kind, "properties"
        ),
      }
    end
  end
  if bool_value(options.auxiliary_circles, false) then
    for _, circle in ipairs(properties.auxiliary_circles or {}) do
      local object = make_ellipse({
        center = circle.center,
        axis1 = V(circle.radius, 0),
        axis2 = V(0, circle.radius),
      }, styles.dotted)
      entries[#entries + 1] = {
        object = object,
        role = "auxiliary_circle",
        metadata = auxiliary_metadata(
          id, "auxiliary_circle", properties.kind, "properties"
        ),
      }
    end
  end
  if bool_value(options.director_circle, false) and properties.director_circle then
    local circle = properties.director_circle
    local object = make_ellipse({
      center = circle.center,
      axis1 = V(circle.radius, 0),
      axis2 = V(0, circle.radius),
    }, styles.dashed)
    entries[#entries + 1] = {
      object = object,
      role = "director_circle",
      metadata = auxiliary_metadata(
        id, "director_circle", properties.kind, "properties"
      ),
    }
  end
  local equations = Advanced.conic_equation_strings(properties.coefficients)
  local equation_labels = {}
  if bool_value(options.general_equation, false) then
    equation_labels[#equation_labels + 1] = equations.general
  end
  if bool_value(options.canonical_equation, false) and equations.canonical then
    equation_labels[#equation_labels + 1] = equations.canonical
  end
  if bool_value(options.parameters, false) and equations.parameters then
    equation_labels[#equation_labels + 1] = equations.parameters
  end
  local label_position = options.label_position
      and point_from_table(options.label_position, "label_position")
    or add(properties.center or properties.vertex, V(16, 16))
  for index, text in ipairs(equation_labels) do
    local object = make_text(text, add(label_position, V(0, -14 * (index - 1))), styles)
    entries[#entries + 1] = {
      object = object,
      role = "equation",
      metadata = auxiliary_metadata(id, "equation", properties.kind, "properties"),
    }
  end
end

local function create_conic_features(model, raw_options)
  return creator_call(model, "Cannot create conic features", function()
    local options = options_table(raw_options)
    validate_keys(options, FEATURE_ALLOWED, "conic feature options")
    local operation = normalized_name(options.operation or "tangent_normal")
    if operation == "fit_replace_path" or operation == "replace_with_conic" then
      if options.definition ~= nil or options.coefficients ~= nil or options.points ~= nil
          or options.focus ~= nil or options.directrix ~= nil
          or options.point_on_conic ~= nil or options.feature_input ~= nil then
        error("fit_replace_path uses only the single selected path as its definition")
      end
      local selected = selected_objects(model)
      if #selected ~= 1 or not selected[1].primary
          or object_type(selected[1].object) ~= "path" then
        error("Select exactly one path as the primary object to fit and replace.")
      end
      local samples = R.path_world_samples(selected[1].object)
      local maximum_points = positive_integer_option(
        options.maximum_points, 512, "maximum_points", 4096, 5
      )
      if #samples > maximum_points then
        error("selected path produced more samples than maximum_points")
      end
      local coefficients, diagnostics = Advanced.conic_coefficients_from_points(samples, {
        allow_degenerate = false,
        expected_kind = options.expected_kind,
        maximum_points = maximum_points,
      })
      if diagnostics.rms_residual > 5e-3 or diagnostics.maximum_residual > 2e-2 then
        error("selected path is too far from a conic to replace reliably")
      end
      local styles = construction_styles(model)
      local entries, properties, id = render_conic_entries(
        coefficients, options, styles, "fit_replace_path", samples
      )
      local metadata = metadata_string({
        role = "group", id = id, kind = properties.kind,
        source = operation, trusted = "true", count = #entries,
      })
      local objects = R.register_replacement(
        model, "fit and replace path with conic", selected[1].index, entries, metadata
      )
      return success_result(model, operation, entries, objects, metadata, {
        type = "fitted-replacement",
        coefficients = coefficients,
        fit = diagnostics,
        properties = serializable_properties(properties),
        replaced_index = selected[1].index,
      })
    end
    local coefficients, definition_from_selection, definition_source =
      conic_coefficients_from_definition(model, options)
    local feature_input = feature_input_options(options)
    local styles, entries, result = construction_styles(model), {}, nil
    local id = next_conic_id()
    local replacement_index

    if operation == "tangent" or operation == "normal" or operation == "tangent_normal" then
      local point = feature_input.point
        and point_from_table(feature_input.point, "feature_input.point")
        or selected_feature_point(model, definition_from_selection)
      local lines = conic_tangent_normal(coefficients, point)
      local create_tangent = operation ~= "normal"
      local create_normal = operation ~= "tangent"
      if operation == "tangent_normal" then
        create_tangent = bool_value(options.tangent, true)
        create_normal = bool_value(options.normal, true)
        if not create_tangent and not create_normal then
          error("tangent_normal must create at least the tangent or the normal")
        end
      elseif operation == "tangent" and options.tangent ~= nil
          and not bool_value(options.tangent, true) then
        error("the tangent operation cannot disable its tangent")
      elseif operation == "normal" and options.normal ~= nil
          and not bool_value(options.normal, true) then
        error("the normal operation cannot disable its normal")
      end
      local line_length = positive_number_option(options.line_length, 192, "line_length")
      local line_result = {}
      if create_tangent then
        add_line_object(entries, lines.tangent, line_length, styles.path, "tangent")
        entries[#entries].metadata = auxiliary_metadata(
          id, "tangent", "conic-feature", definition_source
        )
        line_result.tangent = serializable_line(lines.tangent)
      end
      if create_normal then
        add_line_object(entries, lines.normal, line_length, styles.dashed, "normal")
        entries[#entries].metadata = auxiliary_metadata(
          id, "normal", "conic-feature", definition_source
        )
        line_result.normal = serializable_line(lines.normal)
      end
      if bool_value(options.marks, true) then
        entries[#entries + 1] = {
          object = make_mark(point, styles),
          role = "mark",
          metadata = auxiliary_metadata(id, "mark", "conic-feature", definition_source),
        }
      end
      result = {
        type = "tangent-normal",
        point = point_record(point),
        lines = line_result,
        coefficients = coefficients,
      }
    elseif operation == "polar" or operation == "pole_polar" then
      local point = feature_input.point
        and point_from_table(feature_input.point, "feature_input.point")
        or selected_feature_point(model, definition_from_selection)
      local polar = conic_polar_line(coefficients, point)
      local line_length = positive_number_option(options.line_length, 192, "line_length")
      add_line_object(entries, polar, line_length, styles.path, "polar")
      entries[#entries].metadata = auxiliary_metadata(
        id, "polar", "conic-feature", definition_source
      )
      if bool_value(options.marks, true) then
        entries[#entries + 1] = {
          object = make_mark(point, styles),
          role = "mark",
          metadata = auxiliary_metadata(id, "mark", "conic-feature", definition_source),
        }
      end
      result = {
        type = "line",
        line = serializable_line(polar),
        point = point_record(point),
        coefficients = coefficients,
      }
    elseif operation == "tangents_from_point" or operation == "external_tangents" then
      local point = feature_input.point
        and point_from_table(feature_input.point, "feature_input.point")
        or selected_feature_point(model, definition_from_selection)
      local tangent_result = Advanced.tangents_from_point(coefficients, point)
      if tangent_result.count == 0 then
        return computed_result(model, operation, "empty", {
          type = "tangents-from-point",
          tangent_count = 0,
          point = point_record(point),
          coefficients = coefficients,
        }, "The point has no real tangent lines to this conic.")
      end
      local line_length = positive_number_option(options.line_length, 192, "line_length")
      for _, line in ipairs(tangent_result.tangents) do
        add_line_object(entries, line, line_length, styles.path, "tangent")
        entries[#entries].metadata = auxiliary_metadata(
          id, "tangent", "conic-feature", definition_source
        )
      end
      if tangent_result.count == 2 and bool_value(options.chord, true) then
        add_line_object(
          entries, tangent_result.chord_of_contact, line_length, styles.dashed, "chord"
        )
        entries[#entries].metadata = auxiliary_metadata(
          id, "chord", "conic-feature", definition_source
        )
      end
      if bool_value(options.marks, true) then
        for _, contact in ipairs(tangent_result.contact_points) do
          entries[#entries + 1] = {
            object = make_mark(contact, styles),
            role = "intersection",
            metadata = auxiliary_metadata(
              id, "intersection", "conic-feature", definition_source
            ),
          }
        end
      end
      result = {
        type = "tangents-from-point",
        tangent_count = tangent_result.count,
        point = point_record(point),
        contact_points = point_records(tangent_result.contact_points),
        tangents = {},
        chord_of_contact = tangent_result.count == 2
            and serializable_line(tangent_result.chord_of_contact) or nil,
        coefficients = coefficients,
      }
      for index, line in ipairs(tangent_result.tangents) do
        result.tangents[index] = serializable_line(line)
      end
    elseif operation == "pole" or operation == "pole_of_line" then
      local line = feature_input.line
        and line_from_table(feature_input.line, "feature_input.line")
        or selected_feature_line(model, definition_from_selection)
      local pole = Advanced.conic_pole(coefficients, line)
      if not pole.finite then
        return computed_result(model, operation, "at_infinity", {
          type = "pole",
          finite = false,
          direction = point_record(pole.direction),
          line = serializable_line(line),
          coefficients = coefficients,
        }, "The pole of this line is a point at infinity.")
      end
      if bool_value(options.marks, true) then
        entries[#entries + 1] = {
          object = make_mark(pole.point, styles),
          role = "pole",
          metadata = auxiliary_metadata(id, "pole", "conic-feature", definition_source),
        }
      end
      if bool_value(options.labels, false) then
        entries[#entries + 1] = {
          object = make_text("$P$", add(pole.point, V(4, 4)), styles),
          role = "label",
          metadata = auxiliary_metadata(id, "label", "conic-feature", definition_source),
        }
      end
      if #entries == 0 then
        return computed_result(model, operation, "computed", {
          type = "pole", finite = true, point = point_record(pole.point),
          line = serializable_line(line), coefficients = coefficients,
        }, "Pole computed without creating a mark or label.")
      end
      result = {
        type = "pole",
        finite = true,
        point = point_record(pole.point),
        line = serializable_line(line),
        coefficients = coefficients,
      }
    elseif operation == "focal_chord" then
      local point = feature_input.point
        and point_from_table(feature_input.point, "feature_input.point")
        or selected_feature_point(model, definition_from_selection)
      local focus_index = feature_input.focus_index or options.focus_index
      local chord = Advanced.focal_chord(coefficients, point, focus_index)
      if #chord.endpoints == 2 then
        entries[#entries + 1] = {
          object = make_segment(chord.endpoints[1], chord.endpoints[2], styles.path),
          role = "chord",
          metadata = auxiliary_metadata(id, "chord", "conic-feature", definition_source),
        }
      end
      if bool_value(options.marks, true) then
        for _, endpoint in ipairs(chord.endpoints) do
          entries[#entries + 1] = {
            object = make_mark(endpoint, styles),
            role = "intersection",
            metadata = auxiliary_metadata(
              id, "intersection", "conic-feature", definition_source
            ),
          }
        end
      end
      if #entries == 0 then
        return computed_result(model, operation, "computed", {
          type = "focal-chord", focus = point_record(chord.focus),
          endpoints = point_records(chord.endpoints), coefficients = coefficients,
        }, "Focal chord computed without creating visible objects.")
      end
      result = {
        type = "focal-chord",
        focus = point_record(chord.focus),
        focus_index = chord.focus_index,
        endpoints = point_records(chord.endpoints),
        coefficients = coefficients,
      }
    elseif operation == "line_intersections" or operation == "intersections" then
      local line = feature_input.line
        and line_from_table(feature_input.line, "feature_input.line")
        or selected_feature_line(model, definition_from_selection)
      local intersections = conic_line_intersections(coefficients, line)
      if intersections.infinite then
        return computed_result(model, operation, "infinite", {
          type = "points",
          intersection_count = math.huge,
          infinite = true,
          points = {},
          coefficients = coefficients,
        }, "The line is contained in the conic; there are infinitely many intersections.")
      end
      if #intersections == 0 then
        return computed_result(model, operation, "empty", {
          type = "points",
          intersection_count = 0,
          points = {},
          coefficients = coefficients,
        }, "The line has no real intersections with the conic.")
      end
      local records = point_records(intersections)
      local marks = bool_value(options.marks, true)
      if not marks then
        return computed_result(model, operation, "computed", {
          type = "points",
          intersection_count = #intersections,
          points = records,
          coefficients = coefficients,
        }, "Intersections computed without creating marks.")
      end
      for index, point in ipairs(intersections) do
        entries[#entries + 1] = {
          object = make_mark(point, styles),
          role = "intersection",
          metadata = auxiliary_metadata(
            id, "intersection", "conic-feature", definition_source
          ),
        }
        if bool_value(options.labels, false) then
          entries[#entries + 1] = {
            object = make_text("$X_" .. tostring(index) .. "$", add(point, V(4, 4)), styles),
            role = "label",
            metadata = auxiliary_metadata(
              id, "label", "conic-feature", definition_source
            ),
          }
        end
      end
      result = {
        type = "points",
        intersection_count = #intersections,
        points = records,
        coefficients = coefficients,
      }
    elseif operation == "conic_intersections" or operation == "conic_conic_intersections" then
      local second_coefficients
      if feature_input.second_coefficients ~= nil then
        second_coefficients = normalize_coefficients(feature_input.second_coefficients)
      elseif definition_from_selection then
        second_coefficients = R.selected_second_conic(model).coefficients
      else
        error("feature_input.second_coefficients is required with an explicit first conic")
      end
      local intersections = Advanced.conic_conic_intersections(
        coefficients, second_coefficients
      )
      if intersections.infinite then
        return computed_result(model, operation, "infinite", {
          type = "points", intersection_count = math.huge, infinite = true,
          coincident = true, points = {}, coefficients = coefficients,
          second_coefficients = second_coefficients,
        }, "The two conics coincide and have infinitely many intersections.")
      end
      if #intersections == 0 then
        return computed_result(model, operation, "empty", {
          type = "points", intersection_count = 0, points = {},
          coefficients = coefficients, second_coefficients = second_coefficients,
        }, "The two conics have no real intersections.")
      end
      local records = point_records(intersections)
      if not bool_value(options.marks, true) then
        return computed_result(model, operation, "computed", {
          type = "points", intersection_count = #intersections,
          points = records, coefficients = coefficients,
          second_coefficients = second_coefficients,
        }, "Conic intersections computed without creating marks.")
      end
      for index, point in ipairs(intersections) do
        entries[#entries + 1] = {
          object = make_mark(point, styles),
          role = "intersection",
          metadata = auxiliary_metadata(
            id, "intersection", "conic-feature", definition_source
          ),
        }
        if bool_value(options.labels, false) then
          entries[#entries + 1] = {
            object = make_text("$X_" .. tostring(index) .. "$", add(point, V(4, 4)), styles),
            role = "label",
            metadata = auxiliary_metadata(id, "label", "conic-feature", definition_source),
          }
        end
      end
      result = {
        type = "points", intersection_count = #intersections,
        points = records, coefficients = coefficients,
        second_coefficients = second_coefficients,
      }
    elseif operation == "conic_arc" or operation == "trim" or operation == "crop" then
      local points
      if feature_input.points ~= nil then
        points = points_from_table(feature_input.points, 2, "feature_input.points")
      else
        points = R.selected_feature_points(model, definition_from_selection, 2)
      end
      local definition = Advanced.conic_arc_definition(
        coefficients, points[1], points[2], options.arc_mode
      )
      local object = R.make_conic_arc(definition, styles.path, options)
      entries[1] = {
        object = object,
        role = "curve",
        metadata = curve_metadata(
          object, id, definition.kind, coefficients, "conic_arc", "curve"
        ),
      }
      if bool_value(options.replace_original, true) then
        if not definition_from_selection then
          error("replace_original requires a selected primary conic")
        end
        replacement_index = model:page():primarySelection()
      end
      result = {
        type = "conic-arc",
        kind = definition.kind,
        first_point = point_record(points[1]),
        second_point = point_record(points[2]),
        arc_mode = normalized_name(options.arc_mode or "shorter"),
        coefficients = coefficients,
        replaced = replacement_index ~= nil,
      }
    elseif operation == "properties" or operation == "guides" then
      local properties = conic_properties(coefficients)
      local create_guides = bool_value(M.aliased_value(
        options, "create_guides", "guides", "conic feature options"
      ), operation == "guides")
      if not create_guides then
        return computed_result(model, operation, "inspected", {
          coefficients = coefficients,
          properties = serializable_properties(properties),
        }, "Conic properties computed.")
      end
      local guide_options = clone_table(options)
      if feature_input.label_position ~= nil then
        guide_options.label_position = feature_input.label_position
      end
      add_property_guides(entries, properties, guide_options, styles, id)
      if #entries == 0 then
        return computed_result(model, operation, "inspected", {
          coefficients = coefficients,
          properties = serializable_properties(properties),
        }, "Conic properties computed; no guide was selected for creation.")
      end
      result = {
        type = "properties",
        coefficients = coefficients,
        properties = serializable_properties(properties),
      }
    else
      error("unsupported conic feature operation: " .. operation)
    end

    local group_value = M.aliased_value(
      options, "group_output", "group", "conic feature options"
    )
    local group_output = bool_value(group_value, #entries > 1)
    local metadata = metadata_string({
      role = "group", id = id, kind = "conic-features",
      source = operation, trusted = "true", count = #entries,
    })
    local objects
    if replacement_index then
      objects = R.register_replacement(
        model, "trim conic to arc", replacement_index, entries, metadata
      )
    else
      objects = register_creation(
        model, "create conic features", entries, active_layer(model), group_output, metadata
      )
    end
    return success_result(model, operation, entries, objects, metadata, result)
  end)
end

local function inspect_conic(model, raw_options)
  return creator_call(model, "Cannot inspect conic", function()
    local options = options_table(raw_options)
    validate_keys(options, {
      definition = true, coefficients = true, points = true, focus = true,
      directrix = true, point_on_conic = true,
    }, "inspect options")
    local coefficients, _, source = conic_coefficients_from_definition(model, options)
    local properties = serializable_properties(conic_properties(coefficients))
    local message
    if properties.degenerate then
      message = "Conic: degenerate (" .. tostring(properties.subtype or "unclassified") .. ")"
    else
      message = "Conic: " .. properties.kind
        .. "; eccentricity = " .. format_number(properties.eccentricity, 8)
    end
    if model.ui and type(model.ui.explain) == "function" then model.ui:explain(message) end
    return {
      created = false,
      status = "inspected",
      operation = "inspect",
      element_count = 0,
      object_count = #model:page(),
      metadata = nil,
      result = {
        source = source,
        coefficients = coefficients,
        properties = properties,
      },
      message = message,
    }
  end)
end

local function bezier_point(control, parameter)
  local work = {}
  for index, point in ipairs(control) do work[index] = point end
  for level = #work - 1, 1, -1 do
    for index = 1, level do
      work[index] = lerp(work[index], work[index + 1], parameter)
    end
  end
  return work[1]
end

function R.path_world_samples(object, parent_matrix)
  local shape = path_shape(object)
  if not shape then return {} end
  local matrix = (parent_matrix or ipe.Matrix()) * object_matrix(object)
  local samples = {}
  local function append(point)
    local transformed = matrix * point
    if finite_number(transformed.x) and finite_number(transformed.y) then
      if #samples == 0 or distance(samples[#samples], transformed)
          > scaled_tolerance(math.max(vector_scale(samples[#samples], transformed), MIN_NORMAL), 4096) then
        samples[#samples + 1] = transformed
      end
    end
  end
  for _, component in ipairs(shape) do
    if component.type == "ellipse" and component[1] then
      for index = 0, 15 do
        local angle = 2 * math.pi * index / 16
        append(component[1] * V(math.cos(angle), math.sin(angle)))
      end
    elseif component.type == "curve" then
      for _, segment in ipairs(component) do
        if segment.type == "segment" then
          append(segment[1])
          append(segment[2])
        elseif segment.type == "spline" and #segment >= 3 then
          local control = {}
          for index = 1, #segment do control[index] = segment[index] end
          for _, parameter in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
            append(bezier_point(control, parameter))
          end
        elseif segment.type == "arc" and segment.arc then
          local ok_angles, alpha, beta = pcall(function() return segment.arc:angles() end)
          local ok_matrix, arc_matrix = pcall(function() return segment.arc:matrix() end)
          if ok_angles and ok_matrix and arc_matrix then
            for index = 0, 12 do
              local angle = alpha + (beta - alpha) * index / 12
              append(arc_matrix * V(math.cos(angle), math.sin(angle)))
            end
          else
            append(segment[1])
            append(segment[2])
          end
        end
      end
    end
  end
  return samples
end

local function raw_conics_fields(object)
  local tokens = split_metadata(object_custom_value(object))
  for index, token in ipairs(tokens) do
    if token == "conics:v1" then return metadata_fields(tokens, index) end
  end
  return nil
end

local function without_conics_metadata(custom)
  local tokens, result, skipping = split_metadata(custom), {}, false
  for _, token in ipairs(tokens) do
    local namespace = token:find(":", 1, true) and not token:find("=", 1, true)
    if token:match("^conics:v%d+$") then
      skipping = true
    elseif skipping and namespace then
      skipping = false
      result[#result + 1] = token
    elseif not skipping then
      result[#result + 1] = token
    end
  end
  return table.concat(result, ";")
end

local function replace_conics_metadata(object, metadata)
  local remaining = without_conics_metadata(object_custom_value(object))
  set_object_custom_value(object, remaining ~= "" and (remaining .. ";" .. metadata) or metadata)
end

local function inverse_matrix(matrix)
  local a, c, b, d, tx, ty = unpack(matrix_values(matrix))
  local determinant = a * d - b * c
  local scale_value = math.max(math.abs(a), math.abs(b), math.abs(c), math.abs(d))
  if scale_value == 0 or near_zero(determinant, scale_value * scale_value, 8192) then
    error("conic object matrix must be nonsingular")
  end
  return ipe.Matrix(
    d / determinant,
    -c / determinant,
    -b / determinant,
    a / determinant,
    (b * ty - d * tx) / determinant,
    (c * tx - a * ty) / determinant
  )
end

function R.fitted_coefficients_from_samples(samples)
  if #samples < 5 then error("at least five sampled curve points are required") end
  local coefficients, diagnostics = Advanced.conic_coefficients_from_points(samples, {
    allow_degenerate = false,
    maximum_points = 4096,
  })
  if diagnostics.rms_residual > 5e-3 or diagnostics.maximum_residual > 2e-2 then
    error("edited path is too far from a conic to revalidate reliably")
  end
  return coefficients, diagnostics.rms_residual, diagnostics
end

local function selected_revalidation_paths(model)
  local page, primary = model:page(), model:page():primarySelection()
  if not primary then error("Select a conic as the primary object.") end
  local root = page[primary]
  if not root then error("Primary conic object is unavailable.") end
  local result = {}
  local function visit(object, parent_matrix)
    local matrix = parent_matrix * object_matrix(object)
    if object_type(object) == "group" then
      for _, child in ipairs(object_elements(object) or {}) do visit(child, matrix) end
    elseif object_type(object) == "path" then
      local fields = raw_conics_fields(object)
      if not fields or fields.role == "curve" or fields.role == "branch" then
        result[#result + 1] = {
          object = object,
          matrix = matrix,
          fields = fields or {},
          samples = R.path_world_samples(object, parent_matrix),
        }
      end
    end
  end
  visit(root, ipe.Matrix())
  if #result == 0 then error("Primary selection contains no conic curve to revalidate.") end
  return result
end

local function revalidate_metadata(model, raw_options)
  return creator_call(model, "Cannot revalidate conic metadata", function()
    local options = options_table(raw_options)
    validate_keys(options, {}, "revalidation options")
    local paths, groups = selected_revalidation_paths(model), {}
    for _, record in ipairs(paths) do
      local id = record.fields.id or next_conic_id()
      if not groups[id] then groups[id] = {} end
      groups[id][#groups[id] + 1] = record
    end
    local changes, diagnostics = {}, {}
    for id, records in pairs(groups) do
      local samples = {}
      for _, record in ipairs(records) do
        for _, point in ipairs(record.samples) do samples[#samples + 1] = point end
      end
      local coefficients, residual = R.fitted_coefficients_from_samples(samples)
      local kind = classify_conic(coefficients).kind
      diagnostics[#diagnostics + 1] = {
        id = id, kind = kind, residual = residual, path_count = #records,
      }
      for _, record in ipairs(records) do
        local local_coefficients = transformed_conic_coefficients(
          coefficients, inverse_matrix(record.matrix)
        )
        local source = record.fields.source or "revalidated"
        local metadata = curve_metadata(
          record.object, id, kind, local_coefficients, source,
          record.fields.role == "branch" and "branch" or "curve"
        )
        local old_custom = object_custom_value(record.object)
        local remaining = without_conics_metadata(old_custom)
        local new_custom = remaining ~= "" and (remaining .. ";" .. metadata) or metadata
        changes[#changes + 1] = {
          object = record.object,
          old_custom = old_custom,
          new_custom = new_custom,
        }
      end
    end
    local transaction = {
      label = "revalidate conic metadata",
      pno = model.pno,
      vno = model.vno,
      changes = changes,
    }
    transaction.undo = function(record)
      for _, change in ipairs(record.changes) do
        set_object_custom_value(change.object, change.old_custom)
      end
    end
    transaction.redo = function(record)
      for _, change in ipairs(record.changes) do
        set_object_custom_value(change.object, change.new_custom)
      end
    end
    model:register(transaction)
    if model.ui and type(model.ui.explain) == "function" then
      model.ui:explain("Conic metadata revalidated.")
    end
    return {
      created = false,
      status = "updated",
      operation = "revalidate_metadata",
      element_count = 0,
      object_count = #model:page(),
      metadata = "conics:v1",
      result = {
        updated_object_count = #changes,
        conic_count = #diagnostics,
        conics = diagnostics,
      },
    }
  end)
end

R.create_conic_features = create_conic_features
R.inspect_conic = inspect_conic
R.revalidate_metadata = revalidate_metadata

----------------------------------------------------------------------
-- Live and manual previews
----------------------------------------------------------------------

local P = (function()
local exports = {}

local function preview_object_position(object)
  local ok, position = pcall(function() return object:position() end)
  if ok and position then return position end
  return type(object) == "table" and (object.position_value or object.position) or nil
end

local function append_shapes(target, shapes)
  for _, shape in ipairs(shapes or {}) do target[#target + 1] = shape end
end

local function clone_preview_value(value)
  if type(value) ~= "table" then return value end
  local cloned = {}
  for key, item in pairs(value) do
    cloned[clone_preview_value(key)] = clone_preview_value(item)
  end
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
    { type = "curve", closed = false;
      { type = "segment"; V(point.x - size, point.y), V(point.x + size, point.y) } },
    { type = "curve", closed = false;
      { type = "segment"; V(point.x, point.y - size), V(point.x, point.y + size) } },
  }
end

local function label_preview_shape(point)
  local left, bottom = point.x + 4, point.y + 2
  local right, top = left + 12, bottom + 8
  return {
    type = "curve",
    closed = true,
    { type = "segment"; V(left, bottom), V(right, bottom) },
    { type = "segment"; V(right, bottom), V(right, top) },
    { type = "segment"; V(right, top), V(left, top) },
    { type = "segment"; V(left, top), V(left, bottom) },
  }
end

local function preview_bbox_shapes(object, matrix)
  if type(ipe.Rect) ~= "function" then return {} end
  local rect = ipe.Rect()
  local ok = pcall(function() object:addToBBox(rect, ipe.Matrix(), false) end)
  if not ok or rect:isEmpty() then return {} end
  local bottom_left, top_right = rect:bottomLeft(), rect:topRight()
  local points = {
    bottom_left,
    V(top_right.x, bottom_left.y),
    top_right,
    V(bottom_left.x, top_right.y),
  }
  for index, point in ipairs(points) do points[index] = matrix * point end
  return { {
    type = "curve",
    closed = true,
    { type = "segment"; points[1], points[2] },
    { type = "segment"; points[2], points[3] },
    { type = "segment"; points[3], points[4] },
    { type = "segment"; points[4], points[1] },
  } }
end

local function object_preview_shapes(object, parent_matrix)
  parent_matrix = parent_matrix or ipe.Matrix()
  local kind, matrix = object_type(object), parent_matrix * object_matrix(object)
  if kind == "path" then
    local shape = path_shape(object)
    return shape and transform_preview_shapes(matrix, shape) or {}
  elseif kind == "group" then
    local shapes = {}
    for _, child in ipairs(object_elements(object) or {}) do
      append_shapes(shapes, object_preview_shapes(child, matrix))
    end
    return shapes
  elseif kind == "reference" then
    local position = preview_object_position(object)
    return position and point_preview_shapes(matrix * position) or {}
  elseif kind == "text" then
    local position = preview_object_position(object)
    return position and { label_preview_shape(matrix * position) } or {}
  end
  return preview_bbox_shapes(object, parent_matrix)
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
  function wrapper:active(vno)
    local ok, value = pcall(function() return page:active(vno) end)
    return ok and value or "alpha"
  end
  function wrapper:visible(vno, index)
    local ok, value = pcall(function() return page:visible(vno, index) end)
    return not ok or value
  end
  function wrapper:primarySelection()
    local ok, value = pcall(function() return page:primarySelection() end)
    return ok and value or nil
  end
  function wrapper:objects()
    local ok, iterator, state, initial = pcall(function() return page:objects() end)
    if ok and iterator then return iterator, state, initial end
    return function() return nil end
  end
  setmetatable(wrapper, {
    __index = function(_, key)
      if type(key) == "number" then
        local ok, value = pcall(function() return page[key] end)
        return ok and value or nil
      end
      return rawget(wrapper, key) or page[key]
    end,
    __len = function()
      local ok, count = pcall(function() return #page end)
      return ok and count or 0
    end,
  })
  return wrapper
end

local function preview_capture_model(model)
  local captured = {}
  local preview_model = {
    pno = model and model.pno or 1,
    vno = model and model.vno or 1,
    attributes = model and model.attributes or {},
    captured_objects = captured,
    _conics_preview = true,
  }
  function preview_model:page()
    local ok, page = pcall(function() return model:page() end)
    return ok and preview_page(page) or default_preview_page()
  end
  function preview_model:register(record)
    if type(record.objects) == "table" then
      for _, object in ipairs(record.objects) do captured[#captured + 1] = object end
    elseif record.object then
      captured[#captured + 1] = record.object
    elseif record.redo then
      local document = { [self.pno] = self:page() }
      record:redo(document)
    end
  end
  function preview_model:warning(title, message)
    error(tostring(title or "Preview") .. ": " .. tostring(message or "failed"))
  end
  return preview_model
end

local PREVIEW_CREATORS = {
  conic = create_conic,
  conic_construct = create_conic,
  ellipse_from_foci = create_ellipse_from_foci,
  ellipse = create_ellipse_from_foci,
  hyperbola = create_hyperbola,
  make_parabolas = create_parabolas,
  parabolas = create_parabolas,
  parabola = create_parabolas,
  conic_features = create_conic_features,
}

local function action_options(action, options)
  action = normalized_name(action)
  options = options_table(options)
  local cloned = {}
  for key, value in pairs(options) do cloned[key] = value end
  return cloned
end

local function preview_shape_data(model, action, options)
  action = normalized_name(action)
  local creator = PREVIEW_CREATORS[action]
  if not creator then error("unsupported Conics preview action: " .. tostring(action)) end
  local preview_model = preview_capture_model(model)
  local result = creator(preview_model, action_options(action, options))
  if type(result) ~= "table" or result.created ~= true then
    error(clean_error_message(result and (result.error or result.message)
      or "preview produced no construction"))
  end
  local shapes = {}
  for _, object in ipairs(preview_model.captured_objects) do
    append_shapes(shapes, object_preview_shapes(object))
  end
  if #shapes == 0 then error("preview produced no visible shapes") end
  return {
    action = action,
    created = true,
    shapes = shapes,
    shape_count = #shapes,
    captured_count = #preview_model.captured_objects,
    metadata = result.metadata,
    result = result,
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
  if type(value) ~= "table" or depth > 4 then
    parts[#parts + 1] = prefix .. "=" .. tostring(value)
    return
  end
  for index, item in ipairs(value) do
    signature_value(parts, prefix .. "[" .. tostring(index) .. "]", item, depth + 1)
  end
  local keys = {}
  for key, _ in pairs(value) do if type(key) ~= "number" then keys[#keys + 1] = key end end
  table.sort(keys)
  for _, key in ipairs(keys) do
    signature_value(parts, prefix .. "." .. tostring(key), value[key], depth + 1)
  end
end

local function selection_preview_signature(model)
  local parts = {}
  local ok, entries = pcall(selected_objects, model)
  if not ok then return "" end
  for _, entry in ipairs(entries) do
    parts[#parts + 1] = tostring(entry.index) .. ":" .. tostring(entry.selection)
      .. ":" .. tostring(object_type(entry.object))
    local ok_matrix, values = pcall(matrix_values, object_matrix(entry.object))
    if ok_matrix then
      for index = 1, math.min(6, #values) do
        parts[#parts + 1] = string.format("%.17g", values[index])
      end
    end
    parts[#parts + 1] = object_custom_value(entry.object)
    parts[#parts + 1] = shape_fingerprint(entry.object) or ""
  end
  return table.concat(parts, "|")
end

local function preview_signature(model, action, options)
  local parts, keys = { tostring(action), selection_preview_signature(model) }, {}
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
  local function explain(message)
    if model.ui and type(model.ui.explain) == "function" then model.ui:explain(message) end
  end
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
    local ok_options, options = pcall(read_options)
    if not ok_options then
      preview.tool:update({})
      explain("Conics preview: " .. clean_error_message(options))
      return
    end
    local signature = preview_signature(model, action, options)
    if not force and signature == preview.last_signature then return end
    preview.last_signature = signature
    local ok_shapes, data = pcall(preview_shape_data, model, action, options)
    if ok_shapes then
      preview.tool:update(data.shapes)
      if force then explain("Conics preview updated.") end
    else
      preview.tool:update({})
      explain("Conics preview: " .. clean_error_message(data))
    end
  end
  preview.update = update
  preview.stop = function()
    if not preview.active then return end
    preview.active = false
    if preview.timer then pcall(function() preview.timer:stop() end) end
    if preview.tool then pcall(function() preview.tool:finish() end) end
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

exports.action_options = action_options
exports.preview_shape_data = preview_shape_data
exports.preview_shapes = preview_shapes
exports.object_preview_shapes = object_preview_shapes
exports.preview_signature = preview_signature
exports.add_preview_controls = add_preview_controls
exports.start_dialog_preview = start_dialog_preview
return exports
end)()

----------------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------------

local D = (function()
local exports = {}
local state = PERSISTED_DIALOG_STATE

for _, name in ipairs({ "conic", "ellipse", "hyperbola", "parabolas", "features" }) do
  if type(state[name]) ~= "table" then state[name] = {} end
end

local function value_index(values, value, fallback)
  for index, item in ipairs(values) do
    if item == value then return index end
  end
  return fallback or 1
end

local function operation_index(entries, operation, fallback)
  for index, entry in ipairs(entries) do
    if entry.operation == operation then return index end
  end
  return fallback or 1
end

local function operation_combo(entries, action)
  local values = { action = action }
  for index, entry in ipairs(entries) do values[index] = entry.label end
  return values
end

local function optional_input(dialog, name)
  local value = dialog:get(name)
  if value == nil or value == "" then return nil end
  return value
end

local function optional_bounds(dialog, name)
  local value = optional_input(dialog, name)
  if value == nil then return nil end
  local values = {}
  for item in tostring(value):gmatch("[^,%s]+") do values[#values + 1] = item end
  if #values ~= 4 then
    error("bounds must contain left, bottom, right, and top")
  end
  return {
    left = values[1], bottom = values[2], right = values[3], top = values[4],
  }
end

local function set_enabled(dialog, enabled, ...)
  for index = 1, select("#", ...) do
    dialog:setEnabled(select(index, ...), enabled)
  end
end

local function remember(dialog_state, options, dialog, fields)
  for _, field in ipairs(fields) do dialog_state[field] = options[field] end
  dialog_state.live_preview = dialog:get("live_preview") == true
end

local function successful_creation(result)
  return type(result) == "table" and result.created == true
end

local function execute_dialog(model, title, dialog, action, read_options, creator, on_success)
  local preview
  local ok_execute, accepted_or_error = pcall(function()
    preview = P.start_dialog_preview(model, dialog, action, read_options)
    dialog:addButton("cancel", "&Cancel", "reject")
    dialog:addButton("preview", "&Preview", function()
      if preview then preview.update(true) end
    end)
    dialog:addButton("ok", "&Create", "accept")
    return dialog:execute()
  end)
  if preview then pcall(function() preview.stop() end) end
  if not ok_execute then return warn_and_return(model, title, accepted_or_error) end
  if not accepted_or_error then return false end

  local ok_options, options_or_error = pcall(read_options)
  if not ok_options then return warn_and_return(model, title, options_or_error) end
  local ok_result, result_or_error = pcall(creator, model, options_or_error)
  if not ok_result then return warn_and_return(model, title, result_or_error) end
  if successful_creation(result_or_error) and on_success then
    local ok_remember, remember_error = pcall(on_success, options_or_error, dialog)
    if not ok_remember and model.ui and type(model.ui.explain) == "function" then
      model.ui:explain("The construction succeeded, but dialog preferences were not saved: "
        .. clean_error_message(remember_error))
    end
  end
  return result_or_error
end

local CONIC_OPERATIONS = {
  {
    label = "Steiner ellipses", operation = "steiner",
    selection = "Exactly 3 marks",
    help = "Creates the Steiner circumellipse, inellipse, or both.",
    steiner = true,
  },
  {
    label = "Conic through five points", operation = "five_points",
    selection = "Exactly 5 marks",
    help = "Fits one stable, nondegenerate conic through the five marks.",
    adaptive = true, allow_degenerate = true,
  },
  {
    label = "Best-fit conic", operation = "fit_points",
    selection = "6 to 512 marks",
    help = "Computes a least-squares conic from all selected sample marks.",
    adaptive = true, fit = true, allow_degenerate = true,
  },
  {
    label = "Conic tangent to five lines", operation = "five_tangents",
    selection = "Exactly 5 segments",
    help = "Constructs the unique stable conic tangent to all five lines.",
    adaptive = true, allow_degenerate = true,
  },
  {
    label = "Five mixed conditions", operation = "five_conditions",
    selection = "5 marks; or 4 marks + 1 tangent; or 3 marks + 2 tangents",
    help = "Each tangent segment must pass through exactly one selected tangent-point mark.",
    adaptive = true, allow_degenerate = true,
  },
  {
    label = "Focus, directrix, and point", operation = "focus_directrix_point",
    selection = "2 marks + 1 segment; primary: point on conic",
    help = "The secondary mark is the focus and the segment is the directrix.",
    adaptive = true,
  },
  {
    label = "Focus, directrix, and eccentricity", operation = "focus_directrix_eccentricity",
    selection = "1 primary focus mark + 1 secondary directrix segment",
    help = "Uses the numeric eccentricity: e<1 ellipse, e=1 parabola, e>1 hyperbola.",
    adaptive = true, eccentricity = true,
  },
  {
    label = "Canonical midpoint ellipse", operation = "quadrilateral_ellipse",
    selection = "Exactly 4 marks",
    help = "Uses the canonical minimum-area central ellipse through the side midpoints.",
  },
  {
    label = "Degenerate pair of lines", operation = "degenerate_line_pair",
    selection = "Exactly 2 segments",
    help = "Creates the explicit degenerate conic formed by the two selected lines.",
    line_length = true,
  },
  {
    label = "Degenerate double line", operation = "degenerate_double_line",
    selection = "Exactly 1 segment",
    help = "Creates a line with algebraic multiplicity two.",
    line_length = true,
  },
  {
    label = "Degenerate single line", operation = "degenerate_single_line",
    selection = "Exactly 1 segment",
    help = "Creates a first-degree single-line conic locus.",
    line_length = true,
  },
  {
    label = "Degenerate point", operation = "degenerate_point",
    selection = "Exactly 1 mark",
    help = "Creates a point locus represented as a degenerate conic.",
  },
  {
    label = "Empty degenerate locus", operation = "degenerate_empty",
    selection = "No selection required",
    help = "Computes an empty real conic locus without creating an object.",
  },
}
local STEINER_VALUES = { "both", "circumellipse", "inellipse" }
local STEINER_LABELS = { "Both", "Circumellipse", "Inellipse" }
local BRANCH_VALUES = { "both", "right", "left" }
local BRANCH_LABELS = { "Both branches", "Right branch", "Left branch" }
local EXPECTED_KIND_VALUES = { "auto", "ellipse", "parabola", "hyperbola" }
local EXPECTED_KIND_LABELS = { "Automatic", "Ellipse/circle", "Parabola", "Hyperbola" }

local function update_conic_dialog(dialog)
  local entry = CONIC_OPERATIONS[dialog:get("operation")] or CONIC_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  dialog:set("help_value", entry.help)
  set_enabled(dialog, entry.steiner == true, "steiner_label", "steiner")
  set_enabled(dialog, entry.eccentricity == true, "eccentricity_label", "eccentricity")
  set_enabled(dialog, entry.fit == true, "expected_kind_label", "expected_kind",
    "maximum_points_label", "maximum_points")
  set_enabled(dialog, entry.allow_degenerate == true, "allow_degenerate")
  set_enabled(dialog, entry.line_length == true, "line_length_label", "line_length")
  set_enabled(dialog, entry.adaptive == true, "branch_label", "branch",
    "extent_label", "extent", "padding_label", "padding",
    "bounds_label", "bounds",
    "tolerance_label", "tolerance", "segments_label", "max_segments")
end

local function conic_dialog(model)
  local saved = state.conic
  local dialog = ipeui.Dialog(model.ui:win(), "Construct conic")
  dialog:add("operation_label", "label", { label = "Construction" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(CONIC_OPERATIONS, update_conic_dialog), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("help_label", "label", { label = "How it works" }, 3, 1)
  dialog:add("help_value", "label", { label = "" }, 3, 2)
  dialog:add("steiner_label", "label", { label = "Steiner output" }, 4, 1)
  dialog:add("steiner", "combo", STEINER_LABELS, 4, 2)
  dialog:add("eccentricity_label", "label", { label = "Eccentricity e" }, 5, 1)
  dialog:add("eccentricity", "input", {}, 5, 2)
  dialog:add("expected_kind_label", "label", { label = "Expected fitted type" }, 6, 1)
  dialog:add("expected_kind", "combo", EXPECTED_KIND_LABELS, 6, 2)
  dialog:add("maximum_points_label", "label", { label = "Maximum sample marks" }, 7, 1)
  dialog:add("maximum_points", "input", {}, 7, 2)
  dialog:add("allow_degenerate", "checkbox", {
    label = "Allow an explicitly degenerate result",
  }, 8, 1, 1, 2)
  dialog:add("branch_label", "label", { label = "Hyperbola branch" }, 9, 1)
  dialog:add("branch", "combo", BRANCH_LABELS, 9, 2)
  dialog:add("extent_label", "label", { label = "Open-curve extent (optional)" }, 10, 1)
  dialog:add("extent", "input", {}, 10, 2)
  dialog:add("bounds_label", "label", {
    label = "Bounds: left, bottom, right, top (optional)",
  }, 11, 1)
  dialog:add("bounds", "input", {}, 11, 2)
  dialog:add("padding_label", "label", { label = "Automatic extent padding" }, 12, 1)
  dialog:add("padding", "input", {}, 12, 2)
  dialog:add("tolerance_label", "label", { label = "Approximation tolerance" }, 13, 1)
  dialog:add("tolerance", "input", {}, 13, 2)
  dialog:add("segments_label", "label", { label = "Maximum curve segments" }, 14, 1)
  dialog:add("max_segments", "input", {}, 14, 2)
  dialog:add("line_length_label", "label", { label = "Degenerate line length" }, 15, 1)
  dialog:add("line_length", "input", {}, 15, 2)
  dialog:add("group_output", "checkbox", { label = "Group multiple outputs" }, 16, 1, 1, 2)
  dialog:set("operation", operation_index(CONIC_OPERATIONS, saved.operation, 1))
  dialog:set("steiner", value_index(STEINER_VALUES, saved.mode, 1))
  dialog:set("eccentricity", saved.eccentricity or "1")
  dialog:set("expected_kind", value_index(EXPECTED_KIND_VALUES, saved.expected_kind, 1))
  dialog:set("maximum_points", saved.maximum_points or "512")
  dialog:set("allow_degenerate", saved.allow_degenerate == true)
  dialog:set("branch", value_index(BRANCH_VALUES, saved.branch, 1))
  dialog:set("extent", saved.extent or "")
  dialog:set("bounds", saved.bounds_text or "")
  dialog:set("padding", saved.padding or "24")
  dialog:set("tolerance", saved.tolerance or "0.25")
  dialog:set("max_segments", saved.max_segments or "256")
  dialog:set("line_length", saved.line_length or "192")
  dialog:set("group_output", saved.group_output ~= false)
  P.add_preview_controls(dialog, 17, 2, saved.live_preview)
  update_conic_dialog(dialog)
  local function read_options()
    local entry = CONIC_OPERATIONS[dialog:get("operation")] or CONIC_OPERATIONS[1]
    local options = {
      operation = entry.operation,
      group_output = dialog:get("group_output"),
    }
    if entry.steiner then options.mode = STEINER_VALUES[dialog:get("steiner")] end
    if entry.eccentricity then options.eccentricity = optional_input(dialog, "eccentricity") end
    if entry.fit then
      options.expected_kind = EXPECTED_KIND_VALUES[dialog:get("expected_kind")]
      options.maximum_points = optional_input(dialog, "maximum_points")
    end
    if entry.allow_degenerate then
      options.allow_degenerate = dialog:get("allow_degenerate")
    end
    if entry.line_length then options.line_length = optional_input(dialog, "line_length") end
    if entry.adaptive then
      options.branch = BRANCH_VALUES[dialog:get("branch")]
      options.extent = optional_input(dialog, "extent")
      options.bounds = optional_bounds(dialog, "bounds")
      options.padding = optional_input(dialog, "padding")
      options.tolerance = optional_input(dialog, "tolerance")
      options.max_segments = optional_input(dialog, "max_segments")
    end
    return options
  end
  return execute_dialog(
    model, "Cannot create conic", dialog, "conic", read_options, create_conic,
    function(options, successful_dialog)
      remember(saved, options, dialog,
        { "operation", "mode", "eccentricity", "expected_kind", "maximum_points",
          "allow_degenerate", "branch", "extent", "padding", "tolerance",
          "max_segments", "line_length", "group_output" })
      saved.bounds_text = successful_dialog:get("bounds")
    end
  )
end

local ELLIPSE_OPERATIONS = {
  {
    label = "Foci and point", operation = "foci_point",
    selection = "Exactly 3 marks; primary: point on ellipse",
    help = "The two secondary marks are the foci.",
  },
  {
    label = "Center and semiaxis endpoints", operation = "center_axes",
    selection = "Exactly 3 marks; primary: center",
    help = "The two secondary marks are perpendicular semiaxis endpoints.",
  },
}

local function update_ellipse_dialog(dialog)
  local entry = ELLIPSE_OPERATIONS[dialog:get("operation")] or ELLIPSE_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  dialog:set("help_value", entry.help)
end

local function ellipse_dialog(model)
  local saved = state.ellipse
  local dialog = ipeui.Dialog(model.ui:win(), "Construct ellipse")
  dialog:add("operation_label", "label", { label = "Construction" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(
    ELLIPSE_OPERATIONS, update_ellipse_dialog
  ), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("help_label", "label", { label = "How it works" }, 3, 1)
  dialog:add("help_value", "label", { label = "" }, 3, 2)
  dialog:add("output_label", "label", { label = "Output" }, 4, 1)
  dialog:add("output_value", "label", {
    label = "One native, editable Ipe ellipse.",
  }, 4, 2)
  dialog:set("operation", operation_index(ELLIPSE_OPERATIONS, saved.operation, 1))
  P.add_preview_controls(dialog, 5, 2, saved.live_preview)
  update_ellipse_dialog(dialog)
  local function read_options()
    local entry = ELLIPSE_OPERATIONS[dialog:get("operation")] or ELLIPSE_OPERATIONS[1]
    return { operation = entry.operation }
  end
  return execute_dialog(
    model, "Cannot create ellipse", dialog, "ellipse_from_foci", read_options,
    create_ellipse_from_foci,
    function(options) remember(saved, options, dialog, { "operation" }) end
  )
end

local HYPERBOLA_OPERATIONS = {
  {
    label = "Foci and point", operation = "foci_point",
    selection = "Exactly 3 marks; primary: point on hyperbola",
    help = "The two secondary marks are the foci.",
    foci = true,
  },
  {
    label = "Center and semiaxes", operation = "parameters",
    selection = "1 primary center mark; optional secondary axis segment",
    help = "The segment supplies only the transverse-axis direction.",
    parameters = true,
  },
  {
    label = "Rectangular hyperbola", operation = "rectangular",
    selection = "1 primary center mark; optional secondary axis segment",
    help = "Uses equal transverse and conjugate semiaxes.",
    parameters = true, rectangular = true,
  },
  {
    label = "Asymptotes and point", operation = "asymptotes_point",
    selection = "1 primary point mark + 2 secondary asymptote segments",
    help = "The point chooses the scale and branch of the hyperbola.",
  },
}

local function update_hyperbola_dialog(dialog)
  local entry = HYPERBOLA_OPERATIONS[dialog:get("operation")] or HYPERBOLA_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  dialog:set("help_value", entry.help)
  set_enabled(dialog, entry.parameters == true, "a_label", "a")
  set_enabled(dialog, entry.parameters == true and not entry.rectangular, "b_label", "b")
  local asymptotes = dialog:get("asymptotes") == true
  set_enabled(dialog, asymptotes, "asymptote_length_label", "asymptote_length")
end

local function hyperbola_dialog(model)
  local saved = state.hyperbola
  local dialog = ipeui.Dialog(model.ui:win(), "Construct hyperbola")
  dialog:add("operation_label", "label", { label = "Construction" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(HYPERBOLA_OPERATIONS, update_hyperbola_dialog), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("help_label", "label", { label = "How it works" }, 3, 1)
  dialog:add("help_value", "label", { label = "" }, 3, 2)
  dialog:add("a_label", "label", { label = "Transverse semiaxis a" }, 4, 1)
  dialog:add("a", "input", {}, 4, 2)
  dialog:add("b_label", "label", { label = "Conjugate semiaxis b" }, 5, 1)
  dialog:add("b", "input", {}, 5, 2)
  dialog:add("branch_label", "label", { label = "Branches" }, 6, 1)
  dialog:add("branch", "combo", BRANCH_LABELS, 6, 2)
  dialog:add("extent_label", "label", { label = "Transverse extent (optional)" }, 7, 1)
  dialog:add("extent", "input", {}, 7, 2)
  dialog:add("tolerance_label", "label", { label = "Approximation tolerance" }, 8, 1)
  dialog:add("tolerance", "input", {}, 8, 2)
  dialog:add("segments_label", "label", { label = "Maximum curve segments" }, 9, 1)
  dialog:add("max_segments", "input", {}, 9, 2)
  dialog:add("asymptotes", "checkbox", {
    label = "Create asymptotes", action = update_hyperbola_dialog,
  }, 10, 1, 1, 2)
  dialog:add("asymptote_length_label", "label", { label = "Asymptote length" }, 11, 1)
  dialog:add("asymptote_length", "input", {}, 11, 2)
  dialog:add("group_output", "checkbox", { label = "Group branches and auxiliaries" }, 12, 1, 1, 2)
  dialog:set("operation", operation_index(HYPERBOLA_OPERATIONS, saved.operation, 1))
  dialog:set("a", saved.a or "32")
  dialog:set("b", saved.b or "20")
  dialog:set("branch", value_index(BRANCH_VALUES, saved.branch, 1))
  dialog:set("extent", saved.extent or "")
  dialog:set("tolerance", saved.tolerance or "0.25")
  dialog:set("max_segments", saved.max_segments or "256")
  dialog:set("asymptotes", saved.asymptotes ~= false)
  dialog:set("asymptote_length", saved.asymptote_length or "192")
  dialog:set("group_output", saved.group_output ~= false)
  P.add_preview_controls(dialog, 13, 2, saved.live_preview)
  update_hyperbola_dialog(dialog)
  local function read_options()
    local entry = HYPERBOLA_OPERATIONS[dialog:get("operation")] or HYPERBOLA_OPERATIONS[1]
    local options = {
      operation = entry.operation,
      branch = BRANCH_VALUES[dialog:get("branch")],
      extent = optional_input(dialog, "extent"),
      tolerance = optional_input(dialog, "tolerance"),
      max_segments = optional_input(dialog, "max_segments"),
      asymptotes = dialog:get("asymptotes"),
      group_output = dialog:get("group_output"),
    }
    if options.asymptotes then
      options.asymptote_length = optional_input(dialog, "asymptote_length")
    end
    if entry.parameters then
      options.a = optional_input(dialog, "a")
      if not entry.rectangular then options.b = optional_input(dialog, "b") end
    end
    return options
  end
  return execute_dialog(
    model, "Cannot create hyperbola", dialog, "hyperbola", read_options,
    create_hyperbola,
    function(options)
      remember(saved, options, dialog,
        { "operation", "a", "b", "branch", "extent", "tolerance",
          "max_segments", "asymptotes", "asymptote_length", "group_output" })
    end
  )
end

local PARABOLA_OPERATIONS = {
  {
    label = "Directrix and foci", operation = "directrix_foci",
    selection = "1 primary directrix segment + 1 or more secondary focus marks",
    help = "Creates one parabola for each selected focus.",
  },
  {
    label = "Vertex and focus", operation = "vertex_focus",
    selection = "Exactly 2 marks; primary: vertex",
    help = "The secondary mark is the focus; the directrix is derived automatically.",
  },
}

local function update_parabolas_dialog(dialog)
  local entry = PARABOLA_OPERATIONS[dialog:get("operation")] or PARABOLA_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  dialog:set("help_value", entry.help)
end

local function parabolas_dialog(model)
  local saved = state.parabolas
  local dialog = ipeui.Dialog(model.ui:win(), "Construct parabola")
  dialog:add("operation_label", "label", { label = "Construction" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(
    PARABOLA_OPERATIONS, update_parabolas_dialog
  ), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("help_label", "label", { label = "How it works" }, 3, 1)
  dialog:add("help_value", "label", { label = "" }, 3, 2)
  dialog:add("extent_label", "label", { label = "Half-extent (optional)" }, 4, 1)
  dialog:add("extent", "input", {}, 4, 2)
  dialog:add("padding_label", "label", { label = "Automatic extent padding" }, 5, 1)
  dialog:add("padding", "input", {}, 5, 2)
  dialog:add("group_output", "checkbox", { label = "Group multiple parabolas" }, 6, 1, 1, 2)
  dialog:set("operation", operation_index(PARABOLA_OPERATIONS, saved.operation, 1))
  dialog:set("extent", saved.extent or "")
  dialog:set("padding", saved.padding or "0")
  dialog:set("group_output", saved.group_output ~= false)
  P.add_preview_controls(dialog, 7, 2, saved.live_preview)
  update_parabolas_dialog(dialog)
  local function read_options()
    local entry = PARABOLA_OPERATIONS[dialog:get("operation")] or PARABOLA_OPERATIONS[1]
    return {
      operation = entry.operation,
      extent = optional_input(dialog, "extent"),
      padding = optional_input(dialog, "padding"),
      group_output = dialog:get("group_output"),
    }
  end
  return execute_dialog(
    model, "Cannot create parabolas", dialog, "parabolas", read_options,
    create_parabolas,
    function(options)
      remember(saved, options, dialog, { "operation", "extent", "padding", "group_output" })
    end
  )
end

local FEATURE_OPERATIONS = {
  {
    label = "Tangent", operation = "tangent",
    selection = "1 primary conic + 1 secondary mark on the conic",
    point = true, line_length = true, marks = true,
  },
  {
    label = "Normal", operation = "normal",
    selection = "1 primary conic + 1 secondary mark on the conic",
    point = true, line_length = true, marks = true,
  },
  {
    label = "Tangent and normal", operation = "tangent_normal",
    selection = "1 primary conic + 1 secondary mark on the conic",
    point = true, line_length = true, marks = true, line_choices = true,
  },
  {
    label = "Polar line of point", operation = "polar",
    selection = "1 primary conic + 1 secondary mark",
    point = true, line_length = true, marks = true,
  },
  {
    label = "Tangents from point", operation = "tangents_from_point",
    selection = "1 primary conic + 1 secondary mark",
    point = true, line_length = true, marks = true, chord = true,
  },
  {
    label = "Pole of line", operation = "pole",
    selection = "1 primary conic + 1 secondary segment",
    marks = true, labels = true,
  },
  {
    label = "Focal chord", operation = "focal_chord",
    selection = "1 primary conic + 1 secondary mark defining the focal line",
    marks = true,
  },
  {
    label = "Intersections with line", operation = "line_intersections",
    selection = "1 primary conic + 1 secondary segment",
    marks = true, labels = true,
  },
  {
    label = "Intersections of two conics", operation = "conic_intersections",
    selection = "Exactly 2 conics; primary: first conic",
    marks = true, labels = true,
  },
  {
    label = "Trim conic to arc", operation = "conic_arc",
    selection = "1 primary conic + 2 secondary marks on one connected arc",
    arc = true, quality = true,
  },
  {
    label = "Fit and replace selected path", operation = "fit_replace_path",
    selection = "Exactly 1 primary path",
    fit = true, quality = true,
  },
  {
    label = "Property guides", operation = "guides",
    selection = "Exactly 1 primary conic",
    line_length = true, marks = true, labels = true, properties = true,
  },
}

local ARC_MODE_VALUES = { "shorter", "longer", "counterclockwise", "clockwise" }
local ARC_MODE_LABELS = { "Shorter ellipse arc", "Longer ellipse arc", "Counterclockwise", "Clockwise" }

local function update_features_dialog(dialog)
  local entry = FEATURE_OPERATIONS[dialog:get("operation")] or FEATURE_OPERATIONS[1]
  dialog:set("selection_value", entry.selection)
  set_enabled(dialog, entry.line_length == true, "line_length_label", "line_length")
  set_enabled(dialog, entry.marks == true, "marks")
  set_enabled(dialog, entry.labels == true, "labels")
  set_enabled(dialog, entry.line_choices == true, "tangent", "normal")
  set_enabled(dialog, entry.chord == true, "chord")
  set_enabled(dialog, entry.arc == true, "arc_mode_label", "arc_mode", "replace_original")
  set_enabled(dialog, entry.fit == true,
    "expected_kind_label", "expected_kind", "maximum_points_label", "maximum_points")
  set_enabled(dialog, entry.quality == true,
    "tolerance_label", "tolerance", "segments_label", "max_segments")
  set_enabled(dialog, entry.properties == true,
    "axes", "vertices", "foci", "directrices", "asymptotes",
    "latus_recta", "auxiliary_circles", "director_circle",
    "general_equation", "canonical_equation", "parameters")
end

local function features_dialog(model)
  local saved = state.features
  local dialog = ipeui.Dialog(model.ui:win(), "Conic features")
  dialog:add("operation_label", "label", { label = "Feature" }, 1, 1)
  dialog:add("operation", "combo", operation_combo(FEATURE_OPERATIONS, update_features_dialog), 1, 2)
  dialog:add("selection_label", "label", { label = "Required selection" }, 2, 1)
  dialog:add("selection_value", "label", { label = "" }, 2, 2)
  dialog:add("line_length_label", "label", { label = "Line length" }, 3, 1)
  dialog:add("line_length", "input", {}, 3, 2)
  dialog:add("tangent", "checkbox", { label = "Create tangent" }, 4, 1, 1, 2)
  dialog:add("normal", "checkbox", { label = "Create normal" }, 5, 1, 1, 2)
  dialog:add("chord", "checkbox", { label = "Create chord of contact" }, 6, 1, 1, 2)
  dialog:add("marks", "checkbox", { label = "Create point marks" }, 7, 1)
  dialog:add("labels", "checkbox", { label = "Create labels" }, 7, 2)
  dialog:add("axes", "checkbox", { label = "Axes" }, 8, 1)
  dialog:add("vertices", "checkbox", { label = "Vertices" }, 8, 2)
  dialog:add("foci", "checkbox", { label = "Foci" }, 9, 1)
  dialog:add("directrices", "checkbox", { label = "Directrices" }, 9, 2)
  dialog:add("asymptotes", "checkbox", { label = "Asymptotes" }, 10, 1)
  dialog:add("latus_recta", "checkbox", { label = "Latus recta" }, 10, 2)
  dialog:add("auxiliary_circles", "checkbox", { label = "Auxiliary circles" }, 11, 1)
  dialog:add("director_circle", "checkbox", { label = "Director circle" }, 11, 2)
  dialog:add("general_equation", "checkbox", { label = "General equation label" }, 12, 1)
  dialog:add("canonical_equation", "checkbox", { label = "Canonical equation label" }, 12, 2)
  dialog:add("parameters", "checkbox", { label = "Parameter label (a, b, c, e, p, area)" }, 13, 1, 1, 2)
  dialog:add("arc_mode_label", "label", { label = "Ellipse arc choice" }, 14, 1)
  dialog:add("arc_mode", "combo", ARC_MODE_LABELS, 14, 2)
  dialog:add("replace_original", "checkbox", { label = "Replace the selected conic" }, 15, 1, 1, 2)
  dialog:add("expected_kind_label", "label", { label = "Expected fitted type" }, 16, 1)
  dialog:add("expected_kind", "combo", EXPECTED_KIND_LABELS, 16, 2)
  dialog:add("maximum_points_label", "label", { label = "Maximum sampled points" }, 17, 1)
  dialog:add("maximum_points", "input", {}, 17, 2)
  dialog:add("tolerance_label", "label", { label = "Approximation tolerance" }, 18, 1)
  dialog:add("tolerance", "input", {}, 18, 2)
  dialog:add("segments_label", "label", { label = "Maximum curve segments" }, 19, 1)
  dialog:add("max_segments", "input", {}, 19, 2)
  dialog:add("group_output", "checkbox", { label = "Group multiple outputs" }, 20, 1, 1, 2)
  dialog:set("operation", operation_index(FEATURE_OPERATIONS, saved.operation, 1))
  dialog:set("line_length", saved.line_length or "192")
  dialog:set("tangent", saved.tangent ~= false)
  dialog:set("normal", saved.normal ~= false)
  dialog:set("chord", saved.chord ~= false)
  dialog:set("marks", saved.marks ~= false)
  dialog:set("labels", saved.labels == true)
  dialog:set("axes", saved.axes ~= false)
  dialog:set("vertices", saved.vertices ~= false)
  dialog:set("foci", saved.foci ~= false)
  dialog:set("directrices", saved.directrices ~= false)
  dialog:set("asymptotes", saved.asymptotes ~= false)
  dialog:set("latus_recta", saved.latus_recta == true)
  dialog:set("auxiliary_circles", saved.auxiliary_circles == true)
  dialog:set("director_circle", saved.director_circle == true)
  dialog:set("general_equation", saved.general_equation == true)
  dialog:set("canonical_equation", saved.canonical_equation == true)
  dialog:set("parameters", saved.parameters == true)
  dialog:set("arc_mode", value_index(ARC_MODE_VALUES, saved.arc_mode, 1))
  dialog:set("replace_original", saved.replace_original ~= false)
  dialog:set("expected_kind", value_index(EXPECTED_KIND_VALUES, saved.expected_kind, 1))
  dialog:set("maximum_points", saved.maximum_points or "512")
  dialog:set("tolerance", saved.tolerance or "0.25")
  dialog:set("max_segments", saved.max_segments or "256")
  dialog:set("group_output", saved.group_output ~= false)
  P.add_preview_controls(dialog, 21, 2, saved.live_preview)
  update_features_dialog(dialog)
  local function read_options()
    local entry = FEATURE_OPERATIONS[dialog:get("operation")] or FEATURE_OPERATIONS[1]
    local options = {
      operation = entry.operation,
      group_output = dialog:get("group_output"),
    }
    if entry.line_length then options.line_length = optional_input(dialog, "line_length") end
    if entry.marks then options.marks = dialog:get("marks") end
    if entry.labels then options.labels = dialog:get("labels") end
    if entry.line_choices then
      options.tangent = dialog:get("tangent")
      options.normal = dialog:get("normal")
    end
    if entry.chord then options.chord = dialog:get("chord") end
    if entry.arc then
      options.arc_mode = ARC_MODE_VALUES[dialog:get("arc_mode")]
      options.replace_original = dialog:get("replace_original")
    end
    if entry.fit then
      options.expected_kind = EXPECTED_KIND_VALUES[dialog:get("expected_kind")]
      options.maximum_points = optional_input(dialog, "maximum_points")
    end
    if entry.quality then
      options.tolerance = optional_input(dialog, "tolerance")
      options.max_segments = optional_input(dialog, "max_segments")
    end
    if entry.properties then
      options.axes = dialog:get("axes")
      options.vertices = dialog:get("vertices")
      options.foci = dialog:get("foci")
      options.directrices = dialog:get("directrices")
      options.asymptotes = dialog:get("asymptotes")
      options.latus_recta = dialog:get("latus_recta")
      options.auxiliary_circles = dialog:get("auxiliary_circles")
      options.director_circle = dialog:get("director_circle")
      options.general_equation = dialog:get("general_equation")
      options.canonical_equation = dialog:get("canonical_equation")
      options.parameters = dialog:get("parameters")
    end
    return options
  end
  return execute_dialog(
    model, "Cannot create conic features", dialog, "conic_features", read_options,
    create_conic_features,
    function(options)
      remember(saved, options, dialog,
        { "operation", "line_length", "tangent", "normal", "chord", "marks", "labels",
          "axes", "vertices", "foci", "directrices", "asymptotes",
          "latus_recta", "auxiliary_circles", "director_circle",
          "general_equation", "canonical_equation", "parameters",
          "arc_mode", "replace_original", "expected_kind", "maximum_points",
          "tolerance", "max_segments", "group_output" })
    end
  )
end

local function inspect_selected_conic(model)
  return inspect_conic(model, {})
end

local function revalidate_selected_conic(model)
  return revalidate_metadata(model, {})
end

exports.conic = conic_dialog
exports.ellipse_from_foci = ellipse_dialog
exports.ellipse = ellipse_dialog
exports.hyperbola = hyperbola_dialog
exports.parabolas = parabolas_dialog
exports.parabola = parabolas_dialog
exports.features = features_dialog
exports.inspect = inspect_selected_conic
exports.revalidate_metadata = revalidate_selected_conic
exports.state = state
return exports
end)()

local CONICS_API = (function()
  local api = {}
  local public = {
    "finite_number", "hypot", "point_from_table", "line_from_equation",
    "line_from_table", "bounds_from_table", "normalize_conic_coefficients",
    "conic_matrix_determinant", "is_degenerate_conic", "evaluate_conic",
    "conic_coefficients_from_five_points", "classify_conic", "conic_properties",
    "ellipse_coefficients", "steiner_ellipses", "quadrilateral_midpoint_ellipse",
    "ellipse_from_foci_point", "conic_coefficients_for_focus_directrix",
    "focus_directrix_conic_coefficients", "stable_asinh", "stable_acosh",
    "hyperbola_from_parameters", "hyperbola_from_foci_point",
    "hyperbola_coefficients", "hyperbola_point", "adaptive_hyperbola_cubics",
    "parabola_spline", "conic_gradient", "conic_tangent_normal",
    "conic_polar_line", "conic_line_intersections",
    "transformed_conic_coefficients", "conic_coefficients_from_points",
    "conic_coefficients_from_five_lines", "conic_coefficients_from_constraints",
    "ellipse_from_center_axes", "parabola_from_vertex_focus",
    "hyperbola_from_asymptotes_point", "degenerate_conic_from_lines",
    "degenerate_point_conic", "conic_conic_intersections", "conic_pole",
    "tangents_from_point", "focal_chord", "conic_equation_strings",
    "conic_arc_definition", "parse_conic_metadata",
    "create_conic", "create_ellipse_from_foci", "create_ellipse", "create_hyperbola",
    "create_parabolas", "create_parabola", "create_conic_features", "inspect_conic",
    "revalidate_metadata", "action_options", "preview_shape_data",
    "preview_shapes", "preview_signature",
  }
  for _, name in ipairs(public) do
    local value = M[name] or R[name] or P[name]
    if type(value) ~= "function" then error("missing public Conics function: " .. name) end
    api[name] = value
  end
  api.public_functions = public
  return api
end)()
CONICS_API.api_version = API_VERSION
CONICS_API.version = VERSION
CONICS_API.dialog_state = D.state
CONICS_API.required_functions = {
  "create_conic", "create_ellipse", "create_ellipse_from_foci",
  "create_hyperbola", "create_parabola", "create_parabolas",
  "create_conic_features", "inspect_conic",
  "revalidate_metadata", "preview_shape_data",
}
function CONICS_API.is_compatible(required_version)
  if required_version ~= nil and required_version ~= API_VERSION then return false end
  for _, name in ipairs(CONICS_API.required_functions) do
    if type(CONICS_API[name]) ~= "function" then return false end
  end
  return true
end

_G.CONICS = CONICS_API
_G.CONICS_DIALOGS = {
  conic = D.conic,
  ellipse_from_foci = D.ellipse_from_foci,
  ellipse = D.ellipse,
  hyperbola = D.hyperbola,
  parabolas = D.parabolas,
  parabola = D.parabola,
  features = D.features,
  inspect = D.inspect,
  revalidate_metadata = D.revalidate_metadata,
}

methods = {
  { label = "Construct: conic", run = D.conic },
  { label = "Construct: ellipse", run = D.ellipse },
  { label = "Construct: hyperbola", run = D.hyperbola },
  { label = "Construct: parabola", run = D.parabola },
  { label = "Features: conic", run = D.features },
  { label = "Inspect: conic", run = D.inspect },
  { label = "Metadata: revalidate selected conic", run = D.revalidate_metadata },
}
