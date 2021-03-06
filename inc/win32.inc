
#if WINTTDX

#ifndef __no_extern_vars__
extern kernel32hnd,heapstart
#endif

// DLL imports are the same in all versions
MessageBoxA		equ 0x4234a0
ExitProcess		equ 0x42344c
GetModuleHandleA	equ 0x423384
GetProcAddress		equ 0x4233c8
LoadLibrary		equ 0x4233A0
GetSystemInfo		equ 0x4233e4
GetTickCount		equ 0x4233e8
PeekMessage		equ 0x423480
midiOutGetVolume	equ 0x423538
midiOutSetVolume	equ 0x42353c
mciSendString		equ 0x423540
DirectPlayEnumerate	equ 0x423314
DirectPlayCreate	equ 0x423318
VirtualFree			equ 0x423414
VirtualAlloc		equ 0x423424
CreateFile		equ 0x4233b8
WriteFile		equ 0x4233c0
CloseHandle		equ 0x4233bc
GetLastError		equ 0x423448
CreateWindowEx		equ 0x4234c8
SetCursorPos		equ 0x4234b4
ClientToScreen		equ 0x4234b0
FindWindowA		equ 0x423494	// This is a WinApi call, do not confuse with FindWindow of the TTD GUI
SendMessageA		equ 0x423514
SetDlgItemTextA		equ 0x423508
GetCommandLine		equ 0x423438
LoadLibraryA		equ 0x4233A0
FreeLibrary		equ 0x423380
RegCloseKey		equ 0x423304
RegQueryValueExA	equ 0x423308
RegOpenKeyA		equ 0x42330C
MultiByteToWideChar	equ 0x423428
WideCharToMultiByte	equ 0x423430

// some constant addresses for enhancemultiplayer

DPlayInterface equ 0x420254	// D: pointer to an IDirectPlay interface
RemotePlayerID equ 0x4198c8	// D: DPlay ID of the remote player (target of outgoing packets)
LocalPlayerID equ 0x4198c4	// D: DPlay ID of the local player

// some constant addresses for the ttdwin wrapper c runtime
// Be sure to use c calling convention (cdecl).
c_strcat equ 0x40fe1c
c_strcpy equ 0x40fe20
c_sprintf equ 0x1116D
c_strcmp equ 0x4111dc
c_strlen equ 0x4112b4
c_strncpy equ 0x414634
c_strcmpi equ 0x41797c

c_malloc equ 0x411628
c_calloc equ 0x4115e0
c_free equ 0x41155e

c_memset equ 0x41150c
c_memcpy equ 0x415684

// used for GetSystemInfo API call
struc SYSTEM_INFO
	// union
	.dwOemID:
	.wProcessorArchitecture: resw 1
	.wReserved: resw 1
	// end union
	.dwPageSize resd 1
	.lpMinimumApplicationAddress: resd 1
	.lpMaximumApplicationAddress: resd 1
	.dwActiveProcessorMaskPtr: resd 1
	.dwNumberOfProcessors: resd 1
	.dwProcessorType: resd 1
	.dwAllocationGranularity: resd 1
	.wProcessorLevel: resw 1
	.wProcessorRevision: resw 1
endstruc
#endif

