#include <stdio.h>
#include <stdlib.h>

void iunion(double*, double*);

void main()
{
    double x[4]={1,2,3,4};
    double y[3];
    
    iunion(x, y);

    printf("X=");
    for(int i=0; i<4; i++)
        printf("\t%lf\n",x[i]);
    printf("Y=");
    for(int i=0; i<4; i++)
        printf("\t%lf\n",y[i]);

}
