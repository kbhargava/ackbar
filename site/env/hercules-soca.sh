#!/bin/bash
# Toolchain for ACKBAR on NOAA hercules — SOCA-paper project.
#
# Sourced by site/activate.sh via ACKBAR_ENV_SETUP in site/hercules-soca.sh.
# Nothing here may set an ACKBAR_* variable: this file answers "what compiler and
# libraries", the site file answers "what paths and queues".
#
# This is a VERIFIED variant of the upstream site/env/hercules.sh, which is
# marked UNVERIFIED and was written from what jedi-tools does rather than run.
# Three differences, each of which was required to get a build to complete on
# 2026-08-10 (jobs 9523988..9524125):
#
#   1. spack-stack 2.0.0, not 2.1.0.  This is the stack the JEDI/SOCA bundle and
#      MOM6-SIS2 were actually built against here.
#   2. jedi-fv3-env + soca-env are loaded.  Upstream loads only stack-gcc,
#      stack-openmpi and stack-python, which do not provide eckit, atlas, fckit,
#      fms or gsw; the bundle does not vendor those and will not configure
#      without them.
#   3. The two link-time fixes below, neither of which upstream carries.
#
# gcc rather than intel/oneapi because MOM6's build uses gfortran-only flags
# (-fallow-argument-mismatch, -fallow-invalid-boz), which ifx rejects outright.

module purge
module use /work/noaa/epic/role-epic/spack-stack/hercules/modulefiles
module load git-lfs/3.1.2
module use /apps/contrib/spack-stack/spack-stack-2.0.0/envs/ue-gcc-12.2.0/modules/Core
module load stack-gcc/12.2.0
module load stack-openmpi/4.1.4
module load jedi-fv3-env          # brings fms (needed by MOM6) + base JEDI deps
module load soca-env              # SOCA-specific deps

# OpenMPI here is not built against Slurm's PMIx by default, so a job step needs
# to be told which PMI to use. Without it srun starts N copies of a serial
# program, each its own MPI_COMM_WORLD of size one, and the job still reports
# COMPLETED. ACKBAR_LAUNCHER in the site file spells the same thing on the
# command line; both are set because either alone has been enough to leave the
# other silently unused. `srun --mpi=list` here offers none/cray_shasta/pmi2/pmix.
export SLURM_MPI_TYPE=pmi2

# From upstream site/env/orion.sh: HDF5 refuses to open a file on a Lustre mount
# that reports a lock it cannot take, and a job step otherwise inherits a
# stripped environment.
export HDF5_USE_FILE_LOCKING=FALSE
export SLURM_EXPORT_ENV=ALL

# FIX 1 (link time). netcdf-c pulls in spack's libcurl, which needs OpenSSL 3.2's
# SSL_get0_group_name. No openssl module is loaded, so ld resolves against RHEL9's
# system openssl 3.0 (missing the symbol) and the link dies with
# `undefined reference to SSL_get0_group_name@OPENSSL_3.2.0`. Point ld at the
# spack openssl (3.4.1 provides the @OPENSSL_3.2.0 version node). Measured: -L
# alone did not fix it, and LD_LIBRARY_PATH alone did not either; the working
# combination is -L together with -rpath-link, injected through LDFLAGS, which
# MOM6's autoconf configure honors.
_ssl=$(ls -d /apps/contrib/spack-stack/spack-stack-2.0.0/envs/ue-gcc-12.2.0/install/gcc/12.2.0/openssl-*/lib64 2>/dev/null | head -1)
if [ -n "$_ssl" ]; then
  export LD_LIBRARY_PATH="${_ssl}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LDFLAGS="-L${_ssl} -Wl,-rpath-link,${_ssl} ${LDFLAGS:-}"
fi
unset _ssl

# FIX 2 (link time). spack modules export LD_LIBRARY_PATH (runtime) but not
# LIBRARY_PATH (link time), so raw autoconf builds like FMS fail with
# `ld: cannot find -lopenblas`. Mirror it so gcc's link-time -l search finds the
# spack libs. ecbuild passes -L explicitly and does not need this; MOM6's FMS
# configure does. Kept last so it also picks up the openssl dir added above.
export LIBRARY_PATH="${LD_LIBRARY_PATH}${LIBRARY_PATH:+:$LIBRARY_PATH}"
