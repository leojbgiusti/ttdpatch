
# =========================================================
#	Don't put any local configuration in here
#	Change Makefile.local instead, it'll be
#	preserved when updating the sources
# =========================================================

# Define the name of the default target (actual definition below)
ifndef DEFAULTTARGET
DEFAULTTARGET=allw
endif
default: ${DEFAULTTARGET}

# This is a variable so that we can refer to ../Makefile.local from
# the patchsnd/ Makefile
MAKEFILELOCAL=Makefile.local

# Check whether Makefile.local exists
HAVE_LOCAL = $(shell [ -s ${MAKEFILELOCAL} ]; echo $$?)

# If not, create it with defaults
ifneq (${HAVE_LOCAL},0)
MAKE_LOCAL = $(shell cp ${MAKEFILELOCAL}.sample ${MAKEFILELOCAL}; echo $$?)
ifneq (${MAKE_LOCAL},0)
$(error Could not create ${MAKEFILELOCAL})
endif
$(error ${MAKEFILELOCAL} did not exist, creating new. Please edit it before running make again)
endif

# Set up compilers, targets and host

include Makefile.setup

# Version info is now in version.def to prevent remaking everything
# when the Makefile is changed
include version.def

# to test makelang
# ${HOSTPATH}makelang.o: CFLAGS += -DTESTMAKELANG

# defines for compiling all C and assembly sources
# this is a space-separated list without the command line switches 
# like -d; those will be added later because they differ
DEFS = DEBUG=$(DEBUG) 

WDEF_d = WINTTDX=0
WDEF_w = WINTTDX=1
WDEF_l = WINTTDX=0

# same, but each specialized for the DOS, Windows or Linux versions
DOSDEFS = $(DEFS) ${WDEF_d} LINTTDX=0
WINDEFS = $(DEFS) ${WDEF_w} LINTTDX=0
LINDEFS = $(DEFS) ${WDEF_l} LINTTDX=1

# temporary response files
DRSP = $(TEMP)/BCC.RSP
URSP = $(subst \,\\,$(shell cygpath -w $(DRSP)))

# No configuration below here...


# =======================================================================
#           collect info about source files
# =======================================================================

asmmainsrc:=	header.asm loader.asm init.asm patches.asm 
asmsources:=	$(asmmainsrc) $(wildcard patches/*.asm) $(wildcard procs/*.asm)
asmcsources:=	$(wildcard patches/*.c) $(wildcard procs/*.c)
csources:=	ttdpatch.c error.c grep.c switches.c loadlng.c checkexe.c auxfiles.c
doscsources:=	$(csources) dos.c
wincsources:=	$(csources) windows.c codepage.c
versiondatad:=	$(wildcard versions/1*.ver)
versiondataw:=	$(wildcard versions/2*.ver)

langhsources:=	$(wildcard lang/*.h)
langobjs:=	$(langhsources:%.h=%.o)
hostlangobjs:=	$(langhsources:%.h=host/%.o)
makelangobjs:=	makelang.o switches.o codepage.o texts.o

asmdobjs:=	$(asmsources:%.asm=${OTMP}%.dpo) $(asmcsources:%.c=${OTMP}%.dpo)
asmwobjs:=	$(asmsources:%.asm=${OTMP}%.wpo) $(asmcsources:%.c=${OTMP}%.wpo)
dos:	ttdprotd.bin
dosobjs:=	$(doscsources:%.c=%.obj)
win:	ttdprotw.bin
winobjs:=	$(wincsources:%.c=%.o) ttdpatchw.res libz.a
hostwinobjs:=	$(wincsources:%.c=host/%.o)

# =======================================================================
#           dependencies are in Makefile.dep, include that
# =======================================================================

Makefile.dep%:
	@touch $@
	@make -o Makefile.depd -o Makefile.depw -s INCLUDES
	$(CPP) -x assembler-with-cpp -Iinc -D${WDEF_$*} -MM $(asmmainsrc) patches/*.asm procs/*.asm ${asmcsources} -I. | perl -pe 's/\.o/.$*po/; s#\w+/\.\./##g; print "${OTMP}" if /^\S/; print "$$1/" if /: (patches|procs)\//' > $@

include Makefile.dep
include Makefile.depd
include Makefile.depw

# =======================================================================
#           special targets
# =======================================================================

.PHONY:	all allw dos win nodebug clean cleantemp remake mrproper

# automatic compilation: make the listing with correct addresses and
# the DOS executable file
alld:	dos mkpttxt${EXEW}
allw:	win mkpttxt${EXEW}
dos:	ttdprotd.lst ttdpatch.exe
win:	ttdprotw.lst ttdpatchw.exe
lin:	ttdprotl.lst ttdprotl.bin
all:	alld allw

.PHONY: test testd testw

testd: ttdprotd.lst ttdpatch.exe
	@cp -v -u --remove-destination ttdpatch.exe ${GAMEDIR}/ttdpatch-${VERSION}.exe

testw: ttdprotw.lst ttdpatchw.exe
	@cp -v -u --remove-destination ttdpatchw.exe ${GAMEDIRW}/ttdpatchw-${VERSION}.exe

test:	testd testw

nodebug:
ifneq ($(DEBUG),0)
	@echo Run as mk R
	@exit 1
endif
	@echo Making non-debug version.

# remove temporary files
cleantemp:
	rm -f *.asp
	rm -f *.{o,obj,OBJ}
	rm -f ${OTMP}*.*po ${OTMP}patches/*.*po ${OTMP}procs/*.*po
	rm -f lang/*.{o,map,exe} lang/language.*
	rm -f host/*.o host/lang/* host/mkpttxt host/makelang
	rm -f *.*lst *.LST patches/*.*lst
	rm -f ttdload.ovl
	rm -f reloc*.inc
	rm -f *.pe

# remove files that depend on compiler flags (DEBUG, etc.)
remake:
	rm -f *.{o,obj,OBJ,bin,bil} lang/*.o host/*.o host/lang/*.o
	rm -f ${OTMP}*.*po ${OTMP}patches/*.*po ${OTMP}procs/*.*po reloc.a
	rm -f mkpttxt.exe host/mkpttxt

# remove temporary files and all compilation results that can be
# remade with make
clean:	cleantemp
	rm -f language.dat
	rm -f language.ucd
	rm -f ttdprotd.exe
	rm -f ttdprotw.exe
	rm -f lang/*.{new,o}
	rm -f *.{bin,bil}
	rm -f *.{map,MAP}
	rm -f reloc.a
	rm -f *.{res,RES}
	rm -f langerr.h
	rm -f sw_lists.h
	rm -f inc/ourtexts.h
	rm -f version{d,w}.h

# also remove Makefile.dep?, listings and bak files
mrproper: clean
	rm -f Makefile.dep?
	rm -f *.{d,w,l}lst patches/*.{d,w,l}lst procs/*.{d,w,l}lst
	rm -f patches/*.ba* procs/*.ba*

# files that need to be created to check include dependencies
.PHONY: INCLUDES
#INCLUDES:	patches/texts.h versiond.h versionw.h
INCLUDES:	versiond.h versionw.h

# if a command fails, delete its output
.DELETE_ON_ERROR:

# ========================================================================
#            Actual compilation rules for the C sources
# ========================================================================

# how to make an object file from a C file
ifeq ($(DOSCC),BCC)
%.obj : %.c
	@echo "-3 -a- -c -d -f- -u -K -j7"				> $(DRSP)
	@echo "-zC_mytext"						>> $(DRSP)
	@echo "-m$(MODEL) $(foreach DEF,$(DOSDEFS),-D$(DEF)) "		>> $(DRSP)
	@echo $< 							>> $(DRSP)
	$(CCD) $(CFLAGSD) -o$@ @$(URSP)
	@perl -e 's//pop/e;rename uc, lc or die "Error"' $@
else
%.obj : %.c
	$(CCD) $(CFLAGSD) -fo=$@ -m$(MODEL) $(foreach DEF,$(DOSDEFS),-d$(DEF)) $<
endif

%.o : %.c
	$(CC) -c -o $@ $(CFLAGS) $(foreach DEF,$(WINDEFS),-D$(DEF)) $<

host/%.o : %.c
	$(HOSTCC) -c -o $@ $(HOSTCFLAGS) $(foreach DEF,$(WINDEFS),-D$(DEF)) $<

# make pre-compiled C file
%.E : %.c
	$(CPP) -o $@ $(CFLAGS) $(foreach DEF,$(WINDEFS),-D$(DEF)) $<

%.S : %.c
	$(CC) -S -o $@ $(CFLAGS) $(foreach DEF,$(WINDEFS),-D$(DEF)) $<

%.lst : %.S
	as -a $< -o /dev/null > $@

host/%${HOSTEXE} : %.o
	$(HOSTLD) -o $@ ${filter host/%,$^} $(HOSTLDFLAGS)

%${EXEW} : %.o
	$(LD) -o $@ $^ $(LDFLAGS)

%.o : %.asm
	$(NASM) $(NASMOPT) -f coff -dCOFF $(NASMDEF) $< -o $@

%.obj : %.asm
	$(NASM) $(NASMOPT) -f obj -dOBJ $(NASMDEF) $< -o $@

host/%.o : %.asm
	$(NASM) $(NASMOPT) $(HOSTNASM) $(NASMDEF) $< -o $@

# -------------------------------------------------------------------------
#                  The assembly modules
# -------------------------------------------------------------------------


# make the assembler file by passing the source through
# the C pre-compiler, using perl to add correct, original
# line numbers

# set different preprocessor defines for each target
%.dpo %.dlst:	XASMDEF =  $(foreach DEF,$(DOSDEFS),-D$(DEF))
%.wpo %.wlst:	XASMDEF =  $(foreach DEF,$(WINDEFS),-D$(DEF))
%.lpo %.llst:	XASMDEF =  $(foreach DEF,$(LINDEFS),-D$(DEF))

# commands for making object and list files from the asm sources
# (using a define here because we need the same commands for the 
# various versions)
define A-PO-COMMANDS
	$(CPP) ${XASMDEF} -x assembler-with-cpp -Iinc $< | perl perl/lineinfo.pl > $@.asp
	$(NASM) -f win32 $@.asp -o $@
	@rm -f $@.asp
endef
define A-LST-COMMANDS
	$(CPP) ${XASMDEF} -x assembler-with-cpp -Iinc $< | perl perl/lineinfo.pl > $@.asp
	$(NASM) -f win32 $@.asp -o /dev/null -l $@
	@rm -f $@.asp
endef
C-PO-COMMANDS =	$(CC) ${XASMDEF} -c -o $@ $< -Iinc

${OTMP}%.dpo : %.asm
	${A-PO-COMMANDS}
${OTMP}%.wpo : %.asm
	${A-PO-COMMANDS}

%.dlst : %.asm
	${A-LST-COMMANDS}
%.wlst : %.asm
	${A-LST-COMMANDS}

${OTMP}%.dpo : %.c
	${C-PO-COMMANDS}
${OTMP}%.wpo : %.c
	${C-PO-COMMANDS}

# link all assembly modules into ttdprot?.pe
ttdprotd.pe ttdprotd.map: $(asmdobjs) reloc.a
ttdprotw.pe ttdprotw.map: $(asmwobjs) reloc.a

ttdprotd.pe ttdprotd.map: IMAGEBASE=0x200000
ttdprotw.pe ttdprotw.map: IMAGEBASE=0x600000

# call the linker explicitly (not via gcc), and pass the patches/ object
# files via the shell expansion instead of one giant make command line
ttdprot%.pe ttdprot%.map:
	$(LDEXP) $(LDEXPFLAGS) -Map ttdprot$*.map -o ttdprot$*.pe $(filter-out ${OTMP}procs/%.$*po,$(filter-out ${OTMP}patches/%.$*po,$^)) ${OTMP}patches/*.$*po ${OTMP}procs/*.$*po reloc.a

ttdprot%.bin: ttdprot%.pe
	$(OBJCOPY) -O binary -j .ptext $< $@

loader%.bin: ttdprot%.pe
	$(OBJCOPY) -O binary -j .phead $< $@

reloc.a:	reloc.o
	$(DLLTOOL) -l $@ $<

# replace section name+offset with final offset in listing
loader%.lst: ttdprot%.pe
	$(OBJDUMP) -D -j .phead -Mintel $< > $@

# make .lst without auto-relocation fixups, they confuse the disassembler
%.lst: %.pe
	$(OBJCOPY) -w -N '*_fu[0-9]*' -j .ptext $*.pe $*.pes
	$(OBJDUMP) -D -Mintel $*.pes > $@
	@rm -f $*.pes

texts.lst:	texts.asp
	$(NASM) $(NASMOPT) $(NASMDEF) $< -l $@ -o /dev/null

texts.asp:	texts.asm
	$(NASM) $(NASMOPT) -e -dPREPROCESSONLY $(NASMDEF) $< -o $@

inc/ourtext.h:	inc/ourtext.inc
	perl perl/texts.pl < $< > $@

bitnames.h:	bitnames.ah
	perl perl/bitnames.pl < $< > $@

# generate relocations
reloc%.inc:	ttdprot%.map
	perl -s perl/reloc.pl -os=$* < $(filter %.map,$<) > $@

reloc%.bin:	reloc.asm reloc%.inc
	$(NASM) $(NASMOPT) -f bin $(NASMDEF) -dINCFILE=$(filter %.inc,$^) $< -o $@

pproc%.h:	ttdprot%.map
	perl perl/pproc.pl -os=$* < $< > $@

patchsnd.bin:	patchsnd.asm patchsnd/patchsnd.dll
	$(NASM) $(NASMOPT) -f bin $(NASMDEF) $< -o $@

# ---------------------------------------------------------------------
#               Language data
# ---------------------------------------------------------------------

# define rules for the language modules
langerr.h:	language.h common.h
	perl perl/langerr.pl $^ > $@

makelang${EXEW}:	LDLIBS = -L. -lz
host/makelang${HOSTEXE}:	LDLIBS = -lz
makelang${EXEW}:		${makelangobjs} $(langobjs)
host/makelang${HOSTEXE}:	${makelangobjs:%.o=host/%.o} $(hostlangobjs)

lang/%.o:	lang/%.h
	$(CC) -c -o $@ $(CFLAGS) -DLANGUAGE=$* proclang.c

host/lang/%.o:	lang/%.h
	$(HOSTCC) -c -o $@ $(HOSTCFLAGS) -DLANGUAGE=$* proclang.c

# test versions of makelang with a single language: make lang/<language> and run
# the executable to make a single-language language.dat file
lang/%:		makelang.c lang/%.o switches.o codepage.o texts.o
	$(CC) -o $@ $(CFLAGS) $(LDOPT) $(foreach DEF,$(WINDEFS),-D$(DEF)) -DSINGLELANG=${patsubst lang/%,%,$@} $^ -L. -lz

mkpttxt.o host/mkpttxt.o:       mkpttxt.c # patches/texts.h
mkpttxt${EXEW}:  mkpttxt.o texts.o
host/mkpttxt${HOSTEXE}:  host/mkpttxt.o host/texts.o

# ----------------------------------------------------------------------
#               Resource file for Windows version
# ----------------------------------------------------------------------

%.res : %.rc
	${WINDRES} -i $< -o $@ -O coff


# ----------------------------------------------------------------------
#               The executables
# ----------------------------------------------------------------------


# make both uncompressed (for testing) and compressed language data
language.dat: ${HOSTPATH}makelang${HOSTEXE}
	$< > makelang.log 2> makelang.err
	@$< n > /dev/null 2> makelang.err

# link the modules to the exe file
ifeq ($(DOSCC),BCC)
ttdprotd${EXED}:	$(dosobjs)
	@echo ${LDFLAGSD} 		> $(DRSP)
	@echo $^ 			>> $(DRSP)
	@echo zlib_bc$(MODEL).lib	>> $(DRSP)
	@echo exec_bc$(MODEL).lib	>> $(DRSP)
	$(LDD) -m$(MODEL) -e$@	@$(URSP)
else
# for OpenWatcom wlink, files need to be comma-separated, so we'll use sed to s/ /,/
ttdprotd${EXED}:	$(dosobjs)
	$(LDD) ${LDFLAGSD} name $@ file `echo $^|sed "s/ /,/g"` lib zlib_ow$(MODEL).lib,exec_ow$(MODEL).lib
endif

ttdprotw${EXEW}:	$(winobjs)
	$(LD) -o $@ $^ $(LDFLAGS)

# compress it, and link the language data to it too
ttdpatch.exe:	ttdprotd${EXED} language.dat
ttdpatchw.exe:	ttdprotw${EXEW} language.dat

ttdpatch.exe:	ttdprotd.bin loaderd.bin relocd.bin
ttdpatchw.exe:	ttdprotw.bin loaderw.bin relocw.bin patchsnd.bin

# the $(if ...) makes it append .exe only if $< doesn't have it already
ttdpatch.exe:
	cp $(if $(findstring .exe,$<),$<,$<.exe) $@
	$(STRIPD) $@
ifndef NOUPX
	upx -qq --best $@
endif
	${CAT} language.dat loaderd.bin ttdprotd.bin relocd.bin >> $@

ttdpatchw.exe:
	cp $(if $(findstring .exe,$<),$<,$<.exe) $@
	${STRIP} -s $@
ifndef NOUPX	
	upx -qq --best --compress-icons=0 $@
endif
	${CAT} language.dat loaderw.bin ttdprotw.bin relocw.bin patchsnd.bin >> $@

# ----------------------------------------------------------------------
#                       additional stuff
# ----------------------------------------------------------------------

# make libz.a from the sources
LIBZTEMPDIR = zlib
libz.a:
	mkdir -p $(LIBZTEMPDIR)
	cd $(LIBZTEMPDIR); unzip -n ../zlib_src; ./configure; make libz.a; 
	cp $(LIBZTEMPDIR)/libz.a $@
	@echo NOTE: You can remove the $(LIBZTEMPDIR) directory, it is no longer needed.

# recreate version%.h if deleted

VERSION_NAME_d=DOS
VERSION_NAME_w=Windows

version%.h:
	@echo // Autogenerated by make.  Do not edit.  Edit version.def or the Makefile instead. > $@
	@echo "#define TTDPATCHVERSION \"$(VERSIONSTR) (${VERSION_NAME_$*})\"" >> $@
	@echo "#define TTDPATCHVERSIONNUM 0x$(VERSIONNUM)L" >> $@
	@echo "#define TTDPATCHVERSIONNUMR 0x$(VERSIONNUM)" >> $@
	@echo "#define TTDPATCHVERSIONSHORT \"$(VERSION)\"" >> $@
	@echo "#define TTDPATCHVERSIONMAJOR $(VERSIONMAJOR)" >> $@
	@echo "#define TTDPATCHVERSIONMINOR $(VERSIONMINOR)" >> $@
	@echo "#define TTDPATCHVERSIONREVISION $(VERSIONREVISION)" >> $@
	@echo "#define TTDPATCHVERSIONBUILD $(VERSIONBUILD)" >> $@

# sorted switch list
sw_lists.h:	sw_list.h
	perl perl/sw_sort.pl < $^ > $@

# Autodetection of the TTDPATCH program size, for deciding when to swap out
# - make ttdpatch.exe with a bogus memsize
# - run it on mem.exe to report how large it really is
# - force a remake of dos.obj with that new size
#
# memsize.h is not normally re-made if anything changes because it'll still
# be "almost" correct.  Force a remake by deleting it just before doing
# a make dist or so.

memsize.h:
	echo "#define TTDPATCHSIZE 65536" > $@
	make dos
	rm -f $@
	$(DOSCMD) TTDPATCH '-!t-m-f-s-c' $(subst \,/,$(WINDIR))/command/mem.exe /C | perl perl/memsize.pl > $@
	rm -f dos.obj ttdload.ovl

# copy compiled versions to TTD game directory
${GAMEDIR}/%: %
	cp $^ ${GAMEDIR}

${GAMEDIRW}/%: %
	cp $^ ${GAMEDIRW}

.PHONY:	copyd copyw copy

copyd:	${GAMEDIR}/ttdpatch.exe ${GAMEDIR}/mkpttxt.exe ttdprotd.lst

copyw:	${GAMEDIRW}/ttdpatchw.exe ${GAMEDIRW}/mkpttxt.exe ttdprotw.lst

copy:	copyd copyw

