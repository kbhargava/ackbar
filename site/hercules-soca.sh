#!/bin/bash
# Site configuration for NOAA hercules — SOCA-paper project (kritib).
#
#   export ACKBAR_SITE=hercules-soca
#   source site/activate.sh
#
# A separate site name from upstream's site/hercules.sh on purpose. Upstream now
# ships its own hercules.sh, and an untracked file of the same name blocks the
# next `git pull` outright (it did, on 2026-08-12). Keeping this project's answers
# under their own name means upstream's file stays as shipped, this one is never a
# merge conflict, and the two can be diffed to see what is project-specific.
#
# Every value below marked "probed" came from `tools/site-probe.sh` run on
# hercules-devel-1 on 2026-08-12, not from another machine's site file.

# --- environment -------------------------------------------------------------
# The verified spack-stack 2.0.0 toolchain, not upstream's UNVERIFIED 2.1.0 one.
# See the header of site/env/hercules-soca.sh for the three differences.
ACKBAR_ENV_SETUP=$ACKBAR_ROOT/site/env/hercules-soca.sh

# --- build -------------------------------------------------------------------
ACKBAR_NJOBS=20
ACKBAR_BUILD_TYPE=RelWithDebInfo
ACKBAR_CMAKE_GENERATOR=              # empty = make (always present)

# --- offline tools -----------------------------------------------------------
ACKBAR_MPI_TASKS=20                  # ranks for soca-diffusion/dirac/coldstart-ic
ACKBAR_OFFLINE_LAUNCHER="srun --mpi=pmi2 -n"   # no MPI on the login nodes

# --- data roots --------------------------------------------------------------
# Under the SOCA-paper project rather than upstream's $_work/ackbar/*, so the
# experiments, their inputs and the paper's notes sit in one tree.
ACKBAR_DATASETS_ROOT=/work2/noaa/jcsda/kritib/SOCA-paper/data/mom6-datasets
ACKBAR_STATIC_ROOT=/work2/noaa/jcsda/kritib/SOCA-paper/data/static
ACKBAR_SCRATCH_ROOT=/work2/noaa/jcsda/kritib/SOCA-paper/scratch
ACKBAR_OUTPUT_ROOT=/work2/noaa/jcsda/kritib/SOCA-paper/exp
ACKBAR_TEST_ROOT=/work2/noaa/jcsda/kritib/SOCA-paper/test

# --- scheduler ---------------------------------------------------------------
# probed: `sacctmgr show assoc user=kritib` gives da-cpu with an empty partition
# field and qos batch,debug,novel,ood,urgent,windfall. 'hercules' is the real
# partition; 'batch' is a QoS, not a partition, which is the mistake that cost
# the first two build submissions.
ACKBAR_PARTITION=hercules
ACKBAR_ACCOUNT=da-cpu
ACKBAR_QOS=batch

# probed: `srun --mpi=list` offers none, cray_shasta, pmi2, pmix. pmi2 matches
# the gcc/openmpi-4.1.4 stack. A wrong choice does not fail — it runs N ranks
# each alone in MPI_COMM_WORLD and Slurm records COMPLETED — so this must be
# confirmed against a program that prints MPI_Comm_size, never an exit code.
ACKBAR_LAUNCHER="srun --mpi=pmi2"

# probed: MaxJobCount = 10000 and MaxArraySize = 10001 cluster-wide, but the
# binding limit is the QoS: `sacctmgr show qos` gives batch a MaxSubmitPU of
# 400. That is the number validate's in-flight projection has to respect, so it
# is the one recorded here. Upstream's file guesses 10000 and would let a long
# experiment sail past the real cap.
ACKBAR_MAX_SUBMIT_JOBS=400
ACKBAR_MAX_ARRAY_SIZE=10001

# probed: DependencyParameters = kill_invalid_depend, so a job whose dependency
# can never be met is killed rather than left pending forever. MinJobAge is 300s,
# which is why submit.py re-checks each parent's state instead of trusting that
# an afterok edge still resolves.
ACKBAR_CAN_SUBMIT_FROM_COMPUTE=yes   # to be confirmed at rung 2; nothing reads it yet
