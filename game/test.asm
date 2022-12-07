.386
.model flat, stdcall
; .stack 4096
option casemap:none

include		windows.inc
include		gdi32.inc
include		masm32.inc
include		kernel32.inc
include		user32.inc
include		winmm.inc

includelib	gdi32.lib
includelib  msvcrt.lib
includelib	winmm.lib
includelib	user32.lib
includelib	kernel32.lib
 
printf PROTO C:vararg
.const
 
 
.data  
ITEAM struct	
	hbp dd ? 
	pos_x dd ?
	pos_y dd ? 
	size_w dd ? 
	size_h dd ?
	flag dd ? 
ITEAM ends 

hInstance dd ? 
hWinMain  dd ? 
hBrush dd ? 
startTime dd ? 
board_max_pos_x dd ?
szClassName	db	'MyClass',0
szCaptionMain	db	'good game',0
scHello db 'Hello word', 0ah, 0
szDebug byte 'Paint_flag = %d', 0ah, 0
; 资源文件
IDB_BITMAP1 equ 101
IDR_MENU1 equ 108
IDR_RECT equ 109


; 窗口相关
iteams ITEAM 100 dup(<0,0,0,0,0,0>);待加载
iteams_count dd 0  ; 加载位图数量 

;记录窗口的大小，结构体内容为 left，top, right,bottom（四角的值）
stRect RECT <0,0,0,0>
;页面跳转标志 0：菜单 1：
;游戏界面，2：设置界面，3：帮助界面 4
Paint_flag dd 0
PAUSETIME dd 25 ; 刷新时间

level_flag dd 0 ; 游戏难度 


.code
;存储要刷新的 object, 保存句柄、位置、大小、以及标志位
store proc uses eax edi ecx hbp, x, y, w, h, flag
	mov eax, iteams_count 
	mov edi, offset iteams 
	mov ecx, TYPE ITEAM
	mul ecx 
	add edi, eax
	mov eax, hbp 
	mov (ITEAM PTR [edi]).hbp, eax
	mov eax, x 
	mov (ITEAM PTR [edi]).pos_x, eax
	mov eax, y
	mov (ITEAM PTR [edi]).pos_y, eax 
	mov eax, w
	mov (ITEAM PTR [edi]).size_w, eax 
	mov eax, h
	mov (ITEAM PTR [edi]).size_h, eax 
	mov eax, flag
	mov (ITEAM PTR [edi]).flag, eax 
	mov eax, iteams_count
	inc eax
	mov iteams_count, eax
	ret 

store endp 

displayBm proc uses ebx edi esi eax hwnd, hDc, hBitMap, bmX, bmY, w, h
	invoke store, hBitMap, bmX, bmY, w, h, SRCCOPY
	ret 
displayBm endp 

;菜单按钮的图片要与输出的位置做或运算，才能正确输出
displayBmOR proc uses ebx edi esi eax hWnd,hDc,hBitMap, bmX, bmY, w, h;w=width,h=height，可指定bitmap的位置和大小
		invoke store,hBitMap, bmX, bmY, w, h, SRCPAINT;
		ret
displayBmOR endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;在指定位置输出mark
displayMark proc uses ebx edi esi eax hWnd,hDc,hBitMap, bmX, bmY, w, h;w=width,h=height，可指定bitmap的位置和大小
		invoke store,hBitMap, bmX, bmY, w, h, SRCAND
		ret
displayMark endp

;双缓冲刷新窗口
display proc uses eax ecx hdc
	local	@bminfo :BITMAP
	local	@mdc:DWORD;
	local	@bmp:DWORD;
	local	@maphdc:DWORD

	;创建缓冲区,mdc->hdc
	invoke CreateCompatibleDC,hdc
	mov @mdc,eax

	;创建缓冲区,主要用来存放单张贴图，n*maphdc->mdc
	invoke CreateCompatibleDC,@mdc
	mov @maphdc,eax

	;创建空白贴图，主要为了初始化mdc大小
	invoke CreateCompatibleBitmap,hdc,stRect.right,stRect.bottom
	mov @bmp,eax
	invoke  SelectObject,@mdc,@bmp

	;使得可调整大小
	invoke SetStretchBltMode,hdc,HALFTONE
	invoke SetStretchBltMode,@mdc,HALFTONE
	mov ecx,0
	mov edi ,offset iteams

	;该循环是将所有位图加载进mdc
L1:	
	push ecx
	invoke GetObject,(ITEAM PTR [edi]).hbp,type @bminfo,addr @bminfo
	invoke SelectObject,@maphdc,(ITEAM PTR [edi]).hbp
;		invoke BitBlt,@mdc,(ITEAM PTR [edi]).pos_x,(ITEAM PTR [edi]).pos_y, stRect.right,stRect.bottom, @mdc, 0, 0, (ITEAM PTR [edi]).flag
	invoke  StretchBlt,@mdc,(ITEAM PTR [edi]).pos_x,(ITEAM PTR [edi]).pos_y,(ITEAM PTR [edi]).size_w,(ITEAM PTR [edi]).size_h,@maphdc,0,0,@bminfo.bmWidth,@bminfo.bmHeight,(ITEAM PTR [edi]).flag
	invoke DeleteObject,(ITEAM PTR [edi]).hbp
	pop ecx
	add edi, TYPE ITEAM
	inc ecx
	mov eax,iteams_count
	cmp ecx,eax
	jl L1

	;mdc->hdc一次全部复制过去
	invoke BitBlt,hdc, 0, 0, stRect.right,stRect.bottom, @mdc, 0, 0, SRCCOPY;
	jmp R

R:
	mov eax,0
	mov iteams_count,eax
	invoke DeleteDC,@maphdc
	invoke DeleteDC,@mdc
	ret
display endp

; 开始菜单， 背景 start help 
paint0 proc uses ebx edi esi hWnd 
	local @hDc
	local @stPs: PAINTSTRUCT
	local @hBitMap, @hBmpMark 
	local @posX:DWORD
	local @posY:DWORD 
	invoke BeginPaint, hWnd, addr @stPs 
	mov @hDc, eax 

	;backgournd imge 
	invoke LoadBitmap, hInstance, IDB_BITMAP1 
	mov @hBitMap, eax 
	invoke displayBm, hWnd, @hDc, @hBitMap, 0, 0, stRect.right, stRect.bottom
	
	; PLAY 按钮 
	invoke LoadBitmap, hInstance, IDR_MENU1
	mov @hBitMap, eax
	invoke displayBmOR	, hWnd, @hDc, @hBitMap, 320, 180, 120, 40 
	
	; 显示 
	invoke	display, @hDc
	invoke EndPaint, hWnd,addr @stPs

	invoke DeleteDC, @hDc
	invoke DeleteObject, @hBitMap 
	ret 
paint0 endp 


;paint2_游戏界面
paint1 proc uses ebx edi esi hWnd
		local	@hDc
		local	@stPs:PAINTSTRUCT
		local	@hBitMap
		local  @posX:DWORD
		local @posY:DWORD
		invoke	BeginPaint,hWnd,addr @stPs
		mov	@hDc,eax

		;backgournd imge 
		invoke LoadBitmap, hInstance, IDB_BITMAP1 
		mov @hBitMap, eax 
		invoke displayBm, hWnd, @hDc, @hBitMap, 0, 0, stRect.right, stRect.bottom
	
		; 加载矩形
		invoke LoadBitmap, hInstance, IDR_RECT 
		mov @hBitMap, eax 
		invoke displayBmOR, hWnd, @hDc, @hBitMap, 320, 180, 200, 30
		

		invoke display,@hDc
		invoke	EndPaint,hWnd,addr @stPs
		

		invoke DeleteDC,@hDc
		invoke DeleteObject,@hBitMap
		ret
paint1 endp


;##### 窗口过程
_ProcWinMain proc	uses ebx edi esi hWnd, uMsg, wParam,lParam
	local @hDc
	local @stPs:PAINTSTRUCT
	local @hBitMap
	local @posX: DWORD
	local @posY: DWORD
	
	; uMsg 消息 
	mov eax, uMsg 
	.if eax == WM_KEYDOWN ; 非系统键 除ALT以外
		mov eax, wParam
		; 调用移动函数
		; invoke MovePlay, eax 
	.endif 
; -----------------------------------------
	.if eax == WM_PAINT ; 发出绘制程序窗口请求
		mov eax, Paint_flag
		.if eax == 0 ; 菜单
			invoke paint0, hWnd
		.elseif eax == 1 ; 游戏界面
			invoke paint1, hWnd	
		.elseif	eax == 2 ; 设置界面
		
		.elseif eax == 3 ; 帮助界面 

		.elseif eax == 4 ; 分数 
		
		.endif 
; -----------------------------------------------
	.elseif eax == WM_TIMER ; 计时器过期
		.if Paint_flag == 1 ; 游戏界面
			; invoke generateBoareds 
			; invoke generatePlayer 
			; invoke InvalidateRect, hwnd, NULL, FALSE
		.endif 
; -------------------------------------------
	.elseif eax == WM_CREATE ; 创建 
		invoke GetTickCount
		mov startTime, eax 
		invoke GetClientRect, hWnd, addr stRect 
		mov eax,stRect.right
		sub eax,100
		mov board_max_pos_x,eax
		mov eax,WS_VISIBLE
		or eax, WS_CHILD
		or eax,BS_PUSHBUTTON

;-------------------------------------------------
	.elseif eax == WM_LBUTTONDOWN ; 按下左键 
		mov eax, lParam 
		and eax, 0FFFFH
		mov @posX, eax
		mov eax, lParam
		shr eax, 16
		mov @posY, eax
		mov eax, @posX
		.if Paint_flag == 0 ; 主菜单
			mov Paint_flag, 1
			invoke InvalidateRect, hWnd, addr stRect, TRUE
		.endif 
;---------------------------------------------------
	.if Paint_flag == 1

	.endif
; ----------------------------------------------------
	.if Paint_flag == 2 ; 游戏界面
		; invoke printf, offset szHello 
	.endif 
; --------------------------------------------------
	.if Paint_flag == 4
		.if eax < 460
			.if eax > 340
				mov eax, @posY
				.if eax < 490 
				.if eax > 450
					mov Paint_flag, 0
					invoke InvalidateRect, hWnd,addr stRect, TRUE
				.endif 
			.endif 
		.endif 
	.endif 
	.endif 

; -----------------------------------------------
	.elseif eax == WM_CLOSE
		invoke DestroyWindow, hWinMain
		invoke PostQuitMessage, NULL 
;--------------------------------------------------
	.else ; 默认情况 
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
		ret 
	.endif 
S1: xor eax, eax
	ret 
_ProcWinMain endp 


main proc	
	local @stWndClass: WNDCLASSEX
	local @stMsg: MSG
	invoke	GetModuleHandle, NULL 
	mov hInstance, eax 
	invoke RtlZeroMemory, addr @stWndClass, sizeof @stWndClass 
	
	; 注册窗口类
	invoke LoadCursor, 0, IDC_ARROW 
	mov @stWndClass.hCursor, eax 
	push hInstance
	pop @stWndClass.hInstance
	mov @stWndClass.cbSize, sizeof WNDCLASSEX
	mov @stWndClass.style, CS_HREDRAW or CS_VREDRAW
	mov @stWndClass.lpfnWndProc, offset _ProcWinMain
	mov @stWndClass.hbrBackground, COLOR_WINDOW + 1
	mov @stWndClass.lpszClassName, offset szClassName
	invoke RegisterClassEx, addr @stWndClass 

	; 建立并显示窗口
	invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset szClassName,\
				offset szCaptionMain,WS_OVERLAPPEDWINDOW,\
				100, 100, 800, 600,\
				NULL, NULL, hInstance, NULL 
	mov hWinMain, eax
	invoke ShowWindow, hWinMain, SW_SHOWNORMAL
	invoke UpdateWindow, hWinMain 

	; 消息循环 
	.while TRUE
		invoke GetMessage, addr @stMsg, NULL, 0, 0
		.break .if eax == 0
		invoke TranslateMessage, addr @stMsg ; 转化键盘消息 
		invoke DispatchMessage, addr @stMsg ; 消息传递给窗口函数
	.endw 
	ret 

main endp 
start: 
	call main 
	invoke	ExitProcess,NULL
end start
