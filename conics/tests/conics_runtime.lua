-- Minimal, portable Ipe runtime used by the standalone Conics tests.
-- It intentionally defines no Geometry or MCP globals.

local matrix_mt = {}
matrix_mt.__index = matrix_mt

local function matrix(a, c, b, d, tx, ty)
  return setmetatable({
    a = a or 1, c = c or 0, b = b or 0, d = d or 1,
    tx = tx or 0, ty = ty or 0,
  }, matrix_mt)
end

function matrix_mt:coeff()
  return self.a, self.c, self.b, self.d, self.tx, self.ty
end

matrix_mt.__mul = function(left, right)
  if getmetatable(right) == matrix_mt then
    return matrix(
      left.a * right.a + left.b * right.c,
      left.c * right.a + left.d * right.c,
      left.a * right.b + left.b * right.d,
      left.c * right.b + left.d * right.d,
      left.a * right.tx + left.b * right.ty + left.tx,
      left.c * right.tx + left.d * right.ty + left.ty
    )
  end
  return {
    x = left.a * right.x + left.b * right.y + left.tx,
    y = left.c * right.x + left.d * right.y + left.ty,
  }
end

ipe = {
  Vector = function(x, y) return { x = x, y = y } end,
  Matrix = function(...) return matrix(...) end,
}

local function object(kind, attributes, data, position, symbol, children)
  local value = {
    kind = kind,
    attributes = attributes or {},
    data = data,
    position_value = position,
    symbol_value = symbol,
    elements_value = children,
    matrix_value = matrix(),
    custom = "",
  }
  function value:type() return self.kind end
  function value:shape() return self.data end
  function value:matrix() return self.matrix_value end
  function value:position() return self.position_value end
  function value:symbol() return self.symbol_value end
  function value:elements() return self.elements_value end
  function value:getCustom() return self.custom end
  function value:setCustom(custom) self.custom = custom end
  return value
end

function ipe.Path(attributes, shape)
  return object("path", attributes, shape)
end

function ipe.Reference(attributes, name, position)
  return object("reference", attributes, nil, position, name)
end

function ipe.Text(attributes, text, position)
  local value = object("text", attributes, nil, position)
  value.text = text
  return value
end

function ipe.Group(children)
  return object("group", {}, nil, nil, nil, children)
end

function ipe.Arc(transform, alpha, beta)
  local value = { transform = transform, alpha = alpha, beta = beta }
  function value:angles() return self.alpha, self.beta end
  function value:matrix() return self.transform end
  function value:endpoints()
    return self.transform * { x = math.cos(self.alpha), y = math.sin(self.alpha) },
      self.transform * { x = math.cos(self.beta), y = math.sin(self.beta) }
  end
  return value
end

ipeui = {}
dofile(assert(CONICS_PATH, "CONICS_PATH must name conics.lua"))
api = assert(_G.CONICS)

function mark(x, y, symbol)
  return ipe.Reference({}, symbol or "mark/disk(sx)", { x = x, y = y })
end

function segment(x1, y1, x2, y2)
  return ipe.Path({}, {
    { type = "curve", closed = false;
      { type = "segment"; { x = x1, y = y1 }, { x = x2, y = y2 } } },
  })
end

function new_model(initial, configuration)
  local entries = initial or {}
  configuration = configuration or {}
  local page = { active_layer_value = configuration.active_layer or "alpha" }
  setmetatable(page, {
    __len = function() return #entries end,
    __index = function(self, key)
      if type(key) == "number" then return entries[key] and entries[key].object end
      return rawget(self, key)
    end,
  })
  function page:active() return self.active_layer_value end
  function page:visible(_, value)
    local layer = type(value) == "number" and entries[value] and entries[value].layer or value
    if configuration.invisible_layers and configuration.invisible_layers[layer] then return false end
    return true
  end
  function page:primarySelection()
    for index, entry in ipairs(entries) do
      if entry.selected == 1 then return index end
    end
    return nil
  end
  function page:objects()
    local index = 0
    return function()
      index = index + 1
      local entry = entries[index]
      if entry then return index, entry.object, entry.selected, entry.layer or "alpha" end
    end
  end
  function page:deselectAll()
    for _, entry in ipairs(entries) do entry.selected = nil end
  end
  function page:insert(_, value, selected, layer)
    entries[#entries + 1] = { object = value, selected = selected, layer = layer }
  end
  function page:remove(index) table.remove(entries, index) end
  function page:replace(index, value)
    assert(entries[index], "replacement index must exist")
    entries[index].object = value
  end
  function page:setSelect(index, selection)
    assert(entries[index], "selection index must exist")
    entries[index].selected = selection
  end

  local document = { [1] = page }
  local ui = { explanations = {}, finished_tools = 0, updates = 0 }
  function ui:win() return self end
  function ui:explain(message) self.explanations[#self.explanations + 1] = message end
  function ui:shapeTool(tool)
    self.current_tool = tool
    tool.setColor = function() end
    tool.setShape = function(shapes) self.last_preview_shapes = shapes end
  end
  function ui:finishTool()
    self.finished_tools = self.finished_tools + 1
    self.current_tool = nil
  end
  function ui:update() self.updates = self.updates + 1 end

  local model = {
    pno = 1,
    vno = 1,
    entries = entries,
    attributes = configuration.attributes or {},
    ui = ui,
    registrations = {},
  }
  function model:page() return page end
  function model:register(registration)
    self.registration = registration
    self.registrations[#self.registrations + 1] = registration
    registration:redo(document)
  end
  function model:warning(title, detail)
    self.last_warning = { title = title, detail = detail }
  end
  return model, page, document
end

function approximate(left, right, tolerance)
  tolerance = tolerance or 1e-8
  return math.abs(left - right) <= tolerance * math.max(1, math.abs(left), math.abs(right))
end

function assert_contains(value, fragment)
  assert(type(value) == "string" and value:find(fragment, 1, true),
    "expected '" .. tostring(value) .. "' to contain '" .. fragment .. "'")
end
