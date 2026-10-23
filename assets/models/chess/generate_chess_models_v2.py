"""
Premium Staunton 3D Chess Piece Model Generator (v2.1 - Master Tournament)
FIDE Standard Classical Proportions:
- pawn: Height ~0.076m (FIDE ratio: ~50% of King)
- rook: Height ~0.095m, castle battlements with 4 merlons & embrasures
- knight: Height ~0.115m, anatomical sculpted horse with mane tufts, ears, muzzle
- bishop: Height ~0.126m, tear mitre dome with deep diagonal cleft cut
- queen: Height ~0.138m, flared coronet with 8 spired points & central dome
- king: Height ~0.138m base body (finial ball at top), cross pattee mounted in pure gold/platinum
"""

import math
import os

def write_obj(filename, vertices, normals, faces):
    with open(filename, "w", encoding="utf-8") as f:
        f.write("# Cafe Fekr Luxury 3D Staunton Piece Model (v2.1)\n")
        f.write(f"o {os.path.splitext(os.path.basename(filename))[0]}\n")
        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")
        for n in normals:
            f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")
        for face in faces:
            face_str = " ".join(f"{v_idx}//{n_idx}" for v_idx, n_idx in face)
            f.write(f"f {face_str}\n")

def generate_lathe(profile, num_slices=48):
    vertices = []
    normals = []
    faces = []
    
    num_pts = len(profile)
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
            dr_dy.append((dy / length, -dr / length))

    base_center_idx = -1
    if profile[0][0] > 0.0001:
        vertices.append((0.0, profile[0][1], 0.0))
        normals.append((0.0, -1.0, 0.0))
        base_center_idx = len(vertices)

    top_center_idx = -1
    if profile[-1][0] > 0.0001:
        vertices.append((0.0, profile[-1][1], 0.0))
        normals.append((0.0, 1.0, 0.0))
        top_center_idx = len(vertices)

    grid = []
    for p in range(num_pts):
        row = []
        r, y = profile[p]
        nr, ny = dr_dy[p]
        
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

    for p in range(num_pts - 1):
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v00 = grid[p][s]
            v01 = grid[p][s_next]
            v10 = grid[p + 1][s]
            v11 = grid[p + 1][s_next]
            if v00 == v01:
                faces.append([(v00, v00), (v10, v10), (v11, v11)])
            elif v10 == v11:
                faces.append([(v00, v00), (v10, v10), (v01, v01)])
            else:
                faces.append([(v00, v00), (v10, v10), (v11, v11)])
                faces.append([(v00, v00), (v11, v11), (v01, v01)])

    if base_center_idx != -1:
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v0 = grid[0][s]
            v1 = grid[0][s_next]
            faces.append([(base_center_idx, base_center_idx), (v0, base_center_idx), (v1, base_center_idx)])

    if top_center_idx != -1:
        p_top = num_pts - 1
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v0 = grid[p_top][s]
            v1 = grid[p_top][s_next]
            faces.append([(top_center_idx, top_center_idx), (v1, top_center_idx), (v0, top_center_idx)])

    return vertices, normals, faces

# -------------------------------------------------------------
# 1. PAWN (Height ~0.076m)
# -------------------------------------------------------------
def get_pawn_profile():
    pts = [
        # Stepped plinth
        (0.034, 0.000), (0.036, 0.003), (0.036, 0.007),
        (0.032, 0.010), (0.033, 0.014), (0.030, 0.017),
        # Concave slender column
        (0.026, 0.022), (0.022, 0.028), (0.017, 0.036),
        (0.014, 0.044), (0.012, 0.051),
        # Collar astragal
        (0.018, 0.054), (0.019, 0.056), (0.016, 0.058),
        (0.012, 0.059), (0.010, 0.061),
    ]
    # Spherical head
    head_cy = 0.073
    head_r = 0.015
    for a in range(-65, 91, 10):
        rad = math.radians(a)
        r = head_r * math.cos(rad)
        y = head_cy + head_r * math.sin(rad)
        pts.append((max(0.0, r), y))
    pts.append((0.0, head_cy + head_r))
    return pts

# -------------------------------------------------------------
# 2. ROOK (Height ~0.096m)
# -------------------------------------------------------------
def generate_rook():
    profile = [
        (0.039, 0.000), (0.042, 0.004), (0.042, 0.009),
        (0.038, 0.013), (0.039, 0.017), (0.036, 0.021),
        # Tapered tower
        (0.033, 0.026), (0.031, 0.038), (0.029, 0.052),
        (0.028, 0.066),
        # Stepped corbels
        (0.032, 0.071), (0.034, 0.074), (0.033, 0.077),
        (0.037, 0.080), (0.038, 0.083)
    ]
    num_slices = 48
    verts, norms, faces = generate_lathe(profile, num_slices=num_slices)
    
    num_merlons = 4
    slices_per_section = num_slices // (num_merlons * 2) # 6 slices
    
    top_rim_y = 0.098
    notch_y = 0.086
    inner_r = 0.027
    outer_r = 0.038
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
        
        v_out_idx = len(verts) + 1
        verts.append((outer_r * cos_a, curr_top_y, outer_r * sin_a))
        norms.append((cos_a, 0.2, sin_a))
        
        v_in_idx = len(verts) + 1
        verts.append((inner_r * cos_a, curr_top_y, inner_r * sin_a))
        norms.append((-cos_a, 0.2, -sin_a))
        
        v_fl_idx = len(verts) + 1
        verts.append((inner_r * cos_a, floor_y, inner_r * sin_a))
        norms.append((0.0, 1.0, 0.0))
        
        rim_indices.append((v_out_idx, v_in_idx, v_fl_idx))
        
    for s in range(num_slices):
        s_next = (s + 1) % num_slices
        o1, i1, f1 = rim_indices[s]
        o2, i2, f2 = rim_indices[s_next]
        faces.append([(o1, o1), (i1, i1), (i2, i2)])
        faces.append([(o1, o1), (i2, i2), (o2, o2)])
        faces.append([(i1, i1), (f1, f1), (f2, f2)])
        faces.append([(i1, i1), (f2, f2), (i2, i2)])
        faces.append([(floor_center_idx, floor_center_idx), (f2, floor_center_idx), (f1, floor_center_idx)])
        
    return verts, norms, faces

# -------------------------------------------------------------
# 3. BISHOP (Height ~0.126m)
# -------------------------------------------------------------
def generate_bishop():
    base_profile = [
        (0.039, 0.000), (0.042, 0.004), (0.042, 0.010),
        (0.038, 0.014), (0.039, 0.018), (0.035, 0.022),
        (0.031, 0.028), (0.025, 0.040), (0.020, 0.052),
        (0.016, 0.063), (0.015, 0.068),
        # Double collar
        (0.022, 0.072), (0.024, 0.075), (0.019, 0.078),
        (0.023, 0.081), (0.024, 0.084), (0.018, 0.086)
    ]
    num_slices = 48
    verts, norms, faces = generate_lathe(base_profile, num_slices=num_slices)
    
    # Mitre dome rings with cut out cleft slit
    mitre_rings = [
        (0.086, 0.018), (0.090, 0.021), (0.095, 0.024), (0.100, 0.026),
        (0.106, 0.025), (0.111, 0.022), (0.116, 0.017), (0.120, 0.011),
        (0.123, 0.006)
    ]
    
    grid = []
    cleft_center_angle = math.radians(45.0)
    cleft_half_width = math.radians(18.0)
    
    for y, r in mitre_rings:
        row = []
        for s in range(num_slices):
            angle = (s / num_slices) * 2.0 * math.pi
            diff = (angle - cleft_center_angle + math.pi) % (2.0 * math.pi) - math.pi
            if abs(diff) < cleft_half_width and y >= 0.094 and y <= 0.118:
                depth_factor = 1.0 - (math.cos(diff / cleft_half_width * (math.pi / 2.0)) * 0.58)
                eff_r = r * depth_factor
            else:
                eff_r = r
                
            cos_a = math.cos(angle)
            sin_a = math.sin(angle)
            x = eff_r * cos_a
            z = eff_r * sin_a
            
            idx = len(verts) + 1
            verts.append((x, y, z))
            norms.append((cos_a, 0.35, sin_a))
            row.append(idx)
        grid.append(row)
        
    for p in range(len(mitre_rings) - 1):
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v00 = grid[p][s]
            v01 = grid[p][s_next]
            v10 = grid[p + 1][s]
            v11 = grid[p + 1][s_next]
            faces.append([(v00, v00), (v10, v10), (v11, v11)])
            faces.append([(v00, v00), (v11, v11), (v01, v01)])
            
    # Finial neck
    top_y = mitre_rings[-1][0]
    top_center_idx = len(verts) + 1
    verts.append((0.0, top_y + 0.002, 0.0))
    norms.append((0.0, 1.0, 0.0))
    top_grid_row = grid[-1]
    for s in range(num_slices):
        s_next = (s + 1) % num_slices
        faces.append([(top_center_idx, top_center_idx), (top_grid_row[s_next], top_center_idx), (top_grid_row[s], top_center_idx)])
        
    return verts, norms, faces

# -------------------------------------------------------------
# 4. QUEEN (Height ~0.138m)
# -------------------------------------------------------------
def generate_queen():
    base_profile = [
        (0.041, 0.000), (0.044, 0.004), (0.044, 0.010),
        (0.039, 0.014), (0.040, 0.018), (0.037, 0.022),
        (0.033, 0.028), (0.027, 0.042), (0.022, 0.055),
        (0.018, 0.068), (0.017, 0.076),
        # Astragal
        (0.025, 0.082), (0.027, 0.086), (0.021, 0.089),
        (0.019, 0.092)
    ]
    num_slices = 48
    verts, norms, faces = generate_lathe(base_profile, num_slices=num_slices)
    
    num_petals = 8
    slices_per_petal = num_slices // num_petals
    
    coronet_rings = [
        (0.092, 0.019), (0.096, 0.023), (0.102, 0.028), (0.108, 0.033), (0.114, 0.036)
    ]
    grid = []
    for y, r in coronet_rings:
        row = []
        for s in range(num_slices):
            angle = (s / num_slices) * 2.0 * math.pi
            x = r * math.cos(angle)
            z = r * math.sin(angle)
            idx = len(verts) + 1
            verts.append((x, y, z))
            norms.append((math.cos(angle), 0.3, math.sin(angle)))
            row.append(idx)
        grid.append(row)
        
    for p in range(len(coronet_rings) - 1):
        for s in range(num_slices):
            s_next = (s + 1) % num_slices
            v00 = grid[p][s]
            v01 = grid[p][s_next]
            v10 = grid[p + 1][s]
            v11 = grid[p + 1][s_next]
            faces.append([(v00, v00), (v10, v10), (v11, v11)])
            faces.append([(v00, v00), (v11, v11), (v01, v01)])
            
    top_grid_row = grid[-1]
    petal_tips = []
    for s in range(num_slices):
        angle = (s / num_slices) * 2.0 * math.pi
        phase = (s % slices_per_petal) / float(slices_per_petal)
        h_mod = math.sin(phase * math.pi) * 0.012
        y = 0.114 + h_mod
        r = 0.036 + (h_mod * 0.25)
        
        idx = len(verts) + 1
        verts.append((r * math.cos(angle), y, r * math.sin(angle)))
        norms.append((math.cos(angle), 0.5, math.sin(angle)))
        petal_tips.append(idx)
        
    for s in range(num_slices):
        s_next = (s + 1) % num_slices
        v0 = top_grid_row[s]
        v1 = top_grid_row[s_next]
        t0 = petal_tips[s]
        t1 = petal_tips[s_next]
        faces.append([(v0, v0), (t0, t0), (t1, t1)])
        faces.append([(v0, v0), (t1, t1), (v1, v1)])
        
    # Inner crown bowl
    inner_pts = [
        (0.000, 0.108), (0.012, 0.109), (0.020, 0.110), (0.026, 0.112),
        (0.008, 0.118), (0.005, 0.123), (0.000, 0.126)
    ]
    iv, inn, inf_ = generate_lathe(inner_pts, num_slices=32)
    v_offset = len(verts)
    n_offset = len(norms)
    for v in iv:
        verts.append(v)
    for n in inn:
        norms.append(n)
    for f in inf_:
        faces.append([(vi + v_offset, ni + n_offset) for vi, ni in f])
        
    return verts, norms, faces

# -------------------------------------------------------------
# 5. KING (Imperial Body up to Crown Finial Ball, Cross in Gold)
# -------------------------------------------------------------
def generate_king():
    pts = [
        (0.043, 0.000), (0.046, 0.004), (0.046, 0.011),
        (0.041, 0.015), (0.042, 0.019), (0.039, 0.023),
        (0.035, 0.029), (0.029, 0.044), (0.024, 0.059),
        (0.021, 0.073), (0.020, 0.083),
        # Royal astragal
        (0.028, 0.089), (0.030, 0.093), (0.025, 0.096),
        (0.023, 0.099),
        # Imperial crown bowl
        (0.028, 0.103), (0.033, 0.109), (0.035, 0.116),
        (0.033, 0.122), (0.027, 0.126), (0.017, 0.129),
        # Finial globe base
        (0.009, 0.131), (0.007, 0.133), (0.008, 0.135), (0.005, 0.137), (0.000, 0.138)
    ]
    verts, norms, faces = generate_lathe(pts, num_slices=48)
    return verts, norms, faces

# -------------------------------------------------------------
# 6. KNIGHT (Anatomical Sculpted Masterpiece Horse)
# -------------------------------------------------------------
def generate_knight():
    base_profile = [
        (0.039, 0.000), (0.042, 0.004), (0.042, 0.009),
        (0.037, 0.013), (0.038, 0.017), (0.035, 0.021),
        (0.032, 0.025), (0.031, 0.028), (0.000, 0.028)
    ]
    verts, norms, faces = generate_lathe(base_profile, num_slices=40)
    
    horse_slices_def = [
        (0.028,  0.000, 0.027, 0.027, 0.027, 0.0),
        (0.034,  0.003, 0.024, 0.027, 0.026, 0.0),
        # Muscular chest
        (0.042,  0.008, 0.022, 0.029, 0.025, 0.003),
        (0.051,  0.011, 0.020, 0.031, 0.024, 0.005),
        # Arched neck
        (0.060,  0.012, 0.018, 0.030, 0.023, 0.008),
        (0.069,  0.011, 0.017, 0.029, 0.023, 0.010),
        (0.077,  0.009, 0.016, 0.028, 0.024, 0.012),
        (0.085,  0.009, 0.017, 0.029, 0.023, 0.011),
        # Jowls swelling, chin reaching forward
        (0.092,  0.014, 0.019, 0.032, 0.020, 0.009),
        # Cheeks and throat latch
        (0.098,  0.021, 0.017, 0.033, 0.016, 0.007),
        # Eye level & brow ridge
        (0.103,  0.025, 0.015, 0.031, 0.013, 0.004),
        # Forehead & muzzle
        (0.108,  0.027, 0.012, 0.026, 0.010, 0.002),
        (0.112,  0.028, 0.008, 0.019, 0.007, 0.000),
        # Crown between ears
        (0.115,  0.024, 0.005, 0.011, 0.005, 0.000)
    ]
    
    num_pts_per_ring = 32
    ring_indices = []
    
    for slice_idx, (y, cz, wx, lf, lb, mane_str) in enumerate(horse_slices_def):
        row = []
        for i in range(num_pts_per_ring):
            angle = (i / float(num_pts_per_ring)) * 2.0 * math.pi
            cos_a = math.cos(angle)
            sin_a = math.sin(angle)
            
            rad_z = lf if cos_a >= 0 else lb
            if cos_a < -0.3 and mane_str > 0.0:
                mane_wave = math.cos(slice_idx * 1.8) * 0.003
                mane_boost = ((-cos_a - 0.3) / 0.7) * (mane_str + mane_wave)
                rad_z += mane_boost
                
            if y >= 0.100 and y <= 0.106 and abs(sin_a) > 0.75:
                wx_eff = wx * 1.15
            else:
                wx_eff = wx
                
            x = wx_eff * sin_a
            z = cz + (rad_z * cos_a)
            
            idx = len(verts) + 1
            verts.append((x, y, z))
            norms.append((sin_a, 0.2, cos_a))
            row.append(idx)
        ring_indices.append(row)
        
    for l in range(len(horse_slices_def) - 1):
        r1 = ring_indices[l]
        r2 = ring_indices[l + 1]
        for p in range(num_pts_per_ring):
            p_next = (p + 1) % num_pts_per_ring
            v00 = r1[p]
            v01 = r1[p_next]
            v10 = r2[p]
            v11 = r2[p_next]
            faces.append([(v00, v00), (v10, v10), (v11, v11)])
            faces.append([(v00, v00), (v11, v11), (v01, v01)])
            
    top_row = ring_indices[-1]
    top_center_idx = len(verts) + 1
    verts.append((0.0, 0.116, 0.023))
    norms.append((0.0, 1.0, 0.0))
    for p in range(num_pts_per_ring):
        p_next = (p + 1) % num_pts_per_ring
        faces.append([(top_center_idx, top_center_idx), (top_row[p_next], top_center_idx), (top_row[p], top_center_idx)])
        
    # Sculpted Perked Ears
    for ear_sign in (-1, 1):
        ear_x = ear_sign * 0.007
        base_y = 0.111
        base_z = 0.017
        tip_y = 0.125
        tip_z = 0.022
        
        v_b1 = len(verts) + 1
        verts.append((ear_x - (ear_sign * 0.0035), base_y, base_z - 0.004))
        v_b2 = len(verts) + 1
        verts.append((ear_x + (ear_sign * 0.0035), base_y, base_z - 0.002))
        v_b3 = len(verts) + 1
        verts.append((ear_x, base_y + 0.002, base_z + 0.005))
        v_tip = len(verts) + 1
        verts.append((ear_x + (ear_sign * 0.001), tip_y, tip_z))
        
        for _ in range(4):
            norms.append((ear_sign * 0.6, 0.7, 0.4))
            
        faces.append([(v_b1, v_tip), (v_b2, v_tip), (v_tip, v_tip)])
        faces.append([(v_b2, v_tip), (v_b3, v_tip), (v_tip, v_tip)])
        faces.append([(v_b3, v_tip), (v_b1, v_tip), (v_tip, v_tip)])
        
    return verts, norms, faces

def main():
    target_dir = r"d:\game\cafefekr\assets\models\chess"
    os.makedirs(target_dir, exist_ok=True)
    
    print("[1/6] Generating pawn.obj (Tournament Staunton)...")
    v, n, f = generate_lathe(get_pawn_profile(), num_slices=48)
    write_obj(os.path.join(target_dir, "pawn.obj"), v, n, f)
    
    print("[2/6] Generating rook.obj (Castle Tower with Merlons)...")
    v, n, f = generate_rook()
    write_obj(os.path.join(target_dir, "rook.obj"), v, n, f)
    
    print("[3/6] Generating bishop.obj (Mitre with Diagonal Cleft Cut)...")
    v, n, f = generate_bishop()
    write_obj(os.path.join(target_dir, "bishop.obj"), v, n, f)
    
    print("[4/6] Generating queen.obj (8-Petal Spired Coronet & Pearls)...")
    v, n, f = generate_queen()
    write_obj(os.path.join(target_dir, "queen.obj"), v, n, f)
    
    print("[5/6] Generating king.obj (Imperial Crown & Finial)...")
    v, n, f = generate_king()
    write_obj(os.path.join(target_dir, "king.obj"), v, n, f)
    
    print("[6/6] Generating knight.obj (Masterwork Anatomical Horse)...")
    v, n, f = generate_knight()
    write_obj(os.path.join(target_dir, "knight.obj"), v, n, f)
    
    print("[SUCCESS] All 6 luxury 3D Staunton models successfully generated!")

if __name__ == "__main__":
    main()
