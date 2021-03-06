//////////////////////////////////////////////////////////////////////////////
///
/// @file binaryVal.cpp
///
/// @brief File containing a CUDA device function which finds the approximate
/// location of a value in a vector with monotonically increasing values.
///
/// @author Eric M. Aldrich \n
///         ealdrich@ucsc.edu
///
/// @version 1.0
///
/// @date 23 Oct 2012
///
/// @copyright Copyright Eric M. Aldrich 2012 \n
///            Distributed under the Boost Software License, Version 1.0
///            (See accompanying file LICENSE_1_0.txt or copy at \n
///            http://www.boost.org/LICENSE_1_0.txt)
///
//////////////////////////////////////////////////////////////////////////////

#include "global.h"

//////////////////////////////////////////////////////////////////////////////
///
/// @brief CUDA device function to find the location of a value in a
/// monotonic grid.
///
/// @details This function finds the first value X[ix] such that x <= X[ix],
/// where x is a scalar value, X is a monotonic array, and ix is the index
/// of X.
///
/// @param [in] x Value to search for in vector X.
/// @param [in] nx Length of array X.
/// @param [in] X Vector of data to search.
///
/// @return imax Integer ix (<= nx) such that x <= X[ix].
///
//////////////////////////////////////////////////////////////////////////////
__device__ int binaryVal(const REAL x, const int n, const REAL* X)
{

  int imax;

  // check if x is out of bounds
  if(x < X[0]){
    imax = 0;
    return imax;
  }
  if(x > X[n-1]){
    imax = n-1;
    return imax;
  }

  // otherwise
  int ilo, ihi, imid;
  ilo = 0;
  ihi = n-1;
  while((ihi-ilo) > 1){
    imid = (ilo + ihi)/2;
    if(X[imid] == x){
      imax = imid;
      return imax;
    } else if(X[imid] > x){
      ihi = imid;
    } else ilo = imid;
  }  
  imax = ihi;
  return imax;
}
