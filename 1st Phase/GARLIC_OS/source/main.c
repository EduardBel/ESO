/*------------------------------------------------------------------------------

	"main.c" : fase 1 / programador P

	Programa de prueba de creaci�n y multiplexaci�n de procesos en GARLIC 1.0,
	pero sin cargar procesos en memoria ni utilizar llamadas a _gg_escribir().

------------------------------------------------------------------------------*/
#include <nds.h>
#include <stdio.h>

#include <garlic_system.h>	// definici�n de funciones y variables de sistema

#include <GARLIC_API.h>		// inclusi�n del API para simular un proceso
int hola(int);				// funci�n que simula la ejecuci�n del proceso
int series_PI(int);
extern int * punixTime;		// puntero a zona de memoria con el tiempo real


/* Inicializaciones generales del sistema Garlic */
//------------------------------------------------------------------------------
void inicializarSistema() {
//------------------------------------------------------------------------------

	consoleDemoInit();		// inicializar consola, s�lo para esta simulaci�n
	
	_gd_seed = *punixTime;	// inicializar semilla para n�meros aleatorios con
	_gd_seed <<= 16;		// el valor de tiempo real UNIX, desplazado 16 bits
	
	irqInitHandler(_gp_IntrMain);	// instalar rutina principal interrupciones
	irqSet(IRQ_VBLANK, _gp_rsiVBL);	// instalar RSI de vertical Blank
	irqEnable(IRQ_VBLANK);			// activar interrupciones de vertical Blank
	REG_IME = IME_ENABLE;			// activar las interrupciones en general
	
	_gd_pcbs[0].keyName = 0x4C524147;	// "GARL"
}


//------------------------------------------------------------------------------
int main(int argc, char **argv) {
//------------------------------------------------------------------------------
	
	inicializarSistema();
	
	printf("********************************");
	printf("*                              *");
	printf("* Sistema Operativo GARLIC 1.0 *");
	printf("*                              *");
	printf("********************************");
	printf("*** Inicio fase 1_P\n");
	
	//_gp_crearProc(hola, 7, "HOLA", 2);
	//_gp_crearProc(hola, 14, "HOLA", 2);
	_gp_crearProc(series_PI, 14, "PI", 3);
	while (_gp_numProc() > 1) {
		_gp_WaitForVBlank();
		printf("*** Test %d:%d\n", _gd_tickCount, _gp_numProc());
	}						// esperar a que terminen los procesos de usuario

	printf("*** Final fase 1_P\n");

	while (1) {
		_gp_WaitForVBlank();
	}							// parar el procesador en un bucle infinito
	return 0;
}


/* Proceso de prueba, con llamadas a las funciones del API del sistema Garlic */
//------------------------------------------------------------------------------
int hola(int arg) {
//------------------------------------------------------------------------------
	unsigned int i, j, iter;
	
	if (arg < 0) arg = 0;			// limitar valor m�ximo y 
	else if (arg > 3) arg = 3;		// valor m�nimo del argumento
	
									// esccribir mensaje inicial
	GARLIC_printf("-- Programa HOLA  -  PID (%d) --\n", GARLIC_pid());
	
	j = 1;							// j = c�lculo de 10 elevado a arg
	for (i = 0; i < arg; i++)
		j *= 10;
						// c�lculo aleatorio del n�mero de iteraciones 'iter'
	GARLIC_divmod(GARLIC_random(), j, &i, &iter);
	iter++;							// asegurar que hay al menos una iteraci�n
	
	for (i = 0; i < iter; i++)		// escribir mensajes
		GARLIC_printf("(%d)\t%d: Hello world!\n", GARLIC_pid(), i);

	return 0;
}

//programa d'usuari:
//aplicar s�ries infinites amb el m�tode de Gregory-Leibniz per
//aproximar el valor de PI
int series_PI(int arg){
	int divisor = 1;
	int resultat=0;
	int precisio=100000;	// aquest valor ens aportar� una precisi� de 5 d�gits decimals
	int dividend=4*precisio;
	int cont=1;
	unsigned int quocient, residu;
	
	if (arg < 0) arg = 0;			// limitar valor m�xim 
	else if (arg > 3) arg = 3;		// m�nim de arg
	
	// escrivim el missatge inicial
	GARLIC_printf("-- Programa PI  -  PID (%d) --\n", GARLIC_pid());
	// la idea �s que el valor d'arg seveixi per saber el nombre de successions que
	// realitzarem: (arg + 1)*10, aix� realitzarem 10, 20, 30 o 40 successions
	arg++;	
	arg *=10;
	
	while(cont<=arg){	// mentre no s'hagin realitzat el nombre de successions indicades...
		GARLIC_divmod(dividend, divisor, &quocient, &residu);
		if(cont%2==0){	//en cas de les iteracions parelles sumarem el valor de l'aproximaci�
						//al valor anterior
			resultat=resultat-quocient;
		}
		else{	//en cas contrari, ho restarem
			resultat=resultat+quocient;
		}
		
		GARLIC_divmod(resultat, precisio, &quocient, &residu);
		//GARLIC_printf("Iteracio: %d:", cont);	//en cas que volguessim printar la iteraci�,
		//ho comento ja que genera una interrupci� que causa un print del SO
		GARLIC_printf("PI: %d,%d \n", quocient, residu);
		divisor+=2;	//incrementem el divisor en 2
		cont++;
	}
	
	return 0;
}