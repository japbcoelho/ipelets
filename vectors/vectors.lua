----------------------------------------------------------------------
-- Vectors 1.0.0
-- Copyright (C) 2026 japbcoelho
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Standalone vector decomposition and arithmetic tools for Ipe 7.2.
----------------------------------------------------------------------

label = "Vectors"

about = [[
Vectors 1.0.0

Creates vector components, resultants, and subtractions for vector diagrams.
The standalone runtime validates topology, styles, arithmetic, and metadata.

Copyright (C) 2026 japbcoelho
License: GPL-3.0-or-later
]]

local _G = _G
local ipe = ipe
local ipeui = ipeui
local error = _G.error
local ipairs = ipairs
local math = _G.math
local pairs = pairs
local pcall = _G.pcall
local string = string
local table = table
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

local API = {}
API.API_VERSION = 1
API.VERSION = "1.0.0"

local EPSILON = 1e-9
local RELATIVE_ZERO_TOLERANCE = 1e-12
local TWO_PI = 2 * math.pi
local DEFAULT_TOUCH_TOLERANCE = 1e-3
local ARROWFIX_METADATA_PREFIX = "arrowfix:line"
local DEFAULT_ARROW = "arrow/normal(spx)"
local DEFAULT_LABEL_BASE = "F"
local PATH_ATTRIBUTE_NAMES = {
  stroke = true,
  pen = true,
  pathmode = true,
  dashstyle = true,
  linecap = true,
  linejoin = true,
  strokeopacity = true,
  opacity = true,
  farrow = true,
  rarrow = true,
  farrowshape = true,
  rarrowshape = true,
  farrowsize = true,
  rarrowsize = true,
}
local GUIDE_ATTRIBUTE_NAMES = {
  stroke = true,
  pen = true,
  pathmode = true,
  dashstyle = true,
  linecap = true,
  linejoin = true,
  strokeopacity = true,
  opacity = true,
}
local VECTOR_STYLE_ATTRIBUTES = {
  "stroke",
  "pen",
  "pathmode",
  "dashstyle",
  "linecap",
  "linejoin",
  "strokeopacity",
  "opacity",
}

local COMPONENT_OPTIONS = {
  label_base = true,
  label_style = true,
  label_offset = true,
  component_pen = true,
  arrow_shape = true,
  arrow_size = true,
  component_attributes = true,
  guide_pen = true,
  guide_attributes = true,
  text_stroke = true,
  textsize = true,
  labelstyle = true,
  bold_labels = true,
}

local RESULTANT_OPTIONS = {
  touch_tolerance = true,
  resultant_pen = true,
  arrow_shape = true,
  arrow_size = true,
  resultant_attributes = true,
}

local SUBTRACTION_OPTIONS = {
  touch_tolerance = true,
  subtraction_pen = true,
  resultant_pen = true,
  arrow_shape = true,
  arrow_size = true,
  subtraction_attributes = true,
  resultant_attributes = true,
}

local function finite_number(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clean_error_message(message)
  message = tostring(message or "")
  local cleaned = message:match("^%[string [^%]]+%]:%d+:%s*(.*)$")
    or message:match("^[^:]+:%d+:%s*(.*)$")
  return cleaned and cleaned ~= "" and cleaned or message
end

local function validated_options(options, allowed)
  if options == nil then return {} end
  if type(options) ~= "table" then error("options must be a table") end
  for key, _ in pairs(options) do
    if type(key) ~= "string" or not allowed[key] then
      error("Unsupported Vectors option: " .. tostring(key))
    end
  end
  return options
end

local function validate_table_option(options, name)
  if options[name] ~= nil and type(options[name]) ~= "table" then
    error(name .. " must be a table")
  end
end

local function validate_component_options(options)
  options = validated_options(options, COMPONENT_OPTIONS)
  validate_table_option(options, "component_attributes")
  validate_table_option(options, "guide_attributes")
  if options.bold_labels ~= nil and type(options.bold_labels) ~= "boolean" then
    error("bold_labels must be a boolean")
  end
  return options
end

local function validate_resultant_options(options)
  options = validated_options(options, RESULTANT_OPTIONS)
  validate_table_option(options, "resultant_attributes")
  return options
end

local function validate_subtraction_options(options)
  options = validated_options(options, SUBTRACTION_OPTIONS)
  validate_table_option(options, "subtraction_attributes")
  validate_table_option(options, "resultant_attributes")
  return options
end

local function V(x, y)
  if not finite_number(x) or not finite_number(y) then
    error("Vector calculation produced non-finite coordinates")
  end
  if ipe and type(ipe.Vector) == "function" then return ipe.Vector(x, y) end
  return { x = x, y = y }
end

local function number_value(value, name, fallback)
  if value == nil and fallback ~= nil then return fallback end
  if not finite_number(value) then error(name .. " must be a finite number") end
  return value
end

local function point_value(value, name)
  if type(value) ~= "table" and type(value) ~= "userdata" then
    error(name .. " must be a point")
  end
  local ok_x, x = pcall(function() return value.x end)
  local ok_y, y = pcall(function() return value.y end)
  if not ok_x then x = nil end
  if not ok_y then y = nil end
  if x == nil and type(value) == "table" then x = value[1] end
  if y == nil and type(value) == "table" then y = value[2] end
  x = tonumber(x)
  y = tonumber(y)
  if not finite_number(x) or not finite_number(y) then
    error(name .. " must contain finite x and y coordinates")
  end
  return V(x, y)
end

local function add(a, b)
  return V(a.x + b.x, a.y + b.y)
end

local function sub(a, b)
  return V(a.x - b.x, a.y - b.y)
end

local function scale(vector, factor)
  return V(vector.x * factor, vector.y * factor)
end

local function dot(a, b)
  return a.x * b.x + a.y * b.y
end

local function cross(a, b)
  return a.x * b.y - a.y * b.x
end

local function scaled_hypot(x, y)
  local ax = math.abs(x)
  local ay = math.abs(y)
  local maximum = math.max(ax, ay)
  if maximum == 0 then return 0 end
  if not finite_number(maximum) then return math.huge end
  local sx = ax / maximum
  local sy = ay / maximum
  return maximum * math.sqrt(sx * sx + sy * sy)
end

local function length(vector)
  return scaled_hypot(vector.x, vector.y)
end

local function unit(vector, name)
  local magnitude = length(vector)
  if magnitude <= 0 then error((name or "vector") .. " must have positive length") end
  return V(vector.x / magnitude, vector.y / magnitude)
end

local function clone_attributes(attributes)
  local cloned = {}
  for key, value in pairs(attributes or {}) do cloned[key] = value end
  return cloned
end

local function merge_attributes(base, overrides)
  local merged = clone_attributes(base)
  for key, value in pairs(overrides or {}) do merged[key] = value end
  return merged
end

local function line_curve(a, b)
  return {
    type = "curve",
    closed = false,
    { type = "segment", a, b },
  }
end

local function line_path(attributes, a, b, with_arrows)
  return ipe.Path(clone_attributes(attributes), { line_curve(a, b) }, with_arrows == true)
end

local function text_attributes(model, options, overrides)
  options = type(options) == "table" and options or {}
  local attrs = merge_attributes(model and model.attributes or {}, {
    stroke = options.text_stroke or "black",
    textsize = options.textsize or "normal",
    labelstyle = options.labelstyle or "math",
    transformations = "affine",
  })
  return merge_attributes(attrs, overrides)
end

local function math_text(text)
  if text == false or text == nil then return nil end
  text = tostring(text)
  if text == "" then return nil end
  return text:match("^%$(.*)%$$") or text
end

local function bold_math_text(text, options)
  if options and options.bold_labels == false then return text end
  if text:match("^\\mathbf%b{}$") then return text end
  if text:match("^\\mathbf%b{}_%b{}$") then return text end
  local base, subscript = text:match("^(.*)_(.+)$")
  if base and subscript then
    subscript = subscript:match("^%{(.*)%}$") or subscript
    return "\\mathbf{" .. base .. "}_{" .. subscript .. "}"
  end
  return "\\mathbf{" .. text .. "}"
end

local function text_transform_available(object)
  return type(ipe.Translation) == "function"
    and type(ipe.Rotation) == "function"
    and object
    and type(object.setMatrix) == "function"
end

local function normalized_angle(angle)
  angle = number_value(angle or 0, "angle", 0)
  while angle <= -math.pi do angle = angle + TWO_PI end
  while angle > math.pi do angle = angle - TWO_PI end
  return angle
end

local function swapped_horizontal_alignment(value)
  if value == "right" then return "left" end
  if value == "left" then return "right" end
  return value
end

local function swapped_vertical_alignment(value)
  if value == "top" then return "bottom" end
  if value == "bottom" then return "top" end
  return value
end

local function readable_label_transform(angle, offset, alignment)
  angle = normalized_angle(angle or 0)
  offset = offset or V(0, 0)
  alignment = alignment or {}
  local adjusted = {
    angle = angle,
    offset = offset,
    alignment = clone_attributes(alignment),
  }
  if math.cos(angle) < -EPSILON then
    adjusted.angle = normalized_angle(angle + math.pi)
    adjusted.offset = scale(offset, -1)
    adjusted.alignment.horizontalalignment =
      swapped_horizontal_alignment(alignment.horizontalalignment)
    adjusted.alignment.verticalalignment =
      swapped_vertical_alignment(alignment.verticalalignment)
  end
  return adjusted
end

local function transformed_label(model, text, position, angle, offset, alignment, options)
  local value = math_text(text)
  if not value then return nil end
  value = bold_math_text(value, options)
  local transform = readable_label_transform(angle, offset, alignment)
  offset = transform.offset
  alignment = transform.alignment
  local attrs = text_attributes(model, options, {
    horizontalalignment = alignment.horizontalalignment or "hcenter",
    verticalalignment = alignment.verticalalignment or "vcenter",
  })
  local object = ipe.Text(attrs, value, V(0, 0))
  pcall(function() object:set("transformations", "affine") end)
  if text_transform_available(object) then
    object:setMatrix(ipe.Translation(position) * ipe.Rotation(transform.angle) * ipe.Translation(offset))
  else
    object = ipe.Text(attrs, value, add(position, offset))
  end
  return object
end

local function component_labels(label_base, label_style)
  if label_base == nil then label_base = DEFAULT_LABEL_BASE end
  if type(label_base) ~= "string" then error("label_base must be text") end
  label_base = label_base:gsub("^%s+", ""):gsub("%s+$", "")
  label_base = label_base:match("^%$(.*)%$$") or label_base
  label_base = label_base:gsub("^%s+", ""):gsub("%s+$", "")
  if label_base == "" then label_base = DEFAULT_LABEL_BASE end
  if label_base:find("$", 1, true) then
    error("label_base must not contain unmatched math delimiters")
  end
  if label_style == nil then label_style = "12" end
  if type(label_style) ~= "string" then error("label_style must be '12' or 'xy'") end
  label_style = label_style:lower():gsub("%s+", "")
  if label_style == "xy" or label_style == "_x/_y" or label_style == "x/y" then
    return {
      first = label_base .. "_x",
      second = label_base .. "_y",
      style = "xy",
    }
  end
  if label_style ~= "12" and label_style ~= "_1/_2" and label_style ~= "1/2" then
    error("label_style must be '12' or 'xy'")
  end
  return {
    first = label_base .. "_1",
    second = label_base .. "_2",
    style = "12",
  }
end

local function component_label_preview_text(label_base, label_style)
  local labels = component_labels(label_base, label_style)
  return labels.first .. " / " .. labels.second
end

local function current_axes_from_model(model)
  if type(model) ~= "table" and type(model) ~= "userdata" then error("model is required") end
  local snap = model.snap
  if type(snap) ~= "table" or not snap.with_axes or not snap.origin then
    return {
      origin = V(0, 0),
      orientation = 0,
      f1 = V(1, 0),
      f2 = V(0, 1),
      default_axes = true,
    }
  end

  local origin = point_value(snap.origin, "axis origin")
  local orientation = number_value(snap.orientation, "axis orientation", 0)
  local c, s = math.cos(orientation), math.sin(orientation)
  return {
    origin = origin,
    orientation = orientation,
    f1 = V(c, s),
    f2 = V(-s, c),
    default_axes = false,
  }
end

local function components_in_axes(vector, axes)
  vector = point_value(vector, "vector")
  axes = axes or {}
  local f1 = unit(point_value(axes.f1 or V(1, 0), "first axis"), "first axis")
  local f2 = unit(point_value(axes.f2 or V(0, 1), "second axis"), "second axis")
  local determinant = cross(f1, f2)
  if math.abs(determinant) <= EPSILON then error("Axes must not be parallel") end
  local first_scalar = cross(vector, f2) / determinant
  local second_scalar = cross(f1, vector) / determinant
  if not finite_number(first_scalar) or not finite_number(second_scalar) then
    error("Vector components must be finite")
  end
  return {
    first_scalar = first_scalar,
    second_scalar = second_scalar,
    first = scale(f1, first_scalar),
    second = scale(f2, second_scalar),
    f1 = f1,
    f2 = f2,
  }
end

local function components_in_directions(vector, first_direction, second_direction)
  vector = point_value(vector, "vector")
  local first_unit = unit(point_value(first_direction, "first direction"), "first direction")
  local second_unit = unit(point_value(second_direction, "second direction"), "second direction")
  local determinant = cross(first_unit, second_unit)
  if math.abs(determinant) <= EPSILON then
    error("Selected directions must not be parallel")
  end
  local first_scalar = cross(vector, second_unit) / determinant
  local second_scalar = cross(first_unit, vector) / determinant
  if not finite_number(first_scalar) or not finite_number(second_scalar) then
    error("Vector components must be finite")
  end
  return {
    first_scalar = first_scalar,
    second_scalar = second_scalar,
    first = scale(first_unit, first_scalar),
    second = scale(second_unit, second_scalar),
    f1 = first_unit,
    f2 = second_unit,
  }
end

local function page_from_model(model)
  if model and type(model.page) == "function" then return model:page() end
  error("model:page is not available")
end

local function active_style_sheets(model)
  local ok_method, sheets_method = pcall(function()
    return model and model.doc and model.doc.sheets
  end)
  if not ok_method or type(sheets_method) ~= "function" then return nil end
  local ok_sheets, sheets = pcall(function() return model.doc:sheets() end)
  if not ok_sheets then error("Could not inspect the active style sheet") end
  if not sheets or type(sheets.has) ~= "function" then return nil end
  return sheets
end

local function symbolic_style_exists(model, kind, value, message)
  local sheets = active_style_sheets(model)
  if not sheets then return end
  local ok_has, found = pcall(function() return sheets:has(kind, value) end)
  if not ok_has then error("Could not validate " .. kind .. " in the active style sheet") end
  if not found then error(message) end
end

local function validate_pen_value(model, value, message)
  if value == nil then return end
  message = message or
    "Stroke width must be a finite non-negative number or a symbolic pen defined in the active style sheet"
  if type(value) == "number" then
    if not finite_number(value) or value < 0 then
      error(message)
    end
    return
  end
  if type(value) ~= "string" or value == "" then error(message) end
  symbolic_style_exists(model, "pen", value, message)
end

local function validate_option_pens(model, options)
  validate_pen_value(model, options.component_pen)
  validate_pen_value(model, options.guide_pen)
  validate_pen_value(model, options.resultant_pen)
  validate_pen_value(model, options.subtraction_pen)
end

local function validate_symbolic_style(model, kind, value, message, numeric_minimum, explicit_color)
  if value == nil then return end
  if explicit_color and type(value) == "table" then
    if finite_number(value.r) and finite_number(value.g) and finite_number(value.b)
      and value.r >= 0 and value.r <= 1
      and value.g >= 0 and value.g <= 1
      and value.b >= 0 and value.b <= 1 then
      return
    end
    error(message)
  end
  if numeric_minimum ~= nil and type(value) == "number" then
    if finite_number(value) and value >= numeric_minimum then return end
    error(message)
  end
  if type(value) ~= "string" or value == "" then error(message) end
  symbolic_style_exists(model, kind, value, message)
end

local function validate_dashstyle(model, value, message)
  if value == nil then return end
  if type(value) ~= "string" or value == "" then error(message) end
  if value:sub(1, 1) == "[" then
    if not value:match("^%[%s*[%d%.%+%-eE%s]+%]%s*[%d%.%+%-eE]+%s*$") then
      error(message)
    end
    return
  end
  symbolic_style_exists(model, "dashstyle", value, message)
end

local function validate_enum(value, allowed, message)
  if value == nil then return end
  if type(value) ~= "string" or not allowed[value] then error(message) end
end

local function validate_path_attributes(model, attributes, option_name, allowed_names)
  if not attributes then return end
  for key, _ in pairs(attributes) do
    if type(key) ~= "string" or not allowed_names[key] then
      error("Unsupported " .. option_name .. " attribute: " .. tostring(key))
    end
  end

  validate_symbolic_style(model, "color", attributes.stroke,
    option_name .. ".stroke must be an explicit RGB color or a symbolic color defined in the active style sheet",
    nil, true)
  validate_pen_value(model, attributes.pen,
    option_name .. ".pen must be a finite non-negative number or a symbolic pen defined in the active style sheet")
  if attributes.pathmode ~= nil and attributes.pathmode ~= "stroked" then
    error(option_name .. ".pathmode must be 'stroked'")
  end
  validate_dashstyle(model, attributes.dashstyle,
    option_name .. ".dashstyle must be an absolute dash pattern or a symbolic dash style defined in the active style sheet")
  validate_enum(attributes.linecap, { normal = true, butt = true, round = true, square = true },
    option_name .. ".linecap must be 'normal', 'butt', 'round', or 'square'")
  validate_enum(attributes.linejoin, { normal = true, miter = true, round = true, bevel = true },
    option_name .. ".linejoin must be 'normal', 'miter', 'round', or 'bevel'")
  validate_symbolic_style(model, "opacity", attributes.opacity,
    option_name .. ".opacity must be defined in the active style sheet")
  validate_symbolic_style(model, "opacity", attributes.strokeopacity,
    option_name .. ".strokeopacity must be defined in the active style sheet")

  for _, name in ipairs({ "farrow", "rarrow" }) do
    if attributes[name] ~= nil and type(attributes[name]) ~= "boolean" then
      error(option_name .. "." .. name .. " must be a boolean")
    end
  end
  for _, name in ipairs({ "farrowshape", "rarrowshape" }) do
    validate_symbolic_style(model, "symbol", attributes[name],
      option_name .. "." .. name .. " must be a symbol defined in the active style sheet")
  end
  for _, name in ipairs({ "farrowsize", "rarrowsize" }) do
    validate_symbolic_style(model, "arrowsize", attributes[name],
      option_name .. "." .. name ..
        " must be a positive finite number or a symbolic arrow size defined in the active style sheet",
      EPSILON)
  end
end

local function validate_option_styles(model, options, attribute_names)
  validate_option_pens(model, options)
  validate_symbolic_style(model, "symbol", options.arrow_shape,
    "Arrow shape must be a symbol defined in the active style sheet")
  validate_symbolic_style(model, "arrowsize", options.arrow_size,
    "Arrow size must be a positive finite number or a symbolic arrow size defined in the active style sheet", EPSILON)
  validate_symbolic_style(model, "color", options.text_stroke,
    "Text color must be an explicit color or a symbolic color defined in the active style sheet", nil, true)
  validate_symbolic_style(model, "textsize", options.textsize,
    "Text size must be a positive finite number or a symbolic text size defined in the active style sheet", EPSILON)
  validate_symbolic_style(model, "labelstyle", options.labelstyle,
    "Label style must be defined in the active style sheet")
  for _, name in ipairs(attribute_names or {}) do
    validate_path_attributes(model, options[name], name,
      name == "guide_attributes" and GUIDE_ATTRIBUTE_NAMES or PATH_ATTRIBUTE_NAMES)
  end
end

local function selection_indexes(model, page)
  local indexes = {}
  local primary_index
  if page and type(page.primarySelection) == "function" then
    local ok, primary = pcall(function() return page:primarySelection() end)
    if ok and primary then primary_index = primary end
  end
  if model and type(model.selection) == "function" then
    local ok, selection = pcall(function() return model:selection() end)
    if ok and type(selection) == "table" then
      for _, index in ipairs(selection) do indexes[#indexes + 1] = index end
    end
  end
  if #indexes == 0 and page and type(page.selection) == "function" then
    local ok, selection = pcall(function() return page:selection() end)
    if ok and type(selection) == "table" then
      for _, index in ipairs(selection) do indexes[#indexes + 1] = index end
    end
  end
  if #indexes == 0 and page and type(page.primarySelection) == "function" then
    local ok, primary = pcall(function() return page:primarySelection() end)
    if ok and primary then indexes[#indexes + 1] = primary end
  end
  if #indexes == 0 and page and type(page.objects) == "function" then
    for index, _, selected in page:objects() do
      if selected then indexes[#indexes + 1] = index end
    end
  end
  if primary_index ~= nil then
    local reordered = {}
    local found = false
    for _, index in ipairs(indexes) do
      if index == primary_index then
        if not found then reordered[#reordered + 1] = index end
        found = true
      end
    end
    if found then
      for _, index in ipairs(indexes) do
        if index ~= primary_index then reordered[#reordered + 1] = index end
      end
      indexes = reordered
    end
  end
  return indexes
end

local function object_type(object)
  if object and type(object.type) == "function" then
    local ok, value = pcall(function() return object:type() end)
    if ok then return value end
  end
  return object and object.kind
end

local function object_attribute(object, name)
  if object and type(object.get) == "function" then
    local ok, value = pcall(function() return object:get(name) end)
    if ok then return value end
  end
  if type(object) == "table" and type(object.attributes) == "table" then
    return object.attributes[name]
  end
  return nil
end

local function defined_attribute(value)
  return value ~= nil and value ~= "undefined"
end

local function object_custom(object)
  if object and type(object.getCustom) == "function" then
    local ok, value = pcall(function() return object:getCustom() end)
    if ok and type(value) == "string" and value ~= "" and value ~= "undefined" then
      return value
    end
  end
  if type(object) == "table" and type(object.custom) == "string" then return object.custom end
  return nil
end

local function metadata_unescape(value)
  return tostring(value):gsub("%%3D", "="):gsub("%%3B", ";"):gsub("%%25", "%%")
end

local function parse_arrowfix_metadata(custom)
  if type(custom) ~= "string" then return nil end
  local prefix, rest = custom:match("^([^;]+);?(.*)$")
  if prefix ~= ARROWFIX_METADATA_PREFIX then return nil end
  local fields = { prefix = prefix }
  for key, value in tostring(rest or ""):gmatch("([^=;]+)=([^;]*)") do
    fields[key] = metadata_unescape(value)
  end
  return fields
end

local function decoded_arrowfix_attribute(name, value)
  if type(value) ~= "string" then return value end
  if name == "pen" or name == "farrowsize" or name == "rarrowsize" then
    local number = tonumber(value)
    if finite_number(number) then return number end
  elseif name == "stroke" then
    local components = {}
    for token in value:gmatch("%S+") do
      local number = tonumber(token)
      if not finite_number(number) then return value end
      components[#components + 1] = number
    end
    if #components == 3 then
      return { r = components[1], g = components[2], b = components[3] }
    end
  end
  return value
end

local function has_arrow(value)
  if value == nil or value == false then return false end
  if value == "false" or value == "none" or value == "normal" then return false end
  return true
end

local function logical_vector_attribute(object, name)
  local value = object_attribute(object, name)
  if defined_attribute(value) then return value end
  local fields = parse_arrowfix_metadata(object_custom(object))
  if fields and defined_attribute(fields[name]) then
    return decoded_arrowfix_attribute(name, fields[name])
  end
  return nil
end

local function active_arrow_style(object)
  local farrow = has_arrow(logical_vector_attribute(object, "farrow"))
  local rarrow = has_arrow(logical_vector_attribute(object, "rarrow"))
  local shape
  local size
  if farrow then
    shape = logical_vector_attribute(object, "farrowshape")
    size = logical_vector_attribute(object, "farrowsize")
  elseif rarrow then
    shape = logical_vector_attribute(object, "rarrowshape")
    size = logical_vector_attribute(object, "rarrowsize")
  end
  if not defined_attribute(shape) then shape = DEFAULT_ARROW end
  if not defined_attribute(size) then size = "normal" end
  return shape, size
end

local function inherited_vector_style(object)
  local attrs = {}
  for _, name in ipairs(VECTOR_STYLE_ATTRIBUTES) do
    local value = logical_vector_attribute(object, name)
    if defined_attribute(value) then attrs[name] = value end
  end
  local arrow_shape, arrow_size = active_arrow_style(object)
  attrs.farrow = true
  attrs.rarrow = false
  attrs.farrowshape = arrow_shape
  attrs.farrowsize = arrow_size
  return attrs
end

local function vector_creation_attributes(source_object, defaults, forced, extra)
  local attrs = merge_attributes(defaults or {}, inherited_vector_style(source_object))
  attrs = merge_attributes(attrs, extra)
  return merge_attributes(attrs, forced)
end

local function transformed_point(object, point)
  local result = point_value(point, "path point")
  if not object or type(object.matrix) ~= "function" then return result end
  local ok_matrix, matrix = pcall(function() return object:matrix() end)
  if not ok_matrix or not matrix then return result end
  local ok_product, product = pcall(function() return matrix * result end)
  if ok_product and product then return point_value(product, "transformed path point") end
  return result
end

local function path_straight_points(object)
  if object_type(object) ~= "path" then return nil end

  local shape
  if type(object.shape) == "function" then
    local ok, value = pcall(function() return object:shape() end)
    if ok then shape = value end
  end
  if shape == nil and type(object) == "table" then shape = object.shape_value end

  if type(shape) ~= "table" or #shape ~= 1 then
    error("Selected path must be one open straight segment")
  end
  local subpath = shape[1]
  if type(subpath) ~= "table" or subpath.type ~= "curve"
    or subpath.closed ~= false or #subpath ~= 1 then
    error("Selected path must be one open straight segment")
  end
  local segment = subpath[1]
  if type(segment) ~= "table" or segment.type ~= "segment"
    or #segment ~= 2 or segment[1] == nil or segment[2] == nil then
    error("Selected path must be one open straight segment")
  end
  local a = transformed_point(object, segment[1])
  local b = transformed_point(object, segment[2])
  return a, b
end

local function path_vector_segment(object)
  local a, b = path_straight_points(object)
  if not a then return nil end

  local farrow = has_arrow(object_attribute(object, "farrow"))
  local rarrow = has_arrow(object_attribute(object, "rarrow"))
  if not farrow and not rarrow then error("Selected segment must have an arrowhead") end
  if farrow and rarrow then
    error("Selected vector must have exactly one arrowhead direction")
  end
  if rarrow and not farrow then a, b = b, a end

  local vector = sub(b, a)
  if length(vector) <= 0 then error("Selected vector must have positive length") end

  return {
    object = object,
    start = a,
    finish = b,
    vector = vector,
  }
end

local function arrowfix_vector_segment(object)
  local fields = parse_arrowfix_metadata(object_custom(object))
  if not fields then return nil end

  local x1 = tonumber(fields.x1)
  local y1 = tonumber(fields.y1)
  local x2 = tonumber(fields.x2)
  local y2 = tonumber(fields.y2)
  if not finite_number(x1) or not finite_number(y1)
    or not finite_number(x2) or not finite_number(y2) then
    error("Corrected arrow metadata must contain finite endpoints")
  end

  local a = transformed_point(object, V(x1, y1))
  local b = transformed_point(object, V(x2, y2))
  local farrow = has_arrow(fields.farrow)
  local rarrow = has_arrow(fields.rarrow)
  if not farrow and not rarrow then error("Selected segment must have an arrowhead") end
  if farrow and rarrow then
    error("Selected vector must have exactly one arrowhead direction")
  end
  if rarrow and not farrow then a, b = b, a end

  local vector = sub(b, a)
  if length(vector) <= 0 then error("Selected vector must have positive length") end

  return {
    object = object,
    start = a,
    finish = b,
    vector = vector,
    arrowfix = true,
  }
end

local function direction_segment_from_object(object)
  local corrected_segment = arrowfix_vector_segment(object)
  if corrected_segment then return corrected_segment end

  local a, b = path_straight_points(object)
  if not a then error("Selected direction must be a straight path segment") end

  local farrow = has_arrow(object_attribute(object, "farrow"))
  local rarrow = has_arrow(object_attribute(object, "rarrow"))
  if rarrow and not farrow then a, b = b, a end
  local vector = sub(b, a)
  if length(vector) <= 0 then error("Selected direction must have positive length") end

  return {
    object = object,
    start = a,
    finish = b,
    vector = vector,
  }
end

local function vector_segment_from_object(object)
  local corrected_segment = arrowfix_vector_segment(object)
  if corrected_segment then return corrected_segment end
  local path_segment = path_vector_segment(object)
  if path_segment then return path_segment end
  error("Selected object must be a path segment or a corrected arrow group")
end

local function selected_vector_segments(model, expected_count)
  local page = page_from_model(model)
  local indexes = selection_indexes(model, page)
  local exact_count
  local minimum_count
  if type(expected_count) == "table" then
    exact_count = expected_count.exact
    minimum_count = expected_count.minimum
  else
    exact_count = expected_count
  end
  if exact_count and #indexes ~= exact_count then
    error("Select exactly " .. tostring(exact_count) .. " arrowed segment" ..
      (exact_count == 1 and "" or "s"))
  end
  if minimum_count and #indexes < minimum_count then
    error("Select at least " .. tostring(minimum_count) .. " arrowed segments")
  end

  local result = {}
  for _, index in ipairs(indexes) do
    local segment = vector_segment_from_object(page[index])
    segment.index = index
    result[#result + 1] = segment
  end
  return result
end

local function selected_vector_segment(model)
  return selected_vector_segments(model, 1)[1]
end

local function infer_common_tail_oblique_selection(page, indexes)
  local directions = {}
  for position, index in ipairs(indexes) do
    local ok, direction = pcall(function()
      return direction_segment_from_object(page[index])
    end)
    if not ok then return nil end
    direction.index = index
    direction.selection_position = position
    directions[position] = direction
  end

  local vector_candidates = {}
  for source_position, source_index in ipairs(indexes) do
    local ok_source, source = pcall(function()
      return vector_segment_from_object(page[source_index])
    end)
    if ok_source then
      source.index = source_index
      local ordered_directions = {}
      for position, direction in ipairs(directions) do
        if position ~= source_position then
          ordered_directions[#ordered_directions + 1] = direction
        end
      end
      vector_candidates[#vector_candidates + 1] = {
        source = source,
        first_direction = ordered_directions[1],
        second_direction = ordered_directions[2],
      }
    end
  end

  -- When exactly one selected object has an arrowhead, it is the vector even
  -- if a direction segment is primary or one component is negative.
  if #vector_candidates == 1 then
    local candidate = vector_candidates[1]
    return candidate.source, candidate.first_direction, candidate.second_direction
  end

  local common_tail = directions[1].start
  for position = 2, #directions do
    if length(sub(directions[position].start, common_tail)) > DEFAULT_TOUCH_TOLERANCE then
      return nil
    end
  end

  local candidates = {}
  for _, candidate in ipairs(vector_candidates) do
    local ok_components, components = pcall(function()
      return components_in_directions(
        candidate.source.vector,
        candidate.first_direction.vector,
        candidate.second_direction.vector
      )
    end)
    if ok_components
      and components.first_scalar > EPSILON
      and components.second_scalar > EPSILON then
      candidates[#candidates + 1] = candidate
    end
  end

  if #candidates == 1 then
    return candidates[1].source, candidates[1].first_direction, candidates[1].second_direction
  end
  return nil
end

local function selected_vector_and_directions(model)
  local page = page_from_model(model)
  local indexes = selection_indexes(model, page)
  if #indexes ~= 3 then
    error("Select one arrowed vector and two straight direction segments")
  end

  local inferred_vector, inferred_first_direction, inferred_second_direction =
    infer_common_tail_oblique_selection(page, indexes)
  if inferred_vector then
    return inferred_vector, inferred_first_direction, inferred_second_direction
  end

  local vector = vector_segment_from_object(page[indexes[1]])
  vector.index = indexes[1]
  local first_direction = direction_segment_from_object(page[indexes[2]])
  first_direction.index = indexes[2]
  local second_direction = direction_segment_from_object(page[indexes[3]])
  second_direction.index = indexes[3]

  return vector, first_direction, second_direction
end

local function metadata_escape(value)
  return tostring(value):gsub("%%", "%%25"):gsub(";", "%%3B"):gsub("=", "%%3D")
end

local function metadata_with_prefix(prefix, fields)
  local keys = {}
  for key, _ in pairs(fields or {}) do keys[#keys + 1] = tostring(key) end
  table.sort(keys)
  local parts = { prefix }
  for _, key in ipairs(keys) do
    parts[#parts + 1] = metadata_escape(key) .. "=" .. metadata_escape(fields[key])
  end
  return table.concat(parts, ";")
end

local function metadata(fields)
  return metadata_with_prefix("vectors:components", fields)
end

local function set_custom(object, custom)
  if not object or type(object.setCustom) ~= "function" then
    error("Created object does not support metadata")
  end
  object:setCustom(custom)
end

local function register_object(model, object, custom, label_value)
  set_custom(object, custom)
  if model and type(model.creation) == "function" then
    model:creation(label_value or "create vector components", object)
  else
    error("model:creation is not available")
  end
end

local function active_layer(model, page)
  local ok, layer = pcall(function() return page:active(model.vno) end)
  if ok then return layer end
  return nil
end

local function register_objects(model, objects, label_value)
  if #objects == 0 then return end
  if #objects == 1 then
    if model and type(model.creation) == "function" then
      model:creation(label_value, objects[1])
      return
    end
    error("model:creation is not available")
  end
  if not model or type(model.register) ~= "function" then
    error("model:register is required for atomic vector creation")
  end

  local page = page_from_model(model)
  local transaction = {
    label = label_value,
    pno = model.pno,
    vno = model.vno,
    layer = active_layer(model, page),
    objects = objects,
  }
  if type(page.clone) == "function" and type(_G.revertOriginal) == "function" then
    transaction.original = page:clone()
    transaction.undo = _G.revertOriginal
  else
    transaction.undo = function(t, doc)
      local target = doc[t.pno]
      for _ = 1, #t.objects do target:remove(#target) end
    end
  end
  transaction.redo = function(t, doc)
    local target = doc[t.pno]
    target:deselectAll()
    for index, object in ipairs(t.objects) do
      target:insert(nil, object, index == #t.objects and 1 or nil, t.layer)
    end
  end
  model:register(transaction)
end

local function vector_angle(vector, fallback)
  if length(vector) <= 0 then return fallback or 0 end
  return math.atan(vector.y, vector.x)
end

local function has_positive_length(vector)
  return length(vector) > 0
end

local function has_significant_length(vector, reference_scale)
  local magnitude = length(vector)
  if magnitude <= 0 then return false end
  if not reference_scale or reference_scale <= 0 then return true end
  return magnitude > reference_scale * RELATIVE_ZERO_TOLERANCE
end

local function outside_label_placement(angle, interior_vector, label_offset, fallback_sign)
  local sign = fallback_sign or 1
  if interior_vector and has_positive_length(interior_vector) then
    local local_positive_y = V(-math.sin(angle), math.cos(angle))
    local side = dot(local_positive_y, interior_vector)
    if side > EPSILON then
      sign = -1
    elseif side < -EPSILON then
      sign = 1
    end
  end
  return V(0, sign * label_offset), {
    horizontalalignment = "right",
    verticalalignment = sign > 0 and "bottom" or "top",
  }
end

local function append_object(objects, role, object)
  objects[#objects + 1] = {
    object = object,
    role = role,
  }
end

local function points_close(a, b, tolerance)
  local dx = a.x - b.x
  local dy = a.y - b.y
  if not finite_number(dx) or not finite_number(dy) then return false end
  return scaled_hypot(dx, dy) <= tolerance
end

local function endpoint_graph(segments, tolerance)
  local nodes = {}
  local start_nodes = {}
  local finish_nodes = {}
  local exact_nodes = {}
  local buckets = {}

  local function exact_key(point)
    local x = point.x == 0 and 0 or point.x
    local y = point.y == 0 and 0 or point.y
    return string.format("%.17g|%.17g", x, y)
  end

  local function grid_coordinates(point)
    if tolerance <= 0 then return nil end
    local x = point.x / tolerance
    local y = point.y / tolerance
    if not finite_number(x) or not finite_number(y) then return nil end
    return math.floor(x), math.floor(y)
  end

  local function bucket_key(x, y)
    return tostring(x) .. "|" .. tostring(y)
  end

  local function node_for(point)
    if tolerance == 0 then
      local key = exact_key(point)
      if exact_nodes[key] then return exact_nodes[key] end
      local node = {
        point = point,
        indegree = 0,
        outdegree = 0,
        in_segments = {},
        out_segments = {},
        segments = {},
      }
      nodes[#nodes + 1] = node
      exact_nodes[key] = node
      return node
    end

    local grid_x, grid_y = grid_coordinates(point)
    if grid_x then
      for offset_x = -1, 1 do
        for offset_y = -1, 1 do
          for _, node in ipairs(buckets[bucket_key(grid_x + offset_x, grid_y + offset_y)] or {}) do
            if points_close(node.point, point, tolerance) then return node end
          end
        end
      end
    else
      for _, node in ipairs(nodes) do
        if points_close(node.point, point, tolerance) then return node end
      end
    end

    local node = {
      point = point,
      indegree = 0,
      outdegree = 0,
      in_segments = {},
      out_segments = {},
      segments = {},
    }
    nodes[#nodes + 1] = node
    if grid_x then
      local key = bucket_key(grid_x, grid_y)
      buckets[key] = buckets[key] or {}
      buckets[key][#buckets[key] + 1] = node
    end
    return node
  end

  for index, segment in ipairs(segments) do
    local start_node = node_for(segment.start)
    local finish_node = node_for(segment.finish)
    start_node.outdegree = start_node.outdegree + 1
    finish_node.indegree = finish_node.indegree + 1
    start_node.out_segments[#start_node.out_segments + 1] = index
    finish_node.in_segments[#finish_node.in_segments + 1] = index
    start_node.segments[#start_node.segments + 1] = index
    if finish_node ~= start_node then
      finish_node.segments[#finish_node.segments + 1] = index
    end
    start_nodes[index] = start_node
    finish_nodes[index] = finish_node
  end

  return {
    nodes = nodes,
    start_nodes = start_nodes,
    finish_nodes = finish_nodes,
  }
end

local function require_connected_segments(segments, tolerance, graph)
  if #segments <= 1 then return graph or endpoint_graph(segments, tolerance) end
  graph = graph or endpoint_graph(segments, tolerance)

  local visited = { [1] = true }
  local queue = { 1 }
  local head = 1
  local visited_count = 1
  while head <= #queue do
    local index = queue[head]
    head = head + 1
    for _, node in ipairs({ graph.start_nodes[index], graph.finish_nodes[index] }) do
      for _, candidate in ipairs(node.segments) do
        if not visited[candidate] then
          visited[candidate] = true
          visited_count = visited_count + 1
          queue[#queue + 1] = candidate
        end
      end
    end
  end

  if visited_count ~= #segments then
    error("Selected vectors must touch through one connected endpoint graph")
  end
  return graph
end

local function directed_polyline_endpoints(segments, tolerance, graph)
  graph = graph or endpoint_graph(segments, tolerance)
  local nodes = graph.nodes
  local finish_nodes = graph.finish_nodes
  local start_node
  local finish_node

  for _, node in ipairs(nodes) do
    if node.indegree > 1 or node.outdegree > 1 then return nil end
    local balance = node.outdegree - node.indegree
    if balance == 1 then
      if start_node then return nil end
      start_node = node
    elseif balance == -1 then
      if finish_node then return nil end
      finish_node = node
    elseif balance ~= 0 then
      return nil
    end
  end

  if not start_node or not finish_node then return nil end

  local visited_segments = {}
  local ordered_segments = {}
  local visited_count = 0
  local node = start_node
  while node ~= finish_node do
    if #node.out_segments ~= 1 then return nil end
    local segment_index = node.out_segments[1]
    if visited_segments[segment_index] then return nil end
    visited_segments[segment_index] = true
    ordered_segments[#ordered_segments + 1] = segments[segment_index]
    visited_count = visited_count + 1
    node = finish_nodes[segment_index]
    if not node then return nil end
  end

  if visited_count ~= #segments then return nil end

  return {
    start = start_node.point,
    finish = finish_node.point,
    segments = ordered_segments,
  }
end

local function source_indexes(segments, start_index)
  local indexes = {}
  for index = start_index or 1, #segments do
    indexes[#indexes + 1] = segments[index].index
  end
  return indexes
end

local function source_metadata_fields(segments, fields)
  fields = clone_attributes(fields)
  fields.source_count = #segments
  for index, segment in ipairs(segments) do
    fields["source_" .. tostring(index)] = segment.index
  end
  return fields
end

local function resultant_plan(first, second, tolerance)
  local sum = add(first.vector, second.vector)
  local input_scale = length(first.vector) + length(second.vector)
  local start
  local mode
  local contact

  if points_close(first.start, second.start, tolerance) then
    start = first.start
    mode = "parallelogram"
    contact = "tail_tail"
  elseif points_close(first.finish, second.start, tolerance) then
    start = first.start
    mode = "polyline"
    contact = "head_tail"
  elseif points_close(first.start, second.finish, tolerance) then
    start = second.start
    mode = "polyline"
    contact = "tail_head"
  elseif points_close(first.finish, second.finish, tolerance) then
    error("Selected vectors must touch tail-to-tail or head-to-tail; head-to-head contact is not a valid resultant layout")
  else
    error("Selected vectors must touch tail-to-tail or head-to-tail")
  end

  if not has_significant_length(sum, input_scale) then
    error("Resultant vector must have positive length")
  end
  local finish = add(start, sum)

  return {
    start = start,
    finish = finish,
    vector = sum,
    mode = mode,
    contact = contact,
  }
end

local function resultant_plan_many(segments, tolerance)
  local graph = require_connected_segments(segments, tolerance)
  if #segments == 2 then return resultant_plan(segments[1], segments[2], tolerance) end

  local vector = V(0, 0)
  local input_scale = 0
  for _, segment in ipairs(segments) do
    vector = add(vector, segment.vector)
    input_scale = input_scale + length(segment.vector)
  end
  if not has_significant_length(vector, input_scale) then
    error("Resultant vector must have positive length")
  end

  local directed_polyline = directed_polyline_endpoints(segments, tolerance, graph)
  if directed_polyline then
    return {
      start = directed_polyline.start,
      finish = add(directed_polyline.start, vector),
      vector = vector,
      mode = "directed_polyline",
      contact = "head_tail_chain",
    }
  end

  return {
    start = segments[1].start,
    finish = add(segments[1].start, vector),
    vector = vector,
    mode = "connected_sum",
    contact = "connected",
  }
end

local function subtraction_plan(first, second, tolerance)
  local difference = sub(first.vector, second.vector)
  local input_scale = length(first.vector) + length(second.vector)
  local start
  local mode
  local contact

  if points_close(first.start, second.start, tolerance) then
    start = second.finish
    mode = "common_tail"
    contact = "tail_tail"
  elseif points_close(first.finish, second.finish, tolerance) then
    start = first.start
    mode = "common_head"
    contact = "head_head"
  elseif points_close(first.finish, second.start, tolerance) then
    start = first.start
    mode = "polyline_reverse_second"
    contact = "head_tail"
  elseif points_close(first.start, second.finish, tolerance) then
    start = first.start
    mode = "common_tail_reverse_second"
    contact = "tail_head"
  else
    error("Selected vectors must share an endpoint for subtraction")
  end

  if not has_significant_length(difference, input_scale) then
    error("Subtraction vector must have positive length")
  end
  local finish = add(start, difference)

  return {
    start = start,
    finish = finish,
    vector = difference,
    mode = mode,
    contact = contact,
  }
end

local function subtraction_plan_many(segments, tolerance)
  local graph = require_connected_segments(segments, tolerance)
  if #segments == 2 then return subtraction_plan(segments[1], segments[2], tolerance) end

  local arithmetic_segments = segments
  local mode = "connected_difference"
  local contact = "connected"
  local start = segments[1].start
  local directed_polyline = directed_polyline_endpoints(segments, tolerance, graph)
  if directed_polyline then
    mode = "chain_difference"
    contact = "head_tail_chain"
  end

  local vector = arithmetic_segments[1].vector
  local input_scale = length(arithmetic_segments[1].vector)
  for index = 2, #arithmetic_segments do
    vector = sub(vector, arithmetic_segments[index].vector)
    input_scale = input_scale + length(arithmetic_segments[index].vector)
  end
  if not has_significant_length(vector, input_scale) then
    error("Subtraction vector must have positive length")
  end

  return {
    start = start,
    finish = add(start, vector),
    vector = vector,
    mode = mode,
    contact = contact,
    segments = arithmetic_segments,
  }
end

local function create_selected_vector_components(model, options)
  options = validate_component_options(options)
  validate_option_styles(model, options, { "component_attributes", "guide_attributes" })
  local segment = selected_vector_segment(model)
  local axes = current_axes_from_model(model)
  local components = components_in_axes(segment.vector, axes)
  local labels = component_labels(options.label_base or DEFAULT_LABEL_BASE, options.label_style or "12")

  local start = segment.start
  local first_end = add(start, components.first)
  local second_end = add(start, components.second)
  local vector_tip = segment.finish
  local label_offset = number_value(options.label_offset, "label_offset", 6)
  if label_offset < 0 then error("label_offset must be non-negative") end

  local component_forced_attrs = {
    pathmode = "stroked",
    dashstyle = "dashed",
    farrow = true,
    rarrow = false,
  }
  if options.component_pen then component_forced_attrs.pen = options.component_pen end
  if options.arrow_shape then component_forced_attrs.farrowshape = options.arrow_shape end
  if options.arrow_size then component_forced_attrs.farrowsize = options.arrow_size end
  local component_attrs = vector_creation_attributes(segment.object, {
    stroke = "black",
    pen = "normal",
    pathmode = "stroked",
    farrow = true,
    farrowshape = options.arrow_shape or DEFAULT_ARROW,
    farrowsize = options.arrow_size or "normal",
  }, component_forced_attrs, options.component_attributes)
  local guide_attrs = merge_attributes({
    stroke = "black",
    pen = options.guide_pen or "normal",
    pathmode = "stroked",
    dashstyle = "dotted",
  }, options.guide_attributes)
  guide_attrs.pathmode = "stroked"

  local first_angle = vector_angle(components.first, axes.orientation)
  local second_angle = vector_angle(components.second, axes.orientation + math.pi / 2)
  local source_scale = length(segment.vector)
  local first_nonzero = has_significant_length(components.first, source_scale)
  local second_nonzero = has_significant_length(components.second, source_scale)
  if not first_nonzero and not second_nonzero then
    error("Selected vector must have positive length")
  end

  local first_label_offset, first_label_alignment =
    outside_label_placement(first_angle, components.second, label_offset, -1)
  local second_label_offset, second_label_alignment =
    outside_label_placement(second_angle, components.first, label_offset, 1)

  local objects = {}
  if first_nonzero then
    append_object(objects, "component_1", line_path(component_attrs, start, first_end, true))
  end
  if second_nonzero then
    append_object(objects, "component_2", line_path(component_attrs, start, second_end, true))
  end
  if first_nonzero and second_nonzero then
    append_object(objects, "guide_1", line_path(guide_attrs, vector_tip, first_end, false))
  end
  if second_nonzero and first_nonzero then
    append_object(objects, "guide_2", line_path(guide_attrs, vector_tip, second_end, false))
  end
  if first_nonzero then
    append_object(objects, "label_1", transformed_label(model, labels.first, first_end,
      first_angle, first_label_offset, first_label_alignment, options))
  end
  if second_nonzero then
    append_object(objects, "label_2", transformed_label(model, labels.second, second_end,
      second_angle, second_label_offset, second_label_alignment, options))
  end

  local base_metadata = {
    label_base = options.label_base or DEFAULT_LABEL_BASE,
    label_style = labels.style,
    source = segment.index,
  }
  local created_count = 0
  local created_objects = {}
  for _, item in ipairs(objects) do
    if item.object then
      local fields = clone_attributes(base_metadata)
      fields.role = item.role
      set_custom(item.object, metadata(fields))
      created_objects[#created_objects + 1] = item.object
      created_count = created_count + 1
    end
  end
  register_objects(model, created_objects, "create vector components")

  return {
    created = true,
    created_count = created_count,
    source_index = segment.index,
    label_style = labels.style,
    first_scalar = components.first_scalar,
    second_scalar = components.second_scalar,
    first = components.first,
    second = components.second,
    axis_origin = axes.origin,
    axis_orientation = axes.orientation,
    default_axes = axes.default_axes == true,
    element_count = created_count,
  }
end

local function create_selected_vector_components_in_directions(model, options)
  options = validate_component_options(options)
  validate_option_styles(model, options, { "component_attributes", "guide_attributes" })
  local segment, first_direction, second_direction = selected_vector_and_directions(model)
  local components = components_in_directions(
    segment.vector,
    first_direction.vector,
    second_direction.vector
  )
  local labels = component_labels(options.label_base or DEFAULT_LABEL_BASE, options.label_style or "12")

  local start = segment.start
  local first_end = add(start, components.first)
  local second_end = add(start, components.second)
  local vector_tip = segment.finish
  local label_offset = number_value(options.label_offset, "label_offset", 6)
  if label_offset < 0 then error("label_offset must be non-negative") end

  local component_forced_attrs = {
    pathmode = "stroked",
    dashstyle = "dashed",
    farrow = true,
    rarrow = false,
  }
  if options.component_pen then component_forced_attrs.pen = options.component_pen end
  if options.arrow_shape then component_forced_attrs.farrowshape = options.arrow_shape end
  if options.arrow_size then component_forced_attrs.farrowsize = options.arrow_size end
  local component_attrs = vector_creation_attributes(segment.object, {
    stroke = "black",
    pen = "normal",
    pathmode = "stroked",
    farrow = true,
    farrowshape = options.arrow_shape or DEFAULT_ARROW,
    farrowsize = options.arrow_size or "normal",
  }, component_forced_attrs, options.component_attributes)
  local guide_attrs = merge_attributes({
    stroke = "black",
    pen = options.guide_pen or "normal",
    pathmode = "stroked",
    dashstyle = "dotted",
  }, options.guide_attributes)
  guide_attrs.pathmode = "stroked"

  local first_angle = vector_angle(components.first, vector_angle(first_direction.vector, 0))
  local second_angle = vector_angle(components.second, vector_angle(second_direction.vector, 0))
  local source_scale = length(segment.vector)
  local first_nonzero = has_significant_length(components.first, source_scale)
  local second_nonzero = has_significant_length(components.second, source_scale)
  if not first_nonzero and not second_nonzero then
    error("Selected vector must have positive length")
  end

  local first_label_offset, first_label_alignment =
    outside_label_placement(first_angle, components.second, label_offset, -1)
  local second_label_offset, second_label_alignment =
    outside_label_placement(second_angle, components.first, label_offset, 1)

  local objects = {}
  if first_nonzero then
    append_object(objects, "component_1", line_path(component_attrs, start, first_end, true))
  end
  if second_nonzero then
    append_object(objects, "component_2", line_path(component_attrs, start, second_end, true))
  end
  if first_nonzero and second_nonzero then
    append_object(objects, "guide_1", line_path(guide_attrs, vector_tip, first_end, false))
  end
  if second_nonzero and first_nonzero then
    append_object(objects, "guide_2", line_path(guide_attrs, vector_tip, second_end, false))
  end
  if first_nonzero then
    append_object(objects, "label_1", transformed_label(model, labels.first, first_end,
      first_angle, first_label_offset, first_label_alignment, options))
  end
  if second_nonzero then
    append_object(objects, "label_2", transformed_label(model, labels.second, second_end,
      second_angle, second_label_offset, second_label_alignment, options))
  end

  local base_metadata = {
    label_base = options.label_base or DEFAULT_LABEL_BASE,
    label_style = labels.style,
    source = segment.index,
    direction_1 = first_direction.index,
    direction_2 = second_direction.index,
  }
  local created_count = 0
  local created_objects = {}
  for _, item in ipairs(objects) do
    if item.object then
      local fields = clone_attributes(base_metadata)
      fields.role = item.role
      set_custom(item.object, metadata_with_prefix("vectors:oblique-components", fields))
      created_objects[#created_objects + 1] = item.object
      created_count = created_count + 1
    end
  end
  register_objects(model, created_objects, "create vector oblique components")

  return {
    created = true,
    created_count = created_count,
    source_index = segment.index,
    first_direction_index = first_direction.index,
    second_direction_index = second_direction.index,
    label_style = labels.style,
    first_scalar = components.first_scalar,
    second_scalar = components.second_scalar,
    first = components.first,
    second = components.second,
    element_count = created_count,
  }
end

local function create_selected_vector_resultant_auto(model, options)
  options = validate_resultant_options(options)
  validate_option_styles(model, options, { "resultant_attributes" })
  local segments = selected_vector_segments(model, { minimum = 2 })
  local tolerance = number_value(options.touch_tolerance, "touch_tolerance", DEFAULT_TOUCH_TOLERANCE)
  if tolerance < 0 then error("touch_tolerance must be non-negative") end

  local plan = resultant_plan_many(segments, tolerance)
  local resultant_forced_attrs = {
    pathmode = "stroked",
    farrow = true,
    rarrow = false,
  }
  if options.resultant_pen then resultant_forced_attrs.pen = options.resultant_pen end
  if options.arrow_shape then resultant_forced_attrs.farrowshape = options.arrow_shape end
  if options.arrow_size then resultant_forced_attrs.farrowsize = options.arrow_size end
  local attrs = vector_creation_attributes(segments[1].object, {
    stroke = "black",
    pen = "normal",
    pathmode = "stroked",
    dashstyle = "solid",
    farrow = true,
    farrowshape = options.arrow_shape or DEFAULT_ARROW,
    farrowsize = options.arrow_size or "normal",
  }, resultant_forced_attrs, options.resultant_attributes)
  local object = line_path(attrs, plan.start, plan.finish, true)
  register_object(model, object, metadata_with_prefix("vectors:resultant", source_metadata_fields(segments, {
    mode = plan.mode,
    contact = plan.contact,
  })), "create vector resultant")

  return {
    created = true,
    created_count = 1,
    element_count = 1,
    mode = plan.mode,
    contact = plan.contact,
    source_count = #segments,
    source_indexes = source_indexes(segments),
    first_source_index = segments[1].index,
    second_source_index = segments[2].index,
    start = plan.start,
    finish = plan.finish,
    vector = plan.vector,
  }
end

local function create_selected_vector_subtraction_auto(model, options)
  options = validate_subtraction_options(options)
  validate_option_styles(model, options, { "subtraction_attributes", "resultant_attributes" })
  local segments = selected_vector_segments(model, { minimum = 2 })
  local tolerance = number_value(options.touch_tolerance, "touch_tolerance", DEFAULT_TOUCH_TOLERANCE)
  if tolerance < 0 then error("touch_tolerance must be non-negative") end

  local plan = subtraction_plan_many(segments, tolerance)
  local subtraction_forced_attrs = {
    pathmode = "stroked",
    farrow = true,
    rarrow = false,
  }
  if options.subtraction_pen or options.resultant_pen then
    subtraction_forced_attrs.pen = options.subtraction_pen or options.resultant_pen
  end
  if options.arrow_shape then subtraction_forced_attrs.farrowshape = options.arrow_shape end
  if options.arrow_size then subtraction_forced_attrs.farrowsize = options.arrow_size end
  local attrs = vector_creation_attributes(segments[1].object, {
    stroke = "black",
    pen = "normal",
    pathmode = "stroked",
    dashstyle = "solid",
    farrow = true,
    farrowshape = options.arrow_shape or DEFAULT_ARROW,
    farrowsize = options.arrow_size or "normal",
  }, subtraction_forced_attrs, options.subtraction_attributes or options.resultant_attributes)
  local object = line_path(attrs, plan.start, plan.finish, true)
  local arithmetic_segments = plan.segments or segments
  register_object(model, object, metadata_with_prefix("vectors:subtraction", source_metadata_fields(arithmetic_segments, {
    mode = plan.mode,
    contact = plan.contact,
    minuend = arithmetic_segments[1].index,
    subtrahend = arithmetic_segments[2].index,
  })), "create vector subtraction")

  return {
    created = true,
    created_count = 1,
    element_count = 1,
    mode = plan.mode,
    contact = plan.contact,
    source_count = #arithmetic_segments,
    source_indexes = source_indexes(arithmetic_segments),
    first_source_index = arithmetic_segments[1].index,
    second_source_index = arithmetic_segments[2].index,
    minuend_source_index = arithmetic_segments[1].index,
    subtrahend_source_index = arithmetic_segments[2].index,
    subtrahend_source_indexes = source_indexes(arithmetic_segments, 2),
    start = plan.start,
    finish = plan.finish,
    vector = plan.vector,
  }
end

local VECTOR_PREVIEW_CREATORS = {
  current_axes = create_selected_vector_components,
  selected_directions = create_selected_vector_components_in_directions,
}

local function normalized_preview_action(action)
  local name = tostring(action or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  name = name:gsub("[%s:%-]+", "_")
  local aliases = {
    create_components = "current_axes",
    create_components_in_current_axes = "current_axes",
    decompose_selected_vector_components = "current_axes",
    components_in_selected_directions = "selected_directions",
    decompose_into_selected_directions = "selected_directions",
    decompose_selected_vector_in_directions = "selected_directions",
  }
  return aliases[name] or name
end

local function preview_capture_model(model)
  local captured = {}
  local capture = {
    attributes = model and model.attributes or {},
    snap = model and model.snap or {},
    pno = model and model.pno or 1,
    vno = model and model.vno or 1,
    captured_objects = captured,
  }
  _G.setmetatable(capture, { __index = model })

  function capture:page()
    if model and type(model.page) == "function" then return model:page() end
    error("model:page is not available")
  end

  function capture:selection()
    if model and type(model.selection) == "function" then return model:selection() end
    local page = self:page()
    if page and type(page.selection) == "function" then return page:selection() end
    return {}
  end

  function capture:creation(label_value, object)
    captured[#captured + 1] = { label = label_value, object = object }
  end

  function capture:register(record)
    for _, object in ipairs(record.objects or {}) do
      captured[#captured + 1] = { label = record.label, object = object }
    end
  end

  function capture:warning(title, message)
    error(tostring(title or "Vectors preview") .. ": " .. tostring(message or "failed"))
  end

  return capture
end

local function preview_object_type(object)
  if object and type(object.type) == "function" then
    local ok, value = pcall(function() return object:type() end)
    if ok then return value end
  end
  if type(object) == "table" then return object.kind or object.object_type end
  return nil
end

local function preview_object_shape(object)
  if object and type(object.shape) == "function" then
    local ok, value = pcall(function() return object:shape() end)
    if ok then return value end
  end
  if type(object) == "table" then return object.shape_value or object.shape end
  return nil
end

local function append_preview_object_shapes(shapes, object)
  local kind = preview_object_type(object)
  if kind == "path" then
    for _, shape in ipairs(preview_object_shape(object) or {}) do shapes[#shapes + 1] = shape end
  elseif kind == "group" and object and type(object.elements) == "function" then
    local ok, elements = pcall(function() return object:elements() end)
    if ok then
      for _, child in ipairs(elements or {}) do append_preview_object_shapes(shapes, child) end
    end
  end
end

function API.preview_shape_data(model, action, options)
  local key = normalized_preview_action(action)
  local creator = VECTOR_PREVIEW_CREATORS[key]
  if type(creator) ~= "function" then error("unsupported preview action: " .. tostring(action)) end

  local capture = preview_capture_model(model)
  if options == nil then options = {} end
  local result = creator(capture, options)
  local shapes = {}
  for _, entry in ipairs(capture.captured_objects) do
    append_preview_object_shapes(shapes, entry.object)
  end
  if #shapes == 0 then error("preview produced no visible shapes") end
  return {
    action = key,
    shapes = shapes,
    shape_count = #shapes,
    captured_object_count = #capture.captured_objects,
    result = result,
  }
end

local VECTOR_PREVIEW_COLOR = { 0.1, 0.35, 0.95 }

local VECTOR_PREVIEW_TOOL = {}
VECTOR_PREVIEW_TOOL.__index = VECTOR_PREVIEW_TOOL

function VECTOR_PREVIEW_TOOL:new(model)
  local tool = { model = model, active = true }
  _G.setmetatable(tool, VECTOR_PREVIEW_TOOL)
  model.ui:shapeTool(tool)
  if tool.setColor then tool.setColor(table.unpack(VECTOR_PREVIEW_COLOR)) end
  return tool
end

function VECTOR_PREVIEW_TOOL:update(shapes)
  if not self.active or not self.setShape then return end
  self.setShape(shapes or {})
  if self.model.ui and self.model.ui.update then self.model.ui:update(false) end
end

function VECTOR_PREVIEW_TOOL:finish()
  if not self.active then return end
  self.active = false
  self.model.ui:finishTool()
  if self.model.ui and self.model.ui.update then self.model.ui:update(false) end
end

function VECTOR_PREVIEW_TOOL:mouseButton()
  return true
end

function VECTOR_PREVIEW_TOOL:key(text)
  return text == "\027"
end

local function preview_options_signature(action, options)
  local parts = { tostring(action) }
  local keys = {}
  for key, _ in pairs(options or {}) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. tostring(options[key]) end
  return table.concat(parts, "|")
end

local function start_component_dialog_preview(model, dialog, action, read_options)
  if not model or not model.ui or type(model.ui.shapeTool) ~= "function" then return nil end
  local preview = {
    active = true,
    last_signature = nil,
    last_error = nil,
    live = true,
    tool = VECTOR_PREVIEW_TOOL:new(model),
  }

  local function update(force)
    if not preview.active then return end
    local ok_live, live = pcall(function() return dialog:get("live_preview") end)
    local live_enabled = ok_live and live == true
    if not force and not live_enabled then
      if preview.live then preview.tool:update({}) end
      preview.live = false
      preview.last_signature = nil
      preview.last_error = nil
      return
    end
    preview.live = live_enabled

    local ok_options, options_or_error = pcall(read_options)
    if not ok_options then
      local message = clean_error_message(options_or_error)
      if force or preview.last_error ~= message then
        preview.tool:update({})
        if model.ui.explain then model.ui:explain("Preview: " .. message) end
      end
      preview.last_signature = nil
      preview.last_error = message
      return
    end
    local signature = preview_options_signature(action, options_or_error)
    if not force and signature == preview.last_signature then return end
    preview.last_signature = signature
    preview.last_error = nil
    dialog:set("preview_value", component_label_preview_text(
      options_or_error.label_base,
      options_or_error.label_style
    ))

    local ok_data, data_or_error = pcall(API.preview_shape_data, model, action, options_or_error)
    if ok_data then
      preview.tool:update(data_or_error.shapes)
    else
      preview.tool:update({})
      local message = clean_error_message(data_or_error)
      if force or preview.last_error ~= message then
        if model.ui.explain then model.ui:explain("Preview: " .. message) end
      end
      preview.last_error = message
    end
  end

  preview.update = update
  preview.stop = function()
    if not preview.active then return end
    preview.active = false
    if preview.timer then pcall(function() preview.timer:stop() end) end
    preview.tool:finish()
  end
  preview.tick = function() update(false) end
  if ipeui and type(ipeui.Timer) == "function" then
    preview.timer = ipeui.Timer(preview, "tick")
    preview.timer:setInterval(150)
    preview.timer:start()
  end
  update(false)
  return preview
end

local function dialog_parent(model)
  local ui = model and model.ui
  if ui and type(ui.win) == "function" then return ui:win() end
  return nil
end

local function component_dialog(model, action)
  if type(ipeui) ~= "table" or type(ipeui.Dialog) ~= "function" then
    return {
      label_base = DEFAULT_LABEL_BASE,
      label_style = "12",
    }
  end

  local styles = { "_1 / _2", "_x / _y" }
  local dialog = ipeui.Dialog(dialog_parent(model), "Vector components")
  dialog:add("base_label", "label", { label = "Label base:" }, 1, 1)
  dialog:add("label_base", "input", {}, 1, 2)
  dialog:add("style_label", "label", { label = "Component labels:" }, 2, 1)
  dialog:add("label_style", "combo", styles, 2, 2)
  dialog:add("preview_label", "label", { label = "Preview:" }, 3, 1)
  dialog:add("preview_value", "label", { label = "" }, 3, 2)
  dialog:add("live_preview", "checkbox", { label = "Live preview" }, 4, 1, 1, 2)
  dialog:set("label_base", DEFAULT_LABEL_BASE)
  dialog:set("label_style", 1)
  dialog:set("preview_value", component_label_preview_text(DEFAULT_LABEL_BASE, "12"))
  dialog:set("live_preview", true)

  local function read_options()
    local selected_style = tonumber(dialog:get("label_style")) == 2 and "xy" or "12"
    local base = tostring(dialog:get("label_base") or DEFAULT_LABEL_BASE)
    if base == "" then base = DEFAULT_LABEL_BASE end
    return {
      label_base = base,
      label_style = selected_style,
    }
  end

  local preview = start_component_dialog_preview(model, dialog, action, read_options)
  dialog:addButton("cancel", "&Cancel", "reject")
  dialog:addButton("preview", "&Preview", function() if preview then preview.update(true) end end)
  dialog:addButton("ok", "&Create", "accept")
  local accepted = dialog:execute()
  if preview then preview.stop() end
  if not accepted then return nil end
  return read_options()
end

local function run_with_warning(model, callback)
  local ok, result = pcall(callback)
  if ok then return result end
  if model and type(model.warning) == "function" then
    model:warning("Vectors", clean_error_message(result))
    return false
  end
  error(result)
end

methods = {
  {
    label = "Create components in current axes",
    run = function(model)
      return run_with_warning(model, function()
        local options = component_dialog(model, "current_axes")
        if not options then return false end
        return create_selected_vector_components(model, options)
      end)
    end,
  },
  {
    label = "Decompose into selected directions",
    run = function(model)
      return run_with_warning(model, function()
        local options = component_dialog(model, "selected_directions")
        if not options then return false end
        return create_selected_vector_components_in_directions(model, options)
      end)
    end,
  },
  {
    label = "Create resultant from selected (auto)",
    run = function(model)
      return run_with_warning(model, function()
        return create_selected_vector_resultant_auto(model, {})
      end)
    end,
  },
  {
    label = "Subtract selected (auto)",
    run = function(model)
      return run_with_warning(model, function()
        return create_selected_vector_subtraction_auto(model, {})
      end)
    end,
  },
}

API.current_axes_from_model = current_axes_from_model
API.components_in_axes = components_in_axes
API.components_in_directions = components_in_directions
API.selected_vector_segment = selected_vector_segment
API.component_labels = component_labels
API.component_label_preview_text = component_label_preview_text
API.create_selected_vector_components = create_selected_vector_components
API.create_selected_vector_components_in_directions = create_selected_vector_components_in_directions
API.create_selected_vector_resultant_auto = create_selected_vector_resultant_auto
API.create_selected_vector_subtraction_auto = create_selected_vector_subtraction_auto

_G.VECTORS = API
