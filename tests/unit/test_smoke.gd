extends TestCase


func test_runner_works() -> void:
	check(true)
	eq(1 + 1, 2)


func test_autoloads_present() -> void:
	check(ep() != null and data() != null and bus() != null)
