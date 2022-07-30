/*------------------------------------------------------------------------------

	"SUPI.c" : programa de prova pel sistema operatiu GARLIC 2.0;
	
	Realitza una serie de divisions que aproximen el valor del nombre PI
	Fa (arg + 1) * 10 successions

------------------------------------------------------------------------------*/

#include <GARLIC_API.h>	


int _start(int arg){
	int divisor = 1;
	int resultat=0;
	int precisio=100000;	// aquest valor ens aportarà una precisió de 5 dígits decimals
	int dividend=4*precisio;
	int cont=1;
	unsigned int quocient, residu;
	
	if (arg < 0) arg = 0;			// limitar valor màxim 
	else if (arg > 3) arg = 3;		// mínim de arg
	GARLIC_clear();	//netegem la pantalla
	// escrivim el missatge inicial
	GARLIC_printf("-- Programa PI  -  PID (%d) --\n", GARLIC_pid());
	// la idea és que el valor d'arg seveixi per saber el nombre de successions que
	// realitzarem: (arg + 1)*10, així realitzarem 10, 20, 30 o 40 successions

	

	arg++;	
	arg *=10;
	
	while(cont<=arg){	// mentre no s'hagin realitzat el nombre de successions indicades...
		GARLIC_divmod(dividend, divisor, &quocient, &residu);
		if(cont%2==0){	//en cas de les iteracions parelles sumarem el valor de l'aproximació
						//al valor anterior
			resultat=resultat-quocient;
		}
		else{	//en cas contrari, ho restarem
			resultat=resultat+quocient;
		}
		
		GARLIC_divmod(resultat, precisio, &quocient, &residu);
		GARLIC_printf("Iteracio: %d \n", cont);	
		GARLIC_printf("PI: %d,%d \n\n", quocient, residu);
		divisor+=2;	//incrementem el divisor en 2
		cont++;
	}
	
	return 0;
}