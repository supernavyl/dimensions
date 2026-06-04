"""
Procedural FPS arms generator. Run via:
    blender --background --python tools/build_arms.py

Produces models/viewmodel/fps_arms_v2.glb — a pair of human-proportioned
forearms + hands in a viewmodel pose (forward, palms-down, slightly bent),
with skin material + subdivision surface for organic look.
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

OUT_PATH = (
    Path(__file__).resolve().parent.parent / "models" / "viewmodel" / "fps_arms_v2.glb"
)

# --- Anatomical proportions (meters) ---
UPPER_ARM_LEN = 0.30
FOREARM_LEN = 0.24
HAND_LEN = 0.20
HAND_WIDTH = 0.105
HAND_THICKNESS = 0.045
ELBOW_RADIUS = 0.062
WRIST_RADIUS = 0.038
SHOULDER_RADIUS = 0.070

# --- Viewmodel pose (relative to camera origin facing -Z) ---
# Hands held forward and slightly down, palms toward floor, like just woken up.
# Narrower spread + hands closer to centerline so they read as "my hands".
SHOULDER_OFFSET = Vector((0.13, -0.26, -0.05))  # x,y,z half-spread
HAND_TARGET = Vector((0.10, -0.20, -0.38))  # where the wrist ends up


def reset_scene() -> None:
    """Wipe the default cube + everything else so we start clean."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)


def make_skin_material() -> bpy.types.Material:
    """Realistic skin with subsurface scattering."""
    mat = bpy.data.materials.new("Skin")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    output = nt.nodes.new("ShaderNodeOutputMaterial")
    output.location = (400, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)

    bsdf.inputs["Base Color"].default_value = (0.92, 0.72, 0.62, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.5
    # Subsurface scattering — gives skin its translucent depth.
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = 0.15
    if "Subsurface Radius" in bsdf.inputs:
        bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.4, 0.3)
    bsdf.inputs["Specular IOR Level"].default_value = 0.4
    # Slight self-emission so arms register even in pitch-black scenes.
    if "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (0.30, 0.20, 0.16, 1.0)
    if "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Strength"].default_value = 0.3

    nt.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def make_nail_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("Nail")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.85, 0.72, 0.65, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.25
    return mat


def build_arm_mesh(side: str) -> bpy.types.Object:
    """Build one arm: tapered forearm cylinder + box-ish hand + finger nubs.

    side: "L" or "R" — controls which hand orientation is produced.
    Origin is at the elbow, pointing along -Z toward the wrist by default.
    """
    sign = 1.0 if side == "L" else -1.0

    bm = bmesh.new()

    # --- Forearm: tapered cylinder, elbow → wrist ---
    segments = 16
    rings = 8
    for r in range(rings + 1):
        t = r / rings
        z = -t * FOREARM_LEN
        # Subtle muscle bulge — fatter near elbow, taper to wrist.
        bulge = 1.0 + 0.18 * math.sin(t * math.pi) * (1.0 - t)
        radius = (ELBOW_RADIUS * (1.0 - t) + WRIST_RADIUS * t) * bulge
        for s in range(segments):
            ang = (s / segments) * math.tau
            # Slight elliptical cross-section — forearms aren't round.
            x = math.cos(ang) * radius * 1.1
            y = math.sin(ang) * radius * 0.85
            bm.verts.new((x, y, z))

    bm.verts.ensure_lookup_table()
    # Connect rings into quad faces.
    for r in range(rings):
        for s in range(segments):
            i0 = r * segments + s
            i1 = r * segments + (s + 1) % segments
            i2 = (r + 1) * segments + (s + 1) % segments
            i3 = (r + 1) * segments + s
            bm.faces.new((bm.verts[i0], bm.verts[i1], bm.verts[i2], bm.verts[i3]))

    # Cap the elbow end with a fan.
    elbow_verts = [bm.verts[s] for s in range(segments)]
    bm.faces.new(elbow_verts[::-1])

    # --- Hand: rounded slab at the wrist ---
    wrist_z = -FOREARM_LEN
    palm_z_end = wrist_z - HAND_LEN * 0.62  # palm portion ends here, fingers continue
    half_w = HAND_WIDTH * 0.5
    half_t = HAND_THICKNESS * 0.5

    palm_verts = [
        bm.verts.new((-half_w * sign, -half_t * 0.9, wrist_z)),
        bm.verts.new((half_w * sign, -half_t * 0.9, wrist_z)),
        bm.verts.new((half_w * sign, half_t, wrist_z)),
        bm.verts.new((-half_w * sign, half_t, wrist_z)),
        bm.verts.new((-half_w * sign * 0.92, -half_t * 0.95, palm_z_end)),
        bm.verts.new((half_w * sign * 0.92, -half_t * 0.95, palm_z_end)),
        bm.verts.new((half_w * sign * 0.92, half_t * 0.92, palm_z_end)),
        bm.verts.new((-half_w * sign * 0.92, half_t * 0.92, palm_z_end)),
    ]
    bm.faces.new((palm_verts[0], palm_verts[1], palm_verts[5], palm_verts[4]))  # bottom
    bm.faces.new((palm_verts[2], palm_verts[3], palm_verts[7], palm_verts[6]))  # top
    bm.faces.new(
        (palm_verts[1], palm_verts[2], palm_verts[6], palm_verts[5])
    )  # outer side
    bm.faces.new(
        (palm_verts[0], palm_verts[4], palm_verts[7], palm_verts[3])
    )  # inner side
    bm.faces.new(
        (palm_verts[4], palm_verts[5], palm_verts[6], palm_verts[7])
    )  # finger-end face

    # Fingers: 4 nubs from the palm-end face, slightly bent (curl).
    finger_len = HAND_LEN * 0.42
    finger_xs = [-0.36, -0.12, 0.12, 0.36]  # relative to half_w
    finger_thick = 0.014
    for fx in finger_xs:
        x_base = half_w * sign * fx * 1.6
        # Two-segment finger so it can curl.
        knuckle_z = palm_z_end - finger_len * 0.55
        tip_z = knuckle_z - finger_len * 0.45
        # Curl: tip dips below the palm plane.
        knuckle_y = -half_t * 0.4
        tip_y = -half_t * 1.2

        # Build a tiny tube manually for each finger — 6-sided cross section.
        finger_bm = bmesh.new()
        sides = 6
        # Three rings: at palm end, knuckle, tip
        rings_data = [
            (x_base, -half_t * 0.95, palm_z_end - 0.005, finger_thick),
            (x_base, knuckle_y, knuckle_z, finger_thick * 0.95),
            (x_base, tip_y, tip_z, finger_thick * 0.78),
        ]
        ring_idx = []
        for cx, cy, cz, cr in rings_data:
            base = len(finger_bm.verts)
            for s in range(sides):
                ang = (s / sides) * math.tau
                vx = cx + math.cos(ang) * cr
                vy = cy + math.sin(ang) * cr
                finger_bm.verts.new((vx, vy, cz))
            ring_idx.append(base)
        finger_bm.verts.ensure_lookup_table()
        for ri in range(len(ring_idx) - 1):
            for s in range(sides):
                i0 = ring_idx[ri] + s
                i1 = ring_idx[ri] + (s + 1) % sides
                i2 = ring_idx[ri + 1] + (s + 1) % sides
                i3 = ring_idx[ri + 1] + s
                finger_bm.faces.new(
                    (
                        finger_bm.verts[i0],
                        finger_bm.verts[i1],
                        finger_bm.verts[i2],
                        finger_bm.verts[i3],
                    )
                )
        # Cap fingertip
        tip_verts = [finger_bm.verts[ring_idx[-1] + s] for s in range(sides)]
        finger_bm.faces.new(tip_verts)

        # Merge finger into main bm.
        finger_mesh = bpy.data.meshes.new("FingerTmp")
        finger_bm.to_mesh(finger_mesh)
        finger_bm.free()
        offset_base = len(bm.verts)
        for v in finger_mesh.vertices:
            bm.verts.new(v.co)
        bm.verts.ensure_lookup_table()
        for poly in finger_mesh.polygons:
            face_verts = [bm.verts[offset_base + i] for i in poly.vertices]
            try:
                bm.faces.new(face_verts)
            except ValueError:
                pass  # duplicate face — skip
        bpy.data.meshes.remove(finger_mesh)

    # Thumb — short stubby finger off the side, more angled.
    thumb_bm = bmesh.new()
    thumb_root_x = half_w * sign * 1.05
    thumb_root_z = wrist_z - HAND_LEN * 0.18
    thumb_tip_x = half_w * sign * 1.55
    thumb_tip_z = wrist_z - HAND_LEN * 0.42
    sides = 6
    for cx, cy, cz, cr in [
        (thumb_root_x, -half_t * 0.4, thumb_root_z, 0.018),
        (thumb_tip_x, -half_t * 0.6, thumb_tip_z, 0.013),
    ]:
        for s in range(sides):
            ang = (s / sides) * math.tau
            vx = cx + math.cos(ang) * cr
            vy = cy + math.sin(ang) * cr
            thumb_bm.verts.new((vx, vy, cz))
    thumb_bm.verts.ensure_lookup_table()
    for s in range(sides):
        i0 = s
        i1 = (s + 1) % sides
        i2 = sides + (s + 1) % sides
        i3 = sides + s
        thumb_bm.faces.new(
            (
                thumb_bm.verts[i0],
                thumb_bm.verts[i1],
                thumb_bm.verts[i2],
                thumb_bm.verts[i3],
            )
        )
    thumb_bm.faces.new([thumb_bm.verts[sides + s] for s in range(sides)])

    thumb_mesh = bpy.data.meshes.new("ThumbTmp")
    thumb_bm.to_mesh(thumb_mesh)
    thumb_bm.free()
    offset_base = len(bm.verts)
    for v in thumb_mesh.vertices:
        bm.verts.new(v.co)
    bm.verts.ensure_lookup_table()
    for poly in thumb_mesh.polygons:
        face_verts = [bm.verts[offset_base + i] for i in poly.vertices]
        try:
            bm.faces.new(face_verts)
        except ValueError:
            pass
    bpy.data.meshes.remove(thumb_mesh)

    # Smooth shading
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()

    mesh = bpy.data.meshes.new(f"Arm_{side}")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(f"Arm_{side}", mesh)
    bpy.context.scene.collection.objects.link(obj)

    # Subdivision surface for organic smooth look.
    subsurf = obj.modifiers.new("Subsurf", "SUBSURF")
    subsurf.levels = 2
    subsurf.render_levels = 2

    return obj


def position_arm(obj: bpy.types.Object, side: str) -> None:
    """Place the arm so the wrist lands at HAND_TARGET, elbow at SHOULDER_OFFSET.
    The forearm runs from elbow → wrist along the natural direction."""
    sign = 1.0 if side == "L" else -1.0
    elbow = Vector((SHOULDER_OFFSET.x * sign, SHOULDER_OFFSET.y, SHOULDER_OFFSET.z))
    wrist_target = Vector((HAND_TARGET.x * sign, HAND_TARGET.y, HAND_TARGET.z))

    # Mesh's local "wrist" is at (0, 0, -FOREARM_LEN). We need to rotate
    # so the local -Z axis points from elbow to wrist_target.
    direction = (wrist_target - elbow).normalized()
    # Build a rotation matrix: -Z axis → direction.
    base = Vector((0, 0, -1))
    axis = base.cross(direction)
    if axis.length < 1e-5:
        rot = Matrix.Identity(4)
    else:
        axis.normalize()
        angle = base.angle(direction)
        rot = Matrix.Rotation(angle, 4, axis)

    # Roll: rotate around the new -Z so the palm faces down (Y axis stays up).
    # Apply a small inward roll for natural hand orientation.
    roll_angle = math.radians(-18.0 * sign)
    roll = Matrix.Rotation(roll_angle, 4, direction)

    obj.matrix_world = Matrix.Translation(elbow) @ roll @ rot


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Select everything so the exporter includes both arms.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,  # apply subdivision modifier on export
        export_yup=True,
        export_animations=False,
        export_skins=False,
        export_morph=False,
    )


def main() -> None:
    reset_scene()
    skin = make_skin_material()
    nail = make_nail_material()  # available for future detail
    _ = nail

    for side in ("L", "R"):
        arm = build_arm_mesh(side)
        arm.data.materials.append(skin)
        position_arm(arm, side)

    export_glb(OUT_PATH)
    print(f"[build_arms] wrote {OUT_PATH}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # surface tracebacks to console
        import traceback

        traceback.print_exc()
        sys.exit(1)
