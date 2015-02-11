#This script identify every 3 points as one point and its errobar, averaging their x axis and get the difference of their y axis as the errorbar
BEGIN{
  i=1
} 

{
  if(i==1){
    x=$1;
    y[1]=$2;
  }
  if(i>1){
    x=x+$1;
    l=1;
    for(j=1;j<=i-1;j++){
      if($2>y[j]) l++;
    }
    for(j=i;j>l;j--){
      y[j]=y[j-1];
    } 
    y[l]=$2;
  }
  i++;
  if(i==4){
    print x/3,(y[1]+y[2]+y[3])/3,(y[3]-y[1])/2;
    i=1;
    y[1]=0;
    y[2]=0;
    y[3]=0
  }
}
