################################################################################
# 
#   简介：通用的stm32 makefile，根据自己的工程进行设定就可以使用了
#   
#   作者：yangliu 
#   日期：2017.2.14
#   修改：2019/7/29
################################################################################

################################################################################
#--------------------------------- 编译参数 -----------------------------------
#使用命令 " make V=1 "不隐藏参数信息 只用“make”命令会将隐藏参数
ifneq ($(V),1)
Q		:= @
NULL	:= 2>/dev/null
endif
################################################################################
#Build target
#这里填写产生elf、hex,bin的名称，我的设定是Blink
################################################################################
TARGET := TEST


#######################################
# LDFLAGS
#######################################
# link script 链接脚本
LDSCRIPT = STM32H743XIHx_FLASH.ld

#######################################
# 工具链定义
#######################################
PREFIX = arm-none-eabi-
# The gcc compiler bin path can be either defined in make command via GCC_PATH variable (> make GCC_PATH=xxx)
# either it can be added to the PATH environment variable.
ifdef GCC_PATH
CC = $(GCC_PATH)/$(PREFIX)gcc
AS = $(GCC_PATH)/$(PREFIX)gcc -x assembler-with-cpp
CP = $(GCC_PATH)/$(PREFIX)objcopy
SZ = $(GCC_PATH)/$(PREFIX)size
else
CC = $(PREFIX)gcc
AS = $(PREFIX)gcc -x assembler-with-cpp
CP = $(PREFIX)objcopy
SZ = $(PREFIX)size
endif
HEX = $(CP) -Oihex
BIN = $(CP) -Obinary 
GDB	= $(PREFIX)gdb

#######################################
# CFLAGS     各种参数
#######################################
# cpu           cpu参数
CPU = -mcpu=cortex-m7
# fpu           fpu参数
FPU = -mfpu=fpv5-d16
# float-abi     开启硬件浮点
FLOAT-ABI = -mfloat-abi=hard
# mcu           参数整合
MCU = $(CPU) -mthumb $(FPU) $(FLOAT-ABI)
# optimization  优化等级
OPT = -O0

#########################
#编译支持c11
#########################
CSTD   := -std=c11
CXXSTD := -std=c++11



####################
#预定义 -D 是gcc命令的参数 
####################
#DEFINES += -D __weak="__attribute__((weak))"
#	DEFINES += -D __packed="__attribute__((__packed__))"
DEFINES += -D USE_HAL_DRIVER
DEFINES += -D STM32H743xx

#################
# paths
#################
# Build path 
#输出目录名字 将所有的产生文件放到一起 方便清理
BUILD_DIR = build

#----------------------------- 搜索工程目录下的源代码 ---------------------------
# list of asm objects
AS_SRC := $(shell find ./ -name '*.s')  
OBJECTS = $(addprefix $(BUILD_DIR)/,$(notdir $(AS_SRC:%.s=%.o)))
vpath %.s $(sort $(dir $(AS_SRC)))
# list of objects
C_SRC := $(shell find ./ -name '*.c')  
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(C_SRC:%.c=%.o)))
vpath %.c $(sort $(dir $(C_SRC)))
# list of cpp program objects
CXX_SRC := $(shell find ./ -name '*.cpp')  
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(CXX_SRC:%.cpp=%.o)))
vpath %.cpp $(sort $(dir $(CXX_SRC)))
#需要包含的头文件位置，可以直接从hal库产生的makefile里面copy 
#-I是gcc的参数
#./代表当前makefile所在的目录位置
INC_FLAGS += -I ./Core/Inc
INC_FLAGS += -I ./Drivers/STM32H7xx_HAL_Driver/Inc
INC_FLAGS += -I ./Drivers/STM32H7xx_HAL_Driver/Inc/Legacy
INC_FLAGS += -I ./Drivers/CMSIS/Device/ST/STM32H7xx/Include
INC_FLAGS += -I ./Drivers/CMSIS/Include

#---------------------------------- 编译参数--------------------------------------
LIBS		+= -Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group
LIBDIR = 
LDFLAGS = $(MCU) -specs=nano.specs -T $(LDSCRIPT) $(LIBDIR) $(LIBS) -Wl,-Map=$(BUILD_DIR)/$(TARGET).map,--cref -Wl,--gc-sections

CFLAGS = $(MCU) $(DEFINES)  $(OPT) -Wall -fdata-sections -ffunction-sections -g
# Generate dependency information
#CFLAGS += -MMD -MP -MF"$(@:%.o=%.d)"
#----------------------------------- 编译对象 -----------------------------------

all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin

$(BUILD_DIR)/%.o: %.c Makefile | $(BUILD_DIR) 
	@printf "  CC      $(*).c\n"
	$(Q)$(CC) -c $(INC_FLAGS)  $(CFLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) $< -o $@

$(BUILD_DIR)/%.o: %.s Makefile | $(BUILD_DIR)
	$(Q)$(AS) -c $(CFLAGS) $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) Makefile
	@printf "  LD      $(TARGET).elf\n"
	$(Q)$(CC) $(OBJECTS) $(LDFLAGS) -o $@
	@printf " >>>>>>>>>> SIZE    $(TARGET).elf <<<<<<<<<<<<\n"
	$(Q)$(SZ) $@
	@printf " >>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<\n"
$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@printf "  OBJCOPY $(*).hex\n"
	$(Q)$(HEX) $< $@
	
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@printf "  OBJCOPY $(*).bin\n"
	$(Q)$(BIN) $< $@	
	
$(BUILD_DIR):
	mkdir $@		
#######################################
# clean up
#######################################
clean:
	-rm -fR $(BUILD_DIR)

OOCD		 := openocd.exe
#OOCDFLAGS	 := -f /usr/local/share/openocd/scripts/interface/stlink-v2.cfg
#OOCDFLAGS	 += -f /usr/local/share/openocd/scripts/target/stm32f4x.cfg
OOCDFLAGS        += -f openocd.cfg
flash: $(BUILD_DIR)/$(TARGET).hex
	@printf "  OPEN_OCD FLASH $<\n"
	$(Q)$(OOCD) $(OOCDFLAGS) -c "program $(BUILD_DIR)/$(TARGET).hex verify reset exit" 

debug:$(BUILD_DIR)/$(TARGET).elf
	@printf "  GDB DEBUG $<\n"
	$(GDB) -iex 'target extended | $(OOCD) $(OOCDFLAGS) -c "gdb_port pipe"' \
	-iex 'monitor reset halt' -ex 'load'  $(BUILD_DIR)/$(TARGET).elf
