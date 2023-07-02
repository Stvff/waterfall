(cd iio; bash make_lib.sh)
(cd fenster; bash make_lib.sh)

odin build . -out:waterfall -o:speed -extra-linker-flags:-lX11\ -liio
