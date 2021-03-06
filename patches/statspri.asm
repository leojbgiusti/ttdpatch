//
// new station graphics
//

#include <std.inc>
#include <flags.inc>
#include <textdef.inc>
#include <grf.inc>
#include <station.inc>
#include <window.inc>
#include <veh.inc>
#include <misc.inc>
#include <ptrvar.inc>
#include <newvehdata.inc>
#include <imports/dropdownex.inc>
#include <bitvars.inc>
#include <industry.inc>
#include <transopts.inc>

extern GenerateDropDownMenu,actionhandler
extern actionnewstations_actionnum,cantrainenterstattile,canrventerrailstattile,cleartilefn
extern curcallback,curgrfstationlist,curselclass,curselclassid,curselstation
extern curselstationid,curspriteblock,disallowedlengths,disallowedplatforms
extern ecxcargooffset,fixednumber_addr,getdesertmap,geteffectivetracktype
extern getextendedbyte,getextendedbyte_noadjust,getnewsprite
extern gettextintableptr,gettileinfo,grffeature,grfstage,malloccrit
extern invalidatehandle,invalidatetile,irrgetrailxysouth,isrealhumanplayer
extern laststationid,miscgrfvar,newstationclasses,newstationlayout
extern newstationnames,newstationnum,numstationsinclass,patchflags
extern piececonnections,randomfn,randomstationtrigger
extern setstationdisabledbuttons,station2ofs_ptr,stationcallbackflags
extern stationcargowaitingmask,stationclass,stationclassesused,stationflags
extern stationspritelayout,stsetids
extern unimaglevmode, paStationtramstop
extern lookuptranslatedcargo,mostrecentspriteblock,statcargotriggers
extern lookuptranslatedcargo_usebit,gettileterrain
extern failpropwithgrfconflict,lastextragrm,curextragrm,setspriteerror
extern generatesoundeffect,redrawtile,stationanimtriggers,callback_extrainfo
extern miscgrfvar,irrgetrailxysouth,getirrplatformlength
extern DrawStationImageInSelWindow,MakeTempScrnBlockDesc
extern convertplatformsinecx,convertplatformsincargoacceptlist,convertplatformsinremoverailstation
extern addcargotostation_cargodesthook

extern paStationbusstop1, paStationbusstop2,
extern paStationtruckstop1, paStationtruckstop2
extern paStationtramstop1, paStationtramstop2
extern paStationtramfreightstop1, paStationtramfreightstop2

// 0x53 is the first new layout/station type in L5
// if you add a new Layout don't forget to change the copy code in stationgraphics.asm
vard paStationsNewLayouts, paStationbusstop1,paStationbusstop2,paStationtramstop1,paStationtramstop2,paStationtruckstop1,paStationtruckstop2,paStationtramfreightstop1,paStationtramfreightstop2

// bits in L7:
%define L7STAT_PBS 1		// is station tile in a PBS block?
%define L7STAT_BLOCKED 2	// is station tile blocked (can't be entered)?

	//	in:	esi=window
	//		al=tracktype
	//		ax,cx = position
	global drawstationimageinrailselectwin
drawstationimageinrailselectwin:
	push edi
	// create temp screen description
	pusha
	mov edi, baTempBuffer1
	mov byte [edi], 0
	//	DX,BX = X,Y CX,BP = width,height
	mov dx, [esi+window.x]
	mov bx, [esi+window.y]
	add dx, 7
	add bx, 26
	mov cx, 134 //66
	mov bp, 48

	call [MakeTempScrnBlockDesc]
	popa
	jz .invalid
	mov edi, baTempBuffer1

	push cx
	push dx
	push esi
	mov al, [currconstrtooltracktype]
	call [DrawStationImageInSelWindow]
	pop esi
	pop dx
	pop cx

	add cx, 68
	mov bl, 3
	mov al, [currconstrtooltracktype]
	call [DrawStationImageInSelWindow]
.invalid:
	pop edi
	ret

	// get sprite set for display in station construction window
	//
	// in:	al=railroad track type (or 0 for non-railroad stations)
	//	bl=station type; 2 or 3 for two railroad orientations;
	//	    other for other station types
	// out: eax=sprite offset of station sprites counted station base sprite
	// safe:---
global getstationselsprites
getstationselsprites:
	push ebx
	cmp bl,4
	jnb .notrail

	mov ebx,eax
	and ebx,0x0f

	testflags electrifiedrail
	jnc .notelectrified

	call geteffectivetracktype

.notelectrified:
	mov ah,[curselstation]
	test ah,ah
	jnz .isnewstation

.notrail:
	and eax,0x0f
	imul eax,82
	mov [realtempstationtracktypespriteofs],eax
	and dword [stationspritesetofs],0
	pop ebx
	ret

.isnewstation:
	push esi

	xchg al,bl
	imul ebx,82
	mov [realtempstationtracktypespriteofs],ebx

//	movzx ebx,al
//	mov bl,[tracktypes+ebx]
	xor ebx,ebx
	movzx eax,ah
	xor esi,esi

	mov [stationcurstation],esi
	mov [stationcurgameid],eax
	mov byte [grffeature],4
	call getnewsprite

	pop esi
	pop ebx

	sub eax,1069
	mov [stationspritesetofs],eax
	ret

uvard realtempstationtracktypespriteofs
uvard stationspritesetofs
uvard stationcurgameid
uvard stationcurstation


#if 0
	// called when left/right buttons in station selection window are pressed
	//
	// in:	cl=17h..1ah for class +/- and station +/- buttons
	// out:	---
	// safe:???
stationselbutton:
	cmp cl,0x18
	jbe near makestationclassdropdown

	pusha

	mov ch,[curselclass]

	movzx edx,byte [numstationclasses]	// counter for infinite loop detection
	inc edx

.nextclass:
	mov bh,cl
	and bh,1
	add bh,bh
	dec bh		// now bh=+1 for 17, 19 and -1 for 18, 1A
			// i.e. opposite to button logic

	movzx edi,byte [newstationnum]
	inc edi

	cmp cl,19h
	jnb .setstation

.setclass:
	movzx eax,byte [curselclass]

.cycleclass:
	dec edx
	jnz .noloop

	mov [curselclass],ch
	mov al,[curselstation]
	jmp .done

.noloop:
	sub al,bh
	cmp al,0xff
	jne .nowrap

	mov al,[numstationclasses]
	sub al,1

.nowrap:
	cmp al,[numstationclasses]
	jb .validclass

	mov al,0

.validclass:
	bt [stationclassesused],eax
	jnc .cycleclass

	mov [curselclass],al
	mov bl,al
	mov al,[laststationselinclass+eax]
	mov bh,0xff
	jmp short .nottoohigh	// check station class is right

.setstation:
	movzx eax,byte [curselstation]
	mov bl,[curselclass]

.cyclestat:
	dec edi
	jnz .notlooped

	// we went through all station IDs and apparently couldn't find anything
	// if we were selecting classes, it probably was one with station IDs
	// but all disabled by the callback

	cmp cl,19h
	jb .nextclass

	mov al,[curselstation]
	mov bl,ch
	jmp short .done

.notlooped:

	sub al,bh
	cmp al,0xff
	jne .nottoolow

	mov al,[newstationnum]

.nottoolow:
	cmp al,[newstationnum]
	jbe .nottoohigh

	mov al,0

.nottoohigh:
#endif

	// find suitable station for class
	//
	// in:	eax=class
	// out:	edx=station
	//	carry set if none available
global findstationforclass,findstationforclass.next
findstationforclass:
	movzx edx,byte [laststationselinclass+eax]
.trynext:
	cmp [stationclass+edx],al
	jne .next

	call isstationavailable
	jnc .done

.next:
	inc edx
	cmp edx,[newstationnum]
	jbe .nooverflow

	xor edx,edx

.nooverflow:
	cmp dl,[laststationselinclass+eax]
	jne .trynext

	stc
.done:
	ret

	// find out if station is available
	//
	// in:	edx=station
	// out:	carry set if not available
isstationavailable:
	test byte [stationcallbackflags+edx],1
	jz .done

	mov byte [curcallback],0x13
	mov byte [grffeature],4
	push eax
	push esi
	mov eax,edx
	xor esi,esi
	call getnewsprite
	mov byte [curcallback],0
	mov dh,al
	pop esi
	pop eax
	cmc
	jnc .done

	test dh,dh
	jnz .done

	stc

.done:
	mov dh,0
	ret

#if 0
global makestationclassdropdown
makestationclassdropdown:
	jmp makestationclassdropdownex
	mov eax,0xc000
	xor ebx,ebx
.loop:
	cmp al,MAXDROPDOWNENTRIES
	jae .done
	mov [tempvar+2*(eax-0xc000)],ax

	push eax
	movzx eax,al
	call findstationforclass
	pop eax
	jnc .gotstation

	bts ebx,eax	// mark as disabled, no stations available

.gotstation:
	inc eax
	cmp al,19
	jae .done
	cmp al,[numstationclasses]
	jb .loop

.done:
	mov word [tempvar+2*(eax-0xc000)],-1	// terminate it
	movzx dx,byte [curselclass]		// current selection
	jmp [GenerateDropDownMenu]

#else

exported makestationclassdropdown
	extcall GenerateDropDownExPrepare
	jnc .noolddrop
	ret
.noolddrop:
	push ecx
	xor eax,eax
	xor ebx,ebx
.loop:
	cmp al, MAXDROPDOWNEXENTRIES
	jae .done

	mov ecx, 0xc000
	mov cl, al
	mov dword [DropDownExList+4*eax],ecx

	push eax
	movzx eax,al
	call findstationforclass
	pop eax
	jnc .gotstation
	bts [DropDownExListDisabled], eax	// mark as disabled, no stations available

.gotstation:
	inc eax
	cmp al, MAXDROPDOWNEXENTRIES
	jae .done
	cmp al,[numstationclasses]
	jb .loop

.done:
	mov dword [DropDownExList+4*eax],-1	// terminate it
	movzx dx,byte [curselclass]		// current selection
	pop ecx
	mov byte [DropDownExMaxItemsVisible], 16 // Changed the word to a byte to match var size (Lakie)
	extjmp GenerateDropDownEx
#endif


uvarb stationdropdownnums,255
#if 1
exported makestationseldropdown
	extcall GenerateDropDownExPrepare
	jnc .noolddrop
	ret
.noolddrop:
	test byte [expswitches],EXP_PREVIEWDD
	jnz .preview
	mov byte [DropDownExMaxItemsVisible], 12
	jmp .setupdone
.preview:
	mov word [DropDownExListItemExtraWidth], 38
	mov word [DropDownExListItemHeight], 23
	mov byte [DropDownExMaxItemsVisible], 7
	mov word [DropDownExFlags], 11b
	mov dword [DropDownExListItemDrawCallback], makestationseldropdown_callback
.setupdone:
	xor eax,eax
	mov bl,[curselclass]
	mov bh,-1
	xor edx,edx
.loop:
	cmp al,MAXDROPDOWNEXENTRIES
	jae .done

	cmp [stationclass+edx],bl
	jne .next

	call isstationavailable
	jc .next

	mov dword [DropDownExList+eax*4],0xc100
	mov byte [DropDownExList+eax*4],dl

	mov [stationdropdownnums+eax],dl

	cmp dl,[curselstation]
	jne .notcur

	mov bh,al

.notcur:
	inc eax

.next:
	cmp al,MAXDROPDOWNEXENTRIES
	jae .done
	inc edx
	cmp edx,[newstationnum]
	jbe .loop

.done:
	mov dword [DropDownExList+4*eax],-1	// terminate it
	movzx edx,bh		// current selection
	extjmp GenerateDropDownEx

// in cx, dx (x,y)
makestationseldropdown_callback:
	push edi
	// create temp screen description
	add cx, 1
	pusha
	mov edi, baTempBuffer1
	mov byte [edi], 0
	//	DX,BX = X,Y CX,BP = width,height
	mov ebx, edx
	mov edx, ecx
	mov cx, 64/2
	mov bp, 46/2

	call [MakeTempScrnBlockDesc]
	popa
	jz .invalid
	mov edi, baTempBuffer1
	mov word [edi+scrnblockdesc.zoom], 1
	shl word [edi+scrnblockdesc.x], 1
	shl word [edi+scrnblockdesc.y], 1
	shl word [edi+scrnblockdesc.width], 1
	shl word [edi+scrnblockdesc.height], 1
	pusha
	mov al, byte [curselstation]
	push eax
	mov bl, byte [stationdropdownnums+ebx]
	mov byte [curselstation], bl
	mov bl, 2
	mov al, [currconstrtooltracktype]
	add cx, 16
	add dx, 8
	shl cx, 1
	shl dx, 1
	call [DrawStationImageInSelWindow]
	pop eax
	mov byte [curselstation], al
	popa
.invalid:
	pop edi
	ret
#else

global makestationseldropdown
makestationseldropdown:
	xor eax,eax
	mov bl,[curselclass]
	mov bh,-1
	xor edx,edx
.loop:
	cmp al,MAXDROPDOWNENTRIES
	jae .done

	cmp [stationclass+edx],bl
	jne .next

	call isstationavailable
	jc .next

	mov [tempvar+eax*2],dl
	mov byte [tempvar+1+eax*2],0xc1
	mov [stationdropdownnums+eax],dl

	cmp dl,[curselstation]
	jne .notcur

	mov bh,al

.notcur:
	inc eax

.next:
	cmp al,19
	jae .done
	inc edx
	cmp edx,[newstationnum]
	jbe .loop

.done:
	mov word [tempvar+2*eax],-1	// terminate it
	movzx edx,bh		// current selection
	xor ebx,ebx		// everything available
	jmp [GenerateDropDownMenu]
#endif

global stationseldropdownclick
stationseldropdownclick:
	bt dword [esi+window.activebuttons],0x18
	jnc .notclass

	movzx eax,al
	call findstationforclass
	mov ah,dl
	jnc .notdflt
	mov al,0
	mov ah,0
.notdflt:
	mov [curselclass],al
	mov [curselstation],ah
	movzx eax,ah
	jmp near .update

.notclass:
	bt dword [esi+window.activebuttons],0x1a
	jc .isstation

	ret

.isstation:
	movzx eax,al
	mov al,[stationdropdownnums+eax]
	mov [curselstation],al

.update:
	movzx ebx,byte [curselclass]
	mov [laststationselinclass+ebx],al

	pusha
	mov dl,al	// station ID
	mov dh,bl	// class ID
	mov bh,0	// set station&class ID
	mov bl,1	// do it!
	xor eax,eax
	xor ecx,ecx
	dopatchaction actionnewstations
	popa

	// find out which platform numbers and lengths are (dis)allowed
	// and set buttons accordingly

	movzx ebx,word [wcurrentstationsize]

	// disallowed*: bit 0..6=lengths 1..7, bit 7=+7
	// so length bits 1..14 would be 0..6, 0|7, 1|7, 2|7... 7|7
	movsx ecx,byte [disallowedplatforms+eax]
	or ch,cl
	or ch,0x80
	shl cl,1
	shl ecx,16
	sar ecx,1

	movsx cx,byte [disallowedlengths+eax]
	or ch,cl
	or ch,0x80
	shl cl,1
	sar cx,1

	mov eax,ecx	// now eax bits 0..13 = lengths 1..14, bits 16..29 = platforms 1..14

	movzx ecx,bl

.checklength:
	bt eax,ecx
	jnc .lengthok

	dec cl
	jns .checklength

	mov cl,6
	jmp .checklength

.lengthok:
	mov bl,cl

	mov cl,bh
	and cl,0x7f	// high bit is orientation, mask it out

	shr eax,16

.checkplat:
	bt eax,ecx
	jnc .platok

	dec cl
	jns .checkplat

	mov cl,6
	jmp .checkplat

.platok:
	and bh,0x80
	or bh,cl
	mov [wcurrentstationsize],bx

	call setstationdisabledbuttons

	mov al,[esi]
	mov bx,[esi+6]
	call dword [invalidatehandle]
	ret

#if 0
showtrainstorient:
	add dx,15
	mov bh,0xc0
	mov bl,[curselclass]
	mov al,16	// default colour black
	ret

showtrainstnumtr:
	add dx,76
	mov bh,0xc1
	mov bl,[curselstation]
	mov al,16
	ret
#endif


// patch action to handle selecting new stations
//
// in:	bh=what to do
//		bh=0 set station&class IDs, dl=station ID, dh=class ID
global actionnewstations
actionnewstations:
	test bl,bl
	jnz .doit

	xor ebx,ebx	// choosing stations is free
.done:
	ret

.doit:
	cmp bh,0
	jne .done

	movzx eax,byte [curplayer]
	mov [curselstationid+eax],dl
	mov [curselclassid+eax],dh
	ret

uvarw stationanimdata,256
uvarb stationanimspeeds,256

	//
	// special functions to handle special station properties
	//
	// in:	eax=special prop-num
	//	ebx=offset
	//	ecx=num-info
	//	edx->feature specific data offset
	//	esi=>data
	// out:	esi=>after data
	//	carry clear if successful
	//	carry set if error, then ax=error message
	// safe:eax ebx ecx edx edi

global setstationclass
setstationclass:
	mov eax,[laststationid]
	inc eax
	cmp eax,ebx
	jne .bad

	mov eax,[curspriteblock]
	mov eax,[eax+spriteblock.grfid]
	test eax,eax
	jz .bad

	inc eax
	jnz .next

.bad:		// grfid is 0 or -1, not acceptable for stations
	mov eax,ourtext(invalidsprite) | (INVSP_BADID << 16)
	stc
	ret

.next:
	lodsd
	push ecx
	mov ecx,[numstationclasses]
	mov edi,stationclasses
	repne scasd
	je .gotit

	cmp dword [numstationclasses],byte maxstationclasses
	jb .newclass

.toomany:
	pop ecx
	mov al,GRM_EXTRA_STATIONS
	jmp failpropwithgrfconflict

.newclass:
	stosd
	inc dword [numstationclasses]

.gotit:
	movzx eax,byte [newstationnum]
	inc al
	jnz .ok		// too many stations in set?

	jmp .toomany

.ok:
	cmp byte [grfstage],0
	je .dontrecord
	mov [newstationnum],al
.dontrecord:
	mov [curgrfstationlist+ebx],al
	mov [laststationid],ebx

	neg ecx
	add ecx,[numstationclasses]
	dec ecx
	mov [stationclass+eax],cl
	bts [stationclassesused],ecx
	inc byte [numstationsinclass+ecx]

	or word [stationanimdata+eax*2],byte -1
	mov byte [stationanimspeeds+eax],2

	pop ecx

	inc ebx
	loop .next

	mov eax,[curspriteblock]
	mov [curextragrm+GRM_EXTRA_STATIONS*4],eax

	clc
	ret


vard stationspritelayoutinfo, stationspritelayout,curgrfstationlist,ttdpatchstationspritelayout

global setstationspritelayout
setstationspritelayout:
	mov ebp,stationspritelayoutinfo
	// jmp short setgeneralspritelayout
	// fall through


	// call with standard action 0 prop registers for type "H", and also
	// ebp->sprite layout info
	//	where	[ebp+0]->table where to store sprite layouts
	//		[ebp+4]->ID translation table (may be 0 if none)
	//		[ebp+8]->default sprite layouts
	// note, the offset in ebx must be untranslated
	//	 (i.e. type "H" in the defvehdata argument in grfact.asm)
setgeneralspritelayout:
	mov edi,[edx]
	test edi,0xffff0000
	jnz .gotptr

	call getextendedbyte_noadjust
	inc eax
	imul edi,eax,4
	imul edi,ecx
	push edi
	call malloccrit
	pop edi
	mov [edx],edi

.gotptr:
	call getextendedbyte_noadjust
	mov edx,eax

.next:
	push ebx
	mov eax,[ebp+4]
	test eax,eax
	jz .notrl
	mov bl,[eax+ebx]
.notrl:
	push ecx
	mov [edi],edx	// store number of valid sprite slots
	add edi,4
	mov eax,[ebp]
	mov [eax+ebx*4],edi

	call getextendedbyte
	mov ecx,eax
	cmp ecx,edx
	je .nexttile
	pop ebx

.invalid:
	pop ecx
	mov eax,(INVSP_INVPROPVAL << 16)+ourtext(invalidsprite)
	call setspriteerror
	or edi,byte -1
	ret

.nexttile:
	mov eax,esi
	stosd
	lodsd		// ground sprite
	test eax,eax
	jnz .nextsprite	// has new layout data, skip to next tile

	// use default layout
	imul eax,ecx,byte -4
	lea eax,[eax+edx*4]
	add eax,[ebp+8]
	mov [edi-4],eax
	jmp short .tiledone

.nextsprite:
	lodsb
	cmp al,0x80
	je .tiledone
	add esi,9
	jmp .nextsprite
.tiledone:
	loop .nexttile

	pop ecx
	pop ebx
	inc ebx
	loop .next
	clc
	ret

global copystationspritelayout
copystationspritelayout:
	mov edx,stationspritelayout

docopystationdata:
.next:
	xor eax,eax
	lodsb
	mov al,[curgrfstationlist+eax]
	mov eax,[edx+eax*4]
	mov [edx+ebx*4],eax
	inc ebx
	loop .next
	clc
	ret

global copystationlayout
copystationlayout:
	mov edx,newstationlayout
	jmp docopystationdata

global setstationlayout
setstationlayout:

.next:
	mov [newstationlayout+ebx*4],esi
	or edx,byte -1
	push ecx
	call usenewstationlayout	// skip all layouts
	pop ecx
	jnz setstationclass.bad		// bad if we found 255 platforms...
	loop .next
	clc
	ret

exported setstatcargotriggers
	lodsd

	cmp eax,byte -1	// sets carry if eax wasn't FFFFFFFFh
	cmc
	sbb edx,edx
			// edx is now zero if and only if eax wasn't FFFFFFFFh
	jnz .hasedx

	push dword [curspriteblock]

	or ecx,byte -1

.nextbit:
	inc ecx
	shr eax,1
	ja .nextbit		// ja = both carry and zero are clear
				// (no bit exited on the right, but there are bits left in eax)
	jnc .done		// if we didn't jump already, either carry or zero is set
				// if carry is clear, zero must be set, and we're done
				// (no more bits in eax, no bit exited)

	push ecx
	call lookuptranslatedcargo_usebit
	pop edi

	cmp edi,0xff
	je .nextbit

	bts edx,edi
	jmp short .nextbit

.done:
	add esp,4
.hasedx:
	mov [statcargotriggers+ebx*4],edx
	clc
	ret

	// get text table associated with station names and classes
	// in:	edi=text ID & 7ff
	//	0xx = get station class xx name
	//	1xx = get station xx name
	//	4xx = set station class xx name
	//	5xx = set station xx name
	// out:	eax=table ptr
	//	edi=table index
	// safe:---
global getstationtexttable
getstationtexttable:
	mov eax,edi
	movzx edi,al

	cmp eax,0x7ff
	je .specialnum

	test ah,1
	jz .class

	test ah,4
	mov eax,newstationnames
	jz .notwrite

	// translate from set-id to game-id
	movzx edi,byte [curgrfstationlist+edi]
	ret

.specialnum:
	mov ax,statictext(fixednumber)
	jmp gettextintableptr

.notwrite:
	test edi,edi
	jnz .stationname

.default:
	mov ax,ourtext(defaultstation)
	jmp gettextintableptr

.bad:
	movzx eax,byte [stsetids+edi*stsetid_size+stsetid.setid]
	inc eax
	call .setstationnum
	mov ax,ourtext(stationnumdefault)
	jmp gettextintableptr

.setstationnum:
	mov edi,fixednumber_addr
	aam		// -> al=num mod 10, ah=num div 10
	add al,'0'
	stosb
	test ah,ah
	jz .singledigit
	xchg al,ah
	add al,'0'
	stosb
.singledigit:
	mov al,0
	stosb		// zero-terminate
	ret


.stationname:
	cmp dword [eax+edi*4],0
	je .bad
	ret

.class:
	test ah,4
	mov eax,newstationclasses
	jz .notclasswrite

	movzx edi,byte [curgrfstationlist+edi]
	movzx edi,byte [stationclass+edi]
	ret

.notclasswrite:
	test edi,edi
	jz .default

.classname:
	cmp dword [eax+edi*4],0
	je .badclass
	ret

.badclass:
	mov eax,edi
	inc eax
	call .setstationnum
	mov ax,ourtext(stationclassdefault)
	jmp gettextintableptr


#if 0
	cmp al,[numstationclasses]
	jae .defclass

	cmp al,0
	je .defclass

	test ah,4
	mov eax,newstationclasses
	jz .nowrite
	ret

.nowrite:
	cmp dword [eax+edi*4],0
	je .defclassnowrite
	ret

.defclass:
	test ah,4
	jnz .badwrite	// trying to write name of class 0/an undefined class?
.defclassnowrite:
	mov ax,0x3002	// "Orientation"
	jmp gettextintableptr

.badwrite:
	xor eax,eax
	ret
#endif


//maxstationclasses equ 32
	align 4
	// list of predefined station classes
var stationclasses
	dd 'DFLT'
	dd 'WAYP'

%define CLASS_DFLT 0
%define CLASS_WAYP 1

global numpredefstationclasses
numpredefstationclasses equ (addr($)-stationclasses)/4

	times maxstationclasses-numpredefstationclasses dd 0

var numstationclasses, dd numpredefstationclasses


uvarb laststationselinclass,maxstationclasses


// New stations - how it all works
//
// Each new station basically has three different IDs
// 1) setid:  The ID that is used in the .grf file itself, one for each action 3
// 2) gameid: The global in-game ID
// 3) dataid: The ID stored in the savegame
//
// So we have three lists to maintain:
// a) a list that tells us which .grf a dataid belongs to, and what its
//    current gameid is: this is stationidgrfmap
// b) a list that translates gameid to setid; that's stsetids
// c) only while loading the .grf, a list that tells us what gameid to use for
//    a certain setid, that's curgrfstationlist
//
// So if we place a new station with some gameid, what happens?
// - we look up the gameid in stationsids and find grfid/setid
// - we search stationidgrfmap whether this combination of grfid/setid exists
//   if not, we add it to the first empty slot. we record the slot number->dataid
// - we store the dataid with the new station
//
// And if we want to draw a station with some dataid:
// - we look up this dataid in stationidgrfmap
// - we get the gameid
// - we use the data from stsetids for this gameid to draw the station
//
// If a station tile is deleted, we decrement the corresponding .numtiles,
// and consider it unused if .numtiles is zero


uvard stationidgrfmap,256*2
uvarb havestationidgrfmap	// is anything in the stationidgrfmap list?


// place new station tile
// in:	ah=gameid
// out:	ah=dataid; 0 if no more room in stationidgrfmap
// uses:---
newstationtile:
	pusha
	movzx ecx,ah
	jecxz .regular

	mov ebx,[stsetids+ecx*stsetid_size+stsetid.act3info]
	// mov ebx,[ebx-6]
	mov ebx,[ebx+action3info.spriteblock]
	mov dl,[stsetids+ecx*stsetid_size+stsetid.setid]

	mov ebx,[ebx+spriteblock.grfid]

	xor eax,eax
	mov edi,stationidgrfmap
.searchnext:
	cmp [edi+eax*8+stationid.grfid],ebx
	jne .notit

	cmp [edi+eax*8+stationid.gameid],cl
	je .gotit

.notit:
	add al,1
	jnc .searchnext

	inc eax
.findempty:
	cmp word [edi+eax*8+stationid.numtiles],0
	je .makenew
	add al,1
	jnc .findempty

	// couldn't find it, list is full, return ah=0
	popa
	mov ah,0
	ret

.makenew:
	mov byte [havestationidgrfmap],1
	mov [edi+eax*8+stationid.grfid],ebx
	mov [edi+eax*8+stationid.gameid],cl
	mov [edi+eax*8+stationid.setid],dl

	// also set stationnonenter and stationrventer
	extern persgrfdata
	mov bl,[cantrainenterstattile+ecx]
	mov [stationnonenter+eax],bl

	mov ebx,[canrventerrailstattile+ecx*8]
	mov [stationrventer+eax*8],ebx
	mov ebx,[canrventerrailstattile+ecx*8+4]
	mov [stationrventer+eax*8+4],ebx

.gotit:
	inc word [edi+eax*8+stationid.numtiles]
	xchg eax,ecx

.regular:
	mov [esp+0x1c+1],cl	// save it to be restored in ah by popa
	popa
	ret


// get spritebase to draw station tile
// in:	eax=track type
//	ebx=dataid (must *not* be zero!)
//	esi=>station
// out:	eax=sprite base
//	ebx=track type
//      carry flag if graphics not present
// safe:---
getdataidspritebase:
	push eax
	movzx eax,byte [stationidgrfmap+ebx*8+stationid.gameid]
	mov [stationcurgameid],eax
	xor ebx,ebx
	mov byte [grffeature],4
	call getnewsprite
	pop ebx
	ret

uvard curstationtile	// station tile currently having its graphics drawn


// called to calculate the sprite offset to use for drawing the current
// station tile
//
// in:	ebp=offset for track type
//	other registers from GetTileInfo except ebx and esi are swapped
// out:	ebp=new offset
// safe:---
global getnewstationsprite
getnewstationsprite:
	push eax
	push ebx
	push ebp

	mov [realtempstationtracktypespriteofs],ebp

	xor eax,eax
	mov [stationspritesetofs],eax
	mov [stationcurgameid],eax

	cmp dh,	8
	jae near .nosprites

	// get dataid
	mov ax,[landscape3+ebx*2]
	test ah,ah
	jz near .nosprites

	push esi
	movzx esi,byte [landscape2+ebx]
	imul esi,station_size
	add esi,[stationarrayptr]

	mov [curstationtile],ebx
	mov [stationcurstation],esi

	movzx ebx,ah
	and eax,0x0f
	call getdataidspritebase
	jc .nospritespop

	sub eax,1069	// TTD will add sprite numbers based on this later
	xchg eax,ebx

	testflags electrifiedrail
	jnc .notelectrified

	call geteffectivetracktype

.notelectrified:
	mov [esp],ebx
	mov [stationspritesetofs],ebx
	imul eax,82

	mov [realtempstationtracktypespriteofs],eax

	movzx eax,dh
	and dword [foundationtiletype],eax

	mov eax,[stationcurgameid]
	test byte [stationcallbackflags+eax],2
	jz .nospritespop

	mov bl,dh
	call getspritelayoutcallback
	jc .nospritespop

	mov [orgtiletype],dh
	mov [modtiletype],eax
	mov [foundationtiletype],eax
	mov dh,0xff

.nospritespop:
	pop esi

.nosprites:
	pop ebp
	pop ebx
	pop eax
	ret

	uvarb curstattiletype

// get sprite layout number from callback
//
// in:	al=gameid
//	bl=original layout number
//	esi=>station (or 0 if none)
// out:	eax=sprite layout
//	cf set if error
getspritelayoutcallback:
	push edx
	mov edx,[stationspritelayout+eax*4]

	mov byte [curcallback],0x14
	mov byte [grffeature],4
	mov [curstattiletype],bl
	call getnewsprite
	mov byte [curcallback],0
	jc .error

	push ebx
	and ebx,1
	and eax,byte ~1
	or eax,ebx

	mov bl,8

	test edx,edx
	jz .gotcustom

	mov ebx,[edx-4]

.gotcustom:
	cmp ebx,eax
	pop ebx
	jae .ok

.error:
	stc
	movzx eax,al

.ok:
	pop edx
	ret


// called to set the landscape3 entry for a new station tile
// landscape1 and landscape2 are already set appropriately, and
// some of the station structure fields for it are set
// (at least those set by SetupNewStation)
//
// in:	 ax=track type (0/1/2 for RR/MR/ML)
//	 dh=length remaining
//	 dl=platforms remaining
//	 si=direction (1 or 100)
//	edi=tile index
// out:	---
// safe:ax,cx
global alteraddlandscape3tracktype
alteraddlandscape3tracktype:
	push ebx
	push eax
	call [randomfn]
	and al,0x0f

	cmp dword [curstationsectionsize],0
	jne .notfirsttile
	mov [curstationsectionsize],dx
	mov [curstationsectionpos],edi
	mov [curstationsectiondir],si
.notfirsttile:
	cmp [curstationsectionsize],dl
	jne .notfirstpos
	or al,0x10
.notfirstpos:
	cmp [curstationsectionsize+1],dh
	jne .notfirstplat
	or al,0x20
.notfirstplat:
	cmp dl,1
	jne .notlastpos
	or al,0x40
.notlastpos:
	cmp dh,1
	jne .notlastplat
	or al,0x80
.notlastplat:
	mov [landscape6+edi],al
	pop eax

	mov byte [landscape7+edi],0

	// stop animation just in case the old tile was animated
	pusha
	mov ebx,3				// Class 14 function 3 - remove animated tile
	mov ebp,[ophandler+0x14*8]
	call [ebp+4]
	popa

	// if old tile was station tile, adjust the appropriate .numtiles
	mov bl,[landscape4(di,1)]
	and bl,0xf0
	cmp bl,0x50
	jne .notoverbuild

	movzx ebx,byte [landscape3+edi*2+1]
	test ebx,ebx
	jz .notoverbuild

	dec word [stationidgrfmap+ebx*stationid_size+stationid.numtiles]

.notoverbuild:
	movzx ebx,byte [curplayer]
	mov ah,[curselstationid+ebx]
	call newstationtile
	mov [landscape3+edi*2], ax
	pop ebx
	ret

uvard curstationsectionsize
uvard curstationsectionpos
uvard curstationsectiondir

// called when removing a railway station tile
//
// in:	ax,cx=X,Y coord
//	bl has bit 0 set if actually clearing, bit 0 is clear if only checking
// out:	---
// safe:?
global removerailstation
removerailstation:
	test bl,1
	jz .notremoving

	pusha
	call [gettileinfo]
	movzx eax,byte [landscape3+esi*2+1]
	test eax,eax
	jz .notnewstation
	dec word [stationidgrfmap+eax*8+stationid.numtiles]
.notnewstation:
//	mov eax,[landscape6ptr]
	mov byte [landscape6+esi],0
	mov byte [landscape7+esi],0

	mov edi,esi
	mov ebx,3				// Class 14 function 3 - remove animated tile
	mov ebp,[ophandler+0x14*8]
	call [ebp+4]
	popa

.notremoving:
	call [cleartilefn]	// overwritten
	add ax,0x10
	ret

uvard orgtiletype
uvard modtiletype


uvard ttdstationspritelayout

// get pointer to sprite layout for station tile
//
// in:	 dh=tile type (FF if value comes from callback, then tiletype in [modtiletype])
//	ebx=landscape index
// out:	ebp->sprite layout
// safe:ebx
global getstationspritelayout
getstationspritelayout:

	cmp dh,0xff
	je .modtype

	movzx ebp,dh
	cmp dh,8
	jb .isitours

#if 0
	cmp dh, 0x53
	jb .notours
	cmp dh, 0x5A					//patchman, eis_os? I need some advice on this!!!
	jbe .newRVStop
	test byte [landscape3+ebx*2],0x10
	jz .notours
.newRVStop:
	movzx ebp,dh
	mov ebp,[paStationtramstop+(ebp-0x53)*4]
	retn
#endif

.notours:
	movzx ebp,dh
	mov ebp,[dword 0+ebp*4]
ovar ttdpatchstationspritelayout,-4
	ret

.modtype:
	mov ebp,[modtiletype]
	mov dh,[orgtiletype]

.isitours:
	movzx ebx,byte [landscape3+ebx*2+1]
	test ebx,ebx
	jz .notours

	movzx ebx,byte [stationidgrfmap+ebx*8+stationid.gameid]
	mov ebx,[stationspritelayout+ebx*4]
	test ebx,ebx
	jz .notours

	mov ebp,[ebx+ebp*4]
	ret

// same as above, but during displaying the construction window
//
// in:	ebx=tile type (2 or 3 for railway stations)
// out:	ebx->sprite layout
// safe:eax
global getstationdisplayspritelayout
getstationdisplayspritelayout:
	mov byte [gotnormalsprite],0	// set up support for drawing multiple ground tiles here

	cmp ebx,8
	jb .isitours
//	cmp ebx,0x53
//	jge .newRVStops

.notours:
	mov eax,[ttdpatchstationspritelayout]
	mov ebx,[eax+ebx*4]
	ret

//.newRVStops:
//	mov ebx,[paStationtramstop+(ebx-0x53)*4]
//	ret

.isitours:
	movzx eax,byte [curselstation]
	test eax,eax
	jz .notours

	push eax
	test byte [stationcallbackflags+eax],2
	jz .nocallback

	push esi
	xor esi,esi
	call getspritelayoutcallback
	pop esi
	jc .nocallback

	mov ebx,eax

.nocallback:
	pop eax
	mov eax,[stationspritelayout+eax*4]
	test eax,eax
	jz .notours

	// check if this layout is valid
	cmp ebx,[eax-4]
	jb .gotlayoutnumber

	and ebx, 1		// try keeping just the last bit (i.e. direction)
	cmp ebx,[eax-4]
	jb .gotlayoutnumber

	xor ebx,ebx		// there must be only one layout, use that

.gotlayoutnumber:
	mov ebx,[eax+ebx*4]
	ret

// translate track sprite number in ebx
//
// in:	ebx=sprite number
// out:	ebx=sprite number
// safe:?
global getstationtracktrl
getstationtracktrl:
	btr ebx,31
	jc .newsprites

	add ebx,[realtempstationtracktypespriteofs]
	ret

.newsprites:
	push eax
	mov eax,[stationcurgameid]
	test byte [stationflags+eax],1
	jnz .differentspriteset

.notdifferentspriteset:
	mov eax,[realtempstationtracktypespriteofs]
	shr eax,6
	add ebx,eax
	add ebx,[stationspritesetofs]
	pop eax
	ret

.differentspriteset:
	push esi
	push ebx
	mov esi,[stationcurstation]
	inc dword [miscgrfvar]
	mov byte [grffeature],4
	call getnewsprite
	dec dword [miscgrfvar]
	pop ebx
	pop esi
	jc .notdifferentspriteset

	lea eax,[eax+ebx-1069]
	mov ebx,[realtempstationtracktypespriteofs]
	shr ebx,6
	add ebx,eax
	pop eax
	ret


// when displaying the station in the selection window, don't break manually selected
// recolor sprites and/or semi-transparency
exported dispstationsprite
	btr ebx,30		// bit 30 is meaningless here, sprites are always drawn normally
	test ebx,0x3FFF0000
	jnz .donthurt
	or ebx,eax
.donthurt:
	cmp byte [gotnormalsprite],0
	jne getstationspritetrl		// if we've already had a normal sprite, this one will be normal
	xor ebx, 0x80000000
	jmp getstationtracktrl		// otherwise, this is an extra track sprite - reuse groundsprite code,
					// except that the meaning of bit 31 is inverted
	
// same for station sprite numbers
global getstationspritetrl
getstationspritetrl:
	btr ebx,31
	jc .ttdsprites

	add ebx,[stationspritesetofs]
	ret

.ttdsprites:
	add ebx,[realtempstationtracktypespriteofs]
	ret

extern specialgrfregisters

noglobal uvard foundationtiletype

// called from slopebld.asm to check and draw custom rail station foundations
// return with cf clear if the foundations were drawn and the caller just needs to add the ground sprite
// in:	ax, cx: X and Y coordinates of tile
//	dl: adjusted altitude
// safe: ebp, ???
exported drawstationcustomfoundation
// check if the callback is enabled
	mov ebp,[stationcurgameid]
	test byte [stationflags+ebp],8
	jnz .customfoundation
	stc
	ret

.customfoundation:
	pusha
// the GRF can put a sprite offset to register 100h, but it defaults to 0
	and dword [specialgrfregisters+0*4],0

// put the currently selected tile type to the low word of var18
	mov ebx,[foundationtiletype]
	mov [callback_extrainfo],ebx

// and merge info into bits 16..17
extern gettilealtmergemap
	call gettilealtmergemap
	mov [callback_extrainfo+2],si

// dh will contain 0 for "extended" foundation selection, or the bitmask of parts
// for the "simple" selection
	mov dh,0

	movzx edi,di

	test byte [stationflags+ebp],0x10
	jnz .notsimple

	mov ebx,esi
	mov dh,bl
	shl dh,6
	not dh
// now dh masks off bit 7 for NW merging and 6 for NE merging
	and dh,[foundationpartsforslope+edi]

	jz .noslope	// no foundation sprites needed at all


.notsimple:
	xchg eax,ebp			// save the X coord and move ID to eax
	mov esi,[stationcurstation]
	mov byte [miscgrfvar],2		// to show that we're selecting foundations
	mov byte [grffeature],4
	call getnewsprite
	mov byte [miscgrfvar],0
	jc .error

	sub dl,8		// the adjusted altitude is one level higher than the lowest corner
				// we need the lowest corner as altitude

	mov ebx,eax		// save callback result
	mov eax,ebp		// restore X coord

	add ebx,[specialgrfregisters+0*4]	// add extra offset in register 100h to spriteno

	test dh,dh
	jnz .simple

// "Extended" sprite selection. Some slopes are impossible for stations, so the offset
// into the sprite block isn't the slope itself info itself; slopes 0, 1, 2, 4 and 8 are
// skipped.
	sub edi,4	// subtract four
	adc edi,0	// but add 1 back if edi was below four, so 3 becomes 1
			// (other values <=4 aren't possible)
	cmp edi,4	// if edi isn't below 4 (the original isn't below 8
	adc edi,byte -1	// subtract 1, otherwise do nothing

	add ebx,edi	// add slope-dependent offset to spriteno

extern exscurfeature,exsspritelistext

// add foundation sprite with its own bounding box, and return success
	mov byte [exscurfeature],4
	mov byte [exsspritelistext], 1

	mov dh,7
	mov di,0x10
	mov si,di
extern addsprite
	call [addsprite]
	clc
.error:
	popa
	ret

.noslope:
// WARNING: slight kludge
// no foundation sprites needed - return failure to slopebld.asm, so it draws its
// own foundation, which will end up as an empty 64x32 sprite
// we need this dummy sprite because the ground sprite will be added relatively to it
	stc
	popa
	ret

.simple:
// simple foundation drawing - TTDPatch puts the foundations together from parts

	or ebp,byte -1		// a nonzero ebp will mean this is the first sprite

// dh contains the bitmask of foundation parts to draw
.nextsprite:
	shr dh,1		// check next bit
	jnc .skipsprite

	mov byte [exscurfeature],4
	mov byte [exsspritelistext], 1

	push ebx
	push edx
	test ebp,ebp
	jz .addrel

// this is the first sprite - create a bounding box for it
	mov dh,7
	mov di,0x10
	mov si,di
	call [addsprite]
	jmp short .added

.addrel:
// not the first sprite - add as relative sprite, neutralizing the negative xoffs and yoffs
// of the sprite with the same values in positive
	mov ax,31
	mov cx,9
extern addrelsprite
	call [addrelsprite]

.added:
	pop edx
	pop ebx
	xor ebp,ebp	// the above code destroyed ebp - zero it so the next sprite will be relative
.skipsprite:
	inc ebx		// jump to next sprite in the block
	test dh,dh	// do we have parts remaining?
	jnz .nextsprite

// report success
	clc
	popa
	ret

// bitmask of foundation components present for a slope
// (even impossible slots are filled, this table may come handy later)
noglobal varb foundationpartsforslope
	// 87654321   87654321   87654321   87654321
	db 00000000b, 11010001b, 11100100b, 11100000b	// 0..3
	db 11001010b, 11001001b, 11000100b, 11000000b	// 4..7
	db 11010010b, 10010001b, 11100100b, 10100000b	// 8..b
	db 01001010b, 00001001b, 01000100b, 11010010b	// c..f
endvar

// search station layout and if found, copy to edi
//
// in:	dh=number of platforms
//	dl=platform length
//	esi->new station layout data (must not be 0)
//	edi->station layout buffer
// out:	zf if not found, nz if found
// safe:eax ebx ecx
global usenewstationlayout
usenewstationlayout:
	xor eax,eax

.nextset:
	lodsw
	test eax,eax
	jnz .checkit
	ret	// not found, zf set

.checkit:
	movzx ecx,al
	movzx ebx,ah
	imul ecx,ebx
	cmp ax,dx
	je .foundit
	add esi,ecx
	jmp .nextset

.foundit:
	rep movsb
	or al,1	// clear zf
	ret

// route map handler for station tiles
global checktrainenterstationtile
checktrainenterstationtile:
	cmp al,0
	jne .old

	extern newvehdata
	movzx eax,byte [landscape3+edi*2+1]
	mov ah,[stationnonenter+eax]
	mov al,[landscape5(di,1)]
	add al,8
	bt eax,eax	// really bt ah,tiletype
	mov eax,0	// not xor eax,eax to preserve CF
	jnc .old
	ret

.old:
	jmp near $+5
ovar .oldfn, -4, $, checktrainenterstationtile

// called when checking whether train stops at this station tile or another
// follows
//
// fixes reversing of trains in station when station tile blocked
// or station tile is in the wrong direction

// in:	bx+si=tile index of next tile
//		bx=current tile
//	dl=tile type of next tile
// out:	CF=1 won't stop, CF=0 will stop (station doesn't continue)
// safe:dx esi
global doestrainstopatstationtile
doestrainstopatstationtile:
	cmp dl,8
	jnb .done	// not a train station tile
	lea esi,[bx+si]
	mov dh, [landscape5(bx,1)]
	xor dh, [landscape5(si,1)]
	and dh,1
	jnz .done       // wrong

	movzx esi,byte [landscape3+esi*2+1]
	mov dh,[stationnonenter+esi]
	add dl,8
	bt edx,edx	// really bt dh,tiletype
//	jc .stop
//	stc
	cmc
.done:
	ret

//.stop:
//	clc		// want to return to original address
//	ret


// called by var. action 2 for variables 40+x
//
// in:	esi->station
// out:	eax=variable content
// safe:ecx

// variable 40: platforms/tile location
// out:	eax=0TNLcCpP
//	 T tile type
//	 N number of platforms
//	 L length
//	 C current platform number (0 for first)
//	 c current platform number, counted from last (0 for last)
//	 P position along this platform (0 for beginning)
//	 p position counted from end (0 for end)
//
// ecx=NNLLCCPP
global getplatforminfo,getplatforminfo.getccpp
getplatforminfo:
	mov byte [.checkdirection],0	// direction doesn't matter

.getinfo:
	test byte [esi+station.facilities],1
	jnz .hastrainfacility
	xor eax,eax
	ret

.hastrainfacility:
	mov ecx,[curstationtile]
	testmultiflags irrstations
	jnz NEAR .irregular

	mov al,[esi+station.platforms]
	call convertplatformsincargoacceptlist
	xchg al, ah
	// now al = length, ah = tracks
	shl eax,16
	mov ax,cx
	sub ax,[esi+station.railXY]
.getccppflip:
	test byte [landscape5(cx,1)],1	// orientation
	jz .getccpp
	xchg ah,al
.getccpp:
	// here eax=NNLLCCPP
	push eax
	mov ecx, eax
	shr ecx, 16	// now cx=NNLL
	sub cx, ax	// now cx=ccpp
	sub cx,0x0101
	test cx, 0xf0f0
	jnz .saturate
	test eax, 0xf0f0f0f0
	jnz .saturate2
.saturate_done:
	// here eax=0N0L0C0P
	// here ecx=00000c0p
	shl ecx,4
	or eax,ecx	// now eax=0N0LcCpP
	ror eax,16
	mov ecx,eax
	shr ax,4
	or al,cl	//now eax=cCpP00NL
	or ah,[curstattiletype]
	rol eax,16	// now eax=0TNLcCpP
	pop ecx
	ret
.saturate:
	test cl, 0xf0
	jz .saturate1
	mov cl, 0x0f
.saturate1:
	test ch, 0xf0
	jz .saturate2
	mov ch, 0x0f
.saturate2:
	shl ecx, 16
	test al, 0xf0
	setz cl
	dec cl
	or al, cl
	test ah, 0xf0
	setz cl
	dec cl
	or ah, cl
	rol eax, 16
	test al, 0xf0
	setz cl
	dec cl
	or al, cl
	test ah, 0xf0
	setz cl
	dec cl
	or ah, cl
	rol eax, 16
	and eax, 0x0f0f0f0f
	shr ecx, 16
	jmp .saturate_done

.irregular:
	// ecx=tile
	push ebx
	push edx

	// first loop, calculate LL and PP
	xor eax,eax
	xor ebx,ebx

	lea edx,[eax+1]		// edx=1
	mov bh,[landscape5(cx,1)]
	and bh,1
	jz .start

	mov edx,ebx

.start:
	and bh,[.checkdirection]	// .checkdirection is zero when ignoring direction

.nexttile1:
	mov bl,[landscape4(cx,1)]
	and bl,0xf0
	cmp bl,0x50
	jne .gotend1

	mov bl,[landscape5(cx,1)]
	cmp bl, 7	// train station
	ja .gotend1

	and bl,[.checkdirection]
	cmp bl,bh
	jne .gotend1

	add ecx,edx
	add eax,0x10000		// increase LL
	test edx,edx
	sets bl
	add al,bl		// when going to beginning, also increase PP
	jmp .nexttile1

.gotend1:
	mov ecx,[curstationtile]
	test eax,eax
	jz .gotirr		// not a station tile at all???

	sub ecx,edx
	neg edx
	js .nexttile1

	// second part, get NN and CC
	mov ecx,[curstationtile]
	xchg dh,dl

.nexttile2:
	mov bl,[landscape4(cx,1)]
	and bl,0xf0
	cmp bl,0x50
	jne .gotend2

	mov bl,[landscape5(cx,1)]
	cmp bl, 7	// train station
	ja .gotend2

	and bl,[.checkdirection]
	cmp bl,bh
	jne .gotend2

	add ecx,edx
	add eax,0x1000000	// increase NN
	test edx,edx
	sets bl
	add ah,bl		// when going to beginning, also increase CC
	jmp .nexttile2

.gotend2:
	mov ecx,[curstationtile]
	sub ecx,edx
	neg edx
	js .nexttile2

	// done!
.gotirr:
	pop edx
	pop ebx
	jmp .getccpp

.checkdirection: db 0

// variable 49: same as above, but only for tiles in same direction
global getplatformdirinfo
getplatformdirinfo:
	mov byte [getplatforminfo.checkdirection],1	// only if direction matches
	jmp getplatforminfo.getinfo

// variable 41: same but only for each individually built section
global getstationsectioninfo
getstationsectioninfo:
	test byte [esi+station.facilities],1
	jnz .hastrainfacility

.notnewstation:
	xor eax,eax
	ret

.bad:
	mov ecx,[curstationtile]
	or byte [ebx+ecx],0xf0
	pop edx
	pop ebx
	xor eax,eax
	ret

.hastrainfacility:
	mov ax,0x0101
	push ebx
	push edx
	mov ebx,landscape6
	mov ecx,[curstationtile]
	mov edx,1
	test byte [landscape5(cx,1)],1	// orientation
	jz .notflip
	xchg dh,dl
.notflip:

.moreplat1:
	test ecx,0xffff0000
	jnz .bad
	test byte [ebx+ecx],0x40
	jnz .doneplat1
	inc al
	add ecx,edx
	jmp .moreplat1

.doneplat1:
	xchg dh,dl

.morelen1:
	test ecx,0xffff0000
	jnz .bad
	test byte [ebx+ecx],0x80
	jnz .donelen1
	inc ah
	add ecx,edx
	jmp .morelen1

.donelen1:
	xchg dh,dl

	mov ecx,[curstationtile]

.moreplat2:
	test ecx,0xffff0000
	jnz .bad
	test byte [ebx+ecx],0x10
	jnz .doneplat2
	inc al
	sub ecx,edx
	jmp .moreplat2

.doneplat2:
	xchg dh,dl

.morelen2:
	test ecx,0xffff0000
	jnz .bad
	test byte [ebx+ecx],0x20
	jnz .donelen2
	inc ah
	sub ecx,edx
	jmp .morelen2

.donelen2:
	// now ecx=first tile of section ax=NNLL
	shl eax,16
	mov ax,[curstationtile]
	sub ax,cx	// ax = CCPP
	pop edx
	pop ebx
	mov ecx,[curstationtile]
	jmp getplatforminfo.getccppflip

// variable 42: station terrain
// out:	eax=0000ttTT
//	tt=track type
//	TT=terrain type
global getstationterrain
getstationterrain:
	mov ecx,[curstationtile]

	// get terrain type into eax (this clears ah as well)
	xchg ecx,esi
	call gettileterrain
	xchg ecx,esi

	movzx ecx,byte [landscape3+ecx*2]	// track type
	and ecx,0x0f

	testmultiflags electrifiedrail
	jnz .iselrail

	// elrail off
	inc ecx
	cmp ecx,2
	sbb ecx,0
.gotit:
	mov ah,cl
	ret

.iselrail:
	cmp ecx,1
	jbe .gotit
	mov ah,[unimaglevmode]
	inc ah
	ret

// variable 44: PBS state
// out:	eax=bit 0/1 PBS state
global getstationpbsstate
getstationpbsstate:
	mov eax,2
	testmultiflags pathbasedsignalling
	jz .nopbs

	mov eax,[curstationtile]
	bt dword [landscape3+eax*2],7
	sbb eax,eax
	and eax,3
	or eax,4

.nopbs:
	ret

// variable 45: does track continue
// out: eax=xxxxxxAA
//	AA, bits 0..3: track in +L -L +P -P dir
//	AA, bits 4..7: track in +L -L +P -P dir, even if not connected
global gettrackcont
gettrackcont:
	push ebx
	push edi
	push esi

	xor ebx,ebx

	mov edi,[curstationtile]
	movzx esi,byte [landscape5(di,1)]
	and esi,1
	shl esi,3

.nextdir:
	movsx edi,word [.ofs+esi*2]
	add edi,[curstationtile]

	mov al,[landscape4(di,1)]
	shr al,1
	and eax,0x78
	mov ecx,[ophandler+eax]
	xor eax,eax
	push esi
	call [ecx+0x24]		// GetRouteMap
	pop esi
	or al,ah
	jz .nothing

	movzx ecx,byte [.dir+esi]
	test al,[piececonnections+ecx]
	setnz al
	mov ah,1
	mov ecx,esi
	and ecx,7
	shl eax,cl
	or ebx,eax

.nothing:
	inc esi
	test esi,7
	jnz .nextdir

	mov eax,ebx
	pop esi
	pop edi
	pop ebx
	ret

	align 4
.dir:	db 5,1,3,7,5,1,5,1		// station in X direction
	db 3,7,5,1,3,7,3,7		// station in Y direction
.ofs:	dw 1,-1,0x100,-0x100,0x101,0xff,-0xff,-0x101
	dw 0x100,-0x100,1,-1,0x101,-0xff,0xff,-0x101

// variables 46/47: similar to 40/41 but counted from the middle
// out: eax=xTNLxxCP
//	C and P signed variables counted from the middle, -8..7
global getplatformmiddle
getplatformmiddle:
	call getplatforminfo
	jmp short getstationsectionmiddle.getmiddle

global getstationsectionmiddle
getstationsectionmiddle:
	call getstationsectioninfo
.getmiddle:	// eax=0TNLcCpP
	shld ecx,eax,20		// ecx=xxx0TNLc
	shr cl,5
	shr ch,1
	and ch,7		// ecx=xxxx0n0l where n,l=N,L div 2 //rounded up
	and ax,0x0f0f
	sub ah,ch
	sub al,cl
	shl al,4
	shr ax,4
	mov ah,0		// eax=0TNL00CP
	ret

// var. 48: bit mask of accepted cargos
global getstationacceptedcargos
getstationacceptedcargos:
	testflags newcargos
	jc .new

	xor eax,eax
	xor ecx,ecx
.nextslot:
	test byte [esi+station.cargos+ecx*stationcargo_size+stationcargo.amount+1],0x80
	jz .noaccept
	bts eax,ecx
.noaccept:
	inc cl
	cmp cl,12
	jb .nextslot

	ret

.new:
	mov eax,[esi+station2ofs+station2.acceptedcargos]
	ret

// var. 4A: get current animation frame
exported getstationanimframe
	mov eax,[curstationtile]
	movzx eax, byte [landscape7+eax]
	ret

// parametrized var. 66: get animation frame of nearby tile
exported getnearbystationanimframe
	push ebx
	sar ax,4
	sar al,4
	mov ebx,[curstationtile]
	test byte [landscape5(bx)],1
	jz .noswap
	xchg al,ah
.noswap:
	add al,bl
	add ah,bh

	mov cl,[landscape4(ax,1)]
	and cl,0xf0
	cmp cl,0x50
	jne .nottile

	mov cl,[landscape2+eax]
	cmp [landscape2+ebx],cl
	jne .nottile

	mov cl,[landscape5(ax,1)]
	cmp cl,8
	jae .nottile

	pop ebx
	movzx eax,byte [landscape7+eax]
	ret

.nottile:
	pop ebx
	or eax,byte -1
	ret

// helper function for vars 60..64
// in:	ah: cargo#
//	esi->station
// out: ecx: cargo offset
getstationcargooffset:
	push dword [mostrecentspriteblock]
	movzx eax,ah
	push eax
	call lookuptranslatedcargo
	pop eax
	add esp,4
	cmp al,0xff
	je .notpresent

	testflags newcargos
	jc .newoffset
	movzx ecx,al
	shl ecx,3
	cmp ecx,12*8	// now cf is set if ecx is OK
	cmc
	ret

.newoffset:
	xchg ebx,esi
	call ecxcargooffset
	xchg ebx,esi
	inc cl		//now cl=0 if and only if it was FF (cargo not present)
	sub cl,1	//now cl is back to the old value, but cf is set if it's FF
	ret

.notpresent:
	stc
	ret

// var 60: amount of cargo waiting
global getcargowaiting
getcargowaiting:
	call getstationcargooffset
	jc .returnzero

	movzx eax,word [esi+station.cargos+ecx+stationcargo.amount]
	and ax,[stationcargowaitingmask]	// mask out acceptance data
	ret

.returnzero:
	xor eax,eax
	ret

// var 61: time since cargo was last picked up
global getcargotimesincevisit
getcargotimesincevisit:
	call getstationcargooffset
	jc getcargowaiting.returnzero

	movzx eax,byte [esi+station.cargos+ecx+stationcargo.timesincevisit]
	ret

// var 62: cargo rating (-1 if unrated)
global getcargorating
getcargorating:
	call getstationcargooffset
	jc .returnminusone

	cmp byte [esi+station.cargos+ecx+stationcargo.enroutefrom],-1
	je .returnminusone

	movzx eax,byte [esi+station.cargos+ecx+stationcargo.rating]
	ret

.returnminusone:
	or eax,-1
	ret

// var 63: time since cargo is in transit
global getcargoenroutetime
getcargoenroutetime:
	call getstationcargooffset
	jc getcargowaiting.returnzero

	movzx eax,byte [esi+station.cargos+ecx+stationcargo.enroutetime]
	ret

// var 64: age/speed of last vehicle picking up the cargo
global getcargolastvehdata
getcargolastvehdata:
	call getstationcargooffset
	jc .returndefault

	xor eax,eax
	mov al,[esi+station.cargos+ecx+stationcargo.lastspeed]
	mov ah,[esi+station.cargos+ecx+stationcargo.lastage]
	ret

.returndefault:
	mov eax,0xFF00
	ret

exported getcargoacceptdata
	push dword [mostrecentspriteblock]
	movzx eax,ah
	push eax
	call lookuptranslatedcargo
	pop eax
	add esp,4
	cmp al,0xff
	je getcargowaiting.returnzero

	testflags newcargos
	jc .newformat
	shl eax,3
	cmp eax,12*8
	jae getcargowaiting.returnzero
	movzx eax, byte [esi+station.cargos+eax+stationcargo.amount+1]
	shr eax,4
	ret

.newformat:
	cmp eax,32
	jae getcargowaiting.returnzero
	bt dword [esi+station2ofs+station2.acceptedcargos],eax
	setc al
	shl al,3
	ret

// parametrized variable 67: get land info of nearby tiles

noglobal uvarb getstationslope_orientation

extern getindustilelandslope.got_esi_ebp

exported getstationlandslope
	mov ecx,[curstationtile]

	cmp dword [curcallback],0x149
	jz .gotorientation

	test esi,esi
	jz .error		// calling without structure is allowed for var 149 only

	test byte [landscape5(cx,1)],1
	setnz byte [getstationslope_orientation]
.gotorientation:

	call .docall
	cmp byte [getstationslope_orientation],0
	jz .nomirror
	mov cl,al
	and cl,0101b
	jz .mirrored	// bit 0 and 2 both zero - no swap needed
	cmp cl,0101b
	je .mirrored	// bit 0 and 2 both one - no swap needed
	xor al,0101b	// one of the bits is zero, the other is one - XOR should swap them
.mirrored:
.nomirror:
	ret

.error:
	xor eax,eax
	ret

// getindustilelandslope does a popa at the end, so we can't call
// into the middle of it; we call this helper instead, which ends up
// jumping into the middle of it
.docall:
	pusha
	mov esi,ecx
	cmp byte [getstationslope_orientation],0
	jz .noswap
	rol ah,4
.noswap:
	xor ebp,ebp
	jmp getindustilelandslope.got_esi_ebp

// parametrized variable 68: get station info of nearby tiles
// returns:
// FFFFFFFFh if the selected tile isn't a railway station
// OR
// bits 11..14:	station tile from L5, the last bit modified so
//		1 means perpendicular, 0 means parallel
// bit 10:	does the selected tile belong to the current station?
// bits 8..9:	0 - original TTD station
//		1 - station from the current GRF
//		2 - station from other GRF
// bits 0..7:	setID of station if bits 8..9 is 1, undefined otherwise

exported getotherstationid
	push ebx
	push edx
	push ebp
	sar ax,4
	sar al,4
	mov ebx,[curstationtile]
	test byte [landscape5(bx)],1
	jz .noswap
	xchg al,ah
.noswap:
	add al,bl
	add ah,bh
	mov ebp,eax

	mov cl,[landscape4(bp)]
	and cl,0xf0
	cmp cl,0x50
	jne .nottile

	mov cl,[landscape5(bp)]
	cmp cl,8
	jae .nottile

	xor eax,eax

	// fill bit 10
	mov al,[landscape2+ebp]
	cmp [landscape2+ebx],al
	sete ah
	shl ah,2

	// fill bits 0..7
	movzx ecx,byte [landscape3+ebp*2+1]
	mov al,[stationidgrfmap+ecx*stationid_size+stationid.setid]

	// fill bits 8..9
	test ecx,ecx
	jz .typefound

	mov edx,[mostrecentspriteblock]
	mov edx,[edx+spriteblock.grfid]
	cmp edx,[stationidgrfmap+ecx*stationid_size+stationid.grfid]
	setne dl
	inc dl
	or ah,dl
.typefound:

	// fill bits 11..14
	mov dl,[landscape5(bp)]
	mov cl,[landscape5(bx)]
	and cl,1
	xor dl,cl
	shl dl,3
	or ah,dl

	pop ebp
	pop edx
	pop ebx
	ret

.nottile:
	pop ebp
	pop edx
	pop ebx
	or eax,byte -1
	ret

// parametrized variable 69: get cargo acceptance history
// return value:
// bit 0: set if cargo type was ever accepted
// bit 1: set if cargo was accepted last month
// bit 2: set if cargo was accepted this month
// bit 3: set if cargo was accepted since last periodic processing
// other bits: reserved
exported getstationaccepthistory
	movzx ecx,ah
	push dword [mostrecentspriteblock]
	push ecx
	call lookuptranslatedcargo
	pop ecx
	pop eax
	xor eax,eax

	cmp cl,0xFF
	je .done

	extern stationarray2ptr
	cmp dword [stationarray2ptr],0
	je .done

	push esi
	add esi,[station2ofs_ptr]
	bt [esi+station2.acceptedsinceproc],ecx
	rcl eax,1
	bt [esi+station2.acceptedthismonth],ecx
	rcl eax,1
	bt [esi+station2.acceptedlastmonth],ecx
	rcl eax,1
	bt [esi+station2.everaccepted],ecx
	rcl eax,1
	pop esi

.done:
	ret

#if 0
// variable 41: major cargo waiting
// out:	eax=aaRRTTAA
//	aa age in days (00 if no cargo)
//	RR rating for this cargo (average rating if no cargo)
//	TT cargo type (FE if no cargo ever, FF if no cargo at the moment)
//	AA amount in units of 16 (00 if no cargo)
getmajorcargo:
	push ebx
	xor ebx,ebx
	mov bh,0xff
	xor eax,eax
.nextcargo:
	mov ecx,[esi+eax*stationcargo_size+stationcargo.amount]
	// now ecx = RRxxAAAA
	shr cx,4
	cmp cl,bh
	jbe .notmore
	mov bh,cl
	mov bl,al
.notmore:
	cmp byte [esi+eax*stationcargo_size+stationcargo.enroutefrom],0xff
	je .notrated
	// store sum of ratings and number in upper 16 bits of ecx to get avg
	shr ecx,3
	and ecx,0xff000000
	lea ebx,[ebx+ecx+0x10000]
.notrated:
	inc al
	cmp al,12
	jb .nextcargo
	cmp bh,0xff
	je .nocargo
	movzx ebx,bh
	mov al,[esi+ebx*stationcargo_size+stationcargo.enroutetime]
	mov ah,[esi+ebx*stationcargo_size+stationcargo.rating]
	shl eax,16
	mov ecx,[esi+ebx*stationcargo_size+stationcargo.amount]
	shr cx,4
	mov al,cl
	mov ah,bl
	pop ebx
	ret

.nocargo:
	shld eax,ecx,16		// load ax with upper 16 bits of ecx
	cmp al,0
	je .nocargoever
	mov bl,al
	movzx eax,ah
	div bl
	jmp short .gotrating

.nocargoever:
	mov bh,0xfe
.gotrating:
	mov ah,0
	shl eax,16
	mov ah,bh
	pop ebx
	ret
#endif

// called when initialing a new station structure
// in:	esi->new station struct
// safe:edi
global setupstationstruct
setupstationstruct:
	push eax
	and word [esi+station.flags],0
	mov ax,[currentdate]
	mov [esi+station.datebuilt],ax
	call [randomfn]
	mov [esi+station.random],ax
	pop eax
	ret

// called when creating a new railway station
// in:	esi->station struct
// safe:eax ebp
global setuprailwaystation
setuprailwaystation:
	cmp byte [esi+station.facilities],0
	jne .nowaypoint		// already has other facilities

	movzx eax,byte [curplayer]
	cmp byte [curselclassid+eax],CLASS_WAYP
	jne .nowaypoint

	or byte [esi+station.flags],1<<6

.nowaypoint:
	or byte [esi+station.facilities],1
	ret

// called when a "bad" station in the city's transport zone would decrease ratings
//
// in:	esi->city
//	edi->station
//	 ax=old rating
//	ebx=owner
// out:	 ax=adjusted rating
// safe:?
global badstationintransportzone
badstationintransportzone:
	test byte [edi+station.flags],0x40
	jnz .waypoint
	sub ax,15	// replaced code
.waypoint:
	cmp ax,-1000
	ret


// called to update station windows when a station's cargo or ratings change
//
// in:	bx=station number
// out:	---
// safe:???
global updatestationwindow
updatestationwindow:
	push esi
	movzx esi,bx
	imul esi,station_size
	add esi,[stationarrayptr]
	call updatestationgraphics
	pop esi
	mov al,0x11
	call [invalidatehandle]
	ret

global updatestationgraphics
updatestationgraphics:
	pusha
	movzx eax,word [esi+station.railXY]
	test eax,eax
	jz .notrainstation


	testflags irrstations
	jnc .noirrstations

	call irrgetrailxysouth
	sub dl, al
	sub dh, ah
	add dx, 0x101
	jmp short .notflip

.noirrstations:
	mov dh,[esi+station.platforms]
	call convertplatformsinremoverailstation
	xchg dh, dl
	// now dl = length, dh = tracks
	test byte [landscape5(ax,1)],1	// orientation
	jz .notflip
	xchg dh,dl
.notflip:
	movzx ecx,ah
	movzx eax,al
	shl ecx,4
	shl eax,4

.nexty:
	push edx
	push eax
.nextx:
	push edx
	call [invalidatetile]
	pop edx
	add eax,16
	dec dl
	jnz .nextx

	pop eax
	pop edx
	add ecx,16
	dec dh
	jnz .nexty

.notrainstation:
	popa
	ret


// called when cargo has been added to a station from an industry/town
// in:  ax=amount
//	dl=station number
//	esi->station
//	on stack: cargo type*8
// out:	bx=station number
// safe:???

//WARNING: This code isn't called if newcargos is on, but instead reproduced in patch code
//Anything you modify here must be modified in addcargotostation_2 (newcargo.asm) as well
global cargoinstation
cargoinstation:
	mov ebx,[esp+4]
	pusha

	mov cx, [esi+station.cargos+ebx+stationcargo.amount]

	shr ebx,3
	testflags cargodest
	jnc .nocargodest
	add cx, ax
	test cx, 0xF000
	jnz .nocargodest	//don't add packets if would result in an overflow
	call addcargotostation_cargodesthook
.nocargodest:

	mov [statanim_cargotype],bl
	mov edx,1
	call stationanimtrigger

	xor edx,edx
	bts edx,ebx
	mov al,1
	mov ah,0x80
	mov ebx,esi
	call randomstationtrigger
	popa
	movzx ebx,dl
	jmp updatestationwindow

// trigger only the platform on which the train is active
// in:	esi->vehicle
//	edx=cargo mask for triggers
//	on stack: trigger bits
global stationplatformtrigger
stationplatformtrigger:
	pusha
	cmp byte [esi+veh.class],0x10
	jne .norail

	mov al,[esi+veh.laststation]
	movzx ebx,word [esi+veh.XY]
.withtile:
	mov ah,station_size
	mul ah
	movzx eax,ax
	add eax,[stationarrayptr]
	test byte [eax+station.facilities],1
	jz .norail

	mov [curstationtile],ebx
	mov ebx,eax
	mov esi,eax
	call getplatforminfo
	mov ah, cl
	mov al,[esp+0x24]
	or ah,0x40	// force redraw
	call randomstationtrigger
.norail:
	popa
	ret 4

// same as above, but called with
// in:	ebx=XY of station tile
// 	edx/stack as above
stationplatformtriggerxy:
	pusha
	mov al,[landscape2+ebx]
	jmp stationplatformtrigger.withtile

// called when querying a station tile
// in:	cl=landscape5 value
//	di=tile index
// out:	carry set if railway station tile, then also
//		 ax=text id
//		ecx=textrefstack values
//	carry clear if other station
// safe:bh,si,ebp,others?
global stationquery
stationquery:
	cmp cl,8
	jb .railway
	ret

.railway:
	mov ax,statictext(railstationquery0)
	xor ecx,ecx

	movzx ebp,di
	movzx ebp,byte [landscape3+ebp*2+1]
	movzx ebp,byte [stationidgrfmap+ebp*8+stationid.gameid]
#if 0
	cmp dword [newstationnames+ebp*4],0
	je .nostationname
#endif

	mov ecx,ebp
	mov ch,0xc1
	inc eax

.nostationname:
	movzx ebp,byte [stationclass+ebp]
	cmp dword [newstationclasses+ebp*4],0
	je .nostationclassname

	shl ecx,16
	mov cx,bp
	mov ch,0xc0
	inc eax

.nostationclassname:
	stc
	ret

uvarb buildoverstationflag

// called when trying to clear station tile
// in:	bx=action flags
// out:	zf=1 allow clearing tile
//	zf=0 cf=1 prohibit clearing tile
//	zf=0 cf=0 continue checking
// safe:?
//
global allowbuildoverstation
allowbuildoverstation:
	cmp dh,7
	ja .done

	call isrealhumanplayer
	stc
	jnz .done

	cmp byte [buildoverstationflag],1

.done:
	ret

// action called to create railway station
global createrailwaystation
createrailwaystation:
	mov byte [buildoverstationflag],1
	call $
ovar .oldfn,-4,$,createrailwaystation
	mov byte [buildoverstationflag],0
	ret

// ---- Animation support added by Csaba ----

// Start/stop animation and set the animation stage of a station tile
// (Almost the same as sethouseanimstage, but stores the current frame differently)
// in:	al:	number of new stage where to start
//		or: ff to stop animation
//		or: fe to start wherewer it is currently
//		or: fd to do nothing (for convenience)
//	ah: number of sound effect to generate
//	ebx:	XY of station tile
setstattileanimstage:
	or ah,ah
	jz .nosound

	pusha
	movzx eax,ah
	and al,0x7f
	mov ecx,ebx
	rol bx,4
	ror cx,4
	and bx,0x0ff0
	and cx,0x0ff0
	or esi,byte -1
	call [generatesoundeffect]
	popa

.nosound:
	cmp al,0xfd
	je .animdone

	cmp al,0xff
	jne .dontstop

	pusha
	mov edi,ebx
	mov ebx,3				// Class 14 function 3 - remove animated tile
	mov ebp,[ophandler+0x14*8]
	call [ebp+4]
	popa
	jmp short .animdone

.dontstop:
	cmp al,0xfe
	je .dontset

	mov byte [landscape7+ebx],al

.dontset:
	pusha
	mov edi,ebx
	mov ebx,2				// Class 14 function 2 - add animated tile
	mov ebp,[ophandler+0x14*8]
	call [ebp+4]
	popa

.animdone:
	ret

exported stationanimhandler
#if WINTTDX
	movzx ebx,bx
#endif
	mov al,[landscape5(bx)]

	cmp al,8
	jb .railstation

	cmp al,0x27		// overwritten
	ret

.railstation:
	movzx eax, byte [landscape3+ebx*2+1]
	test eax,eax
	jz near .stop

	mov [curstationtile],ebx

	movzx eax, byte [stationidgrfmap+eax*8+stationid.gameid]

	cmp word [stationanimdata+2*eax],0xFFFF
	je .animdone1

	cmp byte [gamemode],2
	je .animdone1

	movzx esi,byte [landscape2+ebx]
	imul esi,station_size
	add esi,[stationarrayptr]

	mov edx,eax
	movzx edi, word [animcounter]
	mov ebp,1

	test byte [stationcallbackflags+eax],8
	jz .normalspeed

	mov byte [grffeature],4
	mov dword [curcallback],0x142
	call getnewsprite
	mov dword [curcallback],0
	mov cl,al
	jnc .hasspeed

.normalspeed:
	mov cl,[stationanimspeeds+edx]

.hasspeed:
	shl ebp,cl
	dec ebp
	test edi,ebp
	jz .nextframe

.animdone1:
	xor al,al
	stc
	ret

.nextframe:
	test byte [stationcallbackflags+edx],4
	jz .normal
	test byte [stationflags+edx],4
	jz .norandom

	call [randomfn]
	mov [miscgrfvar],eax
.norandom:
	mov eax,edx
	mov byte [grffeature],4
	mov dword [curcallback],0x141
	call getnewsprite
	mov dword [curcallback],0
	mov dword [miscgrfvar],0
	jc .normal

	test ah,ah
	jz .nosound

	pusha
	mov ecx,ebx
	rol bx,4
	ror cx,4
	and bx,0x0ff0
	and cx,0x0ff0
	or esi,byte -1
	call [generatesoundeffect]
	popa

.nosound:
	cmp al,0xff
	je .stop
	cmp al,0xfe
	jne .hasframe

.normal:
	mov al,[landscape7+ebx]
	inc al
	cmp [stationanimdata+2*edx],al
	jb .finished
.hasframe:
	mov [landscape7+ebx],al
	mov esi,ebx
	call redrawtile
	xor al,al
	stc
	ret

.finished:
	cmp byte [stationanimdata+2*edx+1],1
	jne .stop
	xor al,al
	jmp short .hasframe

.stop:
	mov edi,ebx
	mov ebx,3
	mov ebp,[ophandler+0x14*8]
	call [ebp+4]
	xor al,al
	stc
	ret

varb statanim_cargotype, 0xFF

exported stationplatformanimtrigger
	pusha
	cmp byte [esi+veh.class],0x10
	jne .norail

	movzx ebx, word [esi+veh.XY]
	movzx esi, byte [esi+veh.laststation]
	imul esi,station_size
	add esi,[stationarrayptr]

	test byte [esi+station.facilities],1
	jz .norail

	mov ch,1

	testflags irrstations
	jc .irregular

	mov cl,[esi+station.platforms]
	call convertplatformsinecx
	shr ecx, 8
	mov ch,1

	//cl=length, ch=tracks

	test byte [landscape5(bx)],1
	jnz .ydir

	mov bl,[esi+station.XY]
	jmp stationanimtrigger.gotposandsize

.ydir:
	mov bh,[esi+station.XY+1]
	xchg cl,ch
	jmp stationanimtrigger.gotposandsize

.norail:
	popa
	ret

.irregular:
	xchg ebx,esi
	call getirrplatformlength
	xchg ebx,esi
	mov cl,al
	test byte [landscape5(bx)],1
	jz .noflip
	xchg cl,ch
.noflip:
	jmp stationanimtrigger.gotposandsize

// in:	esi-> station
//	edx: trigger bit + extra info for callback
exported stationanimtrigger
	test byte [esi+station.facilities],1
	jnz .hasrailway
	ret

.hasrailway:
	pusha

	movzx ebx,word [esi+station.railXY]

	testflags irrstations
	jc .irregular

	mov cl,[esi+station.platforms]
	call convertplatformsinecx
	xchg cl, ch

	test byte [landscape5(bx)],1
	jz .gotposandsize
	xchg cl,ch
	jmp short .gotposandsize

.irregular:
	mov ebp,edx
	xor edx,edx
	call irrgetrailxysouth
	sub edx,ebx
	lea ecx,[edx+0x0101]
	mov edx,ebp

.gotposandsize:
	mov byte [grffeature],4
	mov dword [curcallback],0x140
	mov [callback_extrainfo],edx
	movzx edx,dl
	call [randomfn]
	mov [miscgrfvar],eax

	movzx edi, byte [statanim_cargotype]

	push ebx
	push ecx

.checktile:
	mov al,[landscape4(bx)]
	and al,0xf0
	cmp al,0x50
	jne .nexttile

	cmp byte [landscape5(bx)],8
	jae .nexttile

	movzx eax, byte [landscape2+ebx]
	imul eax,station_size
	add eax,[stationarrayptr]
	cmp eax,esi
	jne .nexttile

	movzx eax, byte [landscape3+ebx*2+1]
	movzx eax, byte [stationidgrfmap+eax*8+stationid.gameid]
	test eax,eax
	jz .nexttile

	bt [stationanimtriggers+eax*2],edx
	jnc .nexttile

	mov [curstationtile],ebx

	mov ebp,eax

	cmp edi,0xFF
	je .nocargo

	mov eax,[stsetids+eax*stsetid_size+stsetid.act3info]
	mov eax,[eax+action3info.spriteblock]
	mov eax,[eax+spriteblock.cargotransptr]
	mov al,[eax+cargotrans.fromslot+edi]
	mov [callback_extrainfo+1],al

.nocargo:
	call [randomfn]
	mov [miscgrfvar],ax

	mov eax,ebp

	call getnewsprite
	jc .nexttile

	call setstattileanimstage

.nexttile:
	inc ebx
	dec cl
	jnz .checktile

	pop ecx
	pop ebx

	inc bh
	dec ch
	jz .done

	push ebx
	push ecx
	jmp .checktile

.done:
	and dword [curcallback],0
	and dword [miscgrfvar],0
	mov byte [statanim_cargotype],0xFF

	popa
	ret

exported newtrainstatcreated
	call .doanimtrigger
	btr word [esi+station.flags],0	// overwritten
	ret

.doanimtrigger:
	pusha
	xor edx,edx
	xor ecx,ecx
	xchg ecx,[curstationsectionsize]
	mov ebx,[curstationsectionpos]
	cmp word [curstationsectiondir],0x100
	jne .noswap
	xchg ch,cl
.noswap:
	jmp stationanimtrigger.gotposandsize

exported periodicstationupdate
	bt word [esi+station.flags],0	// overwritten
	jnc .trigger
	ret

.trigger:
	mov edx,6
	call stationanimtrigger
	clc
	ret



// Functions dealing with RV on rail station by eis_os

// special functions to handle station properties
//
// in:	eax=special prop-num
//	ebx=offset (stationid)
//	ecx=num-info
//	esi=>data
// out:	esi=>after data
//	carry clear if successful
//	carry set if error, then ax=error message

exported setrailstationrvrouteing
.nexstationid:
	//CALLINT3			// prevent the use of this feature by grfauthors until the feature is complete
	lodsd
	test eax, 0xF0F0F0F0	// prevent the use of the upper 4 bits
	jnz .bad
	mov [canrventerrailstattile+ebx*8], eax
	lodsd
	test eax, 0xF0F0F0F0
	jnz .bad
	mov [canrventerrailstattile+ebx*8+4], eax
	inc ebx
	loop .nexstationid
	clc	// no error
	ret
.bad:
	mov ax, ourtext(invalidsprite)
	stc
	ret

// decide whether to draw station sprite in normal or transparent mode
// in:	ebx: sprite number & flags from layout
//	other regs set up for addsprite or addrelsprite
// out: cf set -> invisible
//	cf clear, zf clear -> normal drawing
//	cf clear, zf set -> transparent
// safe: ebp
decidestationtransparency:
	btr ebx,30
	jc .normal			// bit 30 set - always draw normally
	testmultiflags moretransopts
	jnz .newtrans
	test dword [displayoptions],16	// check "transparent buildings" in display options (test clears CF)
	ret

.transparent:
	cmp eax, eax
	ret

.normal:
	test esp, esp
	ret

.newtrans:
	extern newtransopts
	bt dword [newtransopts],TROPT_STATION
	jnb .normal
	bt dword [newtransopts+transopts.invis],TROPT_STATION
	jnb .transparent
	cmp eax,eax	// sets zf
	stc		// sets cf
	ret

noglobal uvarw rootspritex
noglobal uvarw rootspritey
noglobal uvarb gotnormalsprite	// set to 1 if we've already encountered a normal sprite while drawing this station preview

// Called instead of LandscapeToPixelCoords when drawing a station in the selection window
// The old code assumed that there are no linked sprites in the layout, fix that
// in:	ax: first byte of spritedata (X offset of bounding box/sprite)
//	cx: second byte of spritedata (Y offset of bounding box/sprite)
//	dl: third byte of spritedata (Z offset/80h)
//	ebx->spritedata
// out:	ax: X offset in pixels
//	cx: Y offset in pixels
// safe: ebx,dx,bp
exported getspritecoordsforstationwindow
	cmp dl,0x80
	je .linked
	call $			// call LandscapeToPixelCoords like the old code did
ovar .landscapetopixel,-4,$,getspritecoordsforstationwindow
	mov [rootspritex],ax	// remember the returned values - linked sprite offsets will be relative to these
	mov [rootspritey],cx
	mov byte [gotnormalsprite],1
	ret

.linked:
	cmp byte [gotnormalsprite],0
	je .stackedground
	add ax,[rootspritex]	// this is a linked sprite - just add the coordinates of the root sprite
	add cx,[rootspritey]
	ret

.stackedground:
	// Linked spritedata entries before the first normal one are interpreted as extra land sprites.
	// Normal landscape drawing doesn't support pixel offsets for that, so ignore those here as well
	xor eax,eax
	xor ecx,ecx
	ret

// called to do extra slope check for train stations, from slopebld.asm
// when this is called, we have already weeded out invalid slopes, so if the
// GRF doesn't veto it, we can allow the slope
// in:	ax, cx: X and Y of tile
//	bh: direction (0=X, 1=Y)
//	esi: XY of tile
//	di: slope data
//	ebp-> stack frame of caller with various useful things on stack,
//	see chkrailstationflatland in slopebld.asm for details
// return with zf set if tile is OK
// safe: edx,esi,ebp
exported dostationslopecallback

// check if callback is enabled
	movzx esi,byte [curplayer]
	movzx esi,byte [curselstationid+esi]
	test esi,esi
	jz .gotit
	test byte [stationcallbackflags+esi],0x10
	jnz .docallback
.gotit:
	ret

.docallback:
	mov dx,[ebp+4+10]	// saved dimensions of the station
	shl edx,16

	mov dx,[ebp+4+12]	// saved Y of the north corner
	mov si,[ebp+4+14]	// saved X of the north corner
	shl dx,4
	shr si,4
	or dx,si		// now dx=XY of north corner

	movzx esi,word [ebp+4]	// saved XY of currently checked tile
	mov [curstationtile],esi
	sub si,dx
	mov dx,si		// now dx=XY difference between north corner and current tile

	test bh,bh
	jz .noswap
	xchg dh,dl
.noswap:
// now dl is distance along the platform, dh is platform number
// the high 16 bits are still the station dimensions
	mov [callback_extrainfo],edx

	mov [getstationslope_orientation],bh	// for var 67 to work
	push ebx

	mov edx,edi
	test bh,bh
// create mirrored slope data (with bits 0 and 2 swapped) for stations with Y orientation
	jz .nomirror
	mov dh,dl
	and dh,0101b
	jz .mirrored	// bit 0 and 2 both zero - no swap needed
	cmp dh,0101b
	je .mirrored	// bit 0 and 2 both one - no swap needed
	xor dl,0101b	// one of the bits is zero, the other is one - XOR should swap them
.mirrored:
.nomirror:
// put the usual (not mirrored) slope data into dl bits 4..7
	mov ebx,edi
	shl bl,4
	or dl,bl
// put slope data in dl into miscgrfvar
	mov [miscgrfvar],dl

	mov ebp,eax			// save X coord
	movzx eax,byte [curplayer]
	movzx eax,byte [curselstationid+eax]	// put selected stationID to eax
	xor esi,esi			// no station struc available
	mov byte [grffeature],4
	mov dword [curcallback],0x149
	call getnewsprite
	mov dword [curcallback],0
	mov byte [miscgrfvar],0
	pop ebx
	xchg eax,ebp		// restore X coord and put callback result to a safe place
	jc .error

	test ebp,ebp		// callback allows slope if result is zero
	ret

.error:
	cmp eax,eax		// if the callback fails, we allow the slope - set zf
	ret

// In:	edx: bitmask of already-used station names
//Out:	edx modified to disable Mines and Oilfield, if appropriate
//	flags set as for overwritten cmp.
exported disableindustnames
	// prop 24 set counts as success: -- use jmp short FindIdustTileNearStation.done
	mov word [FindIdustTileNearStation.zerojmp], (FindIdustTileNearStation.done - (FindIdustTileNearStation.zerojmp+2)) << 8 | 0xEB
	call FindIdustTileNearStation
	jc .done			// This is only testing for a nearby industry w/ prop 24
	// At least one industry w/ prop 24 nearby; disable default industry-related texts
	or dh, (1<<0Fh /*Mines*/ | 1<<0Eh /*Oilfield*/ ) >> 8
.done:
	cmp byte [0], 4				// overwritten
ovar preferredStationNameTypePtr, -5
	ret


%push getstationname
%define %$flags ebx-4
%define %$TextID ebx-8

// Look for a newgrf defined station name
// In:	esi->station
//	edi->town
//	cx: XY location
//	edx: mask of already-used default station names
//	ebp: TextID TTD chose, minus 300F.	(Construction would have failed if {bt edx, ebp} sets carry.)
// Locals:  Uses ebx(!) as base pointer
//	ebx-4: Flags; cf is bit 0
//	ebx-8: Most recent successful TID, if pushed cf ((ebx-4):0) is clear
// Out:	bp: TID on success.
//	Return to appropriate location.
// Safe: eax,ebx,ecx,edx,ebp
exported getnewstationname
// General initialization for both called-from-success and called-from-error
	// Ignore prop 24s set to 0: -- use jz short FindIdustTileNearStation.loop
	mov word [FindIdustTileNearStation.zerojmp], (FindIdustTileNearStation.loop - (FindIdustTileNearStation.zerojmp+2)) << 8 | 0x74
	mov ebx,esp
	cmp ebp,20h
	jne .useebp
	bt edx,0Ah
	jmp short .pushf
.useebp:
	bt edx,ebp
.pushf:
	pushf
	add bp, 300Fh		// overwritten
	push ebp

	testflags newindustries
	jnc .nonewindu

	call FindIdustTileNearStation
	jc .nonewindu
	and byte [%$flags], ~1	// clc
	mov [%$TextID], ebp

.nonewindu:
#if 0
 	testflags newstations
	jnc .nonewstats
				// Station callback/prop and station-generic callback should go here
.nonewstats:
#endif
	pop ebp
	popf
	jnc .gottext
	sub dword [ebx], 36h		// Return to fail loc
.gottext:
	ret

%pop

// In:	esi->station
//Out:	ebp: new TextID to use
//	cf if no unused TextID found
// Trashes eax
FindIdustTileNearStation:
	push edx
	push esi
	movzx edx, cx
	mov esi, 0
ovar ObjectSearchOffsTable
	xor eax,eax
.loop:
	lodsw
	or eax, eax
	stc
	jz .done
	add dx, ax
	mov al, [landscape4(dx,1)]
	and al, 0F0h
	cmp al, 80h
	jne .loop
	movzx eax, byte [landscape2+edx]
	imul eax, industry_size
	add eax, [industryarrayptr]
	movzx eax, byte [eax+industry.type]
	extern industrystationname
	movzx ebp, word [industrystationname+eax*2]
	cmp bp, byte -1
	je .loop
	or ebp, ebp
	jz short .loop
ovar .zerojmp, -2, $, FindIdustTileNearStation
	xchg [esp],esi
	call checknewgrfname
	xchg [esp],esi
	jc .loop
.done:
	pop esi
	pop edx
	ret


// In:	esi->station
//	bp: TextID to check
// Out:	cf if TextID is already used.
checknewgrfname:
	pusha
	mov edi, [esi+station.townptr]
	mov ebx, stationarray
	xor edx, edx
	xor ecx, ecx
	mov cl, 250
.loop:
	cmp ebx, esi
	je .next
	cmp word [ebx+station.XY], 0
	je .next
	cmp edi, [ebx+station.townptr]
	jne .next
	cmp bp, [ebx+station.name]
	je .fail
.next:
	add ebx, 8Eh
	loop .loop

	popa
	// The add cleared cf
	ret
.fail:
	popa
	stc
	ret

// This var will be set to 1 by displstationgroundsprite in slopebld.asm if the currently drawn station tile is on sloped land
// We need this to be able to render extra ground tiles correctly (using addrelsprite instead of addgroundsprite)
// If buildonslopes is off, this will stay zero forever
uvarb drawstation_slopedland

// We jump here from Class5DrawLand (0014CB90 in the DOS version, specifically),
// to draw all station sprites except the ground sprites.
// We change almost all of the code in some way, so taking it over completely is easier to follow.
// in:	AX, CX, DL: landscape X, Y, Z coordinates of the tile
//	EBP->station tile sprite layout
// safe: EBX, ESI, EDI, EBP
exported drawstationsprites
// The first loop is for partial support of an OTTD feature "stacked ground tiles"
// If you specify "linked" entries before the first normal one, they are interpreted
// as extra ground sprites to draw. The loop keeps running while it finds such special
// entries, then either returns or jumps into the second loop directly.
.nextground:
	push ax
	push cx
	push dx
	push ebp
	cmp byte [ebp], 0x80
	je .near_ret
	cmp byte [ebp+2], 0x80
	jne .normal	// normal bounding box -- jump into the normal loop
	
	// pixel offsets are not supported, so ignore offsets 0 and 1
	mov ebx, [ebp+6]
	xor ebx, 0x80000000		// reuse groundsprite selector code, except that bit 31 is inverted
	call getstationtracktrl
	test ebx,0x7FFF0000
	jnz .nogroundcolor		// there is a recolor sprite specified, don't ruin it
	or ebx, [dword 0]
ovar class5drawlandcolormap1,-4
.nogroundcolor:
extern addgroundsprite
	cmp byte [drawstation_slopedland],0
	jne .slopedground
	call [addgroundsprite]
	jmp short .thisgrounddone
.slopedground:
	mov ax,31
	mov cx,1
	call [addrelsprite]
.thisgrounddone:
	pop ebp
	pop dx
	pop cx
	pop ax
	add ebp, 10
	jmp .nextground

.near_ret:
	pop ebp
	pop dx
	pop cx
	pop ax
	ret

// The second loop, drawing normal and linked sprites - standard TTD functionality with Patch enhancements
// WARNING: program flow isn't linear here! The logical end of the loop is moved in front of it to avoid some jumps
// The loop is entered at .normal (from the loop above) and does a ret when it's out of things to do
.nextitem_pop:
	pop ebp
	pop dx
	pop cx
	pop ax
	add ebp, 10
	cmp byte [ebp], 0x80
	jne .keepgoing
	ret
	
.keepgoing:
	push ax
	push cx
	push dx
	push ebp
	cmp byte [ebp+2], 0x80
	je .linked

// Sprite establishes a new bounding box
.normal:
	movsx bx, byte [ebp]
	add ax, bx
	movsx bx, byte [ebp+1]
	add cx, bx
	add dl, [ebp+2]
	movsx di, byte [ebp+3]
	movsx si, byte [ebp+4]
	mov dh, [ebp+5]
	mov ebx, [ebp+6]
	mov ebp, [addsprite]
	jmp .gotfunc

.linked:
	movsx ax, byte [ebp]
	movsx cx, byte [ebp+1]
	mov ebx, [ebp+6]
	mov ebp, [addrelsprite]
	
// here EBX=sprite to draw (not translated); EBP->function to call for sprite drawing
// the rest of the registers are set up for whatever is needed by the draw function, so nothing is safe
.gotfunc:
	call getstationspritetrl
	call decidestationtransparency
	jc .nextitem_pop
	jz .transparent

	test bx,0x8000		// overwritten
	jz .nocolor
	test ebx,0x7FFF0000
	jnz .nocolor		// there is a recolor sprite specified, don't ruin it
	or ebx, [dword 0]
ovar class5drawlandcolormap2,-4
.nocolor:
	call ebp
	jmp .nextitem_pop

.transparent:
	and ebx, 0x3fff
	or ebx, 0x3224000
	call ebp
	jmp .nextitem_pop
