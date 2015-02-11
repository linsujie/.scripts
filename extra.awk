#!/bin/awk
function abs(x){
  return (x>0)?(x):(-x);
}

function getmin(x){
  getmin_iter++;
  if(getmin_iter==1){
    getmin_a=x;
    return 1;
  }else
  if(getmin_a>x){
    getmin_a=x;
    return 1;
  }
  return 0;
}

function getmax(x){
  getmax_iter++;
  if(getmax_iter==1){
    getmax_a=x;
    return 1;
  }else
  if(a>x){
    getmax_a=x;
    return 1;
  }
  return 0;
}
