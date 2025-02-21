CC=clang
CXX=clang++
FRAMEWORKS=-framework IOSurface -framework Foundation -F /System/Library/PrivateFrameworks -framework AppleNeuralEngine
CFLAGS=-Wall -O2 ${FRAMEWORKS} -g
CXXFLAGS=-Wall -O2 ${FRAMEWORKS} -std=c++20 
CXXFLAGS=-Wall -O2 ${FRAMEWORKS} -std=c++20 -x objective-c++
CXXFLAGS=-Wall -O2 -g ${FRAMEWORKS} -std=c++20 -x objective-c++

all: ${TARGETS}

clean:
	rm -rf ${TARGETS} *.o
