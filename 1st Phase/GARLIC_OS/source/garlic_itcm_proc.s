@;==============================================================================
@;
@;	"garlic_itcm_proc.s":	c�digo de las funciones de control de procesos (1.0)
@;						(ver "garlic_system.h" para descripci�n de funciones)
@;
@;==============================================================================

.section .itcm,"ax",%progbits

	.arm
	.align 2
	
	.global _gp_WaitForVBlank
	@; rutina para pausar el procesador mientras no se produzca una interrupci�n
	@; de retrazado vertical (VBL); es un sustituto de la "swi #5", que evita
	@; la necesidad de cambiar a modo supervisor en los procesos GARLIC
_gp_WaitForVBlank:
	push {r0-r1, lr}
	ldr r0, =__irq_flags
.Lwait_espera:
	mcr p15, 0, lr, c7, c0, 4	@; HALT (suspender hasta nueva interrupci�n)
	ldr r1, [r0]			@; R1 = [__irq_flags]
	tst r1, #1				@; comprobar flag IRQ_VBL
	beq .Lwait_espera		@; repetir bucle mientras no exista IRQ_VBL
	bic r1, #1
	str r1, [r0]			@; poner a cero el flag IRQ_VBL
	pop {r0-r1, pc}


	.global _gp_IntrMain
	@; Manejador principal de interrupciones del sistema Garlic
_gp_IntrMain:
	mov	r12, #0x4000000
	add	r12, r12, #0x208	@; R12 = base registros de control de interrupciones	
	ldr	r2, [r12, #0x08]	@; R2 = REG_IE (m�scara de bits con int. permitidas)
	ldr	r1, [r12, #0x0C]	@; R1 = REG_IF (m�scara de bits con int. activas)
	and r1, r1, r2			@; filtrar int. activas con int. permitidas
	ldr	r2, =irqTable
.Lintr_find:				@; buscar manejadores de interrupciones espec�ficos
	ldr r0, [r2, #4]		@; R0 = m�scara de int. del manejador indexado
	cmp	r0, #0				@; si m�scara = cero, fin de vector de manejadores
	beq	.Lintr_setflags		@; (abandonar bucle de b�squeda de manejador)
	ands r0, r0, r1			@; determinar si el manejador indexado atiende a una
	beq	.Lintr_cont1		@; de las interrupciones activas
	ldr	r3, [r2]			@; R3 = direcci�n de salto del manejador indexado
	cmp	r3, #0
	beq	.Lintr_ret			@; abandonar si direcci�n = 0
	mov r2, lr				@; guardar direcci�n de retorno
	blx	r3					@; invocar el manejador indexado
	mov lr, r2				@; recuperar direcci�n de retorno
	b .Lintr_ret			@; salir del bucle de b�squeda
.Lintr_cont1:	
	add	r2, r2, #8			@; pasar al siguiente �ndice del vector de
	b	.Lintr_find			@; manejadores de interrupciones espec�ficas
.Lintr_ret:
	mov r1, r0				@; indica qu� interrupci�n se ha servido
.Lintr_setflags:
	str	r1, [r12, #0x0C]	@; REG_IF = R1 (comunica interrupci�n servida)
	ldr	r0, =__irq_flags	@; R0 = direcci�n flags IRQ para gesti�n IntrWait
	ldr	r3, [r0]
	orr	r3, r3, r1			@; activar el flag correspondiente a la interrupci�n
	str	r3, [r0]			@; servida (todas si no se ha encontrado el maneja-
							@; dor correspondiente)
	mov	pc,lr				@; retornar al gestor de la excepci�n IRQ de la BIOS


	.global _gp_rsiVBL
	@; Manejador de interrupciones VBL (Vertical BLank) de Garlic:
	@; se encarga de actualizar los tics, intercambiar procesos, etc.
_gp_rsiVBL:
	push {r4-r7, lr}
		@; INCREMENTAR COMPTADOR TICKS
		ldr r4, =_gd_tickCount	@; carreguem a r4 la direcci� on es troba el valor de ticks
		ldr r5, [r4]	@; introduim a r5 el valor actual de ticks
		add r5, r5, #1	@; incrementem el comptador de ticks en 1
		str r5, [r4]	@; desem el nou valor de ticks a la variable tickCount
		
		@; COMPROVAR SI HI HA ALGUN PROC�S A LA CUA DE READY
		ldr r4, =_gd_nReady	@; carreguem a r4 la direcci� on es troba el valor de nReady
		ldr r5, [r4]	@; introduim a r5 el valor actual de processos a la cua de ready
		cmp r5, #0	@; si no tenim processos a la cua de ready...
		beq .Lrsi_fi	@; finalitzem RSI sense canvi de context
		@; si s'arriba a aquesta part de la RSI vol dir que hi ha algun proces a ready per intercanviar
		
		@; COMPROVEM SI EL PROC�S A DESBANCAR �S EL DEL SO
		ldr r6, =_gd_pidz	@; carreguem a r6 la direcci� on es troba el valor de pidz(proc�s actual en execuci�
		ldr r7, [r6]	@; carreguem a r7 el valor actual de pidz
		cmp r7, #0	@; comprovem si els 4 bits de menor pes s�n 0(el z�calo del proc�s del SO �s 0)
		@; flag Z prendr� valor 1 en cas que es tracti del proc�s de SO
		beq .Lrsi_salva	@; salvem el context del proc�s actual en cas que sigui el proc�s del SO
		@; si arriba a aquesta part de la RSI vol dir que tenim processos per intercanviar i no estem tractant el proc�s del SO
		
		@; COMPROVEM SI �S UN PROC�S AMB PID
		mov r7, r7, lsr #4	@; movem 4b a la dreta per quedar-nos amb el PID
		cmp r7, #0	@; comprovem si el seu PID(b31...b4) �s diferent de 0
		beq .Lrsi_restaura @; el PID �s 0 i per tant, no cal salvar el context. El proc�s actual acaba de finalitzar. 
		@; Simplement restaurar el context del proc�s al cap de la cua de ready
		
		@; en cas que no salti, salvar� el context, ja que no haur� acabat l'execuci� del proc�s actual
	.Lrsi_salva:
		bl _gp_salvarProc	@; salvem el context
		str r5, [r4]	@; la rutina de salvar proc�s ens retorna a r5 el total de processos a la cua de ready actualitzat, el desem a la direcci� de la variable
	.Lrsi_restaura:
		bl _gp_restaurarProc	@; restaurem el proc�s que hi ha al cap de la cua de ready
	.Lrsi_fi:
		pop {r4-r7, pc}

	@; Rutina para salvar el estado del proceso interrumpido en la entrada
	@; correspondiente del vector _gd_pcbs
	@;Par�metros
	@; R4: direcci�n _gd_nReady
	@; R5: n�mero de procesos en READY
	@; R6: direcci�n _gd_pidz
	@;Resultado
	@; R5: nuevo n�mero de procesos en READY (+1)
_gp_salvarProc:
	push {r8-r11, lr}
		ldr r8, [r6]	@; desem a r8 el valor de _gd_pidz
		and r8, r8, #0xF	@; ens quedem amb els 4 bits de menor pes(el z�calo)
		ldr r9, =_gd_qReady	@; carreguem a r9 la direcci� de la cua de Ready
		strb r8, [r9, r5]	@; desem el z�calo a l'�ltima posici� de la cua(comptant que t� posici� 0
		@; ser� la posici� de nProcessos a ready)
		ldr r9, =_gd_pcbs	@; desem a r9 la direcci� de _gd_pcbs
		mov r10, #24
		mla r8, r10, r8, r9	@; multipliquem el z�calo pel total de posicions de l'struct "garlicPCB",
		
		@; desarem a _gd_pcbs[z] el CPSR del proc�s a desbancar
		mrs r10, SPSR	@; desem a r10 l'estat del proc�s a desbancar
		str r10, [r8, #12]	@; desem l'Status a la posici� corresponent de _gd_pcbs
		
		@; desarem a _gd_pcbs[z] el PC del proc�s a desbancar
		mov r10, sp	@; carreguem a r10 la direcci� de la pila de IRQ, on sabem que a la posici�
		@; [SP_irq + 60] es troba el PC del proc�s a desbancar
		ldr r11, [r10, #60]	@; desem a r11 el PC del proc�s a desbancar
		str r11, [r8, #4]	@; desem el PC del proc�s a desbancar a _gd_pcbs[z]
		
		@; canviem al mode d'execuci� del proc�s a desbancar(System)
		mrs r11, CPSR	@; desem a r11 l'estat del mode d'execuci� IRQ
		orr r11, #0x1F	@; canviem els bits de mode del CPSR als de mode System
		msr CPSR, r11	@; desem al CPSR l'estat amb els bits de mode modificats(System)
		
		@; apilem els registres del proc�s a desbancar
		@; sabem on estan situats els registres gracies a la documentaci�
		push {r14}
		ldr r11, [r10, #56]	@; apilem r12
		push {r11}
		ldr r11, [r10, #12]	@; apilem r11
		push {r11}
		ldr r11, [r10, #8]	@; apilem r10
		push {r11}
		ldr r11, [r10, #4]	@; apilem r9
		push {r11}
		ldr r11, [r10]	@; apilem r8
		push {r11}
		ldr r11, [r10, #32]	@; apilem r7
		push {r11}
		ldr r11, [r10, #28]	@; apilem r6
		push {r11}
		ldr r11, [r10, #24]	@; apilem r5
		push {r11}
		ldr r11, [r10, #20]	@; apilem r4
		push {r11}
		ldr r11, [r10, #52]	@; apilem r3
		push {r11}
		ldr r11, [r10, #48]	@; apilem r2
		push {r11}
		ldr r11, [r10, #44]	@; apilem r1
		push {r11}
		ldr r11, [r10, #40]	@;  apilem r0
		push {r11}
		
		@; desem a _gd_pcbs[z]->SP la pila del proc�s a desbancar
		str r13, [r8, #8]	@; desem la pila al vector
		
		@; tornem al mode d'execuci� IRQ
		mrs r11, CPSR	@; desem a r11 l'estat
		and r11, #0xFFFFFFF2	@; canviem a mode IRQ
		msr CPSR, r11	@; ho desem com a estat actual de IRQ
		
		add r5, r5, #1	@; afegim 1 al valor de _gd_nReady
	pop {r8-r11, pc}


	@; Rutina para restaurar el estado del siguiente proceso en la cola de READY
	@;Par�metros
	@; R4: direcci�n _gd_nReady 
	@; R5: n�mero de procesos en READY
	@; R6: direcci�n _gd_pidz
_gp_restaurarProc:
	push {r8-r11, lr}
		ldr r8, =_gd_qReady	@; carreguem la direcci� de la cua de ready a r8
		ldrb r9, [r8]	@; carreguem el primer Byte(z�calo) de la cua a r9
		
		@; comen�em el bucle que despla�ar� els z�calos de ready una posici� a l'"esquerra"
		mov r10, #1	@; la posici� on despla�arem el  z�calo de la posici� de la "dreata"
	.Lrestaura_bucle:
		cmp r10, r5	@; si la posici� d'on moure el z�calo �s nReady
		beq .Lrestaura_fibucle	@; sortim del bucle
		ldrb r11, [r8, r10]	@; obtenim el z�calo de la "dreta"
		sub r10, #1	@; decrementem r10 en 1
		strb r11, [r8, r10]	@; desem el z�calo a la posici� de l'"esquerra"
		add r10, #2
		b .Lrestaura_bucle
	.Lrestaura_fibucle:
		@; creem el pidz(pid+z�calo) del proc�s a restaurar
		mov r10, #24
		ldr r11, =_gd_pcbs	@; carreguem a r11 la direcci� de _gd_pcbs
		mla r8, r9, r10, r11	@; multipliquem el numero de z�calo per 24 per tal d'obtindre
		@; la posici� del PID a _gd_pcbs[z]
		ldr r11, [r8]	@; carreguem a r11 el PID del proc�s a restaurar
		lsl r11, #4	@; despla�em 4 bits a l'esquerra el PID per concatenar-lo amb el z�calo
		orr r11, r9	@; concatenem
		str r11, [r6]	@; desem el pid+z�calo a _gd_pidz
		
		@; ara recuperarem el PC del proc�s a restaurar i el copiarem a la pila
		ldr r11, [r8, #4]	@; carreguem el PC a r11
		str r11, [r13, #60]	@; desem el PC a [SP+60]
		
		@; recuperem el CPSR del proc�s a restaurar i l'introduim a SPSR_irq
		ldr r11, [r8, #12]	@; carreguem el CPSR a r11
		msr SPSR, r11	@; ho desem al SPSR del mode IRQ
		mov r9, sp	@; copiem el punter del SP del mode IRQ a r9
		
		@; canviem el mode d'execuci� a System
		mrs r11, CPSR	@; desem a r11 l'estat del mode d'execuci� IRQ
		orr r11, #0x1F	@; canviem els bits de mode del CPSR als de mode System
		msr CPSR, r11	@; desem al CPSR l'estat amb els bits de mode modificats(System)
		
		@; recuperem el valor del registre r13 a restaurar
		ldr r13, [r8, #8]
		
		@; desapilem els registres de la pila del proc�s a restaurar i els apilem a SP_irq
		pop {r11}
		str r11, [r9, #40]	@; apilem r0
		pop {r11}
		str r11, [r9, #44]	@; apilem r1
		pop {r11}
		str r11, [r9, #48]	@; apilem r2
		pop {r11}
		str r11, [r9, #52]	@; apilem r3
		pop {r11}
		str r11, [r9, #20]	@; apilem r4
		pop {r11}
		str r11, [r9, #24]	@; apilem r5
		pop {r11}
		str r11, [r9, #28]	@; apilem r6
		pop {r11}
		str r11, [r9, #32]	@; apilem r7
		pop {r11}
		str r11, [r9]	@; apilem r8
		pop {r11}
		str r11, [r9, #4]	@; apilem r9
		pop {r11}
		str r11, [r9, #8]	@; apilem r10
		pop {r11}
		str r11, [r9, #12]	@; apilem r11
		pop {r11}
		str r11, [r9, #56]	@; apilem r12
		pop {lr}	@; expulsem lr de la pila
		
		@; tornem al mode d'execuci� IRQ
		mrs r11, CPSR	@; desem a r11 l'estat
		and r11, #0xFFFFFFF2	@; canviem a mode IRQ
		msr CPSR, r11	@; ho desem com a estat actual de IRQ
		
		sub r5, #1	@; decrementem el nombre de processos a ready
		str r5, [r4]	@; desem el nou nombre de processos a la direcci� _gd_nReady
		add r5, #1
	pop {r8-r11, pc}


	.global _gp_numProc
	@;Resultado
	@; R0: n�mero de procesos total
_gp_numProc:
	push {r1-r2, lr}
		mov r0, #1				@; contar siempre 1 proceso en RUN
		ldr r1, =_gd_nReady
		ldr r2, [r1]			@; R2 = n�mero de procesos en cola de READY
		add r0, r2				@; a�adir procesos en READY
	pop {r1-r2, pc}


	.global _gp_crearProc
	@; prepara un proceso para ser ejecutado, creando su entorno de ejecuci�n y
	@; coloc�ndolo en la cola de READY
	@;Par�metros
	@; R0: intFunc funcion,
	@; R1: int zocalo,
	@; R2: char *nombre
	@; R3: int arg
	@;Resultado
	@; R0: 0 si no hay problema, >0 si no se puede crear el proceso
_gp_crearProc:
	push {r1-r6, lr}
		cmp r1, #0	@;comprovem si el z�calo �s 0
		moveq r0, #1	@; en cas que tingui z�calo 0 rebutjem el proc�s
		beq .Lcrear_fi	@; rebutjem el proc�s
		ldr r4, =_gd_pcbs	@; carreguem a r4 la direcci� de _gd_pcbs
		mov r5, #24
		mla r4, r1, r5, r4	@; fem un despla�ament que ens situar� a _gd_pcbs[z]->PID
		ldr r5, [r4]	@; carreguem a r5 el valor del PID
		cmp r5, #0	@; comparem el PID amb 0
		movne r0, #1	@; en cas que el PID no sigui 0 rebutjem el proc�s
		bne .Lcrear_fi
		
		@; obtenim un PID pel nou proc�s
		ldr r5, =_gd_pidCount	@; carreguem a r5 la direcci� de _gd_pidCount
		ldr r6, [r5]	@; carreguem a r6 el valor de _gd_pidCount
		add r6, #1	@; incrementem pidCount en 1
		str r6, [r5]	@; desem el nou valor de _gd_pidCount
		str r6, [r4]	@; desem el nou valor del PID a _gd_pcbs[z]->PID
		
		@; desem la direcci� de la rutina inicial del proc�s
		add r0, #4	@; sumem 4 al PC per compensar el decrement al restaurar-se
		str r0, [r4, #4]	@; desem el valor a _gd_pcbs[z]->PC
		
		@; desem els 4 primers car�cters del nom en clau del programa
		ldr r5, [r2]	@; passem a int
		str r5, [r4, #16]	@; ho desem a _gd_pcbs[z]->keyName
		
		@; calculem la direcci� base de la pila del proc�s
		ldr r5, =_gd_stacks	@; carreguem a r5 la direcci� de _gd_stacks
		mov r6, #512
		mla r5, r1, r6, r5	@; el despla�ament dins _gd_stacks ser� la mida d'un
		@; stack(128)*4(int). Ens situar� al final de la pila seg�ent
		sub r5, #4	@; decrementem el despla�ament en 4 per obtindre la base del stack de z
		
		@; desem a la pila del proc�s inicial dels registres
		ldr r6, =_gp_terminarProc	@; carreguem a r6 la direcci� de _gp_terminarProc()
		str r6, [r5]	@; desem a r14 la direcci�
		mov r6, #0	@; introduim un 0 a r8
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r12
		str r6, [r5]	@; introduim un 0 a r12
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r11
		str r6, [r5]	@; introduim un 0 a r11
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r10
		str r6, [r5]	@; introduim un 0 a r10
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r9
		str r6, [r5]	@; introduim un 0 a r9
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r8
		str r6, [r5]	@; introduim un 0 a r8
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r7
		str r6, [r5]	@; introduim un 0 a r7
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r6
		str r6, [r5]	@; introduim un 0 a r6
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r5
		str r6, [r5]	@; introduim un 0 a r5
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r4
		str r6, [r5]	@; introduim un 0 a r4
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r3
		str r6, [r5]	@; introduim un 0 a r3
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r2
		str r6, [r5]	@; introduim un 0 a r2
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r1
		str r6, [r5]	@; introduim un 0 a r1
		sub r5, #4	@; decrementem el despla�ament en 1 posici� i ens situem a r0
		str r3, [r5]	@; introduim el valor de l'argument a r0
		
		@; desem el valor actual de la pila del proc�s a _gd_pcbs[z]->SP
		str r5, [r4, #8]	@; desem la pila a _gd_pcbs[z]->SP
		
		@; desem el valor inicial de CPSR del proc�s a crear
		mov r5, #0x1F	@; bits de mode System i flags a 0
		str r5, [r4, #12]	@; ho desem a _gd_pcbs[z]->Status
		
		@; inicialitzem workTicks
		str r6, [r4, #20]	@; l'inicialitzem amb r6 que encara cont� 0
		
		@; desem el nombre de z�calo a la ultima posici� de Ready i incrementem el nombre
		@; de processos pendents a la cua
		ldr r4, =_gd_qReady	@; carreguem a r4 la direcci� de la cua de Ready
		ldr r5, =_gd_nReady	@; carreguem a r5 la direcci� de gd_nReady
		ldr r6, [r5]	@; carreguem a r6 el valor de nReady
		strb r1, [r4, r6]	@; desem el nombre de z�calo a la �ltima posici� de ready
		add r6, #1	@; incrementem en 1 el nombre de processos de Ready
		str r6, [r5]	@; ho desem
		mov r0, #0	@; posem r0 a 0 per indicar que s'ha pogut crear el proc�s
		
	.Lcrear_fi:
		pop {r1-r6, pc}


	@; Rutina para terminar un proceso de usuario:
	@; pone a 0 el campo PID del PCB del z�calo actual, para indicar que esa
	@; entrada del vector _gd_pcbs est� libre; tambi�n pone a 0 el PID de la
	@; variable _gd_pidz (sin modificar el n�mero de z�calo), para que el c�digo
	@; de multiplexaci�n de procesos no salve el estado del proceso terminado.
_gp_terminarProc:
	ldr r0, =_gd_pidz
	ldr r1, [r0]			@; R1 = valor actual de PID + z�calo
	and r1, r1, #0xf		@; R1 = z�calo del proceso desbancado
	str r1, [r0]			@; guardar z�calo con PID = 0, para no salvar estado			
	ldr r2, =_gd_pcbs
	mov r10, #24
	mul r11, r1, r10
	add r2, r11				@; R2 = direcci�n base _gd_pcbs[zocalo]
	mov r3, #0
	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto
	
.end

