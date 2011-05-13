/* This file is part of the Random Ball Cover (RBC) library.
 * (C) Copyright 2010, Lawrence Cayton [lcayton@tuebingen.mpg.de]
 */

#ifndef KERNELS_H
#define KERNELS_H

#include "defs.h"
__global__ void planNNKernel(const matrix,const unint*,const matrix,const intMatrix,real*,unint*,compPlan,unint);
__global__ void planKNNKernel(const matrix,const unint*,const matrix,const intMatrix,matrix,intMatrix,compPlan,unint);
__global__ void dist1Kernel(const matrix,unint,const matrix,unint,matrix);
__global__ void nnKernel(const matrix,unint,const matrix,real*,unint*);
__global__ void knnKernel(const matrix,unint,const matrix,matrix,intMatrix);
__global__ void findRangeKernel(const matrix,unint,real*,unint);
__global__ void rangeSearchKernel(const matrix,unint,unint,const real*,charMatrix);
__global__ void rangeCountKernel(const matrix,unint,const matrix,real*,unint*);
__device__ void sort16(real[][16],unint[][16]);
__device__ void sort16off(real[][48],unint[][48]);
__device__ void merge32x16(real[][48],unint[][48]);
__device__ void mmGateI(real*,real*,unint*,unint*);
__device__ void heapInsert(real x[][16], unint xi[][16], matrix h, intMatrix hi, unint rowOff);
__global__ void nnHeapKernel(const matrix Q, unint numDone, const matrix X, matrix dh, intMatrix dhi);
__global__ void setConstantKernel( matrix dx, unint numDone, real z );
__global__ void offDistKernel( const matrix dr, unint rStart, const matrix dx, unint xStart, matrix dD, intMatrix dI, unint colOff, unint indOff );
#endif
