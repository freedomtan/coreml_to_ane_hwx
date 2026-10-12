CC=clang
CFLAGS=-Wall -O2

FRAMEWORKS=-framework CoreML -framework Foundation -F /System/Library/PrivateFrameworks -framework ANECompiler -framework Espresso

TARGETS=coreml2hwx mlmodelc2hwx espressonet2hwx test_mpsgraph_ops

all: ${TARGETS} mil_to_hwx

# Build mil_to_hwx compiler (in mil/ subdirectory)
mil_to_hwx:
	@$(MAKE) -C mil

.PHONY: mil_to_hwx

coreml2hwx: coreml2hwx.o coreml_util.o
	${CC} -o $@ $^ ${FRAMEWORKS} ${LIBS}

mlmodelc2hwx: mlmodelc2hwx.o coreml_util.o
	${CC} -o $@ $^ ${FRAMEWORKS} ${LIBS}

espressonet2hwx: espressonet2hwx.o coreml_util.o
	${CC} -o $@ $^ ${FRAMEWORKS} ${LIBS}

test_mpsgraph_ops: test_mpsgraph_ops.m
	${CC} ${CFLAGS} -fobjc-arc -o $@ $^ -framework Foundation -framework Metal -framework MetalPerformanceShadersGraph

ane_hwx.pdf: ane_hwx.tex
	pdflatex $^

clean:
	rm -rf ${TARGETS} *.o ane_hwx.aux ane_hwx.log ane_hwx.pdf
	@$(MAKE) -C mil clean
