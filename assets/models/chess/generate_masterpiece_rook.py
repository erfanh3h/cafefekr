import math
import os
import numpy as np

def normalize(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else np.array([0.0, 1.0, 0.0])

def compute_smooth_normals_with_crease(verts_np, faces_idx, crease_angle_deg=35.0):
    cos_threshold = math.cos(math.radians(crease_angle_deg))
    face_normals = []
    
    for f in faces_idx:
        p0 = verts_np[f[0]]
        p1 = verts_np[f[1]]
        p2 = verts_np[f[2]]
        fn = np.cross(p1 - p0, p2 - p0)
        norm = np.linalg.norm(fn)
        face_normals.append(fn / norm if norm > 1e-9 else np.array([0.0, 1.0, 0.0]))
        
    v_to_faces = {}
    for f_idx, f in enumerate(faces_idx):
        for v in f:
            if v not in v_to_faces:
                v_to_faces[v] = []
            v_to_faces[v].append(f_idx)
            
    normals_list = []
    norm_cache = {}
    faces_out = []
    
    for f_idx, f in enumerate(faces_idx):
        fn = face_normals[f_idx]
        face_refs = []
        for v in f:
            compatible = []
            for adj_idx in v_to_faces[v]:
                afn = face_normals[adj_idx]
                if np.dot(fn, afn) >= cos_threshold:
                    compatible.append(afn)
            avg_n = normalize(np.mean(compatible, axis=0))
            key = (round(avg_n[0], 4), round(avg_n[1], 4), round(avg_n[2], 4))
            if key not in norm_cache:
                normals_list.append(avg_n)
                norm_cache[key] = len(normals_list)
            face_refs.append((v + 1, norm_cache[key]))
        faces_out.append(face_refs)
        
    return verts_np.tolist(), normals_list, faces_out

def write_obj(filename, vertices, normals, faces):
    with open(filename, "w", encoding="utf-8") as f:
        f.write("# Cafe Fekr Masterpiece 3D Staunton Piece - Royal Fortress Rook (v6.0)\n")
        f.write(f"o {os.path.splitext(os.path.basename(filename))[0]}\n")
        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")
        for n in normals:
            f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")
        for face in faces:
            face_str = " ".join(f"{v_idx}//{n_idx}" for v_idx, n_idx in face)
            f.write(f"f {face_str}\n")

def generate_masterpiece_rook():
    # 1. Classical Tournament Staunton Rook Profile (from base to parapet neck)
    profile = [
        # Base plinth & footpad rim
        (0.0400, 0.0000),
        (0.0425, 0.0035),
        (0.0428, 0.0080), # Lower plinth torus
        (0.0400, 0.0110),
        (0.0378, 0.0135), # Scotia concave hollow
        (0.0388, 0.0160),
        (0.0395, 0.0190), # Upper base torus bead
        (0.0365, 0.0225),
        (0.0345, 0.0255), # Base collar fillet
        # Tower shaft with subtle classical entasis
        (0.0326, 0.0290),
        (0.0315, 0.0360),
        (0.0302, 0.0440),
        (0.0290, 0.0530),
        (0.0278, 0.0620),
        (0.0268, 0.0700),
        (0.0264, 0.0745), # Tower waist (slimmest point)
        # Architectural Corbel Cornice (Machicolations)
        (0.0282, 0.0760), # Lower astragal collar
        (0.0312, 0.0780), # First corbel tier
        (0.0305, 0.0795), # Step indent
        (0.0345, 0.0818), # Second corbel tier
        (0.0338, 0.0832), # Step indent
        (0.0375, 0.0852), # Third corbel tier / Parapet capital
        (0.0386, 0.0872), # Upper corbel crown ring
        (0.0382, 0.0880)  # Parapet outer base ring
    ]
    
    num_merlons = 4
    slices_merlon = 10
    slices_crenel = 6
    cycle_slices = slices_merlon + slices_crenel # 16
    total_slices = num_merlons * cycle_slices    # 64
    
    verts = []
    faces = []
    
    # Bottom center vertex
    base_center_idx = len(verts)
    verts.append([0.0, 0.0, 0.0])
    
    # Lathe the profile for all 64 slices
    grid = []
    for p_idx, (r, y) in enumerate(profile):
        row = []
        for s in range(total_slices):
            angle = (s / float(total_slices)) * 2.0 * math.pi
            verts.append([r * math.cos(angle), y, r * math.sin(angle)])
            row.append(len(verts) - 1)
        grid.append(row)
        
    # Base bottom cap
    for s in range(total_slices):
        s_next = (s + 1) % total_slices
        faces.append([base_center_idx, grid[0][s], grid[0][s_next]])
        
    # Lathe body quads (split to tris)
    for p in range(len(profile) - 1):
        for s in range(total_slices):
            s_next = (s + 1) % total_slices
            p00 = grid[p][s]
            p01 = grid[p][s_next]
            p10 = grid[p + 1][s]
            p11 = grid[p + 1][s_next]
            faces.append([p00, p10, p11])
            faces.append([p00, p11, p01])
            
    # 2. Battlements Construction (Crenellations with 100% vertical rectangular sidewalls)
    outer_r = 0.0382
    inner_r = 0.0275
    crenel_y = 0.0880
    merlon_y = 0.0985 # 10.5mm prominent merlon battlements
    floor_y = 0.0800  # Sunken deck floor
    
    # Build the segmented rim rings:
    # Each slice s has:
    # - v_out_crenel: (outer_r, crenel_y)
    # - v_out_merlon: (outer_r, merlon_y)
    # - v_in_crenel:  (inner_r, crenel_y)
    # - v_in_merlon:  (inner_r, merlon_y)
    # - v_floor:      (inner_r, floor_y)
    #
    # Top rim of lathe body is grid[-1][s], which is at (outer_r, crenel_y)
    
    top_body_ring = grid[-1]
    
    rim_data = []
    for s in range(total_slices):
        angle = (s / float(total_slices)) * 2.0 * math.pi
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        
        # Out lower is already top_body_ring[s]
        out_low = top_body_ring[s]
        
        # Out high
        out_high = len(verts)
        verts.append([outer_r * cos_a, merlon_y, outer_r * sin_a])
        
        # In low
        in_low = len(verts)
        verts.append([inner_r * cos_a, crenel_y, inner_r * sin_a])
        
        # In high
        in_high = len(verts)
        verts.append([inner_r * cos_a, merlon_y, inner_r * sin_a])
        
        # Floor outer edge
        fl_edge = len(verts)
        verts.append([inner_r * cos_a, floor_y, inner_r * sin_a])
        
        phase = s % cycle_slices
        is_merlon = (phase < slices_merlon)
        
        rim_data.append({
            "out_low": out_low,
            "out_high": out_high,
            "in_low": in_low,
            "in_high": in_high,
            "fl_edge": fl_edge,
            "is_merlon": is_merlon,
            "phase": phase
        })
        
    for s in range(total_slices):
        s_next = (s + 1) % total_slices
        c1 = rim_data[s]
        c2 = rim_data[s_next]
        
        # Inner vertical wall down to floor (always present all around the 360 circle)
        faces.append([c1["in_low"], c1["fl_edge"], c2["fl_edge"]])
        faces.append([c1["in_low"], c2["fl_edge"], c2["in_low"]])
        
        if c1["is_merlon"] and c2["is_merlon"]:
            # Normal merlon segment: outer wall extends from crenel_y to merlon_y
            faces.append([c1["out_low"], c1["out_high"], c2["out_high"]])
            faces.append([c1["out_low"], c2["out_high"], c2["out_low"]])
            
            # Merlon top horizontal cap
            faces.append([c1["out_high"], c1["in_high"], c2["in_high"]])
            faces.append([c1["out_high"], c2["in_high"], c2["out_high"]])
            
            # Merlon inner vertical wall (from merlon_y down to crenel_y)
            faces.append([c1["in_high"], c1["in_low"], c2["in_low"]])
            faces.append([c1["in_high"], c2["in_low"], c2["in_high"]])
            
        elif (not c1["is_merlon"]) and (not c2["is_merlon"]):
            # Normal crenel (gap) segment: flat sill at crenel_y
            faces.append([c1["out_low"], c1["in_low"], c2["in_low"]])
            faces.append([c1["out_low"], c2["in_low"], c2["out_low"]])
            
        elif c1["is_merlon"] and (not c2["is_merlon"]):
            # TRANSITION: Merlon ending, Crenel starting!
            # We need a perfectly vertical radial wall dropping down at s_next boundary!
            # The merlon's top cap reaches s_next at height merlon_y:
            faces.append([c1["out_low"], c1["out_high"], c2["out_high"]])
            faces.append([c1["out_low"], c2["out_high"], c2["out_low"]])
            
            faces.append([c1["out_high"], c1["in_high"], c2["in_high"]])
            faces.append([c1["out_high"], c2["in_high"], c2["out_high"]])
            
            faces.append([c1["in_high"], c1["in_low"], c2["in_low"]])
            faces.append([c1["in_high"], c2["in_low"], c2["in_high"]])
            
            # Radial vertical step face: from (out_high, in_high) down to (out_low, in_low) at s_next!
            faces.append([c2["out_high"], c2["in_high"], c2["in_low"]])
            faces.append([c2["out_high"], c2["in_low"], c2["out_low"]])
            
        elif (not c1["is_merlon"]) and c2["is_merlon"]:
            # TRANSITION: Crenel ending, Merlon starting!
            faces.append([c1["out_low"], c1["in_low"], c2["in_low"]])
            faces.append([c1["out_low"], c2["in_low"], c2["out_low"]])
            
            # Radial vertical step face: from (out_low, in_low) up to (out_high, in_high) at s_next!
            faces.append([c2["out_low"], c2["in_low"], c2["in_high"]])
            faces.append([c2["out_low"], c2["in_high"], c2["out_high"]])

    # 3. Sunken Parapet Floor & Central Turret Boss
    # Floor goes from inner_r=0.0275 to boss_r=0.0150 at floor_y=0.0800
    boss_profile = [
        (0.0160, 0.0800), # Boss plinth outer ring
        (0.0145, 0.0825), # Boss step
        (0.0110, 0.0855), # Boss dome
        (0.0050, 0.0875), # Boss peak
        (0.0000, 0.0885)  # Apex finial
    ]
    
    boss_grid = []
    for b_r, b_y in boss_profile[:-1]:
        b_row = []
        for s in range(total_slices):
            angle = (s / float(total_slices)) * 2.0 * math.pi
            verts.append([b_r * math.cos(angle), b_y, b_r * math.sin(angle)])
            b_row.append(len(verts) - 1)
        boss_grid.append(b_row)
        
    # Apex vertex
    apex_idx = len(verts)
    verts.append([0.0, boss_profile[-1][1], 0.0])
    
    # Parapet flat deck floor (connecting fl_edge to boss_grid[0])
    for s in range(total_slices):
        s_next = (s + 1) % total_slices
        f1 = rim_data[s]["fl_edge"]
        f2 = rim_data[s_next]["fl_edge"]
        b1 = boss_grid[0][s]
        b2 = boss_grid[0][s_next]
        faces.append([f1, b1, b2])
        faces.append([f1, b2, f2])
        
    # Boss tiers
    for b in range(len(boss_profile) - 2):
        for s in range(total_slices):
            s_next = (s + 1) % total_slices
            b00 = boss_grid[b][s]
            b01 = boss_grid[b][s_next]
            b10 = boss_grid[b + 1][s]
            b11 = boss_grid[b + 1][s_next]
            faces.append([b00, b10, b11])
            faces.append([b00, b11, b01])
            
    # Boss top apex fan
    for s in range(total_slices):
        s_next = (s + 1) % total_slices
        faces.append([apex_idx, boss_grid[-1][s_next], boss_grid[-1][s]])
        
    return np.array(verts), faces

if __name__ == "__main__":
    v, f = generate_masterpiece_rook()
    print(f"Generated {len(v)} vertices, {len(f)} triangular faces.")
    v_out, n_out, f_out = compute_smooth_normals_with_crease(v, f, crease_angle_deg=35.0)
    print(f"Computed crease-aware normals: {len(n_out)} normals.")
    out_path = r"d:\game\cafefekr\assets\models\chess\rook.obj"
    write_obj(out_path, v_out, n_out, f_out)
    print(f"[SUCCESS] Wrote new masterpiece rook to {out_path}!")
