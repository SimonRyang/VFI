#include "global.h"
#include "cublas_v2.h"
#include <iostream>
#include <ctime>
#include <typeinfo>
#include <fstream>

using namespace std;

#include "ar1.cu"
#include "kGrid.cu"
#include "vfInit.cu"
#include "vfStep.cu"

//////////////////////////////////////////////////////////////////////////////
///
/// @fn main()
///
/// @brief Main function for the VFI problem.
///
/// @details This function performs value function iteration on the GPU,
/// finding the maximum of the Bellman objective function for each node in
/// the state space and iterating until convergence.
///
/// @returns 0 upon successful complete, 1 otherwise.
///
/// @author Eric M. Aldrich \n
///         ealdrich@ucsc.edu
///
/// @version 1.0
///
/// @date 24 July 2012
///
/// @copyright Copyright Eric M. Aldrich 2012 \n
///            Distributed under the Boost Software License, Version 1.0
///            (See accompanying file LICENSE_1_0.txt or copy at \n
///            http://www.boost.org/LICENSE_1_0.txt)
///
//////////////////////////////////////////////////////////////////////////////
int main()
{ 

  // admin
  int imax;
  REAL diff = 1.0;
  cublasHandle_t handle;
  cublasStatus_t status;
  status = cublasCreate(&handle);
  REAL negOne = -1.0;
  double tic = curr_second(); // Start time

  // Load parameters
  parameters params;
  params.load("../parameters.txt");
  int nk = params.nk;
  int nz = params.nz;

  // pointers to variables in device memory
  REAL *K, *Z, *P, *V0, *V, *G, *Vtemp;

  // allocate variables in device memory
  size_t sizeK = nk*sizeof(REAL);
  size_t sizeZ = nz*sizeof(REAL);
  size_t sizeP = nz*nz*sizeof(REAL);
  size_t sizeV = nk*nz*sizeof(REAL);
  size_t sizeG = nk*nz*sizeof(REAL);
  cudaMalloc((void**)&K, sizeK);
  cudaMalloc((void**)&Z, sizeZ);
  cudaMalloc((void**)&P, sizeP);
  cudaMalloc((void**)&V0, sizeV);
  cudaMalloc((void**)&Vtemp, sizeV);
  cudaMalloc((void**)&V, sizeV);
  cudaMalloc((void**)&G, sizeG);

  // blocking
  const int block_size = 4; ///< Block size for CUDA kernel.
  dim3 dimBlockZ(nz, 1);
  dim3 dimBlockK(block_size,1);
  dim3 dimBlockV(block_size, nz);
  dim3 dimGridZ(1,1);
  dim3 dimGridK(nk/block_size,1);
  dim3 dimGridV(nk/block_size,1);

  // compute TFP grid, capital grid and initial VF
  ar1<<<dimGridZ,dimBlockZ>>>(params,Z,P);
  kGrid<<<dimGridK,dimBlockK>>>(params,Z,K);
  vfInit<<<dimGridV,dimBlockV>>>(params,Z,V0);

  // iterate on the value function
  int count = 0;
  bool how = false;
  while(fabs(diff) > params.tol){
    if(count < 3 | count % params.howard == 0) how = false; else how = true;
    vfStep<<<dimGridV,dimBlockV>>>(params,how,K,Z,P,V0,V,G);
    if(typeid(realtype) == typeid(singletype)){
      status = cublasSaxpy(handle, nk*nz, (float*)&negOne, (float*)V, 1, (float*)V0, 1);
      status = cublasIsamax(handle, nk*nz, (float*)V0, 1, &imax);
    } else if(typeid(realtype) == typeid(doubletype)){
      status = cublasDaxpy(handle, nk*nz, (double*)&negOne, (double*)V, 1, (double*)V0, 1);
      status = cublasIdamax(handle, nk*nz, (double*)V0, 1, &imax);
    }
    cudaMemcpy(&diff, V0+imax, sizeof(REAL), cudaMemcpyDeviceToHost);
    Vtemp = V0;
    V0 = V;
    V = Vtemp;
    ++count;
  }
  V = V0;
  
  // Compute solution time
  REAL toc = curr_second();
  REAL solTime  = toc - tic;

  // copy value and policy functions to host memory
  REAL* hV = new REAL[nk*nz];
  REAL* hG = new REAL[nk*nz];
  cudaMemcpy(hV, V, sizeV, cudaMemcpyDeviceToHost);
  cudaMemcpy(hG, G, sizeG, cudaMemcpyDeviceToHost);

  // free variables in device memory
  cudaFree(K);
  cudaFree(Z);
  cudaFree(P);
  cudaFree(V0);
  cudaFree(V);
  cudaFree(Vtemp);
  cudaFree(G);
  cublasDestroy(handle);

  // write to file (row major)
  ofstream fileSolTime, fileValue, filePolicy;
  fileSolTime.open("solutionTime.dat");
  fileValue.open("valueFunc.dat");
  filePolicy.open("policyFunc.dat");
  fileSolTime << solTime << endl;
  fileValue << nk << endl;
  fileValue << nz << endl;
  filePolicy << nk << endl;
  filePolicy << nz << endl;
  for(int jx = 0 ; jx < nz ; ++jx){
    for(int ix = 0 ; ix < nk ; ++ix){
      fileValue << hV[ix*nz+jx] << endl;
      filePolicy << hG[ix*nz+jx] << endl;
    }
  }  
  fileSolTime.close();
  fileValue.close();
  filePolicy.close();

  return 0;

}
