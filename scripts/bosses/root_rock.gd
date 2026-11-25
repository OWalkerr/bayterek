class_name RootRock
extends GrappleFlower
## Faz 3 finali: kuyunun üstünde asılı kök kayası. Kancayla tutulunca kopar, düşer ve
## Kökyiyen'in ağzına girer (docs/04: "son anda ağzına kamçıyla bir kök kayası çekerek bitirir").

signal pulled


func _ready() -> void:
	petal_color = Color("8a6a4a")
	super._ready()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6b4a2f")
	var rock := SphereMesh.new()
	rock.radius = 1.2
	rock.height = 2.0
	rock.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = rock
	mi.position = Vector3.UP * 1.0
	add_child(mi)
	EventBus.grapple_attached.connect(func(flower: Node3D) -> void:
		if flower == self:
			pulled.emit())
