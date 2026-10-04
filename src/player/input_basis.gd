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


## Door traversal: the input that walked the hero along `from_dir` keeps walking along `to_dir`
## (into the new room) until released, whatever the new camera's yaw. Without this, a held key
## re-read in the arrival camera's basis can point straight back into the arrival doorway.
func carry_through(from_dir: Vector3, to_dir: Vector3) -> void:
	if from_dir.length() < 0.01 or to_dir.length() < 0.01:
		return
	var used := locked_yaw if locked else _last_cam_yaw
	locked_yaw = used + angle_difference(atan2(-from_dir.x, -from_dir.z), atan2(-to_dir.x, -to_dir.z))
	locked = true
	_has_last = true
