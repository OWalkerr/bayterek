#!/usr/bin/env python3
"""Oda sahnelerini (.tscn) tek tablodan üretir: kimlik, harita hücresi, kapılar, Ocak, toplanabilir, sunak.
Geometri odanın script'indedir (scripts/world/rooms/). Kapılar karşılıklı yazılmalı (test_m4 denetler).
Kullanım: python3 tools/gen_rooms.py  (proje kökünden)"""
import os

G = "whip_grapple"
# (id, bölge, script, ad, fikir, hücre, boyut, spawn,
#  kapılar[(düğüm, kapı_id, konum, hedef_oda, hedef_kapı, varış_ofseti, boyut|None, gereken|"")],
#  ekler[(düğüm, tür, kimlik, konum)])
ROOMS = [
 ("ocak_odasi","kok_dibi","room_10_ocak_odasi.gd","Ocak Odası","Merkez: dinlen, kaydet, yolunu seç",(0,0),(1,1),(-3,0.5,0),
  [("DoorWest","west",(-12.5,0,0),"tirmanma","east_bottom",(1.8,0.1,0),None,""),
   ("DoorEast","east",(12.5,0,0),"yuva","west",(-1.8,0.1,0),None,""),
   ("DoorUp","up",(0,14,0),"ust_kokler","down",(0,-2.0,0),(10,3,4),G)],
  [("Ocak","ocak","merkez",(0,0,0))]),
 ("tirmanma","kok_dibi","room_02_tirmanma.gd","Tırmanma Kuyusu","Tırmanma sarmaşıkları arası yana zıplama, yukarı = umut",(-1,0),(1,2),(-2,0.5,0),
  [("DoorEastBottom","east_bottom",(16.2,0,0),"ocak_odasi","west",(-1.7,0.1,0),None,""),
   ("DoorEastTop","east_top",(16.2,27,0),"yanki","west",(-1.7,0.1,0),None,"")],[]),
 ("yanki","kok_dibi","room_05_yanki.gd","Yankı Mağarası","Derinlik bir sırdır: mağaradan arka katmana çık",(0,1),(2,1),(-6,0.5,0),
  [("DoorWest","west",(-10.5,0,0),"tirmanma","east_top",(1.5,0.1,0),None,"")],
  [("KutShard","collectible","kut_1",(28,0.6,-29))]),
 ("yuva","kok_dibi","room_04_yuva.gd","Çürük Yuvası","Kamçı: kombo, savrulma saldırısı, pogo",(1,0),(2,1),(-6,0.5,0),
  [("DoorWest","west",(-10.5,0,0),"ocak_odasi","east",(1.5,0.1,0),None,""),
   ("DoorEast","east",(48.5,6,0),"savrulma","west",(-1.5,0.1,0),None,"")],[]),
 ("savrulma","kok_dibi","room_01_savrulma.gd","Savrulma Zinciri","Yere basmadan sarmaşık zinciri; ritim ve mükemmel bırakma",(3,0),(2,1),(-5,0.5,0),
  [("DoorWest","west",(-10.5,0,0),"yuva","east",(1.5,0.1,0),None,""),
   ("DoorEast","east",(38.5,13,0),"curuk","west",(-1.5,0.1,0),None,"")],[]),
 ("curuk","kok_dibi","room_03_curuk.gd","Çürük Geçit","Çürük sarmaşıklar: beklemek yok, akış zorunlu",(5,0),(2,2),(-5,0.5,0),
  [("DoorWest","west",(-10.5,0,0),"savrulma","east",(1.5,0.1,0),None,""),
   ("DoorEast","east",(40.5,19.5,0),"sunak","west",(-1.5,0.1,0),None,"")],
  [("Ocak","ocak","gecit",(38.5,19.5,0))]),
 ("sunak","kok_dibi","room_12_sunak.gd","Sunak Odası","Kamçı Kancası: yeni fiil, hemen dene",(7,1),(1,1),(-5,0.5,0),
  [("DoorWest","west",(-9.5,0,0),"curuk","east",(1.5,0.1,0),None,""),
   ("DoorEast","east",(15.5,0,0),"kanca_bahcesi","west",(-1.5,0.1,0),None,"")],
  [("Shrine","shrine","whip_grapple",(2,0,0))]),
 ("kanca_bahcesi","kok_dibi","room_11_kanca_bahcesi.gd","Kanca Bahçesi","Sarmaşıksız uçurum: yalnızca kanca çiçekleri",(8,1),(2,1),(-6,0.5,0),
  [("DoorWest","west",(-11.5,0,0),"sunak","east",(1.5,0.1,0),None,G),
   ("DoorEast","east",(40.5,1,0),"spor_mahzeni","west",(-1.5,0.1,0),None,G)],[]),
 ("spor_mahzeni","kok_dibi","room_13_spor_mahzeni.gd","Spor Mahzeni","Kalabalığı kancayla aş ya da dövüş",(10,1),(2,1),(-6,0.5,0),
  [("DoorWest","west",(-11.5,0,0),"kanca_bahcesi","east",(1.5,0.1,0),None,""),
   ("DoorEast","east",(41.5,0,0),"cicek_kuyusu","west_bottom",(-1.5,0.1,0),None,"")],[]),
 ("cicek_kuyusu","kok_dibi","room_14_cicek_kuyusu.gd","Çiçek Kuyusu","Tırmanma + kanca: dikey yükseliş",(12,1),(1,2),(-3,0.5,0),
  [("DoorWestBottom","west_bottom",(-7.2,0,0),"spor_mahzeni","east",(1.7,0.1,0),None,""),
   ("DoorEastTop","east_top",(11.2,22.5,0),"kokyiyen_esigi","west",(-1.7,0.1,0),None,G)],[]),
 ("kokyiyen_esigi","kok_dibi","room_15_kokyiyen_esigi.gd","Kökyiyen Eşiği","Fırtına öncesi: son Ocak, mühürlü kapı",(13,2),(1,1),(-5,0.5,0),
  [("DoorWest","west",(-9.5,0,0),"cicek_kuyusu","east_top",(1.5,0.1,0),None,"")],
  [("Ocak","ocak","esik",(4,0,0))]),
 ("ust_kokler","kok_dibi","room_16_ust_kokler.gd","Üst Kökler","Derinlik sırrı: duvarın ardı",(2,1),(3,1),(5,0.5,0),
  [("DoorDown","down",(0,-2.6,0),"ocak_odasi","up",(3.5,2.7,0),(4,2,4),""),
   ("DoorSecret","secret",(35,0,-14.5),"gizli_oda","back",(0,0.1,2.0),(4,3,1),"")],[]),
 ("gizli_oda","kok_dibi","room_17_gizli_oda.gd","Gizli Oda","Sırrın ödülü",(3,2),(1,1),(-5,0.5,0),
  [("DoorBack","back",(-8.5,0,0),"ust_kokler","secret",(1.5,0.1,0),None,"")],
  [("KutShard","collectible","kut_2",(5,0.9,0))]),
 ("kok_agzi","test","room_00_kok_agzi.gd","Kök Ağzı","Hepsinden biraz: sallanma, mağara derinliği, yukarı zincir",(0,0),(1,1),(-6,0.5,0),[],[]),
]

def v3(t): return "Vector3(%s, %s, %s)" % tuple(repr(float(x)) for x in t)
def xf(p): return "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % tuple(repr(float(x)) for x in p)

for rid, region, script, name, idea, cell, size, spawn, doors, extras in ROOMS:
    d = "scenes/world/regions/%s/rooms" % region
    os.makedirs(d, exist_ok=True)
    ext = ['[ext_resource type="Script" path="res://scripts/world/rooms/%s" id="1_room"]' % script]
    kinds = {e[1] for e in extras}
    if doors: ext.append('[ext_resource type="Script" path="res://scripts/world/room_door.gd" id="2_door"]')
    if "ocak" in kinds: ext.append('[ext_resource type="Script" path="res://scripts/world/ocak.gd" id="3_ocak"]')
    if "collectible" in kinds: ext.append('[ext_resource type="Script" path="res://scripts/world/collectible.gd" id="4_pick"]')
    if "shrine" in kinds: ext.append('[ext_resource type="Script" path="res://scripts/world/ability_shrine.gd" id="5_shrine"]')
    out = ['[gd_scene load_steps=%d format=3]' % (len(ext) + 1), ''] + ext + ['']
    out += ['[node name="%s" type="Node3D"]' % ''.join(w.capitalize() for w in rid.split('_')),
            'script = ExtResource("1_room")', 'room_id = &"%s"' % rid, 'display_name = "%s"' % name,
            'idea = "%s"' % idea, 'region = &"%s"' % region, 'map_cell = Vector2i(%d, %d)' % cell,
            'map_size = Vector2i(%d, %d)' % size, 'spawn_point = %s' % v3(spawn), '']
    for node, did, pos, tr, td, arr, dsize, req in doors:
        out += ['[node name="%s" type="Area3D" parent="."]' % node, 'transform = %s' % xf(pos),
                'script = ExtResource("2_door")', 'door_id = &"%s"' % did, 'target_room = &"%s"' % tr,
                'target_door = &"%s"' % td]
        if dsize: out.append('size = %s' % v3(dsize))
        out.append('arrive_offset = %s' % v3(arr))
        if req: out.append('requires = &"%s"' % req)
        out.append('')
    for node, kind, oid, pos in extras:
        out += ['[node name="%s" type="Area3D" parent="."]' % node, 'transform = %s' % xf(pos)]
        if kind == "ocak":
            out += ['script = ExtResource("3_ocak")', 'ocak_id = &"%s"' % oid]
        elif kind == "shrine":
            out += ['script = ExtResource("5_shrine")', 'ability_id = &"%s"' % oid]
        else:
            out += ['script = ExtResource("4_pick")', 'pickup_id = &"%s"' % oid, 'kind = &"kut_shard"']
        out.append('')
    open("%s/%s.tscn" % (d, rid), "w").write("\n".join(out))
print("odalar:", len(ROOMS))
