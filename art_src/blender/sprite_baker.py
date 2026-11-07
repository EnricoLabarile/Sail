"""SPRITE BAKER for Vento e Vele (Enrico, Nov 2026): a Blender add-on that photographs the selected 3D objects into a
PNG sprite ready for the game: a fixed picture (no animation), transparent wherever the objects aren't, seen from the
game's angle, and shaded so it dithers well (greys in a few clean steps, light from the game's sun).

INSTALL: Blender > Edit > Preferences > Add-ons > (the arrow top right) Install from Disk… > pick this file > tick
"Vento e Vele Sprite Baker". Works in Blender 4.2 and later (tested in 5.2).

USE: select the object(s) to print (a house, a tower…), open the 3D View's sidebar (N) > tab "Sprite", set the numbers
and press "Bake sprite". Nothing in the scene is changed: a camera, a sun and a world are made for the photo and
removed after; your own lights, other objects and render settings are put back.

THE SETTINGS (each one in the panel, top to bottom):
  - Output: where the PNG goes (e.g. the game folder: .../sail/Assets/Landscape/land/house_01.png).
  - Pixels per metre: how big it comes out. 12 ≈ the game on the phone at the usual camera distance (the boat sheet
    used 12); 9 = the islands' drawings.
  - Camera tilt: degrees from straight down (0 = top-down; 30 = the game camera). Camera turn: from which side you
    look at it (0 = from the south, looking north, as the game camera does).
  - Sun height / Sun direction: where the light comes from (degrees above the horizon; compass direction it comes
    FROM, 0 = north, 90 = east). The game's sun comes from the north-west, high: 70° / 315°.
  - Sun strength, Ambient: how bright the lit sides are, and how bright the shadowed sides stay.
  - Cast shadows: the object's own shadows on itself (a roof's shadow on a wall).
  - Engine: EEVEE (quick) or Cycles (slower, needs no graphics card: use it if EEVEE gives a flat grey picture).
  - Greyscale: the picture in greys (the game dithers greys to two colours anyway).
  - Stretch greys: the object's darkest grey becomes "Darkest" and its lightest "Lightest", the rest in between, so
    the steps below use the whole range (a render's greys are often all close together, and would round to one).
  - Grey steps: the greys rounded to this many steps (0 = no rounding). Few clean steps (4–6) dither into tidy,
    even patterns instead of noisy ones. Contrast and Brightness are applied before the rounding.
  - Hard edges: every pixel either solid or see-through (no half-transparent fringe), as the game draws pictures
    (alpha scissor). Margin: empty pixels round the object.

(In Unreal terms: like a "render to texture" / impostor bake, done once in the modelling tool.)
"""

bl_info = {
    "name": "Vento e Vele Sprite Baker",
    "author": "Enrico (with Claude)",
    "version": (1, 0, 0),
    "blender": (4, 2, 0),
    "location": "3D View > Sidebar (N) > Sprite",
    "description": "Bakes the selected objects into a PNG sprite for Vento e Vele (fixed angle, transparent, dither-ready)",
    "category": "Render",
}

import math
import os
import tempfile

import bpy
import numpy
from mathutils import Euler, Vector


# ---------- The settings (kept in the .blend, on the scene) ----------

class SpriteBakerSettings(bpy.types.PropertyGroup):
    output_path: bpy.props.StringProperty(name="Output", subtype="FILE_PATH", default="//sprite.png",
                                          description="Where the PNG is saved (// = next to the .blend)")
    pixels_per_metre: bpy.props.FloatProperty(name="Pixels per metre", default=12.0, min=1.0, max=200.0)
    camera_tilt: bpy.props.FloatProperty(name="Camera tilt", default=30.0, min=0.0, max=89.0,
                                         description="Degrees from straight down (0 = top-down, 30 = the game camera)")
    camera_turn: bpy.props.FloatProperty(name="Camera turn", default=0.0, min=-180.0, max=180.0,
                                         description="Degrees round: 0 = from the south looking north, as in the game")
    sun_height: bpy.props.FloatProperty(name="Sun height", default=70.0, min=1.0, max=90.0,
                                        description="Degrees above the horizon")
    sun_direction: bpy.props.FloatProperty(name="Sun direction", default=315.0, min=0.0, max=360.0,
                                           description="Compass direction the light comes FROM (0 north, 90 east)")
    sun_strength: bpy.props.FloatProperty(name="Sun strength", default=3.0, min=0.0, max=20.0)
    ambient: bpy.props.FloatProperty(name="Ambient", default=0.4, min=0.0, max=2.0,
                                     description="How bright the sides away from the sun stay")
    cast_shadows: bpy.props.BoolProperty(name="Cast shadows", default=True)
    engine: bpy.props.EnumProperty(name="Engine", default="EEVEE", items=[
        ("EEVEE", "EEVEE", "Quick (uses the graphics card)"),
        ("CYCLES", "Cycles", "Slower, works without a graphics card")])
    greyscale: bpy.props.BoolProperty(name="Greyscale", default=True)
    stretch_greys: bpy.props.BoolProperty(name="Stretch greys", default=True,
                                          description="The object's darkest grey to Darkest, its lightest to Lightest")
    darkest: bpy.props.FloatProperty(name="Darkest", default=0.15, min=0.0, max=1.0)
    lightest: bpy.props.FloatProperty(name="Lightest", default=1.0, min=0.0, max=1.0)
    grey_steps: bpy.props.IntProperty(name="Grey steps", default=5, min=0, max=32,
                                      description="Round the greys to this many steps (0 = no rounding)")
    contrast: bpy.props.FloatProperty(name="Contrast", default=1.0, min=0.0, max=4.0)
    brightness: bpy.props.FloatProperty(name="Brightness", default=0.0, min=-1.0, max=1.0)
    hard_edges: bpy.props.BoolProperty(name="Hard edges", default=True,
                                       description="Every pixel solid or see-through, as the game draws pictures")
    margin: bpy.props.IntProperty(name="Margin", default=2, min=0, max=64, description="Empty pixels round it")


# ---------- The panel ----------

class SPRITEBAKER_PT_panel(bpy.types.Panel):
    bl_label = "Sprite Baker"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Sprite"

    def draw(self, context):
        settings = context.scene.sprite_baker
        layout = self.layout
        layout.prop(settings, "output_path")
        layout.prop(settings, "pixels_per_metre")
        box = layout.box()
        box.label(text="Camera")
        box.prop(settings, "camera_tilt")
        box.prop(settings, "camera_turn")
        box = layout.box()
        box.label(text="Light")
        box.prop(settings, "sun_height")
        box.prop(settings, "sun_direction")
        box.prop(settings, "sun_strength")
        box.prop(settings, "ambient")
        box.prop(settings, "cast_shadows")
        box = layout.box()
        box.label(text="For the dither")
        box.prop(settings, "engine")
        box.prop(settings, "greyscale")
        box.prop(settings, "stretch_greys")
        if settings.stretch_greys:
            box.prop(settings, "darkest")
            box.prop(settings, "lightest")
        box.prop(settings, "grey_steps")
        box.prop(settings, "contrast")
        box.prop(settings, "brightness")
        box.prop(settings, "hard_edges")
        box.prop(settings, "margin")
        layout.operator("sprite_baker.bake", icon="RENDER_STILL")


# ---------- The bake ----------

class SPRITEBAKER_OT_bake(bpy.types.Operator):
    bl_idname = "sprite_baker.bake"
    bl_label = "Bake sprite"
    bl_description = "Photograph the selected objects into a PNG sprite"

    def execute(self, context):
        targets = [obj for obj in context.selected_objects if obj.type in {"MESH", "CURVE", "SURFACE", "META", "FONT"}]
        if not targets:
            self.report({"ERROR"}, "Select the object(s) to bake first")
            return {"CANCELLED"}
        path = bake_sprite(context.scene, targets, context.scene.sprite_baker)
        self.report({"INFO"}, "Sprite saved: " + path)
        return {"FINISHED"}


def bake_sprite(scene, targets, settings):
    """Photographs `targets` with the settings, saves the PNG and returns its path. The scene is left as it was."""
    saved = remember_scene(scene)
    made = []                              # the temporary things (removed at the end)
    try:
        hide_everything_else(scene, targets)
        camera = make_camera(scene, targets, settings)
        made.append(camera)
        made.append(make_sun(scene, settings))
        world = make_world(settings)
        scene.world = world
        set_up_render(scene, settings)
        # Render to a temporary file, then shade it for the dither and save it where it belongs.
        raw_path = os.path.join(tempfile.gettempdir(), "sprite_baker_raw.png")
        scene.render.filepath = raw_path
        bpy.ops.render.render(write_still=True)
        out_path = bpy.path.abspath(settings.output_path)
        finish_picture(raw_path, out_path, settings)
    finally:
        for obj in made:
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if data is not None:
                (bpy.data.cameras if isinstance(data, bpy.types.Camera) else bpy.data.lights).remove(data)
        restore_scene(scene, saved)
        if "Sprite Baker World" in bpy.data.worlds:
            bpy.data.worlds.remove(bpy.data.worlds["Sprite Baker World"])
    return out_path


# ---- keeping the scene as it was ----

def remember_scene(scene):
    render = scene.render
    return {
        "camera": scene.camera,
        "world": scene.world,
        "engine": render.engine,
        "filter_size": getattr(render, "filter_size", None),
        "resolution": (render.resolution_x, render.resolution_y, render.resolution_percentage),
        "film_transparent": render.film_transparent,
        "filepath": render.filepath,
        "file_format": render.image_settings.file_format,
        "color_mode": render.image_settings.color_mode,
        "view_transform": scene.view_settings.view_transform,
        "look": scene.view_settings.look,
        "hidden": {obj.name: obj.hide_render for obj in scene.objects},
    }


def restore_scene(scene, saved):
    render = scene.render
    scene.camera = saved["camera"]
    scene.world = saved["world"]
    render.engine = saved["engine"]
    if saved["filter_size"] is not None:
        render.filter_size = saved["filter_size"]
    render.resolution_x, render.resolution_y, render.resolution_percentage = saved["resolution"]
    render.film_transparent = saved["film_transparent"]
    render.filepath = saved["filepath"]
    render.image_settings.file_format = saved["file_format"]
    render.image_settings.color_mode = saved["color_mode"]
    scene.view_settings.view_transform = saved["view_transform"]
    scene.view_settings.look = saved["look"]
    for name, hidden in saved["hidden"].items():
        if name in scene.objects:
            scene.objects[name].hide_render = hidden


def hide_everything_else(scene, targets):
    """Only the selected objects in the photo: everything else (other objects, your own lights) hidden for now."""
    for obj in scene.objects:
        obj.hide_render = obj not in targets


# ---- the camera ----

def make_camera(scene, targets, settings):
    """An orthographic camera tilted like the game's, framing the targets exactly (plus the margin)."""
    data = bpy.data.cameras.new("Sprite Baker Camera")
    data.type = "ORTHO"
    camera = bpy.data.objects.new("Sprite Baker Camera", data)
    scene.collection.objects.link(camera)
    # Blender's camera looks down its -Z. Turned about X by the tilt it leans toward +Y (Blender's "north", the game's
    # -Z), then about Z by the turn.
    camera.rotation_euler = Euler((math.radians(settings.camera_tilt), 0.0, math.radians(settings.camera_turn)), "XYZ")
    rotation = camera.rotation_euler.to_matrix()
    right, up, forward = rotation.col[0], rotation.col[1], -rotation.col[2]
    # Every corner of every target's box, measured along the camera's right and up.
    corners = [obj.matrix_world @ Vector(corner) for obj in targets for corner in obj.bound_box]
    xs = [corner.dot(right) for corner in corners]
    ys = [corner.dot(up) for corner in corners]
    middle = sum(corners, Vector()) / len(corners)
    width = max(xs) - min(xs)
    height = max(ys) - min(ys)
    centre = right * ((max(xs) + min(xs)) / 2.0) + up * ((max(ys) + min(ys)) / 2.0)
    centre += forward * middle.dot(forward)                # on the plane through the objects' middle
    # The picture's size in pixels, and the camera's width in metres to match it exactly.
    margin_metres = settings.margin / settings.pixels_per_metre
    width += 2.0 * margin_metres
    height += 2.0 * margin_metres
    scene.render.resolution_x = max(1, math.ceil(width * settings.pixels_per_metre))
    scene.render.resolution_y = max(1, math.ceil(height * settings.pixels_per_metre))
    scene.render.resolution_percentage = 100
    data.ortho_scale = max(scene.render.resolution_x, scene.render.resolution_y) / settings.pixels_per_metre
    camera.location = centre - forward * 100.0             # far back along the way it looks
    data.clip_start = 0.1
    data.clip_end = 1000.0
    scene.camera = camera
    return camera


# ---- the light ----

def make_sun(scene, settings):
    """A sun from the chosen direction and height (its light comes FROM there)."""
    data = bpy.data.lights.new("Sprite Baker Sun", "SUN")
    data.energy = settings.sun_strength
    data.angle = 0.0                                       # sharp shadows
    if hasattr(data, "use_shadow"):
        data.use_shadow = settings.cast_shadows
    sun = bpy.data.objects.new("Sprite Baker Sun", data)
    scene.collection.objects.link(sun)
    # Where the sun is, seen from the objects: compass direction (0 = north = Blender's +Y, 90 = east = +X) and height.
    height = math.radians(settings.sun_height)
    compass = math.radians(settings.sun_direction)
    towards_sun = Vector((math.sin(compass) * math.cos(height), math.cos(compass) * math.cos(height), math.sin(height)))
    # A sun shines down its own -Z: so its +Z must point at the sun.
    sun.rotation_euler = towards_sun.to_track_quat("Z", "Y").to_euler()
    return sun


def make_world(settings):
    """The ambient light: a plain grey sky lighting the shadowed sides (the background itself is see-through)."""
    world = bpy.data.worlds.new("Sprite Baker World")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is None:
        background = world.node_tree.nodes.new("ShaderNodeBackground")
    background.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    background.inputs["Strength"].default_value = settings.ambient
    return world


def set_up_render(scene, settings):
    render = scene.render
    engines = [item.identifier for item in render.bl_rna.properties["engine"].enum_items]
    wanted = ("CYCLES",) if settings.engine == "CYCLES" else ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES")
    for engine in wanted:              # EEVEE's name changed between Blender versions
        if engine in engines:
            render.engine = engine
            break
    if render.engine == "CYCLES":
        scene.cycles.samples = 128          # enough not to leave speckles on a grey step's edge…
        if hasattr(scene.cycles, "use_denoising"):
            scene.cycles.use_denoising = True   # …and smoothed out
    if hasattr(render, "filter_size"):
        render.filter_size = 0.5       # little blur at the edges: crisp pixels
    render.film_transparent = True                          # nothing behind the objects: see-through
    render.image_settings.file_format = "PNG"
    render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"         # plain colours (no film-like curve)
    scene.view_settings.look = "None"


# ---- shading the picture for the dither ----

def finish_picture(raw_path, out_path, settings):
    """Greys, contrast, brightness, the grey steps and the hard edges, on the rendered picture; saved as out_path."""
    image = bpy.data.images.load(raw_path, check_existing=False)
    width, height = image.size
    pixels = numpy.empty(width * height * 4, dtype=numpy.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(-1, 4)
    rgb = pixels[:, :3]
    if settings.greyscale:
        grey = rgb @ numpy.array([0.299, 0.587, 0.114], dtype=numpy.float32)
        rgb[:] = grey[:, None]
    solid = pixels[:, 3] >= 0.5        # the object's pixels (not the see-through ones round it)
    if settings.stretch_greys and solid.any():
        low = rgb[solid].min()
        high = rgb[solid].max()
        if high > low:
            rgb[:] = (rgb - low) / (high - low) * (settings.lightest - settings.darkest) + settings.darkest
    rgb[:] = (rgb - 0.5) * settings.contrast + 0.5 + settings.brightness
    numpy.clip(rgb, 0.0, 1.0, out=rgb)
    if settings.grey_steps >= 2:
        # First a 3 x 3 median: a flat face lying right between two steps would otherwise round to both, in a
        # salt-and-pepper speckle; the median smooths such specks away and keeps the edges between faces sharp.
        for channel in range(3):
            rgb[:, channel] = median_3x3(rgb[:, channel].reshape(height, width)).ravel()
        steps = settings.grey_steps - 1
        rgb[:] = numpy.round(rgb * steps) / steps
    if settings.hard_edges:
        pixels[:, 3] = numpy.where(pixels[:, 3] >= 0.5, 1.0, 0.0)
    image.pixels.foreach_set(pixels.ravel())
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    image.filepath_raw = out_path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def median_3x3(values):
    """Each pixel replaced by the middle value of itself and its 8 neighbours (the picture's edge repeated outward)."""
    padded = numpy.pad(values, 1, mode="edge")
    rows, columns = values.shape
    shifted = [padded[dy:dy + rows, dx:dx + columns] for dy in range(3) for dx in range(3)]
    return numpy.median(numpy.stack(shifted), axis=0)


# ---------- Registration ----------

CLASSES = (SpriteBakerSettings, SPRITEBAKER_PT_panel, SPRITEBAKER_OT_bake)


def register():
    for cls in CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.sprite_baker = bpy.props.PointerProperty(type=SpriteBakerSettings)


def unregister():
    del bpy.types.Scene.sprite_baker
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
