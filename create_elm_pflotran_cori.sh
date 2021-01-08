#!/bin/sh 
# Script to run elm-pflotran regional case on cori.
# Bowen Zhu, 08/12/2019; 

# 1. Clone PFLOTRAN and switch to the correct branch
# git clone https://bitbucket.org/pflotran/pflotran pflotran
# cd pflotran
# git checkout gbisht/elm-pflotran-coupling
export PFLOTRAN_SRC_DIR=/global/project/projectdirs/m2702/zhub210/pflotran
# cd ..
 
 
# 2. Clone E3SM, switch to the correct branch, and checkout submodules
# git clone https://github.com/CLM-PFLOTRAN/e3sm elm-fork
# cd elm-fork
# git checkout bishtgautam/lnd/elm-pflotran-coupled-70b3e8f36
# git submodule update --init
# cd ../



# 2.1 Set path PETSc
export PETSC_VERSION=v3.11.1
export PETSC_DIR=/project/projectdirs/m2702/gbisht/petsc/petsc_${PETSC_VERSION}
export PETSC_ARCH=cori_knl_intel_18_0_1
 
# 2.2 Load correct modules
module swap craype-haswell craype-mic-knl
module swap intel/19.0.3.199  intel/18.0.1.163
module load cray-netcdf-hdf5parallel/4.6.1.3 cray-hdf5-parallel/1.10.2.0 cray-parallel-netcdf/1.8.1.4
 
 
# 2.3 Generate libpflotran.a
# cd pflotran/src/clm-pflotran/
# ./link_files.sh
# make -j 4 libpflotran.a
 
# cd ../../../

# Set path
export CASE_DIR=$PWD/couple_cases
export COMPSET=ICLM45
export RES_NAME=UCPR_1km
export LND_NTASKS=400
export MACH=cori-knl
export RES=CLM_USRDAT
export CASE_NAME=elm.pflotran.${RES_NAME}.np${LND_NTASKS}-${COMPSET}-phd-201617_5-`date "+%Y-%m-%d"`

export OUTPUT_DIR=/global/cscratch1/sd/zhub210
export INPUTDATA_DIR=${OUTPUT_DIR}/inputdata
# delete the old casedir/rundir
rm -rf ${CASE_DIR}/${CASE_NAME}
rm -rf ${OUTPUT_DIR}/acme_scratch/${MACH}/${CASE_NAME}


# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Now do the ELM stuff
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
mkdir -p ${INPUTDATA_DIR}/cesm_inputdata/atm/datm7/${RES_NAME}/CLM1PT_data
rm -f ${INPUTDATA_DIR}/cesm_inputdata/atm/datm7/${RES_NAME}/CLM1PT_data/*.nc
ls -l ${INPUTDATA_DIR}/user_inputdata/UCPR_1km/clmforc/*.nc | awk '{ print $9}' | awk -F'.' '{print $3}' | \
awk -v INPUTDATA_DIR=${INPUTDATA_DIR} -v RES_NAME=${RES_NAME} \
'{ system( "ln -s " INPUTDATA_DIR "/user_inputdata/UCPR_1km/clmforc/clmforc.hanford." $1 ".nc " INPUTDATA_DIR"/cesm_inputdata/atm/datm7/" RES_NAME "/CLM1PT_data/" $1 ".nc") }'

cd /project/projectdirs/m2702/zhub210/elm-fork/cime/scripts
./create_newcase -case ${CASE_DIR}/${CASE_NAME} -res ${RES} -mach ${MACH} -compset ${COMPSET} -compiler intel

# Configuring case :
cd $CASE_DIR/$CASE_NAME

# Copy Macros file that include settings for PETSc and PFLOTRAN
 
cp /project/projectdirs/m2702/gbisht/petsc/Macros.cmake.${PETSC_VERSION}.${PETSC_ARCH} ./Macros.cmake
cp /project/projectdirs/m2702/gbisht/petsc/Macros.make.${PETSC_VERSION}.${PETSC_ARCH}  ./Macros.make

# Make changes Macros.cmake file
perl -w -i -p -e "s@PETSC-DIR@${PETSC_DIR}@"               ${CASE_DIR}/${CASE_NAME}/Macros.cmake
perl -w -i -p -e "s@PETSC-ARCH@${PETSC_ARCH}@"             ${CASE_DIR}/${CASE_NAME}/Macros.cmake
perl -w -i -p -e "s@PFLOTRAN-SRC-DIR@${PFLOTRAN_SRC_DIR}@" ${CASE_DIR}/${CASE_NAME}/Macros.cmake
 
# Make changes Macros.make file
perl -w -i -p -e "s@PETSC-DIR@${PETSC_DIR}@"               ${CASE_DIR}/${CASE_NAME}/Macros.make
perl -w -i -p -e "s@PETSC-ARCH@${PETSC_ARCH}@"             ${CASE_DIR}/${CASE_NAME}/Macros.make
perl -w -i -p -e "s@PFLOTRAN-SRC-DIR@${PFLOTRAN_SRC_DIR}@" ${CASE_DIR}/${CASE_NAME}/Macros.make

# Modifying : env_run.xml
./xmlchange --file env_run.xml --id DATM_CLMNCEP_YR_END --val 2018
./xmlchange --file env_run.xml --id STOP_N --val 2
./xmlchange --file env_run.xml --id REST_N --val 1
./xmlchange --file env_run.xml --id RUN_STARTDATE --val 2016-01-01
./xmlchange --file env_run.xml --id STOP_OPTION --val nyears
./xmlchange --file env_run.xml --id DATM_CLMNCEP_YR_START --val 2016
./xmlchange --file env_run.xml --id DATM_CLMNCEP_YR_ALIGN --val 2016
./xmlchange --file env_run.xml --id DATM_MODE --val CLM1PT
./xmlchange --file env_run.xml --id CLM_USRDAT_NAME --val ${RES_NAME}
./xmlchange --file env_run.xml --id DIN_LOC_ROOT --val ${INPUTDATA_DIR}/cesm_inputdata
./xmlchange --file env_run.xml --id DIN_LOC_ROOT_CLMFORC --val ${INPUTDATA_DIR}/cesm_inputdata/atm/datm7
./xmlchange ATM_DOMAIN_FILE=domain.atm.hanford_00625x00625_c190522.nc
./xmlchange LND_DOMAIN_FILE=domain.lnd.1kmx1km_UCPR_noriver_c20200326.nc
./xmlchange ATM_DOMAIN_PATH=${INPUTDATA_DIR}/user_inputdata/UCPR_1km/triangle
./xmlchange LND_DOMAIN_PATH=${INPUTDATA_DIR}/user_inputdata/UCPR_1km/triangle
./xmlchange LND_NTASKS=$LND_NTASKS
./xmlchange PROJECT=m1800
./xmlchange ATM_NCPL=2

# Modifying the TIME LIMIT
./xmlchange JOB_WALLCLOCK_TIME=47:00:00

#
# Modify user_nl_clm
cat >> user_nl_clm << EOF
use_pflotran_via_emi = .true.
hist_mfilt  = 1
hist_nhtfrq = -24
pflotran_prefix      = '$CASE_NAME'
fsurdat               = '${INPUTDATA_DIR}/user_inputdata/UCPR_1km/triangle/surfdata.1kmx1km_UCPR_noriver_c20200326.nc'
finidat = '${INPUTDATA_DIR}/cesm_inputdata/lnd/clm2/initdata_map/elm.UCPR_1km.np400-ICLM45-spinup-2020-04-07.clm2.r.2020-01-01-00000.nc'
EOF
 

# Modify user_nl_datm
cat >> user_nl_datm << EOF
domainfile="${INPUTDATA_DIR}/user_inputdata/UCPR_1km/triangle/domain.lnd.1kmx1km_UCPR_noriver_c20200326.nc"
taxmode = 'cycle', 'cycle','cycle'
EOF


# Setup the case
./case.setup
 
# Build the case
./case.build


 
# Copy PFLOTRAN related files in the run directory
export RUNDIR=`./xmlquery RUNDIR | awk '{ print $2 }'`
 

cp /global/cscratch1/sd/zhub210/pflotran/1km_ug_old/input/PRW_1km_unstructured.in        $RUNDIR/$CASE_NAME.in
cp /global/cscratch1/sd/zhub210/pflotran/1km_ug_old/input/1km_prism_ugrid*.meshmap   $RUNDIR/
cp /global/cscratch1/sd/zhub210/pflotran/1km_ug_old/input/1km_prism_ugrid.h5   $RUNDIR/
cp /global/cscratch1/sd/zhub210/pflotran/1km_ug_old/input/elm.pflotran.UCPR_1km.np400-ICLM45-phd-201617_5-2020-12-22-8760.0000h.h5 $RUNDIR/PRW_1km_unstructured-restart.h5

cd $RUNDIR
cd ..
mkdir inputs
cd inputs
ln -s /global/cscratch1/sd/zhub210/pflotran/inputs_noleak/new/new3/stage_6h_smooth_2016_2017 stage_6h_smooth_2010_2018

cp -f ${CASE_DIR}/${CASE_NAME}/CaseDocs/datm.streams.txt.CLM1PT.CLM_USRDAT ${CASE_DIR}/${CASE_NAME}/user_datm.streams.txt.CLM1PT.CLM_USRDAT
chmod +rw ${CASE_DIR}/${CASE_NAME}/user_datm.streams.txt.CLM1PT.CLM_USRDAT
perl -w -i -p -e 's@QBOT     shum@RH       rh@' ${CASE_DIR}/${CASE_NAME}/user_datm.streams.txt.CLM1PT.CLM_USRDAT
sed -i '/ZBOT/d' ${CASE_DIR}/${CASE_NAME}/user_datm.streams.txt.CLM1PT.CLM_USRDAT
 

cd $CASE_DIR/$CASE_NAME
# Submit the case
./case.submit
#echo ''
#echo 'case submitted'
#echo ''
