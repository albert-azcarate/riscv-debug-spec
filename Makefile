CC=$(RISCV)/bin/riscv64-unknown-elf-gcc

NAME=riscv-debug-spec

REGISTERS_TEX = jtag_registers.tex
REGISTERS_TEX += core_registers.tex
REGISTERS_TEX += hwbp_registers.tex
REGISTERS_TEX += dm1_registers.tex
REGISTERS_TEX += dm2_registers.tex
REGISTERS_TEX += trace_registers.tex
REGISTERS_TEX += sample_registers.tex
REGISTERS_TEX += abstract_commands.tex

REGISTERS_CHISEL += dm1_registers.scala

FIGURES = *.eps

all:	$(NAME).pdf debug_defines.h

$(NAME).pdf: $(NAME).tex $(REGISTERS_TEX) debug_rom.S $(FIGURES) vc.tex changelog.tex
	pdflatex -shell-escape $< && pdflatex -shell-escape $<

publish:	$(NAME).pdf
	cp $< $(NAME)-`git rev-parse --abbrev-ref HEAD`.`git rev-parse --short HEAD`.pdf

vc.tex: .git/logs/HEAD
	# https://thorehusfeldt.net/2011/05/13/including-git-revision-identifiers-in-latex/
	echo "%%% This file is generated by Makefile." > vc.tex
	echo "%%% Do not edit this file!\n%%%" >> vc.tex
	git log -1 --format="format:\
	    \\gdef\\GITHash{%H}\
	    \\gdef\\GITAbrHash{%h}\
	    \\gdef\\GITAuthorDate{%ad}\
	    \\gdef\\GITAuthorName{%an}" >> vc.tex

changelog.tex: .git/logs/HEAD Makefile
	echo "%%% This file is generated by Makefile." > changelog.tex
	echo "%%% Do not edit this file!\n%%%" >> changelog.tex
	git log --date=short --pretty="format:\\vhEntry{%h}{%ad}{%an}{%s}" | \
	    sed s,_,\\\\_,g | sed "s,#,\\\\#,g" >> changelog.tex

debug_defines.h:	$(REGISTERS_TEX:.tex=.h)
	cat $^ > $@

%.eps: %.dot
	dot -Teps $< -o $@

%.tex %.h: %.xml registers.py
	./registers.py --custom --definitions $@.inc --cheader $(basename $@).h $< > $@


%.scala: %.xml registers.py
	./registers.py --chisel $(basename $@).scala $< > /dev/null

%.o:	%.S
	$(CC) -c $<

# Remove 128-bit instructions since our assembler doesn't like them.
%_no128.S:	%.S
	sed "s/\([sl]q\)/nop\#\1/" < $< > $@

debug_rom:	debug_rom_no128.o main.o
	$(CC) -o $@ $^ -Os

debug_ram:	debug_ram.o main.o
	$(CC) -o $@ $^

hello:	hello.c
	$(CC) -o $@ $^ -Os

hello.s:	hello.c
	$(CC) -o $@ $^ -S -Os

chisel: $(REGISTERS_CHISEL)

clean:
	rm -f $(NAME).pdf $(NAME).aux $(NAME).toc $(NAME).log $(REGISTERS_TEX) \
	    $(REGISTERS_TEX:=.inc) *.o *_no128.S *.h $(NAME).lof $(NAME).lot $(NAME).out \
	    $(NAME).hst $(NAME).pyg debug_defines.h
