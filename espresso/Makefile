CC=clang
FRAMEWORKS=-framework CoreML -framework Foundation -F /System/Library/PrivateFrameworks -framework Espresso
CFLAGS=-Wall -O2 ${FRAMEWORKS}

TARGETS=espresso_dims

all: ${TARGETS}

clean:
	rm -rf ${TARGETS} *.o
