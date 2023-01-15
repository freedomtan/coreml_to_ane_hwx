CC=clang
CFLAGS=-Wall -O2

FRAMEWORKS=-framework CoreML -framework Foundation -F /System/Library/PrivateFrameworks -framework ANECompiler -framework Espresso

TARGETS=coreml2hwx mlmodelc2hwx espressonet2hwx

all: ${TARGETS}

coreml2hwx: coreml2hwx.o coreml_util.o
	${CC} -o $@ $^ ${FRAMEWORKS} ${LIBS}

mlmodelc2hwx: mlmodelc2hwx.o coreml_util.o
	${CC} -o $@ $^ ${FRAMEWORKS} ${LIBS}

espressonet2hwx: espressonet2hwx.o coreml_util.o
	${CC} -o $@ $^ ${FRAMEWORKS} ${LIBS}

ane_hwx.pdf: ane_hwx.tex
	pdflatex $^

clean:
	rm -rf ${TARGETS} *.o ane_hwx.aux ane_hwx.log ane_hwx.pdf
