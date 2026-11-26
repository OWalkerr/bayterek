extends GreyboxRoom
## "Gizli Oda" (M5) — Üst Kökler'in sahte duvarının ardı. Ödül: ikinci Kut parçası.
## Haritada yalnızca bulununca görünür.


func _build() -> void:
	parallax_preset = &"cave"
	backdrop(-8.0, 9.0, -2.0, 9.0, C_CAVE)
	platform(-8.0, 9.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(8.5, 4.0, 0.0), Vector3(1.0, 8.0, 4.0), C_CAVE)
	box(Vector3(0.5, 8.5, 0.0), Vector3(17.0, 1.0, 4.0), C_CAVE)
	glow(Vector3(5.0, 1.4, -1.5), C_SAP)
	glow(Vector3(-5.0, 0.4, -1.5))
