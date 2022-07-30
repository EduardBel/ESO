@;==============================================================================
@;
@;	"garlic_itcm_proc.s":	c�digo de las rutinas de control de procesos (2.0)
@;						(ver "garlic_system.h" para descripci�n de funciones)
@;
@;==============================================================================

.bss
	.align 2
	_gp_pantalla: .space 4
	_gp_quocient: .space 4
	_gp_residu: .space 4

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
		
		bl _gp_actualizarDelay	@; actualitzem el delay dels processos a qDelay
		
		ldr r4, =_gd_pidz	@; carreguem la direccio de pidz
		ldr r5, [r4]	@; carreguem el valor
		and r5, #0xF	@; prenem sols el z�calo
		ldr r4, =_gd_pcbs	@; carreguem la direcci� de pcbs
		mov r6, #24	
		mla r4, r5, r6, r4	@; calculem el despla�ament necessari per situar-nos a pcbs[z].PID
		ldr r5, [r4, #20]	@; prenem els workticks del proc�s actual
		add r5, #1	@; els incrementem en 1
		str r5, [r4, #20]	@; ho desem
		
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
		@; no cal m�scara, ja que tant el PID com el z�calo s�n 0
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
		and r11, r8, #0xF	@; ens quedem amb els 4 bits de menor pes(el z�calo)
		tst r8, #0x80000000	@; comprovem si t� el bit de major pes a 0
		bne .Lsalvar_noReady
		ldr r9, =_gd_qReady	@; carreguem a r9 la direcci� de la cua de Ready
		strb r11, [r9, r5]	@; desem el z�calo a l'�ltima posici� de la cua(comptant que t� posici� 0
		@; ser� la posici� de nProcessos a ready)
		add r5, r5, #1	@; afegim 1 al valor de _gd_nReady
	.Lsalvar_noReady:
		ldr r9, =_gd_pcbs	@; desem a r9 la direcci� de _gd_pcbs
		mov r10, #24
		mla r8, r10, r11, r9	@; multipliquem el z�calo pel total de posicions de l'struct "garlicPCB",
		
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
	pop {r8-r11, pc}


	@; Rutina para actualizar la cola de procesos retardados, poniendo en
	@; cola de READY aquellos cuyo n�mero de tics de retardo sea 0
_gp_actualizarDelay:
	push {r0-r7, lr}
		ldr r1, =_gd_nDelay	@; carreguem a r1 la direcci� de nDelay
		ldr r2, [r1]	@; carreguem a r2 el nombre de processos en delay
		cmp r2, #0	@; comprovem si hi ha processos a la cua de delay, en cas que no, hem acabat
		beq .LfiDelay
		ldr r0, =_gd_qDelay	@; carreguem a r0 la direcci� de la cua de delay
		mov r3, r2	@; comptador per recorrer _gd_qDelay en decrement
		
	.LbucleDelay:
		sub r3, #1	@; decrementem el comptador
		ldr r4, [r0, r3, lsl #2]	@; carreguem el zocalo+tics
		sub r4, #1	@; decrementem el nombre de tics restants en 1
		mov r5, r4
		mov r5, r5, lsl #16	@; posem els primers 16bits a 0 i ens quedem amb els de tics
		mov r5, r5, lsr #16
		cmp r5, #0	@; en cas que tics sigui 0 eliminem el proc�s de qDelay i l'inserim a qReady
		strne r4, [r0, r3, lsl #2]	@; si no s'ha arribat als 0 tics, desem el nou valor a la cua
		bne .LpassaSeguent
		@; en cas que el codi executi aqui voldr� dir que hem de retirar el proc�s de qDelay actual de
		@; la cua i inserir-lo a l'�ltima posici� de qReady
		ldr r5, =_gd_qReady
		ldr r6, =_gd_nReady
		ldr r7, [r6]
		lsr r4, #24	@; movem el z�calo als bits de menor pes
		strb r4, [r5, r7]	@; ho desem a l'�ltima posici� de qReady
		add r7, #1	@; incrementem el nombre de processos a Ready
		str r7, [r6]	@; ho desem a mem�ria
		sub r2, #1
		@; ara modifiquem la cua de Delay
		mov r5, r3	@; copiem a r5 el valor actual del comptador i li sumem un per colocar-nos 
		@; a la posici� de l'esquerra
		add r5, #1
	.LmodificaCua:
		cmp r5, r2
		bgt .LpassaSeguent
		ldr r6, [r0, r5, lsl #2]	@; prenem el valor de la posici� de la "dreta"
		sub r5, #1
		str r6, [r0, r5, lsl #2]	@; l'introduim a la posici� de "l'esquerra"
		add r5, #2
		b .LmodificaCua		
		
	.LpassaSeguent:
		cmp r3, #0	@; en cas que no hagim acabat de recorrer qDelay, fem una altra iteraci�
		bne .LbucleDelay
		str r2, [r1]	@; desem nDelay a memoria quan acabem d'executar la funci�
	.LfiDelay:
		pop {r0-r7, pc}

	.global _gp_numProc
	@;Resultado
	@; R0: n�mero de procesos total
_gp_numProc:
	push {r1-r2, lr}
	mov r0, #1				@; contar siempre 1 proceso en RUN
	ldr r1, =_gd_nReady
	ldr r2, [r1]			@; R2 = n�mero de procesos en cola de READY
	add r0, r2				@; a�adir procesos en READY
	ldr r1, =_gd_nDelay
	ldr r2, [r1]			@; R2 = n�mero de procesos en cola de DELAY
	add r0, r2				@; a�adir procesos retardados
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
	push {r1-r7, lr}
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
		ldr r5, [r2]	@; nom del proc�s
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
		mov r6, #0	@; introduim un 0 a r6
		mov r7, #0	@; comptador del bucle
	.LbucleCrear:
		sub r5, #4	@; modifiquem el despla�ament
		str r6, [r5]	@; desem un 0 a la posici�
		add r7, #1	@; incrementem el comptador
		cmp r7, #12	
		blt .LbucleCrear
			
		sub r5, #4	@; modifiquem el despla�ament
		str r3, [r5]	@; desem l'argument a r0

		@; desem el valor actual de la pila del proc�s a _gd_pcbs[z]->SP
		str r5, [r4, #8]	@; desem la pila a _gd_pcbs[z]->SP
		
		@; desem el valor inicial de CPSR del proc�s a crear
		mov r5, #0x1F	@; bits de mode System i flags a 0
		str r5, [r4, #12]	@; ho desem a _gd_pcbs[z]->Status
		
		@; inicialitzem workTicks
		str r6, [r4, #20]	@; l'inicialitzem amb r6 que encara cont� 0
		
		@; desem el nombre de z�calo a la ultima posici� de Ready i incrementem el nombre
		@; de processos pendents a la cua
		bl _gp_inhibirIRQs
		ldr r4, =_gd_qReady	@; carreguem a r4 la direcci� de la cua de Ready
		ldr r5, =_gd_nReady	@; carreguem a r5 la direcci� de gd_nReady
		ldr r6, [r5]	@; carreguem a r6 el valor de nReady
		strb r1, [r4, r6]	@; desem el nombre de z�calo a la �ltima posici� de ready
		add r6, #1	@; incrementem en 1 el nombre de processos de Ready
		str r6, [r5]	@; ho desem
		mov r0, #0	@; posem r0 a 0 per indicar que s'ha pogut crear el proc�s
		bl _gp_desinhibirIRQs
	.Lcrear_fi:
		
		pop {r1-r7, pc}


	@; Rutina para terminar un proceso de usuario:
	@; pone a 0 el campo PID del PCB del z�calo actual, para indicar que esa
	@; entrada del vector _gd_pcbs est� libre; tambi�n pone a 0 el PID de la
	@; variable _gd_pidz (sin modificar el n�mero de z�calo), para que el c�digo
	@; de multiplexaci�n de procesos no salve el estado del proceso terminado.
_gp_terminarProc:
	ldr r0, =_gd_pidz
	ldr r1, [r0]			@; R1 = valor actual de PID + z�calo
	and r1, r1, #0xf		@; R1 = z�calo del proceso desbancado
	bl _gp_inhibirIRQs
	str r1, [r0]			@; guardar z�calo con PID = 0, para no salvar estado			
	ldr r2, =_gd_pcbs
	mov r10, #24
	mul r11, r1, r10
	add r2, r11				@; R2 = direcci�n base _gd_pcbs[zocalo]
	mov r3, #0
	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
	str r3, [r2, #20]		@; borrar porcentaje de USO de la CPU
	ldr r0, =_gd_sincMain
	ldr r2, [r0]			@; R2 = valor actual de la variable de sincronismo
	mov r3, #1
	mov r3, r3, lsl r1		@; R3 = m�scara con bit correspondiente al z�calo
	orr r2, r3
	str r2, [r0]			@; actualizar variable de sincronismo
	bl _gp_desinhibirIRQs
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto


	.global _gp_matarProc
	@; Rutina para destruir un proceso de usuario:
	@; borra el PID del PCB del z�calo referenciado por par�metro, para indicar
	@; que esa entrada del vector _gd_pcbs est� libre; elimina el �ndice de
	@; z�calo de la cola de READY o de la cola de DELAY, est� donde est�;
	@; Par�metros:
	@;	R0:	z�calo del proceso a matar (entre 1 y 15).
_gp_matarProc:
	push {r1-r6, lr}
		bl _gp_inhibirIRQs
		cmp r0, #0xF	@; en cas que el z�calo donat sigui major que 15 hem acabat
		bgt .Lfi_gp_matarProc
		
		ldr r1, =_gd_pcbs	@; carreguem a r1 la direcci� de _gd_pcbs
		mov r2, #24	@; inserim a r2 el despla�ament per mouren's entre z�calos a _gd_pcbs
		mla r2, r0, r2, r1	@; ens situem a pcbs[z].PID
		mov r3, #0	@; inserim un 0 a r3
		str r3, [r2]	@; introduim un 0 a la posici�
		
		@; comprovem si el proc�s �s a la cua de ready
		ldr r2, =_gd_nReady	@; carreguem la direcciod e nReady	
		ldr r3, [r2]	@; carreguem el valor	
		cmp r3, #0	@; en cas que no hi hagi processos a ready...
		beq .LcercaqDelay	@; saltem a comprovar la cua de delay
		mov r4, #0	@; comptador a 0
		ldr r1, =_gd_qReady	@; carreguem qReady
		
	.LcercaqReady:	@; bucle de cerca a la cua de ready
		ldrb r5, [r1, r4]	@; carreguem el z�calo
		cmp r5, r0	@; en cas que l'hagim trobat...
		beq .LmoureProcessosqReady	@; modifiquem la cua de Ready
		add r4, #1	@; incrementem el comptador en 1
		cmp r4, r3	@; comprovem si hem recorregut tota la cua
		blt .LcercaqReady	
		b .LcercaqDelay	@; en cas que hagim recorregut tota la cua i no l'hagim trobat...
		
	.LmoureProcessosqReady:
		add r5, r4, #1	@; ens situem a la posici� de la "dreta"
		ldrb r6, [r1, r5]	@; prenem el valor
		@;sub r4, #1	@; ens situem a la posici� de l'"esquerra"
		strb r6, [r1, r4]	@; prenem el valor
		add r4, #1	@; incrementem el despla�ament en 2
		cmp r4, r3	@; comprovem si hem acabat de recorrer la cua
		blt .LmoureProcessosqReady
		sub r3, #1	@; quan acabem, decrementem nReady en 1
		str r3, [r2]	@; i ho desem a memoria
		b .Lfi_gp_matarProc	@; hem acabat

	.LcercaqDelay:
		ldr r1, =_gd_qDelay 	@; carreguem la direcci� de qDelay
		ldr r2, =_gd_nDelay 	@; carreguem la direcci� de nReady
		ldr r3, [r2] 			@; carreguem el valor de nReady
		mov r4, #0 	@; inicialitzem un comptador a 0
	.LbucleCercaDelay:
		ldr r5, [r1, r4, lsl #2]	@; prenem el valor de la cua
		and r5, #0xFF000000	@; prenem els bits de z�calo
		mov r5, r5, lsr	#24	@; despla�em 24bits a la dreta
		
		cmp r5, r0	@; comprovem si �s el proc�s a eliminar
		beq .LmoureProcessosqDelay
		add r4, #1	@; incrementem el comptador en 1
		cmp r4, r3	@; comprovem si hem arribat al final de la cua
		blt .LbucleCercaDelay	@; realitzem una altra iteraci�
	.LmoureProcessosqDelay:	@; bucle per modificar la cua de delay(segueix l'estructura d'abans)
		add r5, r4, #1
		ldr r6, [r1, r5, lsl #2]
		@;sub r4, #1
		str r6, [r1, r4, lsl #2]
		add r4, #1
		cmp r4, r3
		blt .LmoureProcessosqDelay
		sub r3, #1 
		str r3, [r2]
	.Lfi_gp_matarProc:
		bl _gp_desinhibirIRQs
		pop {r1-r6,pc}

	
	.global _gp_retardarProc
	@; retarda la ejecuci�n de un proceso durante cierto n�mero de segundos,
	@; coloc�ndolo en la cola de DELAY
	@;Par�metros
	@; R0: int nsec
_gp_retardarProc:
	push {r1-r8, lr}
		bl _gp_inhibirIRQs
		mov r1, #60	@; introduim el nombre de tics per segon que es produeixen per segon a r1
		mul r1, r0 	@; multipliquem per saber quants tics corresponen al nombre de segons que
		@; el proc�s ha d'estar a la cua de delay
		
		ldr r2, =_gd_pidz	@; carreguem a r2 la direcci� de _gd_pidz
		ldr r3, [r2]	@; carreguem a r3 el valor de _gd_pidz
		and r4, r3, #0xF	@; ens quedem amb els 4 bits de menor pes(z�calo)
		mov r5, r4, lsl #24	@; despla�em el z�calo als 8 bits de major pes
		orr r1, r1, r5	@; concatenem els bits de z�calo amb els de el nombre de tics que ha d'assolir
		@; per ser desencuat de la cua de delay
		ldr r6, =_gd_qDelay	@; carreguem a r1 la direcci� de _gd_qDelay
		ldr r7, =_gd_nDelay	@; carreguem a r3 la direcci� de _gd_nDelay
		ldr r8, [r7]	@; carreguem a r4 el valor de _gd_nDelay
		str r1, [r6, r8, lsl #2]	@; introduim zocalo+nTics a la cua de Delay
		add r8, #1	@; incrementem en 1 el nombre de processos a la cua de Delay
		str r8, [r7]	@; desem el nou valor a _gd_nDelay
		
		orr r3, #0x80000000	@; modifiquem el bit de m�s pes de _gd_pidz per tal que sigui 1
		str r3, [r2]	@; ho desem a la seva direcci�
		bl _gp_desinhibirIRQs
		bl _gp_WaitForVBlank
	pop {r1-r8, pc}


	.global _gp_inihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 0, para inhibir todas
	@; las IRQs y evitar as� posibles problemas debidos al cambio de contexto
_gp_inhibirIRQs:
	push {r0-r1, lr}
		ldr r0, =0x04000208	@; carreguem la direcci� de IME
		ldrh r1, [r0]	@; carreguem el valor
		bic r1, #0x0001	@; posem el bit 0 a 0
		strh r1, [r0]	@; ho desem a memoria
	pop {r0-r1, pc}


	.global _gp_desinihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 1, para desinhibir todas
	@; las IRQs
_gp_desinhibirIRQs:
	push {r0-r1, lr}
		ldr r0, =0x04000208	@; carreguem la direcci� de IME
		ldrh r1, [r0]	@; carreguem el seu valor
		orr r1, #0x1	@; posem el bit 0 a 1
		strh r1, [r0]	@; ho desem a memoria
	pop {r0-r1, pc}


	.global _gp_rsiTIMER0
	@; Rutina de Servicio de Interrupci�n (RSI) para contabilizar los tics
	@; de trabajo de cada proceso: suma los tics de todos los procesos y calcula
	@; el porcentaje de uso de la CPU, que se guarda en los 8 bits altos de la
	@; entrada _gd_pcbs[z].workTicks de cada proceso (z) y, si el procesador
	@; gr�fico secundario est� correctamente configurado, se imprime en la
	@; columna correspondiente de la tabla de procesos.
_gp_rsiTIMER0:
	push {r0-r8, lr}
		ldr r4, =_gd_pcbs	@; carreguem a r4 la direcci� de _gd_pcbs
		@; primer tractem el proc�s de SO fora del bule, ja que el seu PID �s sempre 0
		ldr r7, [r4, #20]	@; carreguem els tics del proc�s de SO(amb %CPU)
		and r7, r7, #0x00FFFFFF	@; ens quedem sols amb el nombre de tics
		mov r6, r7	@; r6 actuar� com a variable de sumatori
		add r4, #24	@; situem r4 a _gd_pcbs[1].PID
		mov r5, #1	@; inicialitzem un comptador a 1 que actuar� com a z�calo

	.LbucleTimerTics:
		cmp r5, #16	@; comprovem si ha passat per tots els processos
		beq .LfiBucleTimerTics	@; en cas afirmatiu sortim del bucle
		ldr r7, [r4]	@; carreguem a r7 el valor actual del PID del proc�s
		cmp r7, #0	@; comprovem si est� actiu
		beq .LseguentIteracioTics	@; en cas que no ho estigui preparem la seguent iteracio		
		ldr r8, [r4, #20]	@; ens situem als workTicks del proc�s i ho carreguem a r8
		and r8, #0x00FFFFFF	@; apliquem una m�scara per no prendre el %CPU
		add r6, r8	@; sumem els tics a la variable de sumatori
	.LseguentIteracioTics:
		add r5, #1	@; incrementem el comptador
		add r4, #24	@; ens situem al PID del seguent zocalo
		b .LbucleTimerTics
	.LfiBucleTimerTics:
		
		@; procedim a calcular el percentatge d'�s de CPU de cada proc�s actiu
		@; per fer-ho recorrerem els pcbs, on mirarem els tics que t� cada proc�s
		@; farem la divisi� i escriurem el % de CPU que est� consumint
		ldr r4, =_gd_pcbs	@; carreguem a r4 la direcci� de _gd_pcbs
		@; primer tractem el proc�s de SO fora del bule, ja que el seu PID �s sempre 0
		ldr r7, [r4, #20]	@; carreguem els tics del proc�s de SO(amb %CPU)
		and r7, r7, #0x00FFFFFF	@; ens quedem sols amb el nombre de tics
		mov r0, #100
		mul r0, r7	@; multipliquem el nombre de tics per 100
		mov r1, r6	@; movem el total de tics a r0
		ldr r2, =_gp_quocient
		ldr r3, =_gp_residu
		bl _ga_divmod	@; fem una crida a divmod
		ldr r7, [r2]
		mov r7, r7, lsl #24	@; ho movem 24 bits a l'esquerra per deixar el percentatge als
		@; 8 bits alts
		str r7, [r4, #20]	@; ho desem a _gd_pcbs[z].workTicks
		ldr r0, =_gp_pantalla	@; carreguem la direcci� on la funci� desar� el % transformat a string
		mov r1, #4	@; length
		ldr r2, [r2]	@; carreguem el %CPU calculat per _ga_divmod
		bl _gs_num2str_dec
		ldr r0, =_gp_pantalla
		mov r1, #4	@; fila
		mov r2, #28 @; columna
		mov r3, #0	@; color blanc
		bl _gs_escribirStringSub	@; escrivim el percentatge a la posici�
		
		add r4, #24	@; situem r4 a _gd_pcbs[1].PID
		mov r5, #1	@; inicialitzem un comptador a 1 que actuar� com a z�calo
	.LbucleTimerUs:
		cmp r5, #16	@; comprovem si ha passat per tots els processos
		beq .LfiBucleTimerUs	@; en cas afirmatiu sortim del bucle
		ldr r7, [r4]	@; carreguem a r7 el valor actual del PID del proc�s
		cmp r7, #0	@; comprovem si est� actiu
		beq .LseguentIteracioUs	@; en cas que no ho estigui preparem la seguent iteracio		
		ldr r7, [r4, #20]	@; carreguem els tics del proc�s (amb %CPU)
		and r7, r7, #0x00FFFFFF	@; ens quedem sols amb el nombre de tics
		mov r0, #100
		mul r0, r7	@; multipliquem el nombre de tics per 100
		mov r1, r6	@; movem el total de tics a r0
		ldr r2, =_gp_quocient
		ldr r3, =_gp_residu
		bl _ga_divmod	@; fem una crida a divmod
		ldr r7, [r2]
		mov r7, r7, lsl #24	@; ho movem 24 bits a l'esquerra per deixar el percentatge als
		@; 8 bits alts
		str r7, [r4, #20]	@; ho desem a _gd_pcbs[z].workTicks
		ldr r0, =_gp_pantalla	@; carreguem la direcci� on la funci� desar� el % transformat a string
		mov r1, #4	@; length
		ldr r2, [r2]	@; carreguem el %CPU calculat per _ga_divmod
		bl _gs_num2str_dec
		ldr r0, =_gp_pantalla
		add r1, r5, #4	@; fila
		mov r2, #28 @; columna
		mov r3, #0	@; color blanc
		bl _gs_escribirStringSub	@; escrivim el percentatge a la posici�
	.LseguentIteracioUs:
		add r5, #1	@; incrementem el comptador
		add r4, #24	@; ens situem al PID del seguent zocalo
		b .LbucleTimerUs
		
	.LfiBucleTimerUs:
		@; finalment posem a 1 el bit 0 de _gd_sincMain
		ldr r0, =_gd_sincMain	@; carreguem la direcci�
		ldr r1, [r0]	@; carreguem el valor
		orr r1, #0x1	@; posem el bit 0 a 1
		str r1, [r0]	@; ho desem a memoria
		pop {r0-r8 ,pc}

	
.end

