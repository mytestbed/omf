
PROGRAM = commServer

SRCS = node.c cmd_array.c main.c 

BIN_DIR = /usr/sbin

TOP = ../../../..

#CFLAGS = -g -Wall
CFLAGS = -g -I../ocommLib

# don't use shared lib of ocomm to minimize dependencies
LIBS = $(BUILD_DIR)/../ocomm/libocomm.a -lpopt
#LDFLAGS = -L $(TOP)/build/ocomm
#LIBS = -locomm -lpopt

BUILD_TOP = $(TOP)/build/nodeHandler
BUILD_DIR = $(BUILD_TOP)/commServer

OBJS = $(SRCS:%.c=$(BUILD_DIR)/%.o)

$(PROGRAM): $(BUILD_DIR)/$(PROGRAM)

$(BUILD_DIR)/$(PROGRAM): $(BUILD_DIR) $(SRCS) $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAGS) $(LIBS)

$(BUILD_DIR)/%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(BUILD_DIR):
	mkdir $@

install: $(PROGRAM)
	install -m 755 $(BUILD_DIR)/$(PROGRAM) $(BIN_DIR)

clean:
	rm -fr $(BUILD_DIR) *~

$(BUILD_DIR)/main.o:  version.h o_node.h o_cmd_array.h
$(BUILD_DIR)/node.o: o_node.h
$(BUILD_DIR)/cmd_array.o: o_cmd_array.h