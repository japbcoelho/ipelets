----------------------------------------------------------------------
-- Triangles 1.0.0
-- Copyright (C) 2026 japbcoelho
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Standalone triangle centers and derived constructions for Ipe 7.2.
----------------------------------------------------------------------

label = "Triangles"

about = [[
Triangles 1.0.0

Standalone triangle centers and derived constructions with scale-stable
geometry, live preview, grouped output, and versioned object metadata.

Copyright (C) 2026 japbcoelho
License: GPL-3.0-or-later
]]

local _G = _G
local ipe = ipe
local ipeui = ipeui
local assert = _G.assert
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
local VERSION = "1.0.0"
local MACHINE_EPSILON = 2.220446049250313e-16
local MIN_NORMAL = 2.2250738585072014e-308
local previous_api = rawget(_G, "TRIANGLES")
local PERSISTED_DIALOG_STATE = type(previous_api) == "table"
  and type(previous_api.dialog_state) == "table"
  and previous_api.dialog_state or {}

local CENTER_DEFINITIONS = {
  { name = "centroid", label = "G", title = "Centroid" },
  { name = "incenter", label = "I", title = "Incenter" },
  { name = "circumcenter", label = "O", title = "Circumcenter" },
  { name = "orthocenter", label = "H", title = "Orthocenter" },
  { name = "nine_point_center", label = "N", title = "Nine-point center" },
  { name = "excenter_a", label = "I_a", title = "Excenter A" },
  { name = "excenter_b", label = "I_b", title = "Excenter B" },
  { name = "excenter_c", label = "I_c", title = "Excenter C" },
  { name = "spieker_center", label = "Sp", title = "Spieker center" },
  { name = "mittenpunkt", label = "M", title = "Mittenpunkt" },
  { name = "feuerbach_point", label = "F", title = "Feuerbach point" },
  { name = "symmedian_point", label = "K", title = "Symmedian point" },
  { name = "gergonne_point", label = "Ge", title = "Gergonne point" },
  { name = "nagel_point", label = "Na", title = "Nagel point" },
  { name = "de_longchamps", label = "L", title = "de Longchamps point" },
  { name = "first_brocard", label = "\\Omega_1", title = "First Brocard point" },
  { name = "second_brocard", label = "\\Omega_2", title = "Second Brocard point" },
  { name = "first_fermat", label = "X_{13}", title = "First isogonic center (X13)" },
  { name = "second_fermat", label = "X_{14}", title = "Second isogonic center (X14)" },
  { name = "first_isodynamic", label = "X_{15}", title = "First isodynamic point" },
  { name = "second_isodynamic", label = "X_{16}", title = "Second isodynamic point" },
  { name = "first_napoleon", label = "X_{17}", title = "First Napoleon point" },
  { name = "second_napoleon", label = "X_{18}", title = "Second Napoleon point" },
  { name = "exeter_point", label = "X_{22}", title = "Exeter point" },
}

local CLASSIC_CENTERS = {
  "centroid", "incenter", "circumcenter", "orthocenter", "nine_point_center",
}

local ADVANCED_CENTERS = {
  "excenter_a", "excenter_b", "excenter_c", "spieker_center", "mittenpunkt",
  "feuerbach_point", "symmedian_point", "gergonne_point", "nagel_point",
  "de_longchamps", "first_brocard", "second_brocard", "first_fermat",
  "second_fermat", "first_isodynamic", "second_isodynamic", "first_napoleon",
  "second_napoleon", "exeter_point",
}

local CENTER_PRESETS = {
  fundamental = {
    "centroid", "incenter", "circumcenter", "orthocenter", "nine_point_center",
  },
  contact_cevian = {
    "incenter", "excenter_a", "excenter_b", "excenter_c", "spieker_center",
    "mittenpunkt", "feuerbach_point", "gergonne_point", "nagel_point",
  },
  euler_line = {
    "centroid", "circumcenter", "orthocenter", "nine_point_center",
    "de_longchamps", "exeter_point",
  },
  isogonal_napoleon = {
    "symmedian_point", "first_brocard", "second_brocard", "first_fermat",
    "second_fermat", "first_isodynamic", "second_isodynamic",
    "first_napoleon", "second_napoleon",
  },
}

local CENTER_DEFINING_LINES = {
  centroid = "median",
  incenter = "angle_bisector",
  circumcenter = "perpendicular_bisector",
  orthocenter = "altitude",
  excenter_a = "angle_bisector",
  excenter_b = "angle_bisector",
  excenter_c = "angle_bisector",
  symmedian_point = "symmedian",
  gergonne_point = "gergonne_cevian",
  nagel_point = "nagel_cevian",
}

local DERIVED_DEFINITIONS = {
  { name = "medial_triangle", title = "Medial triangle" },
  { name = "orthic_triangle", title = "Orthic triangle" },
  { name = "contact_triangle", title = "Contact triangle" },
  { name = "excentral_triangle", title = "Excentral triangle" },
  { name = "pedal_triangle", title = "Pedal triangle", point = true },
  { name = "nine_point_points", title = "Nine-point points" },
  { name = "cevian_endpoints", title = "Cevian endpoints", point = true },
  { name = "isogonal_conjugate", title = "Isogonal conjugate", point = true },
  { name = "isotomic_conjugate", title = "Isotomic conjugate", point = true },
}

local CENTER_LABELS = {}
local CENTER_TITLES = {}
local CENTER_NAMES = {}
for _, definition in ipairs(CENTER_DEFINITIONS) do
  CENTER_LABELS[definition.name] = definition.label
  CENTER_TITLES[definition.name] = definition.title
  CENTER_NAMES[#CENTER_NAMES + 1] = definition.name
end

local DERIVED_TITLES = {}
local DERIVED_REQUIRES_POINT = {}
local DERIVED_NAMES = {}
for _, definition in ipairs(DERIVED_DEFINITIONS) do
  DERIVED_TITLES[definition.name] = definition.title
  DERIVED_REQUIRES_POINT[definition.name] = definition.point == true
  DERIVED_NAMES[#DERIVED_NAMES + 1] = definition.name
end

local CENTER_ALIASES = {
  barycenter = "centroid", baricenter = "centroid", baricentro = "centroid",
  circumcentre = "circumcenter", circuncentro = "circumcenter",
  orthocentre = "orthocenter", ortocentro = "orthocenter",
  incentro = "incenter", nine_point = "nine_point_center",
  excenters = "excenters", classic = "all_classic", all_classic = "all_classic",
  extended = "all_advanced", advanced = "all_advanced",
  all_extended = "all_advanced", all_advanced = "all_advanced",
  all = "all_centers", all_centers = "all_centers",
  fundamental = "preset_fundamental", fundamental_centers = "preset_fundamental",
  contact_cevian = "preset_contact_cevian", contact_cevian_centers = "preset_contact_cevian",
  euler_line_centers = "preset_euler_line",
  isogonal_napoleon = "preset_isogonal_napoleon",
  isogonal_napoleon_centers = "preset_isogonal_napoleon",
  first_isogonic = "first_fermat", second_isogonic = "second_fermat",
}

local DERIVED_ALIASES = {
  medial = "medial_triangle", orthic = "orthic_triangle",
  contact = "contact_triangle", intouch_triangle = "contact_triangle",
  excentral = "excentral_triangle", pedal = "pedal_triangle",
  nine_point = "nine_point_points", cevian = "cevian_endpoints",
  isogonal = "isogonal_conjugate", isotomic = "isotomic_conjugate",
}

local M = (function()
local M = {}

local function finite_number(value)
  return type(value) == "number"
    and value == value
    and value ~= math.huge
    and value ~= -math.huge
end

local function clean_error_message(message)
  message = tostring(message or "")
  local cleaned = message:match("^%[string [^%]]+%]:%d+:%s*(.*)$")
    or message:match("^[^:]+:%d+:%s*(.*)$")
  return cleaned and cleaned ~= "" and cleaned or message
end

local function options_table(options)
  if options == nil then return {} end
  if type(options) ~= "table" then error("options must be a table") end
  return options
end

local function validate_keys(options, allowed, context)
  for key, _ in pairs(options) do
    if not allowed[key] then
      error((context or "options") .. " contains unsupported field '" .. tostring(key) .. "'")
    end
  end
  return options
end

local function number_value(value, fallback)
  if value == nil or value == "" then return fallback end
  if type(value) == "number" then return value end
  local ok, converted = pcall(tonumber, value)
  return ok and converted ~= nil and converted or fallback
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

local function boolean_option(value, fallback, name)
  if value == nil then return fallback end
  if value == true or value == 1 or value == "1" or value == "true" then return true end
  if value == false or value == 0 or value == "0" or value == "false" then return false end
  error((name or "boolean option") .. " must be true or false")
end

local function normalized_name(value)
  return tostring(value or ""):lower():gsub("[%s%-]+", "_")
end

local function normalized_center_name(value)
  local name = normalized_name(value)
  return CENTER_ALIASES[name] or name
end

local function normalized_derived_name(value)
  local name = normalized_name(value)
  return DERIVED_ALIASES[name] or name
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
  if not finite_number(x) or not finite_number(y) then
    error(name .. " must contain finite x/y numbers")
  end
  return V(x, y)
end

local function point_record(point)
  if not point or not finite_number(point.x) or not finite_number(point.y) then
    error("geometry contains a non-finite point")
  end
  return { x = point.x, y = point.y }
end

local function points_from_table(points, expected, name)
  name = name or "points"
  if type(points) ~= "table" then error(name .. " must be a point list") end
  if expected and #points ~= expected then
    error(name .. " must contain exactly " .. tostring(expected) .. " points")
  end
  local result = {}
  for index, point in ipairs(points) do
    result[index] = point_from_table(point, name .. "[" .. tostring(index) .. "]")
  end
  return result
end

local function add(a, b) return V(a.x + b.x, a.y + b.y) end
local function sub(a, b) return V(a.x - b.x, a.y - b.y) end
local function scale(vector, factor) return V(vector.x * factor, vector.y * factor) end
local function midpoint(a, b) return V(a.x * 0.5 + b.x * 0.5, a.y * 0.5 + b.y * 0.5) end
local function dot(a, b) return a.x * b.x + a.y * b.y end
local function cross(a, b) return a.x * b.y - a.y * b.x end
local function perpendicular(vector) return V(-vector.y, vector.x) end

local function hypot(x, y)
  x, y = math.abs(x), math.abs(y)
  local maximum = math.max(x, y)
  if maximum == math.huge then return math.huge end
  if maximum == 0 then return 0 end
  return maximum * math.sqrt((x / maximum) ^ 2 + (y / maximum) ^ 2)
end

local function length(vector) return hypot(vector.x, vector.y) end
local function distance(a, b) return hypot(a.x - b.x, a.y - b.y) end

local function scaled_tolerance(scale_value, multiplier)
  return (multiplier or 8192) * MACHINE_EPSILON
    * math.max(math.abs(scale_value or 0), MIN_NORMAL)
end

local function near_zero(value, scale_value, multiplier)
  return math.abs(value) <= scaled_tolerance(scale_value, multiplier)
end

local function unit(vector, context)
  local magnitude = length(vector)
  if not finite_number(magnitude) or near_zero(magnitude, 1, 16384) then
    error((context or "direction") .. " must be nonzero")
  end
  return scale(vector, 1 / magnitude)
end

local function clone_list(values)
  local result = {}
  for _, value in ipairs(values or {}) do result[#result + 1] = value end
  return result
end

local function strict_list(value, name)
  if type(value) ~= "table" then return { value } end
  local maximum = 0
  for key, _ in pairs(value) do
    if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
      error((name or "value") .. " must be a list")
    end
    maximum = math.max(maximum, key)
  end
  local result = {}
  for index = 1, maximum do
    if value[index] == nil then error((name or "value") .. " must be a list") end
    result[#result + 1] = value[index]
  end
  return result
end

local function all_center_names()
  local result = clone_list(CLASSIC_CENTERS)
  for _, name in ipairs(ADVANCED_CENTERS) do result[#result + 1] = name end
  return result
end

local function center_name_list(value, default)
  if value == nil then value = default end
  if value == nil then return {} end
  local result, seen = {}, {}
  local function append(name)
    if CENTER_LABELS[name] == nil then error("unsupported triangle center: " .. name) end
    if not seen[name] then seen[name] = true; result[#result + 1] = name end
  end
  local function expand(raw)
    local name = normalized_center_name(raw)
    if name == "all_classic" then
      for _, entry in ipairs(CLASSIC_CENTERS) do append(entry) end
    elseif name == "all_advanced" then
      for _, entry in ipairs(ADVANCED_CENTERS) do append(entry) end
    elseif name == "all_centers" then
      for _, entry in ipairs(all_center_names()) do append(entry) end
    elseif name == "preset_fundamental" then
      for _, entry in ipairs(CENTER_PRESETS.fundamental) do append(entry) end
    elseif name == "preset_contact_cevian" then
      for _, entry in ipairs(CENTER_PRESETS.contact_cevian) do append(entry) end
    elseif name == "preset_euler_line" then
      for _, entry in ipairs(CENTER_PRESETS.euler_line) do append(entry) end
    elseif name == "preset_isogonal_napoleon" then
      for _, entry in ipairs(CENTER_PRESETS.isogonal_napoleon) do append(entry) end
    elseif name == "excenters" then
      append("excenter_a"); append("excenter_b"); append("excenter_c")
    else
      append(name)
    end
  end
  for _, raw in ipairs(strict_list(value, "centers")) do expand(raw) end
  return result
end

local function derived_name_list(value, default)
  if value == nil then value = default end
  if value == nil then return {} end
  local result, seen = {}, {}
  local function append(name)
    if DERIVED_TITLES[name] == nil then
      error("unsupported triangle-derived construction: " .. name)
    end
    if not seen[name] then seen[name] = true; result[#result + 1] = name end
  end
  for _, raw in ipairs(strict_list(value, "derived")) do
    local name = normalized_derived_name(raw)
    if name == "all" or name == "all_derived" then
      for _, entry in ipairs(DERIVED_NAMES) do append(entry) end
    else
      append(name)
    end
  end
  return result
end

local function world_point(context, normalized)
  local x = context.coordinate_scale
    * (context.origin.x + context.shape_scale * normalized.x)
  local y = context.coordinate_scale
    * (context.origin.y + context.shape_scale * normalized.y)
  if not finite_number(x) or not finite_number(y) then return nil end
  return V(x, y)
end

local function normalized_point(context, world, name)
  world = point_from_table(world, name or "point")
  local x = ((world.x / context.coordinate_scale) - context.origin.x)
    / context.shape_scale
  local y = ((world.y / context.coordinate_scale) - context.origin.y)
    / context.shape_scale
  if not finite_number(x) or not finite_number(y) then
    error((name or "point") .. " cannot be represented in the triangle coordinate system")
  end
  return V(x, y)
end

local function world_length(context, normalized_length)
  local value = context.coordinate_scale * (context.shape_scale * normalized_length)
  return finite_number(value) and value or nil
end

local function triangle_context(a, b, c)
  a = point_from_table(a, "a")
  b = point_from_table(b, "b")
  c = point_from_table(c, "c")
  local coordinate_scale = math.max(
    math.abs(a.x), math.abs(a.y), math.abs(b.x), math.abs(b.y),
    math.abs(c.x), math.abs(c.y)
  )
  if coordinate_scale == 0 then error("triangle vertices must be distinct") end
  local scaled_a = V(a.x / coordinate_scale, a.y / coordinate_scale)
  local scaled_b = V(b.x / coordinate_scale, b.y / coordinate_scale)
  local scaled_c = V(c.x / coordinate_scale, c.y / coordinate_scale)
  local origin = V(
    scaled_a.x / 3 + scaled_b.x / 3 + scaled_c.x / 3,
    scaled_a.y / 3 + scaled_b.y / 3 + scaled_c.y / 3
  )
  local offset_a = sub(scaled_a, origin)
  local offset_b = sub(scaled_b, origin)
  local offset_c = sub(scaled_c, origin)
  local shape_scale = math.max(
    distance(offset_a, offset_b), distance(offset_b, offset_c),
    distance(offset_c, offset_a)
  )
  if not finite_number(shape_scale) or near_zero(shape_scale, 1, 16384) then
    error("triangle vertices must be distinct")
  end
  local na = scale(offset_a, 1 / shape_scale)
  local nb = scale(offset_b, 1 / shape_scale)
  local nc = scale(offset_c, 1 / shape_scale)
  local area2 = cross(sub(nb, na), sub(nc, na))
  if not finite_number(area2) or near_zero(area2, 1, 16384) then
    error("triangle is collinear or too ill-conditioned for reliable construction")
  end
  local side_a = distance(nb, nc)
  local side_b = distance(nc, na)
  local side_c = distance(na, nb)
  local semiperimeter = (side_a + side_b + side_c) * 0.5
  local area = math.abs(area2) * 0.5
  local context = {
    a = na, b = nb, c = nc,
    world_a = a, world_b = b, world_c = c,
    coordinate_scale = coordinate_scale,
    origin = origin,
    shape_scale = shape_scale,
    side_a = side_a, side_b = side_b, side_c = side_c,
    semiperimeter = semiperimeter,
    area = area,
    area2 = area2,
    cache = {},
  }
  context.world_scale = world_length(context, 1)
  if not context.world_scale or context.world_scale <= 0 then
    error("triangle scale cannot be represented reliably")
  end
  return context
end

local function status_record(status, point, normalized, reason)
  return {
    status = status,
    point = point,
    normalized = normalized,
    reason = reason,
  }
end

local function finite_status(context, normalized, context_name)
  if not normalized or not finite_number(normalized.x) or not finite_number(normalized.y) then
    return status_record("ill_conditioned", nil, nil,
      (context_name or "construction") .. " produced non-finite normalized coordinates")
  end
  local point = world_point(context, normalized)
  if not point then
    return status_record("ill_conditioned", nil, normalized,
      (context_name or "construction") .. " lies outside the representable coordinate range")
  end
  return status_record("finite", point, normalized)
end

local function barycentric_status(context, wa, wb, wc, context_name)
  if not finite_number(wa) or not finite_number(wb) or not finite_number(wc) then
    return status_record("ill_conditioned", nil, nil,
      (context_name or "center") .. " has non-finite barycentric weights")
  end
  local maximum = math.max(math.abs(wa), math.abs(wb), math.abs(wc))
  if maximum == 0 then
    return status_record("undefined", nil, nil,
      (context_name or "center") .. " has zero barycentric weights")
  end
  wa, wb, wc = wa / maximum, wb / maximum, wc / maximum
  local total = wa + wb + wc
  local weight_scale = math.abs(wa) + math.abs(wb) + math.abs(wc)
  if near_zero(total, weight_scale, 16384) then
    return status_record("ideal", nil, nil,
      (context_name or "center") .. " is a point at infinity for this triangle")
  end
  return finite_status(context, V(
    (wa * context.a.x + wb * context.b.x + wc * context.c.x) / total,
    (wa * context.a.y + wb * context.b.y + wc * context.c.y) / total
  ), context_name)
end

local function vertex_angle(vertex, first, second)
  local u = sub(first, vertex)
  local v = sub(second, vertex)
  return math.atan(math.abs(cross(u, v)), dot(u, v))
end

local function triangle_angles(context)
  return {
    A = vertex_angle(context.a, context.b, context.c),
    B = vertex_angle(context.b, context.c, context.a),
    C = vertex_angle(context.c, context.a, context.b),
  }
end

local function circumcenter_normalized(context)
  local ab = sub(context.b, context.a)
  local ac = sub(context.c, context.a)
  local denominator = 2 * cross(ab, ac)
  if near_zero(denominator, 1, 16384) then return nil end
  local ab2, ac2 = dot(ab, ab), dot(ac, ac)
  return add(context.a, V(
    (ab2 * ac.y - ac2 * ab.y) / denominator,
    (ab.x * ac2 - ac.x * ab2) / denominator
  ))
end

local function trilinear_status(context, ta, tb, tc, context_name)
  if ta == nil or tb == nil or tc == nil then
    return status_record("ideal", nil, nil,
      (context_name or "center") .. " has singular trilinear coordinates")
  end
  if math.max(math.abs(ta), math.abs(tb), math.abs(tc))
      <= scaled_tolerance(1, 16384) then
    return status_record("undefined", nil, nil,
      (context_name or "center") .. " has indeterminate trilinear coordinates")
  end
  return barycentric_status(
    context,
    context.side_a * ta,
    context.side_b * tb,
    context.side_c * tc,
    context_name
  )
end

local function reciprocal_trig(value)
  if near_zero(value, 1, 16384) then return nil end
  return 1 / value
end

local center_state

center_state = function(context, raw_name)
  local name = normalized_center_name(raw_name)
  if CENTER_LABELS[name] == nil then error("unsupported triangle center: " .. name) end
  if context.cache[name] then return context.cache[name] end
  context.cache[name] = status_record("computing", nil, nil)

  local a, b, c = context.a, context.b, context.c
  local sa, sb, sc = context.side_a, context.side_b, context.side_c
  local s = context.semiperimeter
  local result

  if name == "centroid" then
    result = barycentric_status(context, 1, 1, 1, name)
  elseif name == "incenter" then
    result = barycentric_status(context, sa, sb, sc, name)
  elseif name == "circumcenter" then
    local normalized = circumcenter_normalized(context)
    result = normalized and finite_status(context, normalized, name)
      or status_record("undefined", nil, nil, "circumcenter is undefined")
  elseif name == "orthocenter" or name == "nine_point_center"
      or name == "de_longchamps" then
    local circum = center_state(context, "circumcenter")
    if circum.status ~= "finite" then
      result = status_record(circum.status, nil, nil, "circumcenter is unavailable")
    else
      local orthocenter = sub(add(add(a, b), c), scale(circum.normalized, 2))
      if name == "orthocenter" then
        result = finite_status(context, orthocenter, name)
      elseif name == "nine_point_center" then
        result = finite_status(context, midpoint(circum.normalized, orthocenter), name)
      else
        result = finite_status(context, sub(scale(circum.normalized, 2), orthocenter), name)
      end
    end
  elseif name == "symmedian_point" then
    result = barycentric_status(context, sa * sa, sb * sb, sc * sc, name)
  elseif name == "nagel_point" then
    result = barycentric_status(context, s - sa, s - sb, s - sc, name)
  elseif name == "spieker_center" then
    result = barycentric_status(context, sb + sc, sc + sa, sa + sb, name)
  elseif name == "mittenpunkt" then
    result = barycentric_status(
      context,
      sa * (sb + sc - sa),
      sb * (sc + sa - sb),
      sc * (sa + sb - sc),
      name
    )
  elseif name == "first_brocard" then
    result = barycentric_status(context,
      sa * sa * sc * sc, sa * sa * sb * sb, sb * sb * sc * sc, name)
  elseif name == "second_brocard" then
    result = barycentric_status(context,
      sa * sa * sb * sb, sb * sb * sc * sc, sa * sa * sc * sc, name)
  elseif name == "excenter_a" then
    result = barycentric_status(context, -sa, sb, sc, name)
  elseif name == "excenter_b" then
    result = barycentric_status(context, sa, -sb, sc, name)
  elseif name == "excenter_c" then
    result = barycentric_status(context, sa, sb, -sc, name)
  elseif name == "gergonne_point" then
    local da, db, dc = s - sa, s - sb, s - sc
    if near_zero(da, 1, 16384) or near_zero(db, 1, 16384)
        or near_zero(dc, 1, 16384) then
      result = status_record("ill_conditioned", nil, nil,
        "Gergonne point is unstable for this nearly degenerate triangle")
    else
      result = barycentric_status(context, 1 / da, 1 / db, 1 / dc, name)
    end
  elseif name == "exeter_point" then
    local a2, b2, c2 = sa * sa, sb * sb, sc * sc
    local a4, b4, c4 = a2 * a2, b2 * b2, c2 * c2
    result = barycentric_status(context,
      a2 * (b4 + c4 - a4),
      b2 * (c4 + a4 - b4),
      c2 * (a4 + b4 - c4), name)
  elseif name == "feuerbach_point" then
    local incenter = center_state(context, "incenter")
    local nine = center_state(context, "nine_point_center")
    if incenter.status ~= "finite" or nine.status ~= "finite" then
      result = status_record("undefined", nil, nil,
        "Feuerbach point requires finite incenter and nine-point center")
    else
      local direction = sub(incenter.normalized, nine.normalized)
      local separation = length(direction)
      if near_zero(separation, 1, 16384) then
        result = status_record("undefined", nil, nil,
          "incircle and nine-point circle are concentric; tangency is not unique")
      else
        local inradius = context.area / context.semiperimeter
        result = finite_status(context,
          add(incenter.normalized, scale(direction, inradius / separation)), name)
      end
    end
  else
    local angles = triangle_angles(context)
    if name == "first_fermat" then
      local limit = 2 * math.pi / 3
      if near_zero(angles.A - limit, 1, 65536) then
        result = finite_status(context, a, name)
      elseif near_zero(angles.B - limit, 1, 65536) then
        result = finite_status(context, b, name)
      elseif near_zero(angles.C - limit, 1, 65536) then
        result = finite_status(context, c, name)
      else
        result = trilinear_status(context,
          reciprocal_trig(math.sin(angles.A + math.pi / 3)),
          reciprocal_trig(math.sin(angles.B + math.pi / 3)),
          reciprocal_trig(math.sin(angles.C + math.pi / 3)), name)
      end
    elseif name == "second_fermat" then
      result = trilinear_status(context,
        reciprocal_trig(math.sin(angles.A - math.pi / 3)),
        reciprocal_trig(math.sin(angles.B - math.pi / 3)),
        reciprocal_trig(math.sin(angles.C - math.pi / 3)), name)
    elseif name == "first_isodynamic" then
      result = trilinear_status(context,
        math.sin(angles.A + math.pi / 3),
        math.sin(angles.B + math.pi / 3),
        math.sin(angles.C + math.pi / 3), name)
    elseif name == "second_isodynamic" then
      result = trilinear_status(context,
        math.sin(angles.A - math.pi / 3),
        math.sin(angles.B - math.pi / 3),
        math.sin(angles.C - math.pi / 3), name)
    elseif name == "first_napoleon" then
      result = trilinear_status(context,
        reciprocal_trig(math.cos(angles.A - math.pi / 3)),
        reciprocal_trig(math.cos(angles.B - math.pi / 3)),
        reciprocal_trig(math.cos(angles.C - math.pi / 3)), name)
    elseif name == "second_napoleon" then
      result = trilinear_status(context,
        reciprocal_trig(math.cos(angles.A + math.pi / 3)),
        reciprocal_trig(math.cos(angles.B + math.pi / 3)),
        reciprocal_trig(math.cos(angles.C + math.pi / 3)), name)
    end
  end

  if not result or result.status == "computing" then
    result = status_record("undefined", nil, nil, name .. " is undefined")
  end
  result.name = name
  context.cache[name] = result
  return result
end

local function public_status(state)
  local result = { name = state.name, status = state.status }
  if state.point then result.point = point_record(state.point) end
  if state.reason then result.reason = state.reason end
  return result
end

local function circle_state(context, raw_kind)
  local kind = normalized_name(raw_kind or "incircle")
  local center_name, normalized_radius
  if kind == "incircle" or kind == "incenter" then
    kind, center_name = "incircle", "incenter"
    normalized_radius = context.area / context.semiperimeter
  elseif kind == "circumcircle" or kind == "circumcenter" then
    kind, center_name = "circumcircle", "circumcenter"
  elseif kind == "nine_point_circle" or kind == "nine_point_center" then
    kind, center_name = "nine_point_circle", "nine_point_center"
  elseif kind == "excircle_a" or kind == "excenter_a" then
    kind, center_name = "excircle_a", "excenter_a"
    normalized_radius = context.area / (context.semiperimeter - context.side_a)
  elseif kind == "excircle_b" or kind == "excenter_b" then
    kind, center_name = "excircle_b", "excenter_b"
    normalized_radius = context.area / (context.semiperimeter - context.side_b)
  elseif kind == "excircle_c" or kind == "excenter_c" then
    kind, center_name = "excircle_c", "excenter_c"
    normalized_radius = context.area / (context.semiperimeter - context.side_c)
  else
    error("unsupported triangle circle: " .. kind)
  end
  local center = center_state(context, center_name)
  if center.status ~= "finite" then
    return { status = center.status, kind = kind, reason = center.reason }
  end
  if kind == "circumcircle" or kind == "nine_point_circle" then
    normalized_radius = distance(center_state(context, "circumcenter").normalized, context.a)
    if kind == "nine_point_circle" then normalized_radius = normalized_radius * 0.5 end
  end
  if not finite_number(normalized_radius) or normalized_radius <= 0 then
    return { status = "ill_conditioned", kind = kind, reason = kind .. " radius is unavailable" }
  end
  local radius = world_length(context, normalized_radius)
  if not radius or radius <= 0 then
    return { status = "ill_conditioned", kind = kind,
      reason = kind .. " radius lies outside the representable coordinate range" }
  end
  return {
    status = "finite",
    kind = kind,
    center = center.point,
    normalized_center = center.normalized,
    radius = radius,
    normalized_radius = normalized_radius,
  }
end

local function project_normalized(point, first, second)
  local direction = sub(second, first)
  local denominator = dot(direction, direction)
  if near_zero(denominator, 1, 16384) then error("triangle side has zero length") end
  return add(first, scale(direction, dot(sub(point, first), direction) / denominator))
end

local function line_intersection_normalized(a1, a2, b1, b2)
  local r, s = sub(a2, a1), sub(b2, b1)
  local denominator = cross(r, s)
  local scale_value = length(r) * length(s)
  if near_zero(denominator, scale_value, 16384) then return nil end
  return add(a1, scale(r, cross(sub(b1, a1), s) / denominator))
end

local function contact_points_normalized(context, raw_kind)
  local circle = circle_state(context, raw_kind)
  if circle.status ~= "finite" then error(circle.reason or "contact circle is unavailable") end
  local center = circle.normalized_center
  return {
    project_normalized(center, context.a, context.b),
    project_normalized(center, context.b, context.c),
    project_normalized(center, context.c, context.a),
  }, circle
end

local function barycentric_coordinates_normalized(context, point)
  local denominator = context.area2
  return {
    cross(sub(context.b, point), sub(context.c, point)) / denominator,
    cross(sub(context.c, point), sub(context.a, point)) / denominator,
    cross(sub(context.a, point), sub(context.b, point)) / denominator,
  }
end

local function conjugate_status(context, point, kind)
  local normalized = normalized_point(context, point, "reference point")
  local weights = barycentric_coordinates_normalized(context, normalized)
  for index = 1, 3 do
    if near_zero(weights[index], 1, 16384) then
      return status_record("ideal", nil, nil,
        kind .. " conjugate is undefined for a point on a triangle sideline")
    end
  end
  if kind == "isogonal" then
    weights = {
      context.side_a ^ 2 / weights[1],
      context.side_b ^ 2 / weights[2],
      context.side_c ^ 2 / weights[3],
    }
  else
    weights = { 1 / weights[1], 1 / weights[2], 1 / weights[3] }
  end
  return barycentric_status(context, weights[1], weights[2], weights[3], kind .. " conjugate")
end

local function reference_point_for_options(context, options)
  if options.point ~= nil and options.point_center ~= nil then
    error("point and point_center cannot be used together")
  end
  if options.point ~= nil then return point_from_table(options.point, "point") end
  if options.point_center ~= nil then
    local center = center_state(context, options.point_center)
    if center.status ~= "finite" then error(center.reason or "reference center is unavailable") end
    return center.point
  end
  return nil
end

local DERIVED_LABELS = {
  medial_triangle = { "M_{AB}", "M_{BC}", "M_{CA}" },
  orthic_triangle = { "H_a", "H_b", "H_c" },
  contact_triangle = { "T_{AB}", "T_{BC}", "T_{CA}" },
  excentral_triangle = { "I_a", "I_b", "I_c" },
  pedal_triangle = { "P_a", "P_b", "P_c" },
  nine_point_points = {
    "M_{AB}", "M_{BC}", "M_{CA}", "H_a", "H_b", "H_c",
    "M_{AH}", "M_{BH}", "M_{CH}",
  },
  cevian_endpoints = { "D_a", "D_b", "D_c" },
  isogonal_conjugate = { "P^{*}" },
  isotomic_conjugate = { "P^{t}" },
}

local function derived_status(context, raw_operation, options)
  options = options_table(options)
  local operation = normalized_derived_name(raw_operation)
  if DERIVED_TITLES[operation] == nil then
    error("unsupported triangle-derived construction: " .. operation)
  end
  local normalized_points = {}
  local reference = reference_point_for_options(context, options)

  if DERIVED_REQUIRES_POINT[operation] and not reference then
    error(operation .. " requires point or point_center")
  end

  if operation == "medial_triangle" then
    normalized_points = {
      midpoint(context.a, context.b), midpoint(context.b, context.c),
      midpoint(context.c, context.a),
    }
  elseif operation == "orthic_triangle" then
    normalized_points = {
      project_normalized(context.a, context.b, context.c),
      project_normalized(context.b, context.c, context.a),
      project_normalized(context.c, context.a, context.b),
    }
  elseif operation == "contact_triangle" then
    normalized_points = contact_points_normalized(context, options.contact_circle or "incircle")
  elseif operation == "excentral_triangle" then
    for _, name in ipairs({ "excenter_a", "excenter_b", "excenter_c" }) do
      local state = center_state(context, name)
      if state.status ~= "finite" then
        return { status = state.status, kind = operation, reason = state.reason, points = {} }
      end
      normalized_points[#normalized_points + 1] = state.normalized
    end
  elseif operation == "pedal_triangle" then
    local point = normalized_point(context, reference, "reference point")
    normalized_points = {
      project_normalized(point, context.b, context.c),
      project_normalized(point, context.c, context.a),
      project_normalized(point, context.a, context.b),
    }
  elseif operation == "nine_point_points" then
    local orthocenter = center_state(context, "orthocenter")
    if orthocenter.status ~= "finite" then
      return { status = orthocenter.status, kind = operation,
        reason = orthocenter.reason, points = {} }
    end
    normalized_points = {
      midpoint(context.a, context.b), midpoint(context.b, context.c),
      midpoint(context.c, context.a),
      project_normalized(context.a, context.b, context.c),
      project_normalized(context.b, context.c, context.a),
      project_normalized(context.c, context.a, context.b),
      midpoint(context.a, orthocenter.normalized),
      midpoint(context.b, orthocenter.normalized),
      midpoint(context.c, orthocenter.normalized),
    }
  elseif operation == "cevian_endpoints" then
    local point = normalized_point(context, reference, "reference point")
    local triples = {
      { context.a, context.b, context.c },
      { context.b, context.c, context.a },
      { context.c, context.a, context.b },
    }
    for _, values in ipairs(triples) do
      local foot = line_intersection_normalized(values[1], point, values[2], values[3])
      if not foot then
        return { status = "ideal", kind = operation,
          reason = "a cevian is parallel to its opposite sideline", points = {} }
      end
      normalized_points[#normalized_points + 1] = foot
    end
  elseif operation == "isogonal_conjugate" or operation == "isotomic_conjugate" then
    local conjugate = conjugate_status(
      context, reference, operation == "isogonal_conjugate" and "isogonal" or "isotomic")
    if conjugate.status ~= "finite" then
      return { status = conjugate.status, kind = operation,
        reason = conjugate.reason, points = {} }
    end
    normalized_points = { conjugate.normalized }
  end

  local points = {}
  for _, normalized in ipairs(normalized_points) do
    local point = world_point(context, normalized)
    if not point then
      return { status = "ill_conditioned", kind = operation,
        reason = operation .. " lies outside the representable coordinate range", points = {} }
    end
    points[#points + 1] = point
  end
  return {
    status = "finite",
    kind = operation,
    points = points,
    normalized_points = normalized_points,
    labels = clone_list(DERIVED_LABELS[operation]),
    reference_point = reference,
  }
end

function M.triangle_center(a, b, c, name)
  return public_status(center_state(triangle_context(a, b, c), name))
end

function M.triangle_centers(a, b, c, names)
  local context = triangle_context(a, b, c)
  local requested = center_name_list(names, "all_centers")
  local result = { points = {}, states = {} }
  for _, name in ipairs(requested) do
    local state = center_state(context, name)
    result.states[name] = public_status(state)
    if state.status == "finite" then result.points[name] = point_record(state.point) end
  end
  return result
end

function M.triangle_derived_points(a, b, c, options)
  options = options_table(options)
  local operation = options.operation or options.construction or options.derived
    or "medial_triangle"
  local result = derived_status(triangle_context(a, b, c), operation, options)
  local public = {
    status = result.status,
    kind = result.kind,
    reason = result.reason,
    points = {},
    labels = result.labels and clone_list(result.labels) or {},
  }
  for _, point in ipairs(result.points or {}) do public.points[#public.points + 1] = point_record(point) end
  if result.reference_point then public.reference_point = point_record(result.reference_point) end
  return public
end

function M.barycentric_coordinates(a, b, c, point)
  local context = triangle_context(a, b, c)
  return barycentric_coordinates_normalized(
    context, normalized_point(context, point, "point"))
end

function M.point_from_barycentric(a, b, c, weights)
  if type(weights) ~= "table" or #weights ~= 3 then
    error("weights must contain exactly three values")
  end
  local context = triangle_context(a, b, c)
  local state = barycentric_status(context,
    finite_number_option(weights[1], nil, "weights[1]"),
    finite_number_option(weights[2], nil, "weights[2]"),
    finite_number_option(weights[3], nil, "weights[3]"), "barycentric point")
  if state.status ~= "finite" then error(state.reason) end
  return point_record(state.point)
end

function M.isogonal_conjugate(a, b, c, point)
  local state = conjugate_status(triangle_context(a, b, c), point, "isogonal")
  if state.status ~= "finite" then error(state.reason) end
  return point_record(state.point)
end

function M.isotomic_conjugate(a, b, c, point)
  local state = conjugate_status(triangle_context(a, b, c), point, "isotomic")
  if state.status ~= "finite" then error(state.reason) end
  return point_record(state.point)
end

function M.triangle_contact_points(a, b, c, kind)
  local context = triangle_context(a, b, c)
  local normalized, circle = contact_points_normalized(context, kind)
  local result = { kind = circle.kind, points = {} }
  for _, point in ipairs(normalized) do
    result.points[#result.points + 1] = point_record(assert(world_point(context, point)))
  end
  result.circle = { center = point_record(circle.center), radius = circle.radius }
  return result
end

M.finite_number = finite_number
M.hypot = hypot
M.point_from_table = point_from_table
M.center_names = all_center_names
M.center_name_list = center_name_list
M.derived_name_list = derived_name_list
M.internal = {
  clean_error_message = clean_error_message,
  options_table = options_table,
  validate_keys = validate_keys,
  finite_number_option = finite_number_option,
  positive_number_option = positive_number_option,
  boolean_option = boolean_option,
  normalized_name = normalized_name,
  normalized_center_name = normalized_center_name,
  normalized_derived_name = normalized_derived_name,
  point_record = point_record,
  points_from_table = points_from_table,
  add = add,
  sub = sub,
  scale = scale,
  midpoint = midpoint,
  dot = dot,
  cross = cross,
  perpendicular = perpendicular,
  length = length,
  distance = distance,
  scaled_tolerance = scaled_tolerance,
  near_zero = near_zero,
  unit = unit,
  clone_list = clone_list,
  triangle_context = triangle_context,
  world_point = world_point,
  normalized_point = normalized_point,
  center_state = center_state,
  public_status = public_status,
  circle_state = circle_state,
  project_normalized = project_normalized,
  line_intersection_normalized = line_intersection_normalized,
  contact_points_normalized = contact_points_normalized,
  derived_status = derived_status,
}
return M
end)()

----------------------------------------------------------------------
-- Ipe selection, object construction, metadata, and transactions
----------------------------------------------------------------------

local R = (function()
local R = {}
local I = M.internal
local clean_error_message = I.clean_error_message
local finite_number = M.finite_number
local point_from_table = M.point_from_table
local point_record = I.point_record
local points_from_table = I.points_from_table
local normalized_name = I.normalized_name
local triangle_context = I.triangle_context
local distance = I.distance
local scaled_tolerance = I.scaled_tolerance

local DEFAULT_PATH_ATTRIBUTES = {
  stroke = "black", pen = "normal", dashstyle = "normal",
  linecap = "normal", linejoin = "miter",
}
local DEFAULT_MARK_ATTRIBUTES = {
  stroke = "black", fill = "white", symbolsize = "normal",
  markshape = "mark/disk(sx)",
}
local DEFAULT_TEXT_ATTRIBUTES = {
  stroke = "black", textsize = "normal",
  horizontalalignment = "left", verticalalignment = "baseline",
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
    markshape = type(source) == "table" and source.markshape
      or DEFAULT_MARK_ATTRIBUTES.markshape,
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
  if existing ~= "" then
    if existing:find(value, 1, true) then return end
    value = existing .. ";" .. value
  end
  set_object_custom_value(object, value)
end

local function matrix_values(matrix)
  local values = { matrix:coeff() }
  if #values == 1 and type(values[1]) == "table" then values = values[1] end
  return values
end

local function fingerprint_number(value)
  -- Ipe serializes geometry with six significant digits.  Hashing the same
  -- canonical precision keeps metadata valid after an XML save/reload while
  -- still detecting every geometric change that Ipe itself can preserve.
  if value == 0 then value = 0 end
  return string.format("%.6g", value)
end

local function serialize_value(parts, value, depth)
  depth = depth or 0
  if depth > 10 then return end
  if type(value) == "number" then
    parts[#parts + 1] = fingerprint_number(value)
  elseif type(value) == "string" or type(value) == "boolean" then
    parts[#parts + 1] = tostring(value)
  elseif type(value) == "table" then
    if finite_number(value.x) and finite_number(value.y) then
      parts[#parts + 1] = fingerprint_number(value.x) .. "," .. fingerprint_number(value.y)
    else
      for index, item in ipairs(value) do serialize_value(parts, item, depth + 1) end
      local keys = {}
      for key, _ in pairs(value) do if type(key) ~= "number" then keys[#keys + 1] = key end end
      table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
      for _, key in ipairs(keys) do
        parts[#parts + 1] = tostring(key)
        serialize_value(parts, value[key], depth + 1)
      end
    end
  else
    local ok_x, x = pcall(function() return value.x end)
    local ok_y, y = pcall(function() return value.y end)
    if ok_x and ok_y and finite_number(x) and finite_number(y) then
      parts[#parts + 1] = fingerprint_number(x) .. "," .. fingerprint_number(y)
      return
    end
    local ok, values = pcall(matrix_values, value)
    if ok and type(values) == "table" and #values >= 6 then
      for index = 1, 6 do serialize_value(parts, values[index], depth + 1) end
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

local function object_fingerprint(object)
  local kind = object_type(object)
  if not kind then return nil end
  local parts = { kind }
  local ok_matrix, matrix = pcall(object_matrix, object)
  if ok_matrix and matrix then serialize_value(parts, matrix, 0) end
  if kind == "path" then
    serialize_value(parts, path_shape(object), 0)
  elseif kind == "reference" then
    local ok_position, position = pcall(function() return object:position() end)
    local ok_symbol, symbol = pcall(function() return object:symbol() end)
    if not ok_position or not position or not ok_symbol then return nil end
    parts[#parts + 1] = tostring(symbol)
    serialize_value(parts, position, 0)
  elseif kind == "text" then
    local ok_position, position = pcall(function() return object:position() end)
    local ok_text, text_value = pcall(function() return object:text() end)
    if not ok_text and type(object) == "table" then text_value = object.text end
    if ok_position and position then serialize_value(parts, position, 0) end
    text_value = tostring(text_value or "")
    -- Label text is written as $...$ in XML, but Ipe removes that wrapper
    -- when the same label is read back through object:text().
    if text_value:sub(1, 1) == "$" and text_value:sub(-1) == "$" then
      text_value = text_value:sub(2, -2)
    end
    parts[#parts + 1] = text_value
  elseif kind == "group" then
    for _, child in ipairs(object_elements(object) or {}) do
      parts[#parts + 1] = object_fingerprint(child) or "unavailable"
    end
  end
  return fnv1a(table.concat(parts, "|"))
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
  local point = ok_transformed and transformed or position
  if not finite_number(point.x) or not finite_number(point.y) then return nil end
  return point
end

local function selected_objects(model)
  local page, result = model:page(), {}
  for index, object, selection, layer in page:objects() do
    if selection then
      local ok_visible, visible = pcall(function() return page:visible(model.vno, index) end)
      if not ok_visible or visible ~= false then
        result[#result + 1] = {
          index = index, object = object, selection = selection, layer = layer,
          primary = selection == 1,
        }
      end
    end
  end
  return result
end

local function triangle_path_vertices(object)
  local shape = path_shape(object)
  if not shape or #shape ~= 1 then return nil end
  local curve = shape[1]
  if curve.type ~= "curve" or not curve.closed or #curve < 2 then return nil end
  local matrix = object_matrix(object)
  local raw_segments = {}
  for _, segment in ipairs(curve) do
    if segment.type ~= "segment" or not segment[1] or not segment[2] then return nil end
    local ok_first, first = pcall(function() return matrix * segment[1] end)
    local ok_second, second = pcall(function() return matrix * segment[2] end)
    if not ok_first or not ok_second or not first or not second
        or not finite_number(first.x) or not finite_number(first.y)
        or not finite_number(second.x) or not finite_number(second.y) then
      return nil
    end
    raw_segments[#raw_segments + 1] = { first, second }
  end
  local path_scale = 0
  for _, segment in ipairs(raw_segments) do
    path_scale = math.max(path_scale, distance(segment[1], segment[2]))
  end
  if path_scale == 0 then return nil end
  local tolerance = scaled_tolerance(path_scale, 65536)
  local vertices = { raw_segments[1][1] }
  local current = raw_segments[1][1]
  for _, segment in ipairs(raw_segments) do
    if distance(current, segment[1]) > tolerance then return nil end
    current = segment[2]
    vertices[#vertices + 1] = current
  end
  if distance(vertices[#vertices], vertices[1]) <= tolerance then vertices[#vertices] = nil end
  local unique = {}
  for _, vertex in ipairs(vertices) do
    local duplicate = false
    for _, existing in ipairs(unique) do
      if distance(vertex, existing) <= tolerance then duplicate = true; break end
    end
    if not duplicate then unique[#unique + 1] = vertex end
  end
  if #unique ~= 3 then return nil end
  local ok = pcall(triangle_context, unique[1], unique[2], unique[3])
  return ok and unique or nil
end

local function single_segment_vertices(object)
  local shape = path_shape(object)
  if not shape or #shape ~= 1 then return nil end
  local curve = shape[1]
  if curve.type ~= "curve" or curve.closed or #curve ~= 1 then return nil end
  local segment = curve[1]
  if segment.type ~= "segment" or not segment[1] or not segment[2] then return nil end
  local matrix = object_matrix(object)
  local ok_first, first = pcall(function() return matrix * segment[1] end)
  local ok_second, second = pcall(function() return matrix * segment[2] end)
  if not ok_first or not ok_second or not first or not second then return nil end
  if not finite_number(first.x) or not finite_number(first.y)
      or not finite_number(second.x) or not finite_number(second.y) then return nil end
  if distance(first, second) == 0 then return nil end
  return first, second
end

local function triangle_from_side_segments(segments)
  if #segments ~= 3 then return nil end
  local segment_scale = 0
  for _, segment in ipairs(segments) do
    segment_scale = math.max(segment_scale, distance(segment.p1, segment.p2))
  end
  if segment_scale == 0 then return nil end
  local tolerance = scaled_tolerance(segment_scale, 65536)
  local vertices = {}
  local function vertex_index(point)
    for index, existing in ipairs(vertices) do
      if distance(point, existing) <= tolerance then return index end
    end
    vertices[#vertices + 1] = point
    return #vertices
  end
  local edges, degree = {}, {}
  for _, segment in ipairs(segments) do
    local first, second = vertex_index(segment.p1), vertex_index(segment.p2)
    if first == second then return nil end
    local low, high = math.min(first, second), math.max(first, second)
    local key = tostring(low) .. ":" .. tostring(high)
    if edges[key] then return nil end
    edges[key] = true
    degree[first] = (degree[first] or 0) + 1
    degree[second] = (degree[second] or 0) + 1
  end
  if #vertices ~= 3 then return nil end
  for index = 1, 3 do if degree[index] ~= 2 then return nil end end
  local ok = pcall(triangle_context, vertices[1], vertices[2], vertices[3])
  return ok and vertices or nil
end

local function active_layer(model)
  return model:page():active(model.vno)
end

local function explicit_triangle_points(options)
  if options.points ~= nil then
    if options.a ~= nil or options.b ~= nil or options.c ~= nil then
      error("points cannot be combined with a, b, or c")
    end
    return points_from_table(options.points, 3, "points")
  end
  local named = options.a ~= nil or options.b ~= nil or options.c ~= nil
  if named then
    if options.a == nil or options.b == nil or options.c == nil then
      error("triangle points a, b, and c must be provided together")
    end
    return {
      point_from_table(options.a, "a"), point_from_table(options.b, "b"),
      point_from_table(options.c, "c"),
    }
  end
  return nil
end

local function primary_first_marks(marks)
  local result = {}
  for _, entry in ipairs(marks) do if entry.primary then result[#result + 1] = entry end end
  for _, entry in ipairs(marks) do if not entry.primary then result[#result + 1] = entry end end
  return result
end

local function canonical_triangle_vertices(vertices, preferred_a)
  if #vertices ~= 3 then error("triangle vertex ordering requires exactly three points") end
  local scale_value = math.max(
    distance(vertices[1], vertices[2]),
    distance(vertices[2], vertices[3]),
    distance(vertices[3], vertices[1]))
  local tolerance = scaled_tolerance(scale_value, 65536)
  local a_index = preferred_a
  if a_index == nil then
    a_index = 1
    for index = 2, 3 do
      local candidate, current = vertices[index], vertices[a_index]
      if candidate.y > current.y + tolerance
          or (math.abs(candidate.y - current.y) <= tolerance
            and candidate.x < current.x - tolerance) then
        a_index = index
      end
    end
  end
  if a_index < 1 or a_index > 3 then error("preferred vertex A is outside the triangle") end

  local remaining = {}
  for index = 1, 3 do
    if index ~= a_index then remaining[#remaining + 1] = vertices[index] end
  end
  local a, b, c = vertices[a_index], remaining[1], remaining[2]
  local orientation = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
  if orientation < 0 then b, c = c, b end
  return { a, b, c }
end

local function resolve_triangle_input(model, options, needs_reference)
  local explicit = explicit_triangle_points(options)
  if explicit then
    return {
      a = explicit[1], b = explicit[2], c = explicit[3],
      source_layer = active_layer(model), source_kind = "explicit",
      vertex_order = "provided",
    }
  end

  local paths, marks, segments, invalid = {}, {}, {}, {}
  for _, entry in ipairs(selected_objects(model)) do
    local vertices = triangle_path_vertices(entry.object)
    if vertices then
      entry.vertices = vertices
      paths[#paths + 1] = entry
    else
      local position = reference_position(entry.object)
      if position then
        entry.point = position
        marks[#marks + 1] = entry
      else
        local p1, p2 = single_segment_vertices(entry.object)
        if p1 and p2 then
          entry.p1, entry.p2 = p1, p2
          segments[#segments + 1] = entry
        else
          invalid[#invalid + 1] = entry
        end
      end
    end
  end
  if #invalid > 0 then
    error("selection contains an unsupported object; use one triangle path, three marks, or three sides")
  end

  local explicit_reference = options.point ~= nil or options.point_center ~= nil
  local allow_selected_reference = needs_reference and not explicit_reference
  if #paths == 1 and #segments == 0
      and (#marks == 0 or (allow_selected_reference and #marks == 1)) then
    local vertices = canonical_triangle_vertices(paths[1].vertices)
    return {
      a = vertices[1], b = vertices[2], c = vertices[3],
      reference = marks[1] and marks[1].point or nil,
      source_layer = paths[1].layer, source_kind = "path",
      vertex_order = "upper_ccw",
    }
  end

  if #paths == 0 and #segments == 0 then
    local ordered = primary_first_marks(marks)
    if #ordered == 3 then
      local raw_vertices = { ordered[1].point, ordered[2].point, ordered[3].point }
      local vertices = canonical_triangle_vertices(raw_vertices, ordered[1].primary and 1 or nil)
      return {
        a = vertices[1], b = vertices[2], c = vertices[3],
        source_layer = ordered[1].layer, source_kind = "marks",
        vertex_order = ordered[1].primary and "primary_a_ccw" or "upper_ccw",
      }
    end
    if allow_selected_reference and #ordered == 4 then
      local reference_index
      for index, entry in ipairs(ordered) do if entry.primary then reference_index = index; break end end
      if not reference_index then
        error("with four selected marks, make the reference point the primary selection")
      end
      local vertices = {}
      for index, entry in ipairs(ordered) do
        if index ~= reference_index then vertices[#vertices + 1] = entry.point end
      end
      vertices = canonical_triangle_vertices(vertices)
      return {
        a = vertices[1], b = vertices[2], c = vertices[3],
        reference = ordered[reference_index].point,
        source_layer = ordered[2] and ordered[2].layer or active_layer(model),
        source_kind = "marks",
        vertex_order = "upper_ccw",
      }
    end
  end

  if #paths == 0 and #segments == 3
      and (#marks == 0 or (allow_selected_reference and #marks == 1)) then
    local vertices = triangle_from_side_segments(segments)
    if not vertices then error("the three selected segments do not form one closed triangle") end
    vertices = canonical_triangle_vertices(vertices)
    local source_layer = segments[1].layer
    for index = 2, 3 do
      if segments[index].layer ~= source_layer then source_layer = active_layer(model); break end
    end
    return {
      a = vertices[1], b = vertices[2], c = vertices[3],
      reference = marks[1] and marks[1].point or nil,
      source_layer = source_layer, source_kind = "sides",
      vertex_order = "upper_ccw",
    }
  end

  local suffix = allow_selected_reference and " Add one reference-point mark when required." or ""
  error("select exactly one closed triangular path, three vertex marks, or three side segments."
    .. suffix)
end

local function resolve_output_layer(model, input, raw_mode)
  local mode = normalized_name(raw_mode or "active")
  if mode ~= "active" and mode ~= "source" then
    error("output_layer must be 'active' or 'source'")
  end
  if mode == "source" and input.source_layer then return input.source_layer end
  return active_layer(model)
end

local function warn_for_output_layer(model, layer)
  if model._triangles_preview then return end
  local page = model:page()
  local messages = {}
  local ok_visible, visible = pcall(function() return page:visible(model.vno, layer) end)
  if ok_visible and visible == false then messages[#messages + 1] = "The layer is invisible." end
  local ok_locked, locked = pcall(function() return page:isLocked(layer) end)
  if ok_locked and locked == true then messages[#messages + 1] = "The layer is locked." end
  if #messages > 0 then
    model:warning("Triangles output layer", "Objects were created in layer '" .. tostring(layer)
      .. "'.\n\n" .. table.concat(messages, " "))
  end
end

local function segment_shape(p1, p2)
  return { type = "curve", closed = false; { type = "segment"; p1, p2 } }
end

local function polygon_shape(points)
  local curve = { type = "curve", closed = true }
  for index = 1, #points - 1 do
    curve[#curve + 1] = { type = "segment"; points[index], points[index + 1] }
  end
  return curve
end

local function make_segment(p1, p2, attributes)
  point_record(p1); point_record(p2)
  return ipe.Path(clone_table(attributes), { segment_shape(p1, p2) }, false)
end

local function make_polygon(points, attributes)
  if #points < 3 then error("polygon requires at least three points") end
  for _, point in ipairs(points) do point_record(point) end
  return ipe.Path(clone_table(attributes), { polygon_shape(points) }, false)
end

local function make_circle(center, radius, attributes)
  point_record(center)
  if not finite_number(radius) or radius <= 0 then error("circle radius must be finite and positive") end
  return ipe.Path(clone_table(attributes), {
    { type = "ellipse"; ipe.Matrix(radius, 0, 0, radius, center.x, center.y) },
  }, false)
end

local function make_mark(point, styles)
  point_record(point)
  return ipe.Reference(clone_table(styles.mark), styles.markshape, point)
end

local function make_text(text_value, point, styles)
  point_record(point)
  local attributes = clone_table(styles.text)
  attributes.horizontalalignment = "hcenter"
  attributes.verticalalignment = "vcenter"
  return ipe.Text(attributes, text_value, point)
end

local TRIANGLE_ID_COUNTER = 0
local function next_triangle_id()
  TRIANGLE_ID_COUNTER = TRIANGLE_ID_COUNTER + 1
  return string.format("t%08x", TRIANGLE_ID_COUNTER)
end

local function encoded_point(point)
  return string.format("%.17g,%.17g", point.x, point.y)
end

local function encoded_source(input)
  return table.concat({ encoded_point(input.a), encoded_point(input.b), encoded_point(input.c) }, "|")
end

local METADATA_FIELD_ORDER = {
  "role", "id", "construction", "kind", "source", "source_fingerprint",
  "reference", "geometry_fingerprint", "count", "trusted",
}

local function metadata_string(fields)
  local parts = { "triangles:v1" }
  for _, key in ipairs(METADATA_FIELD_ORDER) do
    if fields[key] ~= nil then parts[#parts + 1] = key .. "=" .. tostring(fields[key]) end
  end
  return table.concat(parts, ";")
end

local function split_metadata(custom)
  local result = {}
  for token in tostring(custom or ""):gmatch("[^;]+") do result[#result + 1] = token end
  return result
end

local METADATA_ALLOWED = {
  role = true, id = true, construction = true, kind = true, source = true,
  source_fingerprint = true, reference = true, geometry_fingerprint = true,
  count = true, trusted = true,
}

local function parse_metadata(object)
  local tokens = split_metadata(object_custom_value(object))
  local namespace_index, namespace_count = nil, 0
  for index, token in ipairs(tokens) do
    if token:match("^triangles:") then
      namespace_count = namespace_count + 1
      if token ~= "triangles:v1" then error("unsupported Triangles metadata version: " .. token) end
      namespace_index = index
    end
  end
  if namespace_count == 0 then return { status = "absent" } end
  if namespace_count > 1 then error("Triangles metadata namespace is repeated") end
  local fields = {}
  for index = namespace_index + 1, #tokens do
    local token = tokens[index]
    if token:find(":", 1, true) and not token:find("=", 1, true) then break end
    local key, value = token:match("^([^=]+)=(.*)$")
    if not key then error("Triangles metadata contains a malformed field") end
    if not METADATA_ALLOWED[key] then
      error("Triangles metadata contains an unknown field: " .. key)
    end
    if fields[key] ~= nil then error("Triangles metadata repeats the field: " .. key) end
    fields[key] = value
  end
  for _, key in ipairs({
    "role", "id", "construction", "kind", "source", "source_fingerprint",
    "geometry_fingerprint", "trusted",
  }) do
    if not fields[key] or fields[key] == "" then
      error("Triangles metadata is missing field: " .. key)
    end
  end
  if fields.trusted ~= "true" then error("Triangles metadata is not marked as trusted") end
  if fnv1a(fields.source) ~= fields.source_fingerprint then
    error("Triangles metadata has a corrupted source fingerprint")
  end
  local current = object_fingerprint(object)
  return {
    status = current == fields.geometry_fingerprint and "current" or "stale",
    fields = fields,
    current_fingerprint = current,
  }
end

local function attach_metadata(object, fields)
  fields.geometry_fingerprint = object_fingerprint(object)
  if not fields.geometry_fingerprint then error("cannot fingerprint constructed object") end
  local metadata = metadata_string(fields)
  append_object_custom_value(object, metadata)
  return metadata
end

local function register_creation(model, label_value, entries, layer, group_output, common)
  if #entries == 0 then error("construction produced no visible elements") end
  local id = next_triangle_id()
  local source = encoded_source(common.input)
  local source_fingerprint = fnv1a(source)
  local objects = {}
  for _, entry in ipairs(entries) do
    local kinds = entry.kinds or { entry.kind }
    entry.metadata = attach_metadata(entry.object, {
      role = entry.role,
      id = id,
      construction = entry.construction,
      kind = table.concat(kinds, "+"),
      source = source,
      source_fingerprint = source_fingerprint,
      reference = common.reference and encoded_point(common.reference) or nil,
      trusted = "true",
    })
  end
  if group_output and #entries > 1 and type(ipe.Group) == "function" then
    local children = {}
    for _, entry in ipairs(entries) do children[#children + 1] = entry.object end
    local group = ipe.Group(children)
    local group_kind = common.kind or "mixed"
    common.metadata = attach_metadata(group, {
      role = "group", id = id, construction = common.construction,
      kind = group_kind, source = source, source_fingerprint = source_fingerprint,
      reference = common.reference and encoded_point(common.reference) or nil,
      count = #entries, trusted = "true",
    })
    objects[1] = group
  else
    for _, entry in ipairs(entries) do objects[#objects + 1] = entry.object end
    common.metadata = entries[1].metadata
  end
  warn_for_output_layer(model, layer)
  local transaction = {
    label = label_value, pno = model.pno, vno = model.vno,
    object = objects[1], objects = objects, layer = layer,
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
  return objects, common.metadata
end

local function warn_and_return(model, title, message)
  message = clean_error_message(message)
  if model and type(model.warning) == "function" then model:warning(title, message) end
  return {
    created = false, status = "error", operation = nil,
    element_count = 0, created_object_count = 0,
    object_count = model and model.page and #model:page() or 0,
    metadata = nil, result = nil, error = message,
  }
end

local function creator_call(model, title, callback)
  local ok, result = pcall(callback)
  if not ok then return warn_and_return(model, title, result) end
  return result
end

R.construction_styles = construction_styles
R.object_type = object_type
R.object_matrix = object_matrix
R.path_shape = path_shape
R.object_elements = object_elements
R.object_fingerprint = object_fingerprint
R.parse_metadata = parse_metadata
R.selected_objects = selected_objects
R.triangle_path_vertices = triangle_path_vertices
R.resolve_triangle_input = resolve_triangle_input
R.make_segment = make_segment
R.make_polygon = make_polygon
R.make_circle = make_circle
R.make_mark = make_mark
R.make_text = make_text
R.segment_shape = segment_shape
R.polygon_shape = polygon_shape
R.resolve_output_layer = resolve_output_layer
R.register_creation = register_creation
R.warn_and_return = warn_and_return
R.creator_call = creator_call
return R
end)()

----------------------------------------------------------------------
-- Shared construction plan
----------------------------------------------------------------------

local P = (function()
local P = {}
local I = M.internal
local clean_error_message = I.clean_error_message
local finite_number = M.finite_number
local options_table = I.options_table
local validate_keys = I.validate_keys
local positive_number_option = I.positive_number_option
local boolean_option = I.boolean_option
local normalized_name = I.normalized_name
local normalized_center_name = I.normalized_center_name
local point_from_table = M.point_from_table
local point_record = I.point_record
local add, sub, scale = I.add, I.sub, I.scale
local midpoint, dot, perpendicular = I.midpoint, I.dot, I.perpendicular
local length, distance = I.length, I.distance
local scaled_tolerance, unit = I.scaled_tolerance, I.unit
local clone_list = I.clone_list
local triangle_context = I.triangle_context
local world_point, normalized_point = I.world_point, I.normalized_point
local center_state, public_status = I.center_state, I.public_status
local circle_state = I.circle_state
local project_normalized = I.project_normalized
local line_intersection_normalized = I.line_intersection_normalized
local contact_points_normalized = I.contact_points_normalized
local derived_status = I.derived_status
local center_name_list, derived_name_list = M.center_name_list, M.derived_name_list
local construction_styles = R.construction_styles
local resolve_triangle_input = R.resolve_triangle_input
local resolve_output_layer = R.resolve_output_layer
local make_segment, make_polygon = R.make_segment, R.make_polygon
local make_circle, make_mark, make_text = R.make_circle, R.make_mark, R.make_text
local register_creation = R.register_creation
local creator_call = R.creator_call

local CENTER_FEATURE_ALLOWED = {
  mark = true, label = true, auxiliaries = true, cevians = true,
  construction_lines = true, defining_lines = true,
  circle = true, circles = true, contact_marks = true, euler_line = true,
}

local COMBINED_ALLOWED = {
  points = true, a = true, b = true, c = true,
  point = true, point_center = true,
  centers = true, derived = true, center_features = true,
  derived_polygon = true, derived_marks = true, derived_labels = true,
  derived_circle = true, contact_circle = true,
  auxiliary_length = true, group_output = true, output_layer = true,
}

local CENTER_CREATOR_ALLOWED = {
  points = true, a = true, b = true, c = true,
  centers = true, center = true, construction = true,
  mark = true, marks = true, center_marks = true,
  label = true, labels = true, center_labels = true,
  cevians = true, auxiliaries = true, center_auxiliaries = true,
  construction_lines = true, defining_lines = true,
  circle = true, circles = true, center_circles = true,
  euler_line = true,
  auxiliary_length = true, group_output = true, output_layer = true,
}

local DERIVED_CREATOR_ALLOWED = {
  points = true, a = true, b = true, c = true,
  point = true, point_center = true,
  derived = true, operation = true, construction = true,
  polygon = true, derived_polygon = true,
  marks = true, derived_marks = true,
  labels = true, derived_labels = true,
  circle = true, derived_circle = true,
  contact_circle = true, contact_marks = true,
  group_output = true, output_layer = true,
}

local function aliased_value(options, names, context)
  local value, found
  for _, name in ipairs(names) do
    if options[name] ~= nil then
      if found then
        error((context or "options") .. " cannot contain both '" .. found
          .. "' and '" .. name .. "'")
      end
      value, found = options[name], name
    end
  end
  return value
end

local function normalized_contact_circle(value)
  local kind = normalized_name(value or "incircle")
  local aliases = {
    incenter = "incircle", excenter_a = "excircle_a",
    excenter_b = "excircle_b", excenter_c = "excircle_c",
  }
  kind = aliases[kind] or kind
  if kind ~= "incircle" and kind ~= "excircle_a"
      and kind ~= "excircle_b" and kind ~= "excircle_c" then
    error("contact_circle must be incircle, excircle_a, excircle_b, or excircle_c")
  end
  return kind
end

local function normalize_combined_options(raw_options)
  local options = options_table(raw_options)
  validate_keys(options, COMBINED_ALLOWED, "triangle construction options")
  local feature_options = options.center_features or {}
  if type(feature_options) ~= "table" then error("center_features must be a table") end
  validate_keys(feature_options, CENTER_FEATURE_ALLOWED, "center_features")
  local auxiliaries = aliased_value(feature_options,
    { "construction_lines", "defining_lines", "auxiliaries", "cevians" },
    "center_features")
  local circles = aliased_value(feature_options, { "circle", "circles" }, "center_features")
  local normalized = {
    points = options.points, a = options.a, b = options.b, c = options.c,
    point = options.point, point_center = options.point_center,
    centers = center_name_list(options.centers),
    derived = derived_name_list(options.derived),
    center_features = {
      mark = boolean_option(feature_options.mark, true, "center_features.mark"),
      label = boolean_option(feature_options.label, false, "center_features.label"),
      auxiliaries = boolean_option(auxiliaries, false, "center_features.auxiliaries"),
      circle = boolean_option(circles, false, "center_features.circle"),
      contact_marks = boolean_option(
        feature_options.contact_marks, false, "center_features.contact_marks"),
      euler_line = boolean_option(
        feature_options.euler_line, false, "center_features.euler_line"),
    },
    derived_polygon = boolean_option(options.derived_polygon, true, "derived_polygon"),
    derived_marks = boolean_option(options.derived_marks, true, "derived_marks"),
    derived_labels = boolean_option(options.derived_labels, false, "derived_labels"),
    derived_circle = boolean_option(options.derived_circle, false, "derived_circle"),
    contact_circle = normalized_contact_circle(options.contact_circle),
    group_output = boolean_option(options.group_output, true, "group_output"),
    output_layer = normalized_name(options.output_layer or "active"),
  }
  if options.auxiliary_length ~= nil then
    normalized.auxiliary_length = positive_number_option(
      options.auxiliary_length, nil, "auxiliary_length")
  end
  if normalized.point_center ~= nil then
    normalized.point_center = normalized_center_name(normalized.point_center)
    if CENTER_LABELS[normalized.point_center] == nil then
      error("unsupported reference center: " .. normalized.point_center)
    end
  end
  return normalized
end

local function center_wrapper_options(raw_options)
  local options = options_table(raw_options)
  validate_keys(options, CENTER_CREATOR_ALLOWED, "triangle center options")
  local centers = aliased_value(options,
    { "centers", "center", "construction" }, "triangle center options")
  local marks = aliased_value(options,
    { "center_marks", "marks", "mark" }, "triangle center options")
  local labels = aliased_value(options,
    { "center_labels", "labels", "label" }, "triangle center options")
  local auxiliaries = aliased_value(options,
    { "construction_lines", "defining_lines", "center_auxiliaries", "auxiliaries", "cevians" },
    "triangle center options")
  local circles = aliased_value(options,
    { "center_circles", "circles", "circle" }, "triangle center options")
  return {
    points = options.points, a = options.a, b = options.b, c = options.c,
    centers = centers or "centroid",
    center_features = {
      mark = marks, label = labels, auxiliaries = auxiliaries, circle = circles,
      euler_line = options.euler_line,
    },
    auxiliary_length = options.auxiliary_length,
    group_output = options.group_output,
    output_layer = options.output_layer,
  }
end

local function derived_wrapper_options(raw_options)
  local options = options_table(raw_options)
  validate_keys(options, DERIVED_CREATOR_ALLOWED, "triangle-derived options")
  local derived = aliased_value(options,
    { "derived", "operation", "construction" }, "triangle-derived options")
  local polygon = aliased_value(options,
    { "derived_polygon", "polygon" }, "triangle-derived options")
  local marks = aliased_value(options,
    { "derived_marks", "marks" }, "triangle-derived options")
  local labels = aliased_value(options,
    { "derived_labels", "labels" }, "triangle-derived options")
  local circle = aliased_value(options,
    { "derived_circle", "circle" }, "triangle-derived options")
  return {
    points = options.points, a = options.a, b = options.b, c = options.c,
    point = options.point, point_center = options.point_center,
    derived = derived or "medial_triangle",
    center_features = { mark = false },
    derived_polygon = polygon,
    derived_marks = marks,
    derived_labels = labels,
    derived_circle = circle,
    contact_circle = options.contact_circle,
    group_output = options.group_output,
    output_layer = options.output_layer,
  }
end

local function points_near(context, first, second, multiplier)
  local nf = normalized_point(context, first, "geometry point")
  local ns = normalized_point(context, second, "geometry point")
  return distance(nf, ns) <= scaled_tolerance(1, multiplier or 262144)
end

local function radius_near(context, first, second)
  return math.abs(first - second) <= scaled_tolerance(context.world_scale, 262144)
end

local function append_unique(values, value)
  for _, existing in ipairs(values) do if existing == value then return end end
  values[#values + 1] = value
end

local function same_segment(context, first, second)
  return (points_near(context, first.p1, second.p1)
      and points_near(context, first.p2, second.p2))
    or (points_near(context, first.p1, second.p2)
      and points_near(context, first.p2, second.p1))
end

local function same_polygon(context, first, second)
  if #first.points ~= #second.points then return false end
  local count = #first.points
  for offset = 0, count - 1 do
    local forward, reverse = true, true
    for index = 1, count do
      local other = ((index + offset - 1) % count) + 1
      if not points_near(context, first.points[index], second.points[other]) then forward = false end
      local reversed = ((offset - index + 1) % count) + 1
      if not points_near(context, first.points[index], second.points[reversed]) then reverse = false end
    end
    if forward or reverse then return true end
  end
  return false
end

local function merge_specification(existing, specification)
  existing.kinds = existing.kinds or { existing.kind }
  append_unique(existing.kinds, specification.kind)
  if existing.construction ~= specification.construction then existing.construction = "mixed" end
  if existing.role ~= specification.role then existing.role = "combined" end
end

local function add_specification(plan, specification)
  for _, existing in ipairs(plan.specifications) do
    local same = false
    if existing.type == specification.type then
      if specification.type == "segment" then
        same = same_segment(plan.context, existing, specification)
      elseif specification.type == "circle" then
        same = points_near(plan.context, existing.center, specification.center)
          and radius_near(plan.context, existing.radius, specification.radius)
      elseif specification.type == "polygon" then
        same = same_polygon(plan.context, existing, specification)
      elseif specification.type == "mark" then
        same = points_near(plan.context, existing.point, specification.point)
      elseif specification.type == "text" then
        same = existing.text == specification.text
          and points_near(plan.context, existing.point, specification.point)
      end
    end
    if same then merge_specification(existing, specification); return existing end
  end
  specification.kinds = specification.kinds or { specification.kind }
  plan.specifications[#plan.specifications + 1] = specification
  return specification
end

local function add_issue(plan, category, name, status, reason)
  local key = table.concat({ category or "", name or "", status or "", reason or "" }, "|")
  if plan.issue_keys[key] then return end
  plan.issue_keys[key] = true
  plan.issues[#plan.issues + 1] = {
    category = category, name = name, status = status, reason = reason,
  }
end

local function point_segment_distance(point, first, second)
  local direction = sub(second, first)
  local squared = dot(direction, direction)
  if squared == 0 then return distance(point, first) end
  local parameter = dot(sub(point, first), direction) / squared
  parameter = math.max(0, math.min(1, parameter))
  return distance(point, add(first, scale(direction, parameter)))
end

local function geometry_clearance(plan, point)
  local clearance = math.huge
  local vertices = { plan.input.a, plan.input.b, plan.input.c }
  for index = 1, 3 do
    local next_index = index == 3 and 1 or index + 1
    clearance = math.min(clearance,
      point_segment_distance(point, vertices[index], vertices[next_index]))
    clearance = math.min(clearance, distance(point, vertices[index]))
  end
  local reference = plan.reference or plan.input.reference or plan.options.point
  if reference then clearance = math.min(clearance, distance(point, reference)) end
  for _, state in pairs(plan.center_states or {}) do
    if state.point then clearance = math.min(clearance, distance(point, state.point)) end
  end
  for _, state in pairs(plan.derived_states or {}) do
    for _, derived_point in ipairs(state.points or {}) do
      clearance = math.min(clearance, distance(point, derived_point))
    end
  end
  for _, specification in ipairs(plan.specifications) do
    if specification.type == "segment" then
      clearance = math.min(clearance,
        point_segment_distance(point, specification.p1, specification.p2))
    elseif specification.type == "circle" then
      clearance = math.min(clearance,
        math.abs(distance(point, specification.center) - specification.radius))
    elseif specification.type == "polygon" then
      for index = 1, #specification.points do
        local next_index = index == #specification.points and 1 or index + 1
        clearance = math.min(clearance, point_segment_distance(
          point, specification.points[index], specification.points[next_index]))
      end
    elseif specification.type == "mark" then
      clearance = math.min(clearance, distance(point, specification.point))
    end
  end
  return clearance
end

local TEXT_SIZE_FACTORS = {
  tiny = 0.5, script = 0.7, footnote = 0.8, small = 0.9,
  normal = 1, large = 1.2, Large = 1.44, LARGE = 1.73,
  huge = 2.07, Huge = 2.49,
}

local function model_label_scale(model)
  local value = model and type(model.attributes) == "table"
    and model.attributes.textsize or nil
  if type(value) == "number" and finite_number(value) and value > 0 then
    return math.max(0.5, math.min(3, value / 10))
  end
  return TEXT_SIZE_FACTORS[value] or 1
end

local function label_extent(label_value, step)
  local text_value = tostring(label_value or "")
  local visible = text_value:gsub("\\[A-Za-z]+", "X"):gsub("[{}_^]", "")
  local half_width = math.max(step * 0.28, math.min(step * 1.35, #visible * step * 0.13))
  return half_width, step * 0.34
end

local function label_position(plan, point, label_value)
  local step = math.max(8, math.min(16, plan.context.world_scale * 0.035))
    * (plan.label_scale or 1)
  if not finite_number(step) then step = 10 end
  local half_width, half_height = label_extent(label_value, step)
  local centroid = V(
    (plan.input.a.x + plan.input.b.x + plan.input.c.x) / 3,
    (plan.input.a.y + plan.input.b.y + plan.input.c.y) / 3)
  local outward = sub(point, centroid)
  local outward_length = length(outward)
  if outward_length > 0 then outward = scale(outward, 1 / outward_length) else outward = nil end

  local best, best_score
  for ring = 1, 3 do
    local radius = step * (0.85 + 0.32 * ring) + half_width * 0.2
    for index = 0, 15 do
      local angle = index * math.pi / 8
      local direction = V(math.cos(angle), math.sin(angle))
      local candidate = add(point, scale(direction, radius))
      if finite_number(candidate.x) and finite_number(candidate.y) then
        local score = math.min(
          geometry_clearance(plan, candidate) - half_height,
          step * 0.8)
        for _, occupied in ipairs(plan.label_positions) do
          local required = math.max(half_height + occupied.half_height,
            half_width + occupied.half_width)
          score = math.min(score, distance(candidate, occupied.point) - required)
        end
        if outward then score = score + dot(direction, outward) * step * 0.12 end
        score = score - (ring - 1) * step * 0.35
        if not best or score > best_score then best, best_score = candidate, score end
      end
    end
  end
  best = best or point
  plan.label_positions[#plan.label_positions + 1] = {
    point = best, half_width = half_width, half_height = half_height,
  }
  return best
end

local function combined_center_label(names)
  local labels = {}
  for _, name in ipairs(names) do labels[#labels + 1] = CENTER_LABELS[name] or name end
  return table.concat(labels, "=")
end

local function add_mark_and_label(plan, point, label_value, role, construction, kind,
    marks, labels)
  if marks then
    add_specification(plan, {
      type = "mark", point = point, role = role or "mark",
      construction = construction, kind = kind,
    })
  end
  if labels then
    add_specification(plan, {
      type = "text", point = label_position(plan, point, label_value),
      text = "$" .. label_value .. "$", role = "label",
      construction = construction, kind = kind,
    })
  end
end

local function normalized_segment_to_world(context, p1, p2)
  local first, second = world_point(context, p1), world_point(context, p2)
  if not first or not second then return nil end
  return first, second
end

local function cevian_normalized(vertex, center, opposite_a, opposite_b)
  if distance(vertex, center) <= scaled_tolerance(1, 262144) then return nil end
  local foot = line_intersection_normalized(vertex, center, opposite_a, opposite_b)
  return foot and { p1 = vertex, p2 = foot } or nil
end

local function add_normalized_segment(plan, p1, p2, role, construction, kind, style)
  local first, second = normalized_segment_to_world(plan.context, p1, p2)
  if not first or not second then
    add_issue(plan, "geometry", kind, "ill_conditioned",
      kind .. " lies outside the representable coordinate range")
    return
  end
  add_specification(plan, {
    type = "segment", p1 = first, p2 = second, role = role,
    construction = construction, kind = kind, style = style or "path",
  })
end

local function center_auxiliaries(plan, name, state, minimum_world_length)
  local context = plan.context
  local line_kind = CENTER_DEFINING_LINES[name]
  if not line_kind then return false end
  local triples = {
    { context.a, context.b, context.c, "a" },
    { context.b, context.c, context.a, "b" },
    { context.c, context.a, context.b, "c" },
  }
  if line_kind == "median" then
    for _, values in ipairs(triples) do
      add_normalized_segment(plan, values[1], midpoint(values[2], values[3]),
        "median", "center", name .. "_median_" .. values[4], "dashed")
    end
  elseif line_kind == "altitude" then
    for _, values in ipairs(triples) do
      add_normalized_segment(plan, values[1], project_normalized(values[1], values[2], values[3]),
        "altitude", "center", name .. "_altitude_" .. values[4], "dashed")
    end
  elseif line_kind == "perpendicular_bisector" then
    local triangle_centroid = scale(add(add(context.a, context.b), context.c), 1 / 3)
    local sides = {
      { context.b, context.c, "a" }, { context.c, context.a, "b" },
      { context.a, context.b, "c" },
    }
    for _, side in ipairs(sides) do
      local middle = midpoint(side[1], side[2])
      local endpoint = state.normalized
      local delta = sub(endpoint, middle)
      local current_length = length(delta)
      local requested_length = minimum_world_length
        and minimum_world_length / context.world_scale or nil
      if current_length <= scaled_tolerance(1, 262144) then
        local direction = unit(perpendicular(sub(side[2], side[1])), "perpendicular bisector")
        if dot(direction, sub(triangle_centroid, middle)) < 0 then
          direction = scale(direction, -1)
        end
        endpoint = add(middle, scale(direction, requested_length or 0.35))
      elseif requested_length and current_length < requested_length then
        endpoint = add(middle, scale(delta, requested_length / current_length))
      end
      add_normalized_segment(plan, middle, endpoint,
        "perpendicular_bisector", "center",
        name .. "_bisector_" .. side[3], "dashed")
    end
  elseif line_kind == "angle_bisector" then
    for _, values in ipairs(triples) do
      add_normalized_segment(plan, values[1], state.normalized,
        "angle_bisector", "center", name .. "_angle_bisector_" .. values[4], "dashed")
    end
  else
    for _, values in ipairs(triples) do
      local segment = cevian_normalized(values[1], state.normalized, values[2], values[3])
      if segment then
        add_normalized_segment(plan, segment.p1, segment.p2, line_kind, "center",
          name .. "_cevian_" .. values[4], "dashed")
      end
    end
  end
  return true
end

local CENTER_CIRCLE_KIND = {
  nine_point_center = "nine_point_circle",
}

local function add_circle_specification(plan, circle, construction, kind)
  if circle.status ~= "finite" then
    add_issue(plan, "circle", kind, circle.status, circle.reason)
    return nil
  end
  return add_specification(plan, {
    type = "circle", center = circle.center, radius = circle.radius,
    role = "circle", construction = construction, kind = kind,
    style = kind == "nine_point_circle" and "dotted" or "path",
  })
end

local function add_contact_marks(plan, raw_kind, construction)
  local ok, normalized_or_error, circle = pcall(contact_points_normalized,
    plan.context, raw_kind)
  if not ok then
    add_issue(plan, "contact", raw_kind, "undefined", clean_error_message(normalized_or_error))
    return
  end
  for index, normalized in ipairs(normalized_or_error) do
    local point = world_point(plan.context, normalized)
    if point then
      add_specification(plan, {
        type = "mark", point = point, role = "contact",
        construction = construction, kind = circle.kind .. "_contact_" .. tostring(index),
      })
    end
  end
end

local function add_center_outputs(plan, options)
  local features = options.center_features
  local finite_centers = {}
  local circle_added = false
  for _, name in ipairs(options.centers) do
    local state = center_state(plan.context, name)
    plan.center_states[name] = public_status(state)
    if state.status == "finite" then
      finite_centers[#finite_centers + 1] = { name = name, state = state }
      plan.finite_center_count = plan.finite_center_count + 1
      if features.auxiliaries then
        center_auxiliaries(plan, name, state, options.auxiliary_length)
      end
      local circle_kind = CENTER_CIRCLE_KIND[name]
      if features.circle and circle_kind then
        add_circle_specification(plan, circle_state(plan.context, circle_kind), "center", circle_kind)
        circle_added = true
      end
    else
      add_issue(plan, "center", name, state.status, state.reason)
    end
  end

  if features.circle and not circle_added then
    add_issue(plan, "feature", "nine_point_circle", "not_applicable",
      "the nine-point circle requires the nine-point center")
  end

  local groups = {}
  for _, entry in ipairs(finite_centers) do
    local group
    for _, candidate in ipairs(groups) do
      if points_near(plan.context, candidate.point, entry.state.point) then group = candidate; break end
    end
    if not group then
      group = { point = entry.state.point, names = {} }
      groups[#groups + 1] = group
    end
    group.names[#group.names + 1] = entry.name
  end
  for _, group in ipairs(groups) do
    if #group.names > 1 then
      add_issue(plan, "overlap", table.concat(group.names, ","), "coincident",
        tostring(#group.names) .. " requested centers coincide at one point")
    end
    add_mark_and_label(plan, group.point, combined_center_label(group.names),
      "center", "center", table.concat(group.names, "+"),
      features.mark, features.label)
  end

  if features.euler_line then
    local circum = center_state(plan.context, "circumcenter")
    local orthocenter = center_state(plan.context, "orthocenter")
    if circum.status == "finite" and orthocenter.status == "finite" then
      local direction = sub(orthocenter.normalized, circum.normalized)
      local magnitude = length(direction)
      if magnitude <= scaled_tolerance(1, 262144) then
        add_issue(plan, "line", "euler_line", "undefined",
          "Euler line is not unique because O and H coincide")
      else
        local normalized_direction = scale(direction, 1 / magnitude)
        add_normalized_segment(plan,
          sub(circum.normalized, scale(normalized_direction, 0.25)),
          add(orthocenter.normalized, scale(normalized_direction, 0.25)),
          "euler_line", "center", "euler_line", "dashed")
      end
    else
      add_issue(plan, "line", "euler_line", "undefined",
        "Euler line requires finite circumcenter and orthocenter")
    end
  end
end

local POLYGON_DERIVED = {
  medial_triangle = true, orthic_triangle = true, contact_triangle = true,
  excentral_triangle = true, pedal_triangle = true, cevian_endpoints = true,
}

local function add_derived_outputs(plan, options, input)
  local derived_options = {
    contact_circle = options.contact_circle,
    point = options.point or input.reference,
    point_center = options.point_center,
  }
  if derived_options.point ~= nil and derived_options.point_center ~= nil then
    error("selected reference point cannot be combined with point_center")
  end
  for _, name in ipairs(options.derived) do
    local ok, result = pcall(derived_status, plan.context, name, derived_options)
    if not ok then
      result = { status = "undefined", kind = name, points = {},
        reason = clean_error_message(result) }
    end
    plan.derived_states[name] = {
      status = result.status, kind = result.kind, reason = result.reason,
      points = {}, labels = result.labels and clone_list(result.labels) or {},
    }
    for _, point in ipairs(result.points or {}) do
      plan.derived_states[name].points[#plan.derived_states[name].points + 1] = point_record(point)
    end
    if result.reference_point then
      plan.derived_states[name].reference_point = point_record(result.reference_point)
      plan.reference = plan.reference or result.reference_point
    end
    if result.status ~= "finite" then
      add_issue(plan, "derived", name, result.status, result.reason)
    else
      plan.finite_derived_count = plan.finite_derived_count + 1
      if options.derived_polygon and POLYGON_DERIVED[name] and #result.points >= 3 then
        add_specification(plan, {
          type = "polygon", points = result.points, role = "polygon",
          construction = "derived", kind = name,
        })
      end
      if options.derived_circle then
        if name == "nine_point_points" then
          add_circle_specification(plan, circle_state(plan.context, "nine_point_circle"),
            "derived", "nine_point_circle")
        elseif name == "contact_triangle" then
          add_circle_specification(plan, circle_state(plan.context, options.contact_circle),
            "derived", options.contact_circle)
        else
          add_issue(plan, "feature", name, "not_applicable",
            DERIVED_TITLES[name] .. " has no associated circle")
        end
      end
      for index, point in ipairs(result.points) do
        add_mark_and_label(plan, point, result.labels[index] or ("P_" .. tostring(index)),
          "derived_point", "derived", name .. "_point_" .. tostring(index),
          options.derived_marks, options.derived_labels)
      end
      if options.center_features.contact_marks and name == "contact_triangle" then
        add_contact_marks(plan, options.contact_circle, "derived")
      end
    end
  end
end

local function plan_requires_reference(derived_names)
  for _, name in ipairs(derived_names) do
    if DERIVED_REQUIRES_POINT[name] then return true end
  end
  return false
end

local function build_construction_plan(model, raw_options)
  local options = normalize_combined_options(raw_options)
  if #options.centers == 0 and #options.derived == 0 then
    error("select at least one center or derived construction")
  end
  local requires_reference = plan_requires_reference(options.derived)
  local input = resolve_triangle_input(model, options, requires_reference)
  if requires_reference and options.point == nil and options.point_center == nil
      and input.reference == nil then
    error("the selected derived construction requires a reference point; select one extra mark, choose point_center, or pass point")
  end
  local context = triangle_context(input.a, input.b, input.c)
  local plan = {
    options = options, input = input, context = context,
    layer = resolve_output_layer(model, input, options.output_layer),
    label_scale = model_label_scale(model),
    specifications = {}, label_positions = {}, issues = {}, issue_keys = {},
    center_states = {}, derived_states = {},
    finite_center_count = 0, finite_derived_count = 0,
  }
  add_center_outputs(plan, options)
  add_derived_outputs(plan, options, input)
  if #plan.specifications == 0 then
    local reason = plan.issues[1] and plan.issues[1].reason
      or "selected options produced no visible elements"
    error(reason)
  end
  return plan
end

local function render_plan(plan, styles)
  local entries = {}
  for _, specification in ipairs(plan.specifications) do
    local attributes = styles[specification.style or "path"] or styles.path
    local object
    if specification.type == "segment" then
      object = make_segment(specification.p1, specification.p2, attributes)
    elseif specification.type == "circle" then
      object = make_circle(specification.center, specification.radius, attributes)
    elseif specification.type == "polygon" then
      object = make_polygon(specification.points, attributes)
    elseif specification.type == "mark" then
      object = make_mark(specification.point, styles)
    elseif specification.type == "text" then
      object = make_text(specification.text, specification.point, styles)
    else
      error("unsupported construction specification: " .. tostring(specification.type))
    end
    entries[#entries + 1] = {
      object = object,
      role = specification.role,
      construction = specification.construction,
      kind = specification.kind,
      kinds = clone_list(specification.kinds),
    }
  end
  return entries
end

local function issue_summary(issues)
  if #issues == 0 then return nil end
  local lines, limit = {}, math.min(#issues, 8)
  for index = 1, limit do
    local issue = issues[index]
    lines[#lines + 1] = "- " .. tostring(issue.name or issue.category)
      .. ": " .. tostring(issue.reason or issue.status)
  end
  if #issues > limit then
    lines[#lines + 1] = "- " .. tostring(#issues - limit) .. " additional notices"
  end
  return table.concat(lines, "\n")
end

local function create_from_combined_options(model, raw_options, operation, transaction_label)
  local plan = build_construction_plan(model, raw_options)
  local entries = render_plan(plan, construction_styles(model))
  local common = {
    input = plan.input,
    reference = plan.reference or plan.input.reference or plan.options.point,
    construction = operation,
    kind = #plan.options.centers > 0 and #plan.options.derived > 0 and "mixed"
      or (#plan.options.centers > 0 and "centers" or "derived"),
  }
  if common.reference then common.reference = point_from_table(common.reference, "reference") end
  local objects, metadata = register_creation(
    model, transaction_label, entries, plan.layer, plan.options.group_output, common)
  local notice = issue_summary(plan.issues)
  if notice and model and type(model.warning) == "function" then
    model:warning("Triangles construction notices", notice)
  end
  local entry_records = {}
  for _, entry in ipairs(entries) do
    entry_records[#entry_records + 1] = {
      role = entry.role, construction = entry.construction,
      kinds = clone_list(entry.kinds), metadata = entry.metadata,
    }
  end
  return {
    created = true, status = "created", operation = operation,
    element_count = #entries, created_object_count = #objects,
    object_count = #model:page(), metadata = metadata,
    center_count = plan.finite_center_count,
    derived_count = plan.finite_derived_count,
    result = {
      centers = plan.center_states,
      derived = plan.derived_states,
      entries = entry_records,
      issues = plan.issues,
      source_kind = plan.input.source_kind,
      vertex_order = plan.input.vertex_order,
      output_layer = plan.layer,
      grouped = plan.options.group_output and #entries > 1 and type(ipe.Group) == "function",
    },
  }
end

local function create_triangle_constructions(model, raw_options)
  return creator_call(model, "Cannot create triangle constructions", function()
    return create_from_combined_options(
      model, raw_options, "triangle_constructions", "create triangle constructions")
  end)
end

local function create_triangle_centers(model, raw_options)
  return creator_call(model, "Cannot create triangle centers", function()
    local combined = center_wrapper_options(raw_options)
    return create_from_combined_options(
      model, combined, "triangle_centers", "create triangle centers")
  end)
end

local function create_triangle_derived(model, raw_options)
  return creator_call(model, "Cannot create triangle-derived construction", function()
    local combined = derived_wrapper_options(raw_options)
    return create_from_combined_options(
      model, combined, "triangle_derived", "create triangle-derived construction")
  end)
end

P.normalize_options = normalize_combined_options
P.build_construction_plan = build_construction_plan
P.render_plan = render_plan
P.polygon_derived = POLYGON_DERIVED
P.create_triangle_constructions = create_triangle_constructions
P.create_triangle_centers = create_triangle_centers
P.create_triangle_derived = create_triangle_derived
return P
end)()

----------------------------------------------------------------------
-- Live preview
----------------------------------------------------------------------

local Preview = (function()
local Preview = {}
local I = M.internal
local clean_error_message = I.clean_error_message
local options_table = I.options_table
local finite_number = M.finite_number
local selected_objects = R.selected_objects
local object_type = R.object_type
local object_fingerprint = R.object_fingerprint
local segment_shape = R.segment_shape
local polygon_shape = R.polygon_shape
local build_construction_plan = P.build_construction_plan

local function append_shape(shapes, shape)
  if shape then shapes[#shapes + 1] = shape end
end

local function preview_shapes_for_specification(specification)
  local shapes = {}
  if specification.type == "segment" then
    append_shape(shapes, segment_shape(specification.p1, specification.p2))
  elseif specification.type == "circle" then
    append_shape(shapes, {
      type = "ellipse";
      ipe.Matrix(specification.radius, 0, 0, specification.radius,
        specification.center.x, specification.center.y),
    })
  elseif specification.type == "polygon" then
    append_shape(shapes, polygon_shape(specification.points))
  elseif specification.type == "mark" then
    local point = specification.point
    local half = 3
    append_shape(shapes, segment_shape(V(point.x - half, point.y), V(point.x + half, point.y)))
    append_shape(shapes, segment_shape(V(point.x, point.y - half), V(point.x, point.y + half)))
  elseif specification.type == "text" then
    local point = specification.point
    append_shape(shapes, segment_shape(V(point.x, point.y), V(point.x + 7, point.y)))
    append_shape(shapes, segment_shape(V(point.x, point.y), V(point.x, point.y + 5)))
  end
  return shapes
end

local function preview_shape_data(model, raw_options)
  local plan = build_construction_plan(model, raw_options)
  local shapes = {}
  for _, specification in ipairs(plan.specifications) do
    for _, shape in ipairs(preview_shapes_for_specification(specification)) do
      shapes[#shapes + 1] = shape
    end
  end
  return {
    shapes = shapes,
    shape_count = #shapes,
    element_count = #plan.specifications,
    center_count = plan.finite_center_count,
    derived_count = plan.finite_derived_count,
    issues = plan.issues,
    center_states = plan.center_states,
    derived_states = plan.derived_states,
  }
end

local function preview_shapes(model, raw_options)
  return preview_shape_data(model, raw_options).shapes
end

local function signature_value(parts, prefix, value, depth)
  depth = depth or 0
  if type(value) ~= "table" or depth > 6 then
    if type(value) == "number" then
      parts[#parts + 1] = prefix .. "=" .. string.format("%.17g", value)
    else
      parts[#parts + 1] = prefix .. "=" .. tostring(value)
    end
    return
  end
  if finite_number(value.x) and finite_number(value.y) then
    parts[#parts + 1] = prefix .. "=" .. string.format("%.17g,%.17g", value.x, value.y)
    return
  end
  for index, item in ipairs(value) do
    signature_value(parts, prefix .. "[" .. tostring(index) .. "]", item, depth + 1)
  end
  local keys = {}
  for key, _ in pairs(value) do if type(key) ~= "number" then keys[#keys + 1] = key end end
  table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
  for _, key in ipairs(keys) do
    signature_value(parts, prefix .. "." .. tostring(key), value[key], depth + 1)
  end
end

local function selection_signature(model)
  local parts = {}
  local ok, entries = pcall(selected_objects, model)
  if not ok then return "unavailable" end
  for _, entry in ipairs(entries) do
    parts[#parts + 1] = tostring(entry.index) .. ":" .. tostring(entry.selection)
      .. ":" .. tostring(entry.layer) .. ":" .. tostring(object_type(entry.object))
    local fingerprint = object_fingerprint(entry.object)
    parts[#parts + 1] = fingerprint or "unavailable"
  end
  return table.concat(parts, "|")
end

local function preview_signature(model, raw_options)
  local parts = { selection_signature(model) }
  local options = options_table(raw_options)
  local keys = {}
  for key, _ in pairs(options) do keys[#keys + 1] = key end
  table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
  for _, key in ipairs(keys) do signature_value(parts, tostring(key), options[key], 0) end
  return table.concat(parts, "|")
end

local PREVIEW_TOOL = {}
PREVIEW_TOOL.__index = PREVIEW_TOOL

function PREVIEW_TOOL:new(model)
  local tool = setmetatable({ model = model, active = true }, PREVIEW_TOOL)
  model.ui:shapeTool(tool)
  if tool.setColor then tool.setColor(0.10, 0.45, 0.95) end
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
function PREVIEW_TOOL:key(text_value) return text_value == "\027" end

local function start_dialog_preview(model, dialog, read_options, update_controls)
  if not model.ui or not model.ui.shapeTool then return nil end
  local preview = {
    active = true, live = true, last_signature = nil,
    tool = PREVIEW_TOOL:new(model),
  }
  local function explain(message)
    if model.ui and type(model.ui.explain) == "function" then model.ui:explain(message) end
  end
  local function update(force)
    if not preview.active then return end
    if update_controls then pcall(update_controls) end
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
      explain("Triangles preview: " .. clean_error_message(options))
      return
    end
    local signature = preview_signature(model, options)
    if not force and signature == preview.last_signature then return end
    preview.last_signature = signature
    local ok_shapes, data = pcall(preview_shape_data, model, options)
    if ok_shapes then
      preview.tool:update(data.shapes)
      if force then explain("Triangles preview updated.") end
    else
      preview.tool:update({})
      explain("Triangles preview: " .. clean_error_message(data))
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

Preview.preview_shape_data = preview_shape_data
Preview.preview_shapes = preview_shapes
Preview.preview_signature = preview_signature
Preview.start_dialog_preview = start_dialog_preview
return Preview
end)()

----------------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------------

local D = (function()
local D = {}
local I = M.internal
local clean_error_message = I.clean_error_message
local options_table = I.options_table
local validate_keys = I.validate_keys
local warn_and_return = R.warn_and_return
local creator_call = R.creator_call
local selected_objects = R.selected_objects
local parse_metadata = R.parse_metadata
local object_type = R.object_type
local object_elements = R.object_elements
local create_triangle_constructions = P.create_triangle_constructions
local start_dialog_preview = Preview.start_dialog_preview
local POLYGON_DERIVED = P.polygon_derived
local dialog_state = PERSISTED_DIALOG_STATE
if type(dialog_state.centers) ~= "table" then dialog_state.centers = {} end
if type(dialog_state.derived) ~= "table" then dialog_state.derived = {} end

local CENTER_DIALOG_PRESETS = {
  [2] = "preset_fundamental",
  [3] = "preset_contact_cevian",
  [4] = "preset_euler_line",
  [5] = "preset_isogonal_napoleon",
}

local function safe_set_enabled(dialog, name, enabled)
  pcall(function() dialog:setEnabled(name, enabled) end)
end

local function execute_dialog(model, dialog, preview, read_options, callback)
  local ok_execute, accepted = pcall(function() return dialog:execute() end)
  if preview then preview.stop() end
  if not ok_execute then
    return warn_and_return(model, "Triangles dialog failed", accepted)
  end
  if not accepted then return false end
  local ok_options, options = pcall(read_options)
  if not ok_options then return warn_and_return(model, "Invalid Triangles options", options) end
  return callback(options)
end

local function centers_dialog(model)
  local state = dialog_state.centers
  local dialog = ipeui.Dialog(model.ui:win(), "Triangle centers")
  local preview
  dialog:add("selection_help", "label", {
    label = "Select one triangle path, three vertex marks, or three side segments.",
  }, 1, 1, 1, 3)
  dialog:add("preset_label", "label", { label = "Center set" }, 2, 1)
  dialog:add("preset", "combo", {
    "Individual selection", "Fundamental centers", "Contact / Cevian centers",
    "Euler-line centers", "Isogonal / Napoleon centers",
  }, 2, 2, 1, 2)

  for index, definition in ipairs(CENTER_DEFINITIONS) do
    local row = 3 + math.floor((index - 1) / 3)
    local column = ((index - 1) % 3) + 1
    dialog:add("center_" .. definition.name, "checkbox", {
      label = definition.title,
    }, row, column)
  end

  local output_row = 11
  dialog:add("output_title", "label", { label = "Output" }, output_row, 1, 1, 3)
  dialog:add("marks", "checkbox", { label = "Center marks" }, output_row + 1, 1)
  dialog:add("labels", "checkbox", { label = "Labels" }, output_row + 1, 2)
  dialog:add("auxiliaries", "checkbox", { label = "Defining lines" }, output_row + 1, 3)
  dialog:add("circles", "checkbox", { label = "Nine-point circle" }, output_row + 2, 1)
  dialog:add("euler_line", "checkbox", { label = "Euler line" }, output_row + 2, 2)
  dialog:add("group_output", "checkbox", { label = "Group output" }, output_row + 2, 3)
  dialog:add("layer_label", "label", { label = "Output layer" }, output_row + 3, 1)
  dialog:add("output_layer", "combo", { "Active layer", "Triangle source layer" },
    output_row + 3, 2, 1, 2)
  dialog:add("live_preview", "checkbox", { label = "Live preview" }, output_row + 4, 1)

  dialog:set("preset", state.preset or 1)
  for _, definition in ipairs(CENTER_DEFINITIONS) do
    local selected = state.selected and state.selected[definition.name]
    if selected == nil then selected = definition.name == "centroid" end
    dialog:set("center_" .. definition.name, selected)
  end
  dialog:set("marks", state.marks ~= false)
  dialog:set("labels", state.labels == true)
  dialog:set("auxiliaries", state.auxiliaries == true)
  dialog:set("circles", state.circles == true)
  dialog:set("euler_line", state.euler_line == true)
  dialog:set("group_output", state.group_output ~= false)
  dialog:set("output_layer", state.output_layer or 1)
  dialog:set("live_preview", state.live_preview ~= false)

  local function update_controls()
    local individual = dialog:get("preset") == 1
    for _, definition in ipairs(CENTER_DEFINITIONS) do
      safe_set_enabled(dialog, "center_" .. definition.name, individual)
    end
    local preset = dialog:get("preset")
    local requested = {}
    if CENTER_DIALOG_PRESETS[preset] then
      requested = M.center_name_list(CENTER_DIALOG_PRESETS[preset])
    else
      for _, definition in ipairs(CENTER_DEFINITIONS) do
        if dialog:get("center_" .. definition.name) then requested[#requested + 1] = definition.name end
      end
    end
    local lines_capable, circle_capable = false, false
    for _, name in ipairs(requested) do
      if CENTER_DEFINING_LINES[name] then lines_capable = true end
      if name == "nine_point_center" then circle_capable = true end
    end
    safe_set_enabled(dialog, "auxiliaries", lines_capable)
    safe_set_enabled(dialog, "circles", circle_capable)
  end

  local function read_options()
    local preset = dialog:get("preset")
    local centers = {}
    if CENTER_DIALOG_PRESETS[preset] then
      centers = { CENTER_DIALOG_PRESETS[preset] }
    else
      for _, definition in ipairs(CENTER_DEFINITIONS) do
        if dialog:get("center_" .. definition.name) then centers[#centers + 1] = definition.name end
      end
    end
    local lines_capable, circle_capable = false, false
    for _, name in ipairs(M.center_name_list(centers)) do
      if CENTER_DEFINING_LINES[name] then lines_capable = true end
      if name == "nine_point_center" then circle_capable = true end
    end
    return {
      centers = centers,
      center_features = {
        mark = dialog:get("marks"), label = dialog:get("labels"),
        auxiliaries = lines_capable and dialog:get("auxiliaries") or false,
        circle = circle_capable and dialog:get("circles") or false,
        euler_line = dialog:get("euler_line"),
      },
      group_output = dialog:get("group_output"),
      output_layer = dialog:get("output_layer") == 2 and "source" or "active",
    }
  end

  dialog:addButton("cancel", "&Cancel", "reject")
  dialog:addButton("preview", "&Preview", function() if preview then preview.update(true) end end)
  dialog:addButton("create", "&Create", "accept")
  update_controls()
  preview = start_dialog_preview(model, dialog, read_options, update_controls)
  return execute_dialog(model, dialog, preview, read_options, function(options)
    state.preset = dialog:get("preset")
    state.selected = {}
    for _, definition in ipairs(CENTER_DEFINITIONS) do
      state.selected[definition.name] = dialog:get("center_" .. definition.name)
    end
    state.marks, state.labels = dialog:get("marks"), dialog:get("labels")
    state.auxiliaries, state.circles = dialog:get("auxiliaries"), dialog:get("circles")
    state.euler_line = dialog:get("euler_line")
    state.group_output, state.output_layer = dialog:get("group_output"), dialog:get("output_layer")
    state.live_preview = dialog:get("live_preview")
    return create_triangle_constructions(model, options)
  end)
end

local POINT_SOURCE_CENTERS = {
  [2] = "centroid", [3] = "incenter", [4] = "circumcenter",
  [5] = "orthocenter", [6] = "symmedian_point",
}

local function derived_dialog(model)
  local state = dialog_state.derived
  local dialog = ipeui.Dialog(model.ui:win(), "Triangle-derived construction")
  local preview
  local operation_titles = {}
  for _, definition in ipairs(DERIVED_DEFINITIONS) do operation_titles[#operation_titles + 1] = definition.title end
  dialog:add("selection_help", "label", {
    label = "Select a triangle path, three vertex marks, or three side segments.",
  }, 1, 1, 1, 2)
  dialog:add("operation_label", "label", { label = "Construction" }, 2, 1)
  dialog:add("operation", "combo", operation_titles, 2, 2)
  dialog:add("point_source_label", "label", { label = "Reference point" }, 3, 1)
  dialog:add("point_source", "combo", {
    "Selected extra mark", "Centroid", "Incenter", "Circumcenter",
    "Orthocenter", "Symmedian point", "Coordinates",
  }, 3, 2)
  dialog:add("point_x_label", "label", { label = "Reference X" }, 4, 1)
  dialog:add("point_x", "input", {}, 4, 2)
  dialog:add("point_y_label", "label", { label = "Reference Y" }, 5, 1)
  dialog:add("point_y", "input", {}, 5, 2)
  dialog:add("contact_circle_label", "label", { label = "Contact circle" }, 6, 1)
  dialog:add("contact_circle", "combo", {
    "Incircle", "Excircle A", "Excircle B", "Excircle C",
  }, 6, 2)
  dialog:add("polygon", "checkbox", { label = "Polygon / connecting lines" }, 7, 1)
  dialog:add("marks", "checkbox", { label = "Point marks" }, 7, 2)
  dialog:add("labels", "checkbox", { label = "Semantic labels" }, 8, 1)
  dialog:add("circle", "checkbox", { label = "Associated circle" }, 8, 2)
  dialog:add("contact_marks", "checkbox", { label = "Contact marks" }, 9, 1)
  dialog:add("group_output", "checkbox", { label = "Group output" }, 9, 2)
  dialog:add("output_layer_label", "label", { label = "Output layer" }, 10, 1)
  dialog:add("output_layer", "combo", { "Active layer", "Triangle source layer" }, 10, 2)
  dialog:add("live_preview", "checkbox", { label = "Live preview" }, 11, 1, 1, 2)

  dialog:set("operation", state.operation or 1)
  dialog:set("point_source", state.point_source or 1)
  dialog:set("point_x", state.point_x or "0")
  dialog:set("point_y", state.point_y or "0")
  dialog:set("contact_circle", state.contact_circle or 1)
  dialog:set("polygon", state.polygon ~= false)
  dialog:set("marks", state.marks ~= false)
  dialog:set("labels", state.labels == true)
  dialog:set("circle", state.circle == true)
  dialog:set("contact_marks", state.contact_marks == true)
  dialog:set("group_output", state.group_output ~= false)
  dialog:set("output_layer", state.output_layer or 1)
  dialog:set("live_preview", state.live_preview ~= false)

  local function selected_operation()
    return DERIVED_DEFINITIONS[dialog:get("operation")].name
  end

  local function update_controls()
    local operation = selected_operation()
    local requires_point = DERIVED_REQUIRES_POINT[operation] == true
    local coordinate_source = requires_point and dialog:get("point_source") == 7
    safe_set_enabled(dialog, "point_source_label", requires_point)
    safe_set_enabled(dialog, "point_source", requires_point)
    safe_set_enabled(dialog, "point_x_label", coordinate_source)
    safe_set_enabled(dialog, "point_x", coordinate_source)
    safe_set_enabled(dialog, "point_y_label", coordinate_source)
    safe_set_enabled(dialog, "point_y", coordinate_source)
    local contact = operation == "contact_triangle"
    safe_set_enabled(dialog, "contact_circle_label", contact)
    safe_set_enabled(dialog, "contact_circle", contact)
    safe_set_enabled(dialog, "contact_marks", contact)
    safe_set_enabled(dialog, "circle", contact or operation == "nine_point_points")
    safe_set_enabled(dialog, "polygon", POLYGON_DERIVED[operation] == true)
  end

  local function read_options()
    local operation = selected_operation()
    local contact = operation == "contact_triangle"
    local has_circle = contact or operation == "nine_point_points"
    local options = {
      derived = operation,
      center_features = {
        mark = false,
        contact_marks = contact and dialog:get("contact_marks") or false,
      },
      derived_polygon = POLYGON_DERIVED[operation] and dialog:get("polygon") or false,
      derived_marks = dialog:get("marks"),
      derived_labels = dialog:get("labels"),
      derived_circle = has_circle and dialog:get("circle") or false,
      contact_circle = ({ "incircle", "excircle_a", "excircle_b", "excircle_c" })[
        dialog:get("contact_circle")],
      group_output = dialog:get("group_output"),
      output_layer = dialog:get("output_layer") == 2 and "source" or "active",
    }
    if DERIVED_REQUIRES_POINT[operation] then
      local source = dialog:get("point_source")
      if POINT_SOURCE_CENTERS[source] then
        options.point_center = POINT_SOURCE_CENTERS[source]
      elseif source == 7 then
        options.point = { x = dialog:get("point_x"), y = dialog:get("point_y") }
      end
    end
    return options
  end

  dialog:addButton("cancel", "&Cancel", "reject")
  dialog:addButton("preview", "&Preview", function() if preview then preview.update(true) end end)
  dialog:addButton("create", "&Create", "accept")
  update_controls()
  preview = start_dialog_preview(model, dialog, read_options, update_controls)
  return execute_dialog(model, dialog, preview, read_options, function(options)
    state.operation, state.point_source = dialog:get("operation"), dialog:get("point_source")
    state.point_x, state.point_y = dialog:get("point_x"), dialog:get("point_y")
    state.contact_circle = dialog:get("contact_circle")
    state.polygon, state.marks = dialog:get("polygon"), dialog:get("marks")
    state.labels, state.circle = dialog:get("labels"), dialog:get("circle")
    state.contact_marks = dialog:get("contact_marks")
    state.group_output, state.output_layer = dialog:get("group_output"), dialog:get("output_layer")
    state.live_preview = dialog:get("live_preview")
    return create_triangle_constructions(model, options)
  end)
end

local function collect_metadata_information(object, information)
  information = information or { current = 0, stale = 0, absent = 0, errors = {} }
  local ok, result = pcall(parse_metadata, object)
  if not ok then
    information.errors[#information.errors + 1] = clean_error_message(result)
  elseif result.status == "current" then
    information.current = information.current + 1
  elseif result.status == "stale" then
    information.stale = information.stale + 1
  else
    information.absent = information.absent + 1
  end
  if object_type(object) == "group" then
    for _, child in ipairs(object_elements(object) or {}) do
      collect_metadata_information(child, information)
    end
  end
  return information
end

local function inspect_selected_construction(model, raw_options)
  return creator_call(model, "Cannot inspect triangle construction", function()
    local options = options_table(raw_options)
    validate_keys(options, {}, "triangle inspection options")
    local entries = selected_objects(model)
    if #entries == 0 then error("select at least one Triangles object or group") end
    local information = { current = 0, stale = 0, absent = 0, errors = {} }
    for _, entry in ipairs(entries) do collect_metadata_information(entry.object, information) end
    local details = table.concat({
      "Current metadata: " .. tostring(information.current),
      "Stale geometry: " .. tostring(information.stale),
      "Without Triangles metadata: " .. tostring(information.absent),
      "Metadata errors: " .. tostring(#information.errors),
    }, "\n")
    if #information.errors > 0 then details = details .. "\n\n" .. information.errors[1] end
    if model and type(model.warning) == "function" then
      model:warning("Triangles construction metadata", details)
    end
    return {
      created = false, status = "inspected", operation = "inspect",
      element_count = 0, created_object_count = 0,
      object_count = #model:page(), result = information,
    }
  end)
end

D.centers = centers_dialog
D.derived = derived_dialog
D.inspect = inspect_selected_construction
D.state = dialog_state
return D
end)()

----------------------------------------------------------------------
-- Public API and Ipe menu
----------------------------------------------------------------------

local TRIANGLES_API = {}
local PUBLIC_FUNCTIONS = {
  "finite_number", "hypot", "point_from_table",
  "center_names", "center_name_list", "derived_name_list",
  "triangle_center", "triangle_centers", "triangle_derived_points",
  "triangle_contact_points", "barycentric_coordinates",
  "point_from_barycentric", "isogonal_conjugate", "isotomic_conjugate",
  "triangle_path_vertices", "parse_metadata",
  "build_construction_plan", "create_triangle_centers",
  "create_triangle_derived", "create_triangle_constructions",
  "preview_shape_data", "preview_shapes", "preview_signature",
  "inspect_selected_construction",
}

for _, name in ipairs(PUBLIC_FUNCTIONS) do
  local value = M[name] or R[name] or P[name] or Preview[name]
  if name == "inspect_selected_construction" then value = D.inspect end
  if type(value) ~= "function" then error("missing public Triangles function: " .. name) end
  TRIANGLES_API[name] = value
end

TRIANGLES_API.api_version = API_VERSION
TRIANGLES_API.version = VERSION
TRIANGLES_API.public_functions = PUBLIC_FUNCTIONS
TRIANGLES_API.required_functions = {
  "triangle_center", "triangle_centers", "triangle_derived_points",
  "create_triangle_centers", "create_triangle_derived",
  "create_triangle_constructions", "preview_shape_data", "parse_metadata",
}
TRIANGLES_API.center_definitions = CENTER_DEFINITIONS
TRIANGLES_API.derived_definitions = DERIVED_DEFINITIONS
TRIANGLES_API.dialog_state = D.state

function TRIANGLES_API.is_compatible(required_version)
  if required_version ~= nil and required_version ~= API_VERSION then return false end
  for _, name in ipairs(TRIANGLES_API.required_functions) do
    if type(TRIANGLES_API[name]) ~= "function" then return false end
  end
  return true
end

_G.TRIANGLES = TRIANGLES_API
_G.TRIANGLES_DIALOGS = {
  centers = D.centers,
  derived = D.derived,
  inspect = D.inspect,
}

methods = {
  { label = "Construct: triangle centers", run = D.centers },
  { label = "Construct: derived triangle geometry", run = D.derived },
}
