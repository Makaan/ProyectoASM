%include "convertir.asm"
%include "itoa.asm"
%include "caracter_hexa.asm"
%include "caracter_imprimible.asm"
%include "caracter_contador.asm"


%define hex_offset 8
%define char_offset 58
%define linea_max 16

section .data

  ayuda db "Ayuda"
  ayudal equ $ - ayuda
  linea db "000000  hh hh hh hh hh hh hh hh hh hh hh hh hh hh hh hh  |................|"
  lineal equ $ - linea
  buffer0s db "000000"			;Buffer para escribir la ultima vez la cantidad de elementos leidos
  buffer0sl equ $ - buffer0s

  char_max dd 0				;cantidad de caracteres leidos del archivo
  contador dd 0 			;contador de lineas
  hex_pos dd hex_offset			;offset a la posicion de la linea para insertar la representacion hexadecim
  char_pos dd char_offset		;offset a la posicion de la linea donde insertar el char


  salto db 10				;"\n"
  espacio db 0x20			;" "
  barra db 7ch				;"|"
  resto dd 0				;Diferencia entre el contador y la cantidad de lineas


section .bss

  buffer: resb 1048576		;Buffer para leer de archivo
  buf: resb 32

section .text

global _start

imprimir_salto:

; imprimo un salto de linea por pantalla
mov EAX,4
mov EBX,1
mov ECX,salto
mov EDX,1
int 80h
ret

_start:

;Miro la cantidad de parametros

pop EAX				;saco la cantidad de parametros
cmp EAX, 2			;argc == 2?
jne salir_error			;si no es 2 salgo con error


;Miro los argumentos

pop EAX				;Descarto el nombre del programa
pop EAX				;Guardo el puntero al segundo parametro
mov EBX,EAX			;Hago una copia del puntero


;Compruebo que el segundo parametro sea "-h"
cmp BYTE [EAX], 2Dh		;Comparo el primer caracter con "-"
jne abrir_archivo		;Si no es "-" procedo a abrir el archivo
inc EAX				;incremento el puntero
cmp BYTE [EAX], 68h		;Comparo el segundo caracter con "h"
jne salir_error			;Si no es "h", procedo a abrir el archivo
inc EAX				;Incremento el puntero
cmp BYTE [EAX], 0h		;Comparo con el caracter nulo
jne salir_error			;Si no es caracter nulo salgo con error
jmp imprimir_ayuda		;Si el argv es "-h" imprimo la ayuda

abrir_archivo:

;Abro el archivo que tiene el texto a imprimir, la ruta al archivo se encuentra en EBX
 mov EAX,5			;Pongo el numero de llamada al sistema para abrir el archivo
 mov ECX,0
 mov EDX,0			;Voy a abrir el archivo en solo lectura
 int 80h
push EAX

add EAX,2
cmp EAX, 0 			;Si hubo error el descriptor del archivo sera -1 y salgo con error 2
je salir_error_archivo

push EAX			;Guardo el descriptor del archivo para cerrarlo despues

call imprimir_salto
pop EAX
mov EBX,EAX			;Pongo el descriptor del archivo en EBX
mov EAX,3			;LLamada al sistema para leer
mov ECX,buffer			;Buffer donde va a quedar el archivo
mov EDX,1048576			;Tamaño maximo del buffer
int 80h
				;Sumo uno a la cantidad de caracteres para leer el ultimo
mov [char_max],EAX		;Guardo la cantidad de caracteres leidos

leer_linea:

;Cargo el caracter del archivo
mov EBX,buffer			;Muevo la direccion inicial del buffer
add EBX,[contador]		;Le sumo el contador donde tengo que char leer
mov CL,[EBX]			;Copio el caracter almacenado en la posicion buffer+contador

push ECX			;Guardo el caracter

;Escribo en la posicion correspondiente de la linea el caracter que leo del buffer
mov EAX,linea			;Muevo la direccion inicial de la linea
add EAX,[char_pos]		;Le summo el offset
call caracter_imprimible	;Convierte el caracter leido en un caracter imprimible
mov [EAX],CL			;Copio el caracter que lei en linea+char_pos

pop ECX				;Saco el caracter que lei de la pila

mov EAX,linea			;Muevo la direccion inicial de la linea
add EAX,[hex_pos]		;Le sumo el offset
call caracter_hexa		;Convierto el caracter en hexadecimal
mov [EAX],CX			;Lo escribo en la linea


inc DWORD [char_pos]		;Incremento la posicion donde escribir caracteres en la linea
add [hex_pos],DWORD 3		;Incremento la posicion donde escribir el hexa en la linea

;Incremento el contador, si es igual a la cantidad de caracteres que tiene el archivo dejo de leer
inc DWORD [contador]		;incremento el contador
mov EAX,[contador]		;lo muevo a EAX para comparar
cmp [char_max],EAX		;Si es igual que la cantidad de caracteres leidos
je fin_archivo			;salto a fin_archivo

;Veo si el contador es multiplo de 16, para cambiar de linea
mov EAX,[contador]		;Muevo el contador al registro EAX como dividendo
mov EBX,linea_max		;Muevo un 16 como divisor
mov EDX,0			;Reseteo EDX con 0
idiv EBX			;Uso division entera
cmp EDX,0			;Si el resto es 0 salto a resetear la linea para leer una nueva
je reset

jmp leer_linea			;Vuelvo a leer un caracter

reset:

;Imprimo la linea por pantalla
mov EAX,4
mov EBX,1
mov ECX,linea
mov EDX,lineal
int 80h

;Reseteo las posiciones donde voy a escribir los caracteres
mov [char_pos],DWORD char_offset		;char_pos=57
mov [hex_pos],DWORD hex_offset			;hex_pos=8



mov EAX,[contador]				;Cargo el contador para imprimir la cantidad actual en la linea
mov EBX,linea
call caracter_contador				;Llamo a la funcion que me escribe el contador en la linea

call imprimir_salto

jmp leer_linea					;Vuelvo a imprimir una linea

fin_archivo:

;Si no hay nada mas para imprimir salgo a imprimir el contador
mov EAX,[contador]		;Muevo el contador
mov EDX,0			;Reseteo EDX en 0
mov EBX,linea_max		;Muevo a EBX 16
idiv EBX			;Divido contador/16
cmp EDX,0			;Comparo el resto con 0
je imprimir_contador		;Si es 0 no hay nada mas para copiar

;Guardo el resto
sub EBX,EDX			;16-resto
mov [resto], EBX		;Guardo el resto para saber cuantos caracteres tengo que reemplazar

;Agrego una sola vez una barra vertical al final de los caracteres
mov EAX,linea			;"|"
add EAX,[char_pos]
mov BL,BYTE [barra]
mov [EAX], BL
inc BYTE [char_pos]

reemplazar:
;Reemplazo todos los caracteres restantes con espacios

  ;Reemplazo el caracter en la linea por un espacio
  mov EAX,linea
  add EAX,[char_pos]
  mov BL,[espacio]
  mov [EAX],BL
  inc BYTE [char_pos]

  ;Reemplazo los dos hexadecimales por dos espacios
  mov EAX,linea
  add EAX,[hex_pos]
  mov BL,[espacio]
  mov BH,[espacio]
  mov [EAX],BX
  add BYTE [hex_pos],3

  dec BYTE [resto]
  cmp [resto], WORD 0
  je imprimir_faltante


  jmp reemplazar

imprimir_faltante:
;Imprimo la linea que falta
mov EAX,4
mov EBX,1
mov ECX,linea
mov EDX,lineal
int 80h

call imprimir_salto


imprimir_contador:

mov EAX,[contador]
mov EBX,buffer0s
call caracter_contador

mov EAX,4
mov EBX,1
mov ECX,buffer0s
mov EDX,buffer0sl
int 80h

call imprimir_salto

;Cierro el archivo
pop EBX
mov EAX,6
int 80h

;salgo correctamente
mov EAX,1
mov EBX,0
int 80h





imprimir_ayuda:

;Imprimo el texto de ayuda
mov EAX,4
mov EBX,1
mov ECX,ayuda
mov EDX,ayudal
int 80h

call imprimir_salto		;Imprimo un salto de linea

; Salgo sin error
mov EAX,1
mov EBX,0
int 80h

salir_error:

;Salgo con error 1
mov EAX,1
mov EBX,1
int 80h

salir_error_archivo:

;Salgo con error 2
mov EAX,1
mov EBX,2
int 80h
