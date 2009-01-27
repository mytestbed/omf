
LIBRARY = ocomm

INSTALL_DIR = /usr/lib

#### FOR EXPERTS ONLY  ###
SRCS = log.c socket.c socket_group.c eventloop.c  queue.c 
MT_SRCS = mt_queue.c

TESTS = client server queue mt_queue

#CFLAGS = -g -Wall
CFLAGS = -g -I.
LDFLAGS = 
TOP = ../../../..

TEST_LIBS = -lpopt -lpthread

BUILD_TOP = $(TOP)/build/nodeHandler
BUILD_DIR = $(BUILD_TOP)/$(LIBRARY)

LIB_FILE_A = lib$(LIBRARY).a
LIB_FILE_SO = lib$(LIBRARY).so 
OBJS = $(SRCS:%.c=$(BUILD_DIR)/%.o)

MT_LIB_FILE_A = libmt_$(LIBRARY).a
MT_LIB_FILE_SO = libmt_$(LIBRARY).so 
MT_OBJS = $(MT_SRCS:%.c=$(BUILD_DIR)/%.o)

LIB_FILES = $(LIB_FILE_A) $(LIB_FILE_SO) $(MT_LIB_FILE_A) $(MT_LIB_FILE_SO)


TEST_SRCS = $(TESTS:%=test/%.c)
TEST_OBJS = $(TEST_SRCS:%.c=$(BUILD_DIR)/%.o)
TEST_BINS = $(TESTS:%=$(BUILD_DIR)/test/%)

#all:
#	echo $(LIB_FILES)

$(LIBRARY): $(BUILD_DIR) $(LIB_FILES:%=$(BUILD_DIR)/%)

$(BUILD_DIR)/libmt_%.so: $(SRCS) $(OBJS) $(MT_SRCS) $(MT_OBJS)
	$(CC) -fPIC -shared -o $@ $(OBJS) $(MT_OBJS) $(LDFLAGS) $(LIBS)

$(BUILD_DIR)/lib%.so: $(SRCS) $(OBJS) $(MT_SRCS) $(MT_OBJS)
	$(CC) -fPIC -shared -o $@ $(OBJS) $(LDFLAGS) $(LIBS)

$(BUILD_DIR)/libmt_%.a:  $(SRCS) $(OBJS) $(MT_SRCS) $(MT_OBJS)
	ar cr $@ $(OBJS) $(MT_OBJS)

$(BUILD_DIR)/lib%.a:  $(SRCS) $(OBJS)
	ar cr $@ $(OBJS)

tests: $(LIBRARY) $(BUILD_DIR)/test  $(TEST_OBJS) $(TEST_BINS)

$(BUILD_DIR)/%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(BUILD_DIR)/test/%: $(BUILD_DIR)/test/%.o $(BUILD_DIR)/$(LIB_FILE_A)
	$(CC) -o $@ $< $(BUILD_DIR)/$(MT_LIB_FILE_A) $(TEST_LIBS)

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/test:
	mkdir -p $@

install: $(LIBRARY)
	install -m 755 $(BUILD_DIR)/$(LIB_FILE) $(INSTALL_DIR)

clean:
	rm -fr $(BUILD_DIR) *~

$(BUILD_DIR)/log.o: ocomm/o_log.h
$(BUILD_DIR)/socket.o: ocomm/o_log.h ocomm/o_socket.h
$(BUILD_DIR)/socket_group.o: ocomm/o_log.h ocomm/o_socket.h ocomm/o_socket_group.h
$(BUILD_DIR)/eventloop.o: ocomm/o_eventloop.h ocomm/o_log.h ocomm/o_socket.h
$(BUILD_DIR)/node.o: ocomm/o_node.h ocomm/o_log.h
$(BUILD_DIR)/cmd_array.o: ocomm/o_cmd_array.h ocomm/o_log.h ocomm/o_socket.h