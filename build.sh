rm -rf bin
mkdir bin

if [ "$1" = "release" ]; then
	odin build src -out:bin/spall -debug -o:speed -no-bounds-check -define:GL_DEBUG=false -strict-style -vet-tabs -vet-unused-imports -minimum-os-version:11.0
elif [ "$1" = "opt" ]; then
	odin build src -out:bin/spall -debug -o:speed -strict-style -vet-tabs -vet-unused-imports -minimum-os-version:11.0
else
	odin build src -out:bin/spall -debug -strict-style -vet-tabs -vet-unused-imports -minimum-os-version:11.0
fi
