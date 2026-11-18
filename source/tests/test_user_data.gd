extends SceneTree

# The rename to «Mans Duty» moved Godot's user folder (…/app_userdata/<name>).
# The settings, the campaign and the loadouts are copied once from the old
# folder into the new one, never over a file that is already there, and the
# old folder is left as it was. Works in folders of its own under user://.
var checks := 0
var failed := false

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok   ",message)

func _initialize():call_deferred("run")

func write(path: String, text: String) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()

func read(path: String) -> String:
 return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func clear(dir: String) -> void:
 if not DirAccess.dir_exists_absolute(dir):return
 for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
 DirAccess.remove_absolute(dir)

func run():
 var game: GDScript=load("res://scripts/game.gd")
 var files: Array=game.USER_FILES
 check(ProjectSettings.get_setting("application/config/name")=="Mans Duty" and OS.get_user_data_dir().get_file()=="Mans Duty","The game is «Mans Duty», and so is its user folder")
 check(game.OLD_USER_DIR=="КВАРТАЛ — Зачистка" and files.has("settings.cfg") and files.has("campaign.cfg") and files.has("loadouts.cfg"),"Settings, campaign and loadouts come from «КВАРТАЛ — Зачистка»")
 var base:=OS.get_user_data_dir().path_join("test-user-data")
 var old_dir:=base.path_join(game.OLD_USER_DIR)
 var new_dir:=base.path_join("Mans Duty")
 clear(old_dir);clear(new_dir)
 check(game.migrate_user_data(old_dir,new_dir,files)==0 and not DirAccess.dir_exists_absolute(new_dir),"No old folder: nothing to do")
 DirAccess.make_dir_recursive_absolute(old_dir)
 write(old_dir.path_join("settings.cfg"),"[audio]\nvolume=0.4\n")
 write(old_dir.path_join("campaign.cfg"),"[progress]\nmission=3\n")
 check(game.migrate_user_data(old_dir,new_dir,files)==2,"Two files of the old folder copied")
 check(read(new_dir.path_join("settings.cfg"))=="[audio]\nvolume=0.4\n" and read(new_dir.path_join("campaign.cfg"))=="[progress]\nmission=3\n","…byte for byte")
 check(not FileAccess.file_exists(new_dir.path_join("loadouts.cfg")),"A file the old folder lacks is not invented")
 write(new_dir.path_join("settings.cfg"),"[audio]\nvolume=0.9\n")
 write(old_dir.path_join("loadouts.cfg"),"[presets]\n")
 check(game.migrate_user_data(old_dir,new_dir,files)==1,"Next start: only the file still missing is copied")
 check(read(new_dir.path_join("settings.cfg"))=="[audio]\nvolume=0.9\n","Settings made in the renamed game are never overwritten")
 check(read(old_dir.path_join("settings.cfg"))=="[audio]\nvolume=0.4\n" and FileAccess.file_exists(old_dir.path_join("campaign.cfg")),"The old folder stays as it was")
 check(game.migrate_user_data(new_dir,new_dir,files)==0,"The same folder is never copied onto itself")
 clear(old_dir);clear(new_dir);DirAccess.remove_absolute(base)
 print("checks: ",checks)
 print("PASS: %d user data rename checks" % checks if not failed else "FAILED")
 quit(1 if failed else 0)
