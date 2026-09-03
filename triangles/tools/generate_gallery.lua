local runtime, output, style_path = assert(argv[1]), assert(argv[2]), assert(argv[3])
dofile(runtime)
local api = assert(TRIANGLES)

local V = ipe.Vector
local document = ipe.Document()
local layout = assert(ipe.Sheet(nil, [[
<ipestyle name="triangles-gallery-layout">
<layout paper="900 600" origin="0 0" frame="900 600" crop="no"/>
</ipestyle>
]]))
local style = assert(ipe.Sheet(style_path))
local sheets = document:sheets()
sheets:insert(1, style)
sheets:insert(1, layout)
local TRIANGLE_SCALE = 0.78

local function path_attributes(stroke, dash, pen)
  return {
    stroke = stroke or "black", pen = pen or "normal", dashstyle = dash or "normal",
    linecap = "normal", linejoin = "miter",
  }
end

local function text_attributes(stroke, size)
  return {
    stroke = stroke or "black", textsize = size or "normal",
    horizontalalignment = "hcenter", verticalalignment = "vcenter",
  }
end

local function mark_attributes(stroke, size)
  return {
    stroke = stroke or "black", fill = "white", symbolsize = size or "normal",
  }
end

local function text(page, value, x, y, size, stroke)
  page:insert(nil, ipe.Text(text_attributes(stroke, size), value, V(x, y)), nil, "alpha")
end

local function mark(page, x, y, stroke, size, selection)
  local object = ipe.Reference(mark_attributes(stroke, size), "mark/disk(sx)", V(x, y))
  page:insert(nil, object, selection, "alpha")
  return #page
end

local function triangle_path(points)
  local a, b, c = points[1], points[2], points[3]
  return ipe.Path(path_attributes("black", nil, "semithick"), {
    { type = "curve", closed = true;
      { type = "segment"; V(a.x, a.y), V(b.x, b.y) },
      { type = "segment"; V(b.x, b.y), V(c.x, c.y) },
      { type = "segment"; V(c.x, c.y), V(a.x, a.y) },
    },
  }, false)
end

local function compact_triangle(points, reference)
  local center = {
    x = (points[1].x + points[2].x + points[3].x) / 3,
    y = (points[1].y + points[2].y + points[3].y) / 3,
  }
  local function compact(point)
    point.x = center.x + (point.x - center.x) * TRIANGLE_SCALE
    point.y = center.y + (point.y - center.y) * TRIANGLE_SCALE
  end
  for _, point in ipairs(points) do compact(point) end
  if reference then compact(reference) end
end

local function add_triangle(page, points, labels, reference)
  compact_triangle(points, reference)
  page:insert(nil, triangle_path(points), 1, "alpha")
  local index = #page
  if labels then
    local offsets = { { 0, 20 }, { -18, -15 }, { 18, -15 } }
    for vertex = 1, 3 do
      text(page, "$" .. ({ "A", "B", "C" })[vertex] .. "$",
        points[vertex].x + offsets[vertex][1], points[vertex].y + offsets[vertex][2], "LARGE")
    end
  end
  return index
end

local function page_model(page_number, color)
  local model = {
    doc = document, pno = page_number, vno = 1, warnings = {},
    attributes = {
      stroke = color or "blue", pen = "normal", dashstyle = "normal",
      markshape = "mark/disk(sx)", symbolsize = "large", textsize = "LARGE",
      horizontalalignment = "hcenter", verticalalignment = "vcenter",
    },
  }
  function model:page() return self.doc[self.pno] end
  function model:warning(title, detail)
    self.warnings[#self.warnings + 1] = { title = title, detail = detail }
  end
  function model:register(transaction) transaction.redo(transaction, self.doc) end
  return model
end

local function select_source(page, triangle_index, reference_index)
  page:deselectAll()
  page:setSelect(triangle_index, 1)
  if reference_index then page:setSelect(reference_index, 2) end
end

local function run(model, triangle_index, creator, options, reference_index)
  select_source(model:page(), triangle_index, reference_index)
  local result = creator(model, options)
  assert(result.created == true, result.error)
  return result
end

local function new_page(title, subtitle)
  local page = ipe.Page()
  if #document == 1 and #document[1] == 0 then
    document:set(1, page)
  else
    document:append(page)
  end
  local page_number = #document
  page = document[page_number]
  text(page, title, 450, 558, "LARGE")
  if subtitle then text(page, subtitle, 450, 520, "large", "darkgray") end
  return page, page_number
end

local function panel_title(page, value, x)
  text(page, value, x, 462, "Large")
end

local page, page_number = new_page(
  "Fundamental centers and Euler line",
  "Select the triangle once; no vertex marks are required")
local fundamental = {
  { x = 325, y = 455 }, { x = 135, y = 105 }, { x = 765, y = 135 },
}
local source = add_triangle(page, fundamental, true)
local model = page_model(page_number, "blue")
run(model, source, api.create_triangle_centers, {
  centers = "fundamental", marks = true, labels = true,
  euler_line = true, group_output = true,
})

page, page_number = new_page(
  "Defining lines",
  "Only recognized constructions are drawn for each center")
local panels = {
  {
    title = "Medians", x = 155, color = "blue", centers = { "centroid" },
    points = { { x = 155, y = 405 }, { x = 45, y = 115 }, { x = 285, y = 130 } },
  },
  {
    title = "Angle bisectors", x = 450, color = "darkgreen", centers = { "incenter" },
    points = { { x = 450, y = 405 }, { x = 335, y = 120 }, { x = 580, y = 140 } },
  },
  {
    title = "Bisectors and altitudes", x = 745, color = "purple",
    centers = { "circumcenter", "orthocenter" },
    points = { { x = 745, y = 405 }, { x = 625, y = 120 }, { x = 865, y = 145 } },
  },
}
for _, panel in ipairs(panels) do
  panel_title(page, panel.title, panel.x)
  source = add_triangle(page, panel.points, false)
  model = page_model(page_number, panel.color)
  run(model, source, api.create_triangle_centers, {
    centers = panel.centers, marks = true, labels = true,
    defining_lines = true, group_output = true,
  })
end

page, page_number = new_page(
  "Contact and Cevian geometry",
  "Contact triangle, Gergonne cevians, and Nagel cevians")
local contact_panels = {
  {
    title = "Contact triangle", x = 155, color = "darkgreen", derived = true,
    points = { { x = 155, y = 400 }, { x = 35, y = 120 }, { x = 285, y = 140 } },
  },
  {
    title = "Gergonne point", x = 450, color = "blue", center = "gergonne_point",
    points = { { x = 450, y = 400 }, { x = 330, y = 120 }, { x = 580, y = 140 } },
  },
  {
    title = "Nagel point", x = 745, color = "darkred", center = "nagel_point",
    points = { { x = 745, y = 400 }, { x = 625, y = 120 }, { x = 875, y = 140 } },
  },
}
for _, panel in ipairs(contact_panels) do
  panel_title(page, panel.title, panel.x)
  source = add_triangle(page, panel.points, false)
  model = page_model(page_number, panel.color)
  if panel.derived then
    run(model, source, api.create_triangle_derived, {
      operation = "contact_triangle", polygon = true, marks = true, labels = true,
      circle = true, contact_circle = "incircle", group_output = true,
    })
  else
    run(model, source, api.create_triangle_centers, {
      center = panel.center, marks = true, labels = true,
      defining_lines = true, group_output = true,
    })
  end
end

page, page_number = new_page(
  "Nine-point circle",
  "Side midpoints, altitude feet, and vertex-orthocenter midpoints")
local nine_point = {
  { x = 300, y = 455 }, { x = 105, y = 100 }, { x = 795, y = 135 },
}
source = add_triangle(page, nine_point, true)
model = page_model(page_number, "blue")
run(model, source, api.create_triangle_constructions, {
  centers = { "nine_point_center" },
  center_features = { mark = true, label = true, circle = true },
  derived = { "nine_point_points" }, derived_polygon = false,
  derived_marks = true, derived_labels = true, derived_circle = true,
  group_output = true,
})

page, page_number = new_page(
  "Reference-point constructions",
  "A selected point P drives the pedal triangle or the three cevians")
local reference_panels = {
  {
    title = "Pedal triangle", x = 245, color = "darkgreen", operation = "pedal_triangle",
    points = { { x = 245, y = 415 }, { x = 60, y = 105 }, { x = 425, y = 130 } },
    reference = { x = 245, y = 235 },
  },
  {
    title = "Cevian endpoints", x = 655, color = "darkred", operation = "cevian_endpoints",
    points = { { x = 655, y = 415 }, { x = 480, y = 105 }, { x = 845, y = 135 } },
    reference = { x = 675, y = 225 },
  },
}
for _, panel in ipairs(reference_panels) do
  panel_title(page, panel.title, panel.x)
  source = add_triangle(page, panel.points, false, panel.reference)
  local reference = mark(page, panel.reference.x, panel.reference.y, "orange", "large", 2)
  text(page, "$P$", panel.reference.x + 19, panel.reference.y + 19, "LARGE", "orange")
  model = page_model(page_number, panel.color)
  run(model, source, api.create_triangle_derived, {
    operation = panel.operation, polygon = true, marks = true, labels = true,
    group_output = true,
  }, reference)
end

page, page_number = new_page(
  "Isogonal and isotomic conjugates",
  "Both conjugates are calculated from the same selected point P")
local conjugate = {
  { x = 315, y = 455 }, { x = 115, y = 100 }, { x = 790, y = 135 },
}
local conjugate_reference = { x = 390, y = 245 }
source = add_triangle(page, conjugate, true, conjugate_reference)
local reference = mark(page, conjugate_reference.x, conjugate_reference.y, "orange", "large", 2)
text(page, "$P$", conjugate_reference.x + 22, conjugate_reference.y + 20, "LARGE", "orange")
model = page_model(page_number, "purple")
run(model, source, api.create_triangle_constructions, {
  derived = { "isogonal_conjugate", "isotomic_conjugate" },
  derived_polygon = false, derived_marks = true, derived_labels = true,
  group_output = true,
}, reference)

page, page_number = new_page(
  "Selected named centers",
  "Brocard, isogonic, isodynamic, symmedian, and Napoleon centers")
local named_panels = {
  {
    title = "Brocard points", x = 155, color = "blue",
    centers = { "first_brocard", "second_brocard" },
    points = { { x = 155, y = 400 }, { x = 35, y = 120 }, { x = 285, y = 140 } },
  },
  {
    title = "Isogonic and isodynamic", x = 450, color = "purple",
    centers = { "first_isogonic", "second_isogonic", "first_isodynamic", "second_isodynamic" },
    points = { { x = 450, y = 210 }, { x = 330, y = 150 }, { x = 570, y = 150 } },
  },
  {
    title = "K, X17, and X18", x = 745, color = "darkred",
    centers = { "symmedian_point", "first_napoleon", "second_napoleon" },
    points = { { x = 745, y = 400 }, { x = 625, y = 120 }, { x = 875, y = 140 } },
  },
}
for _, panel in ipairs(named_panels) do
  panel_title(page, panel.title, panel.x)
  source = add_triangle(page, panel.points, false)
  model = page_model(page_number, panel.color)
  run(model, source, api.create_triangle_centers, {
    centers = panel.centers, marks = true, labels = true, group_output = true,
  })
end

assert(#document == 7)
assert(document:save(output, "xml", { nozip = true }))
local latex_ok, latex_error = document:runLatex(output)
assert(latex_ok, latex_error)
assert(document:save(output, "xml", { nozip = true }))
print("TRIANGLES_GALLERY_OK pages=" .. tostring(#document))
