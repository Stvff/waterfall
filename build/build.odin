package build_waterfall

import build "core_build"
import "core:os"

main :: proc() {
	project := build.Project {
		name = "waterfall",
		configure_target_proc = config_target
	}
	build.add_target(&project, &target_debug)
	build.add_target(&project, &target_release)
	build.add_project(&project)

	options := build.parse_args(os.args)
	options.default_config_name = "release"
	build.run(&project, options)
}

target_debug := build.Target {
	name = "debug",
	platform = {ODIN_OS, ODIN_ARCH},
}
target_release := build.Target {
	name = "release",
	platform = {ODIN_OS, ODIN_ARCH},
}

config_target :: proc(project: ^build.Project, target: ^build.Target) -> build.Config {
	config := build.Config {
		name = target.name,
		platform = target.platform,
		out_file = project.name,
		out_dir = ".",
		build_mode = .EXE,
		src_path = ".",
	}
	switch target.name {
		case "debug":
			config.flags += {.Debug}
			config.opt = .None
			build.add_pre_build_command(&config, "compile C libraries", compile_c_libs)
			build.add_post_build_command(&config, "cleanup C libraries", cleanup_c_libs)
		case "release":
			config.flags += {.Disable_Assert, .No_Bounds_Check}
			config.opt = .Speed
			build.add_pre_build_command(&config, "compile C libraries", compile_c_libs_release)
			build.add_post_build_command(&config, "cleanup C libraries", cleanup_c_libs)
			build.add_post_build_command(&config, "Remove build executable", selfdestruct)
	}
	return config
}

import "core:c/libc"
compile_c_libs_release :: proc(config: build.Config) -> int {
	cmds := []cstring{
		"cc -O2 -c iio/iio_odin.c",
		"ar rcs iio_odin.a iio_odin.o",
		"cc -O2 -c fenster/fenster_x11.c",
		"ar rcs fenster.a fenster_x11.o",
	}
	for cmd in cmds do if e := libc.system(cmd); e != 0 do return int(e)
	return 0
}

compile_c_libs :: proc(config: build.Config) -> int {
	cmds := []cstring{
		"cc -c iio/iio_odin.c",
		"ar rcs iio_odin.a iio_odin.o",
		"cc -c fenster/fenster_x11.c",
		"ar rcs fenster.a fenster_x11.o",
	}
	for cmd in cmds do if e := libc.system(cmd); e != 0 do return int(e)
	return 0
}

cleanup_c_libs :: proc(config: build.Config) -> int {
	os.remove("fenster.a")
	os.remove("fenster_x11.o")
	os.remove("iio_odin.a")
	os.remove("iio_odin.o")
	return 0
}

selfdestruct :: proc(config: build.Config) -> int {
	os.remove(os.args[0])
	return 0
}
