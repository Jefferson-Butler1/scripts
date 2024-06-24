#include <stdio.h>
#include <stdlib.h>


int main (int argc, char**  argv){

  if( argc != 4 ){ //check if usage is legal in terms of number of arguments
    printf("Invalid call. Usage: bc (number) [+,-,*,/] (number)\n");
    exit(1);
  }
  
  switch(argv[2][0]){
    case '-':
      printf("%f\n", (double)(atoi(argv[1]) - atoi(argv[3])));
      break;
    case '/':
      printf("%f\n", (double)(atoi(argv[1]) / atoi(argv[3])));
      break;
    case '*':
      printf("%f\n", (double)(atoi(argv[1]) * atoi(argv[3])));
      break;
    case '+':
      printf("%f\n", (double)(atoi(argv[1]) + atoi(argv[3])));
      break;
  }
  
}
