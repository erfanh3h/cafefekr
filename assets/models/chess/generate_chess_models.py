"""
High-Poly Authentic Staunton 3D Chess Piece Model Generator
Generates clean, smooth Wavefront .OBJ 3D models with vertex normals for:
- pawn.obj
- rook.obj
- knight.obj
- bishop.obj
- queen.obj
- king.obj
"""

import math
import os


def write_obj(filename, vertices, normals, faces):
    """
    Writes an OBJ file with vertices, normals, and 1-based face indices.
    faces is a list of tuples: [(v1, n1), (v2, n2), (v3, n3), ...]
    """
    with open(filename, "w", encoding="utf-8") as f:
        f.write("# Cafe Fekr 3D Staunton Piece Model\n")
        f.write(f"o {os.path.splitext(os.path.basename(filename))[0]}\n")
        
        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")
            
        for n in normals:
            f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")
            
        for face in faces:
            face_str = " ".join(f"{v_idx}//{n_idx}" for v_idx, n_idx in face)
            f.write(f"f {face_str}\n")


def generate_lathe(profile, num_slices=40):
    """
    Generates a surface of revolution around the Y-axis from a profile of (r, y).
    Faces are strictly wound CCW pointing OUTWARD.
    """
    vertices = []
    normals = []
    faces = []
    
    num_pts = len(profile)
    
    # Precompute profile tangents for normals pointing outwards
    dr_dy = []
    for i in range(num_pts):
        if i == 0:
            dr = profile[1][0] - profile[0][0]
            dy = profile[1][1] - profile[0][1]
        elif i == num_pts - 1:
            dr = profile[-1][0] - profile[-2][0]
            dy = profile[-1][1] - profile[-2][1]
        else:
            dr = profile[i + 1][0] - profile[i - 1][0]
            dy = profile[i + 1][1] - profile[i - 1][1]
        length = math.sqrt(dr * dr + dy * dy)
        if length < 1e-8:
            dr_dy.append((1.0, 0.0))
        else:
            # Outward normal in (r, y): (dy, -dr)
            dr_dy.append((dy / length, -dr / length))

    # Bottom cap center
    base_center_idx = -1
    if profile[0][0] > 0.0001:
        vertices.append((0.0, profile[0][1], 0.0))
        normals.append((0.0, -1.0, 0.0))
        base_center_idx = len(vertices)

    # Top cap center
    top_center_idx = -1
    if profile[-1][0] > 0.0001:
        vertices.append((0.0, profile[-1][1], 0.0))
        normals.append((0.0, 1.0, 0.0))
        top_center_idx = len(vertices)

    # Grid of vertices: row p in 0..num_pts-1, col s in 0..num_slices-1
    grid = []
    for p in range(num_pts):
        row = []
        r, y = profile[p]
        nr, ny = dr_dy[p]
        
        # Tip vertex (r ~ 0)
        if r < 0.0001:
            vertices.append((0.0, y, 0.0))
            normals.append((0.0, 1.0 if ny >= 0 else -1.0, 0.0))
            idx = len(vertices)
            row = [idx] * num_slices
            grid.append(row)
            continue
            
        for s in range(num_slices):
            angle = (s / num_slices) * 2.0 * math.pi
            cos_a = math.cos(angle)
            sin_a = math.sin(angle)
            
            x = r * cos_a
            z = r * sin_a
            nx = nr * cos_a
            nz = nr * sin_a
            
            vertices.append((x, y, z))
            normals.append((nx, ny, nz))
            row.append(len(vertices))
        grid.append(row)

    # Faces between rings (Strictly CCW outward winding: v00 -> v10 -> v11 and v00 -> v11 -> v01)
    for p in range(num_pts - 1):
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v00 = grid[p][s]
            v01 = grid[p][s_next]
            v10 = grid[p + 1][s]
            v11 = grid[p + 1][s_next]
            
            if v00 == v01:
                # Bottom apex
                faces.append([(v00, v00), (v10, v10), (v11, v11)])
            elif v10 == v11:
                # Top apex
                faces.append([(v00, v00), (v10, v10), (v01, v01)])
            else:
                faces.append([(v00, v00), (v10, v10), (v11, v11)])
                faces.append([(v00, v00), (v11, v11), (v01, v01)])

    # Bottom cap (pointing down -Y)
    if base_center_idx != -1:
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v0 = grid[0][s]
            v1 = grid[0][s_next]
            faces.append([(base_center_idx, base_center_idx), (v0, base_center_idx), (v1, base_center_idx)])

    # Top cap (pointing up +Y)
    if top_center_idx != -1:
        p_top = num_pts - 1
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v0 = grid[p_top][s]
            v1 = grid[p_top][s_next]
            faces.append([(top_center_idx, top_center_idx), (v1, top_center_idx), (v0, top_center_idx)])

    return vertices, normals, faces


# -------------------------------------------------------------
# 1. PAWN PROFILE
# -------------------------------------------------------------
def get_pawn_profile():
    pts = [
        (0.040, 0.000), (0.042, 0.004), (0.042, 0.010),
        (0.038, 0.014), (0.039, 0.018), (0.036, 0.022),
        (0.033, 0.026), (0.030, 0.032), (0.024, 0.040),
        (0.020, 0.048), (0.018, 0.054), (0.024, 0.058),
        (0.025, 0.061), (0.021, 0.063), (0.016, 0.065),
    ]
    head_cy = 0.074
    head_r = 0.020
    for a in range(-65, 91, 15):
        rad = math.radians(a)
        r = head_r * math.cos(rad)
        y = head_cy + head_r * math.sin(rad)
        pts.append((max(0.0, r), y))
    pts.append((0.0, head_cy + head_r))
    return pts


# -------------------------------------------------------------
# 2. ROOK (CASTLE)
# -------------------------------------------------------------
def generate_rook():
    profile = [
        (0.042, 0.000), (0.044, 0.004), (0.044, 0.012),
        (0.040, 0.016), (0.041, 0.020), (0.038, 0.024),
        (0.035, 0.030), (0.033, 0.042), (0.031, 0.054),
        (0.030, 0.064), (0.032, 0.070), (0.037, 0.076),
        (0.040, 0.080), (0.041, 0.084)
    ]
    num_slices = 48
    verts, norms, faces = generate_lathe(profile, num_slices=num_slices)
    
    num_merlons = 4
    slices_per_section = num_slices // (num_merlons * 2) # 6 slices per section
    
    top_rim_y = 0.096
    notch_y = 0.086
    inner_r = 0.030
    outer_r = 0.041
    floor_y = 0.082
    
    floor_center_idx = len(verts) + 1
    verts.append((0.0, floor_y, 0.0))
    norms.append((0.0, 1.0, 0.0))
    
    rim_indices = []
    for s in range(num_slices):
        angle = (s / num_slices) * 2.0 * math.pi
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        
        section = s // slices_per_section
        is_merlon = (section % 2 == 0)
        curr_top_y = top_rim_y if is_merlon else notch_y
        
        # Outer rim
        v_out_idx = len(verts) + 1
        verts.append((outer_r * cos_a, curr_top_y, outer_r * sin_a))
        norms.append((cos_a, 0.2, sin_a))
        
        # Inner rim
        v_in_idx = len(verts) + 1
        verts.append((inner_r * cos_a, curr_top_y, inner_r * sin_a))
        norms.append((-cos_a, 0.2, -sin_a))
        
        # Inner floor
        v_fl_idx = len(verts) + 1
        verts.append((inner_r * cos_a, floor_y, inner_r * sin_a))
        norms.append((0.0, 1.0, 0.0))
        
        rim_indices.append((v_out_idx, v_in_idx, v_fl_idx))
        
    for s in range(num_slices):
        s_next = (s + 1) % num_slices
        o1, i1, f1 = rim_indices[s]
        o2, i2, f2 = rim_indices[s_next]
        
        # Outward outer wall between profile top (p_top) and crenellation outer rim
        # Top rim surface (o1 -> i1 -> i2 and o1 -> i2 -> o2)
        faces.append([(o1, o1), (i1, i1), (i2, i2)])
        faces.append([(o1, o1), (i2, i2), (o2, o2)])
        
        # Inner wall
        faces.append([(i1, i1), (f1, f1), (f2, f2)])
        faces.append([(i1, i1), (f2, f2), (i2, i2)])
        
        # Inner floor
        faces.append([(floor_center_idx, floor_center_idx), (f2, floor_center_idx), (f1, floor_center_idx)])
        
    return verts, norms, faces


# -------------------------------------------------------------
# 3. BISHOP PROFILE
# -------------------------------------------------------------
def get_bishop_profile():
    pts = [
        (0.040, 0.000), (0.043, 0.004), (0.043, 0.012),
        (0.039, 0.016), (0.040, 0.020), (0.036, 0.024),
        (0.033, 0.030), (0.028, 0.042), (0.024, 0.054),
        (0.020, 0.066), (0.018, 0.072), (0.026, 0.076),
        (0.028, 0.080), (0.022, 0.083), (0.019, 0.085),
        # Mitre dome
        (0.022, 0.088), (0.026, 0.093), (0.028, 0.099),
        (0.027, 0.105), (0.022, 0.111), (0.014, 0.116),
        (0.008, 0.119), (0.006, 0.121),
    ]
    finial_cy = 0.126
    finial_r = 0.0075
    for a in range(-60, 91, 20):
        rad = math.radians(a)
        r = finial_r * math.cos(rad)
        y = finial_cy + finial_r * math.sin(rad)
        pts.append((max(0.0, r), y))
    pts.append((0.0, finial_cy + finial_r))
    return pts


# -------------------------------------------------------------
# 4. QUEEN PROFILE
# -------------------------------------------------------------
def get_queen_profile():
    pts = [
        (0.042, 0.000), (0.045, 0.004), (0.045, 0.012),
        (0.041, 0.016), (0.042, 0.020), (0.039, 0.024),
        (0.036, 0.030), (0.030, 0.044), (0.025, 0.058),
        (0.021, 0.070), (0.019, 0.080), (0.028, 0.086),
        (0.030, 0.090), (0.024, 0.093), (0.022, 0.096),
        # Coronet crown
        (0.026, 0.100), (0.032, 0.106), (0.037, 0.114),
        (0.039, 0.120), (0.036, 0.122), (0.028, 0.122),
        (0.018, 0.123), (0.010, 0.125), (0.006, 0.127),
    ]
    finial_cy = 0.133
    finial_r = 0.009
    for a in range(-60, 91, 20):
        rad = math.radians(a)
        r = finial_r * math.cos(rad)
        y = finial_cy + finial_r * math.sin(rad)
        pts.append((max(0.0, r), y))
    pts.append((0.0, finial_cy + finial_r))
    return pts


# -------------------------------------------------------------
# 5. KING PROFILE + 3D CROSS
# -------------------------------------------------------------
def generate_king():
    pts = [
        (0.044, 0.000), (0.047, 0.004), (0.047, 0.014),
        (0.043, 0.018), (0.044, 0.022), (0.040, 0.026),
        (0.037, 0.032), (0.032, 0.046), (0.027, 0.062),
        (0.024, 0.076), (0.022, 0.086), (0.032, 0.092),
        (0.034, 0.096), (0.028, 0.100), (0.026, 0.103),
        # Imperial crown bowl
        (0.031, 0.108), (0.036, 0.115), (0.037, 0.122),
        (0.034, 0.127), (0.026, 0.130), (0.014, 0.132),
        (0.008, 0.134), (0.000, 0.135)
    ]
    verts, norms, faces = generate_lathe(pts, num_slices=40)
    
    # 3D Imperial Cross on top
    def add_box(bx, by, bz, sx, sy, sz):
        hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
        base_v = len(verts)
        base_n = len(norms)
        
        corners = [
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
            (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)
        ]
        for c in corners:
            verts.append((bx + c[0], by + c[1], bz + c[2]))
            
        face_norms = [
            (0, 0, -1), (0, 0, 1), (-1, 0, 0), (1, 0, 0), (0, -1, 0), (0, 1, 0)
        ]
        for fn in face_norms:
            norms.append(fn)
            
        # CCW outward quad pairs
        quads = [
            ([0, 1, 2, 3], 0), # -Z
            ([5, 4, 7, 6], 1), # +Z
            ([4, 0, 3, 7], 2), # -X
            ([1, 5, 6, 2], 3), # +X
            ([4, 5, 1, 0], 4), # -Y
            ([3, 2, 6, 7], 5)  # +Y
        ]
        for q, ni in quads:
            v_idx = [base_v + 1 + i for i in q]
            n_idx = base_n + 1 + ni
            faces.append([(v_idx[0], n_idx), (v_idx[1], n_idx), (v_idx[2], n_idx)])
            faces.append([(v_idx[0], n_idx), (v_idx[2], n_idx), (v_idx[3], n_idx)])
            
    # Vertical cross bar
    add_box(0.0, 0.146, 0.0, 0.006, 0.022, 0.006)
    # Horizontal crossbeam
    add_box(0.0, 0.149, 0.0, 0.018, 0.006, 0.006)
    
    return verts, norms, faces


# -------------------------------------------------------------
# 6. KNIGHT (3D SCULPTED HORSE)
# -------------------------------------------------------------
def generate_knight():
    base_profile = [
        (0.042, 0.000), (0.044, 0.004), (0.044, 0.012),
        (0.040, 0.016), (0.041, 0.020), (0.038, 0.024),
        (0.035, 0.028), (0.000, 0.028)
    ]
    verts, norms, faces = generate_lathe(base_profile, num_slices=36)
    
    horse_levels = [
        (0.028, [(0.0, -0.026), (0.018, -0.018), (0.024, 0.0), (0.018, 0.018), (0.0, 0.024)]),
        (0.040, [(0.0, -0.028), (0.017, -0.018), (0.023, 0.002), (0.017, 0.020), (0.0, 0.026)]),
        (0.052, [(0.0, -0.027), (0.016, -0.016), (0.022, 0.006), (0.016, 0.024), (0.0, 0.030)]),
        (0.064, [(0.0, -0.024), (0.015, -0.012), (0.020, 0.012), (0.015, 0.030), (0.0, 0.036)]),
        (0.076, [(0.0, -0.018), (0.014, -0.008), (0.018, 0.018), (0.013, 0.038), (0.0, 0.044)]),
        (0.088, [(0.0, -0.012), (0.013, -0.002), (0.016, 0.022), (0.011, 0.040), (0.0, 0.045)]),
        (0.098, [(0.0, -0.008), (0.010, 0.004), (0.012, 0.018), (0.008, 0.032), (0.0, 0.035)]),
        (0.106, [(0.0, -0.004), (0.005, 0.002), (0.006, 0.007), (0.005, 0.012), (0.0, 0.015)])
    ]
    
    level_indices = []
    for y, half_pts in horse_levels:
        full_pts = []
        for x, z in half_pts:
            full_pts.append((x, z))
        for x, z in reversed(half_pts[1:-1]):
            full_pts.append((-x, z))
            
        row = []
        for x, z in full_pts:
            idx = len(verts) + 1
            mag = math.sqrt(x * x + z * z)
            nx = x / mag if mag > 1e-6 else 0.0
            nz = z / mag if mag > 1e-6 else 1.0
            verts.append((x, y, z))
            norms.append((nx, 0.2, nz))
            row.append(idx)
        level_indices.append(row)
        
    num_pts_per_level = len(level_indices[0])
    for l in range(len(horse_levels) - 1):
        r1 = level_indices[l]
        r2 = level_indices[l + 1]
        for p in range(num_pts_per_level):
            p_next = (p + 1) % num_pts_per_level
            v00 = r1[p]
            v01 = r1[p_next]
            v10 = r2[p]
            v11 = r2[p_next]
            faces.append([(v00, v00), (v10, v10), (v11, v11)])
            faces.append([(v00, v00), (v11, v11), (v01, v01)])
            
    top_row = level_indices[-1]
    top_center_idx = len(verts) + 1
    verts.append((0.0, 0.107, 0.006))
    norms.append((0.0, 1.0, 0.0))
    for p in range(num_pts_per_level):
        p_next = (p + 1) % num_pts_per_level
        faces.append([(top_center_idx, top_center_idx), (top_row[p_next], top_center_idx), (top_row[p], top_center_idx)])

    # 3D triangular ears
    for ear_x in (-0.007, 0.007):
        b_idx = len(verts) + 1
        verts.append((ear_x - 0.003, 0.103, -0.002))
        verts.append((ear_x + 0.003, 0.103, -0.002))
        verts.append((ear_x, 0.103, 0.004))
        tip_idx = len(verts) + 1
        verts.append((ear_x, 0.116, 0.001))
        
        for _ in range(4):
            norms.append((ear_x * 50.0, 0.8, -0.2))
            
        v1, v2, v3 = b_idx, b_idx + 1, b_idx + 2
        faces.append([(v1, tip_idx), (tip_idx, tip_idx), (v2, tip_idx)])
        faces.append([(v2, tip_idx), (tip_idx, tip_idx), (v3, tip_idx)])
        faces.append([(v3, tip_idx), (tip_idx, tip_idx), (v1, tip_idx)])
        
    return verts, norms, faces


def main():
    target_dir = r"d:\game\cafefekr\assets\models\chess"
    os.makedirs(target_dir, exist_ok=True)
    
    print("[1/6] Generating pawn.obj...")
    v, n, f = generate_lathe(get_pawn_profile(), num_slices=44)
    write_obj(os.path.join(target_dir, "pawn.obj"), v, n, f)
    
    print("[2/6] Generating rook.obj...")
    v, n, f = generate_rook()
    write_obj(os.path.join(target_dir, "rook.obj"), v, n, f)
    
    print("[3/6] Generating bishop.obj...")
    v, n, f = generate_lathe(get_bishop_profile(), num_slices=44)
    write_obj(os.path.join(target_dir, "bishop.obj"), v, n, f)
    
    print("[4/6] Generating queen.obj...")
    v, n, f = generate_lathe(get_queen_profile(), num_slices=48)
    write_obj(os.path.join(target_dir, "queen.obj"), v, n, f)
    
    print("[5/6] Generating king.obj...")
    v, n, f = generate_king()
    write_obj(os.path.join(target_dir, "king.obj"), v, n, f)
    
    print("[6/6] Generating knight.obj...")
    v, n, f = generate_knight()
    write_obj(os.path.join(target_dir, "knight.obj"), v, n, f)
    
    print("SUCCESS! All 6 Staunton 3D models regenerated with outward normals.")


if __name__ == "__main__":
    main()
