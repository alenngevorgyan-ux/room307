class_name InputBasis
extends RefCounted
## Camera-relative input with the 2.5D direction lock: while the stick/keys stay held through a
## camera rig change, movement keeps using the previous camera yaw. Releasing input re-syncs.

var locked_yaw := 0.0
var locked := false
var _last_cam_yaw := 0.0
var _has_last := false


## input: x = right, y = forward (screen-up). cam_yaw: camera yaw (radians). Returns world XZ dir.
func world_dir(input: Vector2, cam_yaw: float) -> Vector3:
	if input.length() < 0.05:
		locked = false
		_last_cam_yaw = cam_yaw
		_has_last = true
		return Vector3.ZERO
	if not _has_last:
		_last_cam_yaw = cam_yaw
		_has_last = true
	if not locked and absf(angle_difference(cam_yaw, _last_cam_yaw)) > 0.01:
		# camera changed while input held: keep the old basis until release
		locked = true
		locked_yaw = _last_cam_yaw
	var yaw := locked_yaw if locked else cam_yaw
	if not locked:
		_last_cam_yaw = cam_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var d := right * input.x + fwd * input.y
	return d.normalized() * minf(input.length(), 1.0)
