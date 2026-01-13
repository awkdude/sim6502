AS = ca65
LD = ld65
LDFLAGS = --config config.txt 
AFLAGS = --cpu 65c02 
ASM_TARGET = a.out
ODIN_SRCS = main.odin $(wildcard emu_c02/*)
ODIN_TARGET = sim6502
RM := rm
ifeq ($(OS),Windows_NT)
	SHELL := cmd.exe
	RM := del
endif
all: $(ASM_TARGET) $(ODIN_TARGET)

.PHONY: clean

$(ODIN_TARGET): $(ODIN_SRCS)
	odin build . -debug

$(ASM_TARGET): prog.o
	$(LD) $(LDFLAGS) $^ -o $@

%.o: %.s
	$(AS) $(AFLAGS) $^ -o $@

clean:
#ifeq ($(OS),Windows_NT)
	$(RM) prog.o $(ASM_TARGET) $(ODIN_TARGET)* *.res
#endif
