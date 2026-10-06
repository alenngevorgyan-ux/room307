extends SceneTree
## FINAL VISUAL LANGUAGE V1 — bakes the Vesper detail maps (headless, deterministic):
##   godot --headless --path . -s res://tools/bake_vesper_textures.gd
## Writes assets/vesper/textures/*.png. Every map is tileable (noise on a torus) and packed:
##   R = value (painted mark / grain / mineral mass, mean ~0.5)
##   G = secondary mask (wood: rubbed wear, marble: veins, brush: patina / rub)
##   B = roughness deviation around 0.5
## These are authored procedural maps (designed stroke groups, sparse veins), not photo scans and not
## final hand-painted production textures — see docs/FINAL_VISUAL_LANGUAGE_PHASE1.md.

const OUT := "res://assets/vesper/textures/"
const N := 512


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save("wood", _wood())
	_save("marble", _marble())
	_save("brush", _brush())
	print("[bake] done")
	quit()


func _save(name: String, img: Image) -> void:
	var p := ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(p)
	print("[bake] ", p)


# ------------------------------------------------------------------ periodic value noise

func _h(i: int, j: int, seed: int) -> float:
	var n := (i * 374761393 + j * 668265263 + seed * 2147483647) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 100000) / 100000.0


## value noise with `cells` lattice cells across the tile, wrapped (tileable)
func _vn(u: float, v: float, cells: int, seed: int) -> float:
	var x := u * cells
	var y := v * cells
	var i0 := int(floor(x))
	var j0 := int(floor(y))
	var fx := x - i0
	var fy := y - j0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var i1 := posmod(i0 + 1, cells)
	var j1 := posmod(j0 + 1, cells)
	i0 = posmod(i0, cells)
	j0 = posmod(j0, cells)
	var a := lerpf(_h(i0, j0, seed), _h(i1, j0, seed), fx)
	var b := lerpf(_h(i0, j1, seed), _h(i1, j1, seed), fx)
	return lerpf(a, b, fy)


func _fbm(u: float, v: float, cells: int, seed: int) -> float:
	return 0.5 * _vn(u, v, cells, seed) + 0.25 * _vn(u, v, cells * 2, seed + 7) + 0.125 * _vn(u, v, cells * 4, seed + 13) + 0.125 * _vn(u, v, cells * 8, seed + 29)


# ------------------------------------------------------------------ maps

## Walnut: long grain running along U in broad stroke groups (0.1–0.4 m), quiet joints, rubbed patches.
func _wood() -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for py in N:
		var v := float(py) / N
		for px in N:
			var u := float(px) / N
			# grain lines: level sets of a slowly warped coordinate across the board
			var warp := _fbm(u * 1.0, v, 3, 11) * 0.9 + _vn(u, v, 6, 5) * 0.25
			var g := v * 22.0 + warp * 4.5 + _vn(u, v, 2, 17) * 2.0
			var line := 0.5 + 0.5 * sin(g * TAU)
			line = pow(line, 3.0 + 5.0 * _vn(u, v, 5, 19))   # latewood lines of uneven weight
			# stroke groups: elongated value patches (long along the grain)
			var groups := _fbm(u * 0.25, v * 1.0, 4, 23)
			var val := 0.5 + (groups - 0.5) * 0.9 - line * 0.18 + (_vn(u, v, 64, 3) - 0.5) * 0.05
			var wear := smoothstep(0.58, 0.86, 0.7 * _vn(u, v, 4, 41) + 0.3 * _vn(u, v, 8, 43))
			var rough := 0.5 + line * 0.25 - wear * 0.2
			img.set_pixel(px, py, Color(clampf(val, 0.0, 1.0), wear, clampf(rough, 0.0, 1.0)))
	return img


## Marble: quiet mineral clouds + few unequal broken veins (no sine stripes).
func _marble() -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for py in N:
		var v := float(py) / N
		for px in N:
			var u := float(px) / N
			var cloud := _fbm(u, v, 3, 101)
			var f := _fbm(u, v, 2, 131) + _vn(u, v, 5, 151) * 0.3
			var vein := smoothstep(0.012, 0.0, absf(f - 0.55)) * smoothstep(0.45, 0.65, _vn(u, v, 4, 171)) * 0.7
			var vein2 := smoothstep(0.008, 0.0, absf(_fbm(u, v, 3, 191) - 0.48)) * 0.5 * smoothstep(0.55, 0.75, _vn(u, v, 3, 211))
			var veins := clampf(vein + vein2, 0.0, 1.0)
			var val := 0.5 + (cloud - 0.5) * 1.1
			var rough := 0.5 + (cloud - 0.5) * 0.4 + veins * 0.2
			img.set_pixel(px, py, Color(clampf(val, 0.0, 1.0), veins, clampf(rough, 0.0, 1.0)))
	return img


## Brush: directional painted strokes (~25° diagonal clusters), patina/rub mask for metals & leather.
func _brush() -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for py in N:
		var v := float(py) / N
		for px in N:
			var u := float(px) / N
			# strokes: anisotropic noise stretched along a diagonal; stays tileable by sampling a
			# sheared coordinate on integer-period lattices
			var su := u + v * 0.5   # integer lattice shift keeps the tile seamless
			var stroke := _fbm(su * 1.0, v * 1.0, 6, 307)
			var fine := _vn(su, v, 48, 311)
			var val := 0.5 + (stroke - 0.5) * 0.8 + (fine - 0.5) * 0.08
			var patina := smoothstep(0.45, 0.75, 0.7 * _vn(u, v, 5, 331) + 0.3 * _vn(u, v, 10, 337))
			var rough := 0.5 + (stroke - 0.5) * 0.5 + patina * 0.15
			img.set_pixel(px, py, Color(clampf(val, 0.0, 1.0), patina, clampf(rough, 0.0, 1.0)))
	return img
