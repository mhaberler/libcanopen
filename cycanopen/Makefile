DEST := .
TARGET := $(DEST)/canopen.so

CFLAGS += -fPIC \
	$(shell pkg-config python --cflags)	\
	$(shell pkg-config libcanopen --cflags)

LDFLAGS +=  \
	$(shell pkg-config python --libs) \
	$(shell pkg-config libcanopen --libs)
CC = gcc

$(TARGET): canopen.o
	echo Linking $@
	$(CC) -g  -shared -o $@ $^ $(LDFLAGS) -lrt

canopen.c: canopen.pyx canopen.pxd

canopen.c: canopen.pyx
	cython -o $@ $<


clean:
	rm -f canopen.c canopen.o canopen.so

