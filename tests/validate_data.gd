extends TestCase
## AT-DATA-01..08 + line budget.

var _results: Dictionary = {}


func _res() -> Dictionary:
	if _results.is_empty():
		_results = DataValidator.new(data()).run_all()
	return _results


func _assert_clean(key: String) -> void:
	for e in _res()[key]:
		failures.append("%s %s" % [key, e])


func test_at_data_01_references() -> void: _assert_clean("AT-DATA-01")
func test_at_data_02_required_facts() -> void: _assert_clean("AT-DATA-02")
func test_at_data_03_sources() -> void: _assert_clean("AT-DATA-03")
func test_at_data_04_chip_chains() -> void: _assert_clean("AT-DATA-04")
func test_at_data_05_cines() -> void: _assert_clean("AT-DATA-05")
func test_at_data_06_captions() -> void: _assert_clean("AT-DATA-06")
func test_at_data_07_lengths() -> void: _assert_clean("AT-DATA-07")
func test_at_data_08_silence_leave() -> void: _assert_clean("AT-DATA-08")
func test_line_budget() -> void: _assert_clean("LINE-BUDGET")
