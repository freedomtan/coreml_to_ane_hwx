CC=clang
CFLAGS=-Wall -O2

FRAMEWORKS=-framework CoreML -framework Foundation -F /System/Library/PrivateFrameworks -framework ANECompiler -framework Espresso

TARGETS=coreml2hwx

all: ${TARGETS}

coreml2hwx: coreml2hwx.o
	${CC} -o $@ $< ${FRAMEWORKS} ${LIBS}

clean:
	rm -rf ${TARGETS} *.o
