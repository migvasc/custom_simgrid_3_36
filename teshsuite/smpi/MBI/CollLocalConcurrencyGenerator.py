#! /usr/bin/python3
import os
import sys
import generator_utils as gen

template = """// @{generatedby}@
/* ///////////////////////// The MPI Bugs Initiative ////////////////////////

  Origin: MBI

  Description: @{shortdesc}@
    @{longdesc}@

   Version of MPI: Conforms to MPI 3, requires MPI 3 implementation

BEGIN_MPI_FEATURES
  P2P!basic: Lacking
  P2P!nonblocking: Lacking
  P2P!persistent: Lacking
  COLL!basic: Lacking
  COLL!nonblocking: @{icollfeature}@
  COLL!persistent: @{pcollfeature}@
  COLL!tools: Lacking
  RMA: Lacking
END_MPI_FEATURES

BEGIN_MBI_TESTS
  $ mpirun -np 2 ${EXE}
  | @{outcome}@
  | @{errormsg}@
END_MBI_TESTS
//////////////////////       End of MBI headers        /////////////////// */

#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

#define buff_size 128

int main(int argc, char **argv) {
  int nprocs = -1;
  int rank = -1;
  int root = 0;

  MPI_Init(&argc, &argv);
  MPI_Comm_size(MPI_COMM_WORLD, &nprocs);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  printf("Hello from rank %d \\n", rank);

  if (nprocs < 2)
    printf("MBI ERROR: This test needs at least 2 processes to produce a bug!\\n");

  int dbs = sizeof(int)*nprocs; /* Size of the dynamic buffers for alltoall and friends */
  MPI_Op op = MPI_SUM;
  MPI_Comm newcom = MPI_COMM_WORLD;
  MPI_Datatype type = MPI_INT;

  @{init}@
  @{start}@
   @{operation}@
  @{write}@ /* MBIERROR */
  @{fini}@
  @{free}@

  MPI_Finalize();
  printf("Rank %d finished normally\\n", rank);
  return 0;
}
"""

for c in gen.icoll + gen.pcoll:
    patterns = {}
    patterns = {'c': c}
    patterns['generatedby'] = f'DO NOT EDIT: this file was generated by {os.path.basename(sys.argv[0])}. DO NOT EDIT.'
    patterns['icollfeature'] = 'Yes' if c in gen.icoll else 'Lacking'
    patterns['pcollfeature'] = 'Yes' if c in gen.pcoll else 'Lacking'
    patterns['c'] = c
    patterns['init'] = gen.init[c]("1")
    patterns['start'] = gen.start[c]("1")
    patterns['fini'] = gen.fini[c]("1")
    patterns['operation'] = gen.operation[c]("1")
    patterns['write'] = gen.write[c]("1")
    patterns['free'] = gen.free[c]("1")

    replace = patterns.copy()
    replace['shortdesc'] = 'Local concurrency with a collective'
    replace['longdesc'] = f'The buffer in {c} is modified before the call has been completed.'
    replace['outcome'] = 'ERROR: LocalConcurrency'
    replace['errormsg'] = 'Local Concurrency with a collective. The buffer in @{c}@ is modified at @{filename}@:@{line:MBIERROR}@ whereas there is no guarantee the call has been completed.'
    gen.make_file(template, f'LocalConcurrency_{c}_nok.c', replace)