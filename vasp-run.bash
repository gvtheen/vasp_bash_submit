############################################
####                                    ####
####  Author: Guilin Zhuang             ####
####  E-mail: glzhuang@zjut.edu.tn      ####
####                                    ####
############################################

#!/bin/bash

pbs_file=vasp-sugon-new.pbs
INCAR_PARA_FILE=""

############# for normal submit
#####   current path: /XXX/qqq/
#####   sub_path="OPT"
#####   sumit the all jobs in the OPT folder of all folers in current path
RUNNING_PATH="OPT"

####################Following keywords must be setted in the series_running 
######## IS_Series_Running=T    Or   F
IS_Series_Running=F
########optimization folder
OPT_PATH="OPT"
##################

############# for dos
DOS_SCF_PATH=1
DOS_NOSCF_PATH=2
INCAR_template=INCAR.in
#############

############## donot need to be modified
machine_name=`uname -a | awk '{print $2}'`
pwd_str=`pwd`
VASP_FILES="INCAR KPOINTS POSCAR POTCAR"
tmp_ID=".job_ID"
taskindex=$[0]
Shellname="$0"
#############

#############
#### check files of VASP
function checkfile(){
     err="TRUE"
     if [ -f $1 ]
        then
        err="TRUE"
     else
        if [ x$2 = "xVASP" ];then 
           echo " $1 file has no $file_name required by VASP calculations!" >> ${pwd_str}/ERROR
        fi
        err="FALSE"
     fi
     echo $err
}
function checkpath(){
     err="TRUE"

     if [ -d $1 ]
        then
        err="TRUE"
     else
        if [ x$2 = "xVASP" ];then 
           echo " $1 file has no $file_name required by VASP calculations!" >> ${pwd_str}/ERROR
        fi
        err="FALSE"
     fi
     echo $err
}
function check(){
     cd ${pwd_str}
       ###rm -rf ${pwd_str}/ERROR
     err="TRUE"
     LScmd=""
     
     str=${pwd_str}
     if [ $# -eq 0 ]
     then
        cd ${pwd_str}
        LScmd="ls"
     else
        LScmd="ls $1"
     fi
     
     for a in `$LScmd`
      do
       if [ -d $a ];then
         for file_name in ${VASP_FILES}
         do
            err=`checkfile ${str}/$a VASP`
         done
       fi
      done
     
     if [ ${err} = "ERROR" ]
     then
       cat ${pwd_str}/ERROR
     fi
     echo $err
}
function checkIsRunningJob(){
##### $1:  jobing path of testing jobs

   res="FALSE"
   
   qstat | awk '{print $1}' | awk -F '.' '{print $1}' | tail -n +3 >${pwd_str}/.tmpRunningID
   
   for b in `cat ${pwd_str}/.tmpRunningID`
    do
       qstat -f $b | grep $1 > /dev/null
       if [ $? -eq 0 ]
       then
          state=`qstat ${b} | tail -1 | awk '{print $5}'`
          if [ ${state} = "R" ] || [ ${state} = "Q" ]
          then
             res="TRUE"
             if [ ${2}_x = "RECORD_x" ];then
                echo "$b    $1    State_${state}" >> ${pwd_str}/${tmp_ID}
             fi
             break
          fi               
       fi
    done
    rm -rf ${pwd_str}/.tmpRunningID
    echo $res
    return 0
}
###check whether this job in current path is finished with disregarding finished states
function checkIsRecordedJob(){
    res="FALSE"
    
    if [ `checkfile ${pwd_str}/${tmp_ID}` = "TRUE" ];then
        grep $1  ${pwd_str}/${tmp_ID} > /dev/null
        if [ $? -eq 0 ];then
          res="TRUE"
        fi
     fi
     
    echo $res
    return 0
}
function checkIsRunningShell(){

    time_str=`date --date="-24 hour" +%H:%M`
    
    ps -ef | grep "${Shellname}" | grep -v "grep\|${time_str}" > ${pwd_str}/.tmp_shell
  #  n=`grep -n "grep" ${pwd_str}/.tmp_shell | awk '{print $1}' |awk -F ':' '{print $1}'`
  #  sed -i ''${n}''d'' ${pwd_str}/.tmp_shell > /dev/null
    
    cat ${pwd_str}/.tmp_shell | awk '{print $2}' > ${pwd_str}/.tmp_shell2
    res="FALSE"
    for idi in `cat ${pwd_str}/.tmp_shell2`
      do
         ls -la /proc/${idi} | grep "cwd" | awk -F '->' '{print $2}' | grep ${pwd_str} >/dev/null
         if [ $? -eq 0 ];then
           res="TRUE"
           break
         fi
      done
     rm -rf ${pwd_str}/.tmp_shell ${pwd_str}/.tmp_shell2
     echo $res
     return 0
}
#####check job
function check_isNormalFinish(){
   res="FALSE"
   if [ -f $1 ];then
     grep "General timing and accounting informations" $1 >/dev/null
     if [ $? -eq 0 ];then
        res="TRUE"
     else
        res="FALSE"
     fi 
   fi
   echo $res
   return 0
}
function check_job(){  
    
 ###   echo "check_job()"
    
    rm -rf ${pwd_str}/.jobstate
    #####  #1: ID_Forlder
    if [ x$1 = "x" ]
     then
     file="${tmp_ID}"
    else
     file=$1
    fi
    
    if [ `checkfile ${pwd_str}/${file}` = "FALSE" ];then
       exit 1
    fi
    
    awk '{print $1}' ${pwd_str}/${file} > ${pwd_str}/.tmpfile
    
    for b in `cat ${pwd_str}/.tmpfile`
     do
       row=`grep -n $b ${pwd_str}/${file} | awk '{print $1}' | awk -F ':' '{print $1}'`
       
       jobpath=`grep $b ${pwd_str}/${file} | awk '{print $2}'` 
       
       qstat | grep ${b} > /dev/null
       if [ $? -eq 0 ]
       then 
          state=`qstat ${b} | tail -1 | awk '{print $5}'`
          
          sed -i ''${row}''c' '$b'     '${jobpath}'     'State_${state}'' ${pwd_str}/${file}
       else
          if [ `check_isNormalFinish $jobpath/OUTCAR` = "TRUE" ];then      
               enery=`read_single_energy $jobpath`
               sed -i ''${row}''c' '$b'     '${jobpath}'     '$energy'' ${pwd_str}/${file}
          else
               sed -i ''${row}''c' '$b'     '${jobpath}'      ERROR' ${pwd_str}/${file} 
          fi
       fi
     done
    rm -rf ${pwd_str}/.tmpfile
}
function check_all_jobs_state(){

     check_job ${tmp_ID}
     
     res="TRUE"
     
     awk '{print $3}' ${pwd_str}/${tmp_ID} >${pwd_str}/.tmp_state_check
     
     grep "State_R" ${pwd_str}/.tmp_state_check >/dev/null
     if [ $? -eq 0 ] 
     then
        res="FALSE"
     fi
     
     grep "State_Q" ${pwd_str}/.tmp_state_check >/dev/null
     if [ $? -eq 0 ] 
     then
        res="FALSE"
     fi
     
     rm -rf ${pwd_str}/.tmp_state_check
     echo $res
     return 0
}
### read energy from OUTCAR
function read_single_energy(){
   str=""
   if [ $# -eq 0 ];then
        cd ${pwd_str}
   else
      i=$[0]
      for s in "$@"
      do
        if [ $i -eq 0 ];then
           str=${s}
        else
           str=${str}/${s} 
        fi
        i=$[$i + 1]
      done 
        if [ -d $str ];then
          cd $str
        else
          echo "${str} in reading energy is not exit!"
          return 1
        fi
   fi
   
   if [ `check_isNormalFinish ${str}/OUTCAR` = "TRUE" ];then
      energy=`grep " energy(sigma->0)" ${str}/OUTCAR | tail -1 | awk '{print $7}'`
      echo $energy
      return 0
   else
      echo "abnormal output"
      return 1
   fi
}
############read energy 
function read_energy(){
     if [ x$1 = "x" ]
     then
       cd ${pwd_str}
     
       for a in `ls`
        do
         if [ -d $a ];then
           cd ./$a
           if [ -f ${pwd_str}/$1/OUTCAR ];then
              grep "General timing and accounting informations" ${pwd_str}/$1/OUTCAR >/dev/null
              if [ $? -eq 0 ] 
              then
                 energy=`grep " energy(sigma->0)" ${pwd_str}/$a/OUTCAR | tail -1 | awk '{print $7}'`
                 echo "$1    ${energy}" >>${pwd_str}/energy_out
              else
                 echo "$1    ERROR_OUTPUT" >>${pwd_str}/energy_out
              fi
           else
                 echo "$1    ERROR_OUTPUT" >>${pwd_str}/energy_out
           fi
         fi
       done
     else  
       grep "General timing and accounting informations" ${pwd_str}/$1/OUTCAR >/dev/null
       if [ $? -eq 0 ] 
       then
         energy=`grep " energy(sigma->0)" ${pwd_str}/${1}/OUTCAR | tail -1 | awk '{print $7}'`
         
         row=`grep -n "$1"  ${pwd_str}/energy_out | awk '{print $1}'`
         if [ ${row}x = "x" ];then
            echo "$1    ${energy}" >>${pwd_str}/energy_out
         else
            res1="$1    ${energy}"
            sed -i ''${row}''c' '${1}' '${energy}'' ${pwd_str}/energy_out

         fi
       else
         echo "$1    ERROR_OUTPUT" >>${pwd_str}/energy_out
       fi
     fi
}
###delete jobs
function del_jobs(){
     if [ `checkfile ${pwd_str}/${tmp_ID}` = "TRUE" ];then
        awk '{print $1}' ${pwd_str}/${tmp_ID} > ${pwd_str}/.tmpfile
        for b in `cat ${pwd_str}/.tmpfile`
        do
           state=`qstat ${b} | tail -1 | awk '{print $5}'`
           if [ ${state}_state = "R_state" ] || [ ${state}_state = "Q_state" ]
           then
               qdel $b >/dev/null
           fi       
        done
     else
        return 1
     fi
     rm -rf ${pwd_str}/.tmpfile
}
####submit job_1
function submit_job_wait(){

     rm -rf ${pwd_str}/.${tmp_ID}   
     
     LScmd=""
     str=${pwd_str}
     if [ $# -eq 0 ]
     then
        cd ${pwd_str}
        LScmd="ls"
     else
        for s in "$@"
          do
               str=${str}/${s} 
          done
        if [ -d $str ];then
          LScmd="ls $str"
          cd $str
        else
          echo "${str} folder is not exit!"
          return 1
        fi
     fi
     
     for a in `$LScmd`
     do
      if [ -d ${str}/$a ];then
        if [ ${RUNNING_PATH}null = "null" ];then
               cd ${str}/$a
        else
            if [ -d ${str}/$a/${RUNNING_PATH} ];then
               cd ${str}/$a/${RUNNING_PATH}
            else
               echo "${str}/$a/${RUNNING_PATH} is not exit!"
               return 1
            fi
        fi
        
        #### check whether the job will be run
        current_job_path=`pwd`
        
        if [ `checkIsRecordedJob ${current_job_path}`x = "TRUEx" ];then
           continue
        else
           echo "checkIsRunningJob in ${current_job_path}"
           if [ `checkIsRunningJob ${current_job_path} RECORD`x = "TRUEx" ];then          
               continue
           fi
        fi
        if [ `check_isNormalFinish ${current_job_path}/OUTCAR` = "TRUE" ];then
           continue
        fi
        
        while true
          do
            free_node=`pestat | grep "free" | awk '{ print $1 }'`    
            if [ ${free_node}x = "x" ]
            then
               sleep 120       
            else 
               ##### submit         
               cp -rf ${pwd_str}/${pbs_file} ./
            
            ##### according to INCAR_para.in file, revise INCAR file  
            if [ `checkfile ${path_str}/INCAR_para.in` = "TRUE" ]
            then
              for cmdValue in `cat ${path_str}/INCAR_para.in`
               do
                 newkeyword=`echo ${cmdValue} | awk -F '=' '{print $1}'`
                 row=`grep -n ${newkeyword}  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
                 if [ x${row} = "x" ]
                 then
                    sed -i '3a '${cmdValue}'' ./INCAR
                 else
                    sed -i ''${row}''c' '${cmdValue}'' ./INCAR 
                 fi
              done
            fi
            
            run_bol="TRUE"
            if [ ${IS_Series_Running}x = "Tx" ] || [ ${IS_Series_Running}x = "tx" ] && [ ${OPT_PATH} != ${RUNNING_PATH} ];then
                if [ `check_isNormalFinish ${currpath}/${a}/${OPT_PATH}/OUTCAR` = "TRUE" ];then
               
                  if [ `checkfile ${currpath}/${a}/${OPT_PATH}/CONTCAR` = "TRUE" ];then
                  
                     cp ${currpath}/${a}/${OPT_PATH}/CONTCAR  ${currpath}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}/POSCAR
                     
                  else
                     echo "${currpath}/${a}/${OPT_PATH}/CONTCAR isnot exist! DOS calculation was suspended" >> bash.out
                     continue
                  fi
               else
                  run_bol="FALSE"
                  continue
               fi 
            fi
            if [ ${run_bol} = "TRUE" ];
            then
               sed -i '1c #PBS -N '${a}'_'${RUNNING_PATH}'' ./${pbs_file} 
               
               res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
               
               if [ ${RUNNING_PATH}null = "null" ];then
                  echo "$res     ${str}/$a" >>${pwd_str}/${tmp_ID} 
               else
                  echo "$res     ${str}/$a/${RUNNING_PATH}" >>${pwd_str}/${tmp_ID}  
               fi
               taskindex=$[$taskindex + 1]
               break 
               fi
            fi 
        done 
      fi    
     done

}

####submit job_2
function submit_job(){

     rm -rf ${pwd_str}/${tmp_ID}  
      
     LScmd=""
     str=${pwd_str}
     if [ $# -eq 0 ]
     then
        cd ${pwd_str}
        LScmd="ls ./"
     else
        for s in "$@"
          do
               str=${str}/${s} 
          done
        if [ -d $str ];then
          LScmd="ls $str"
          cd ${str}
        else
          echo "${str} is not exit!"
          return 1
        fi
     fi
     
     for a in `$LScmd`
     do
       
      if [ -d ${str}/$a ];then
        if [ ${RUNNING_PATH}null = "null" ];then
            cd ${str}/$a
        else
            if [ -d ${str}/$a/${RUNNING_PATH} ];then
               cd ${str}/$a/${RUNNING_PATH}
            else
               echo "${str}/$a/${RUNNING_PATH} is not exit!"
               exit 1
            fi
        fi

        #### check whether the job will be run
        current_job_path=`pwd`     
        if [ `checkIsRecordedJob ${current_job_path}`x = "TRUEx" ];then
           continue
        else
           if [ `checkIsRunningJob ${current_job_path} RECORD`x = "TRUEx" ];then          
               continue
           fi
        fi
        if [ `check_isNormalFinish ${current_job_path}/OUTCAR` = "TRUE" ];then
           continue
        fi
        
        ##### submit       
        cp -rf ${pwd_str}/${pbs_file} ./
        
        if [ `checkfile ${path_str}/${INCAR_PARA_FILE}` = "TRUE" ]
         then
           numi=0
           for cmdValue in `cat ${path_str}/INCAR_para.in`
            do
               newkeyword=`echo ${cmdValue} | awk -F '=' '{print $1}'`
               row=`grep -n ${newkeyword}  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
               numi=$[ $numi + 2 ]
               if [ x${row} = "x" ]
               then
                  sed -i ''${numi}''a' '${cmdValue}'' ./INCAR
               else
                  sed -i ''${row}''c' '${cmdValue}'' ./INCAR 
               fi
            done
         fi
        
       #  echo "submit job 1 runbol"
       
         run_bol="TRUE"
         if [ ${IS_Series_Running}_o = "T_o" ] || [ ${IS_Series_Running}_o = "t_o" ] && [ ${OPT_PATH} != ${RUNNING_PATH} ];then
             if [ `check_isNormalFinish ${currpath}/${a}/${OPT_PATH}/OUTCAR` = "TRUE" ];then
               
               if [ `checkfile ${currpath}/${a}/${OPT_PATH}/CONTCAR` = "TRUE" ];then
               
                  cp ${currpath}/${a}/${OPT_PATH}/CONTCAR  ${currpath}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}/POSCAR
                  
               else
                  echo "${currpath}/${a}/${OPT_PATH}/CONTCAR isnot exist! DOS calculation was suspended" >> bash.out
                  continue
               fi
            else
               run_bol="FALSE"
               continue
            fi 

         fi

         if [ ${run_bol} = "TRUE" ];
            then
            sed -i '1c #PBS -N '${a}'_'${RUNNING_PATH}'' ./${pbs_file}
            
            res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
            if [ ${RUNNING_PATH}null = "null" ];then
                 echo "$res     ${str}/$a" >>${pwd_str}/${tmp_ID} 
            else
                 echo "$res     ${str}/$a/${RUNNING_PATH}" >>${pwd_str}/${tmp_ID} 
            fi
            taskindex=$[$taskindex + 1]
            cd  ${str}
         fi
      fi    
     done

}
####submit dos

function submit_dos_scf(){
     ####  $1: path1
     ####  $2: sub-path
     path_str=""
     i=$[0]
     for s in "$@"
      do
            if [ $i -eq 0 ];then
               path_str=${s}
            else
               path_str=${path_str}/${s} 
            fi
            i=$[$i + 1]
      done 
      
     if [ -d ${path_str} ];then
       cd ./
     else
       echo "${path_str} is not exist"
       exit 1
     fi
     
     cd ${path_str}/${DOS_SCF_PATH}
     
     if [ `checkfile ${path_str}/${DOS_SCF_PATH}/OUTCAR` = "TRUE" ];then
       grep "General timing and accounting informations" ./OUTCAR >/dev/null
       if [ $? -eq 0 ] 
       then
        return 0
       fi
     fi
     
     if [ -f ./INCAR ];then
       cd ./
     else
       if [ -f ./${INCAR_template} ]
       then
          incar_temp_path=${INCAR_template}
       else
          incar_temp_path=${pwd_str}/${INCAR_template}
          if [ -f ${incar_temp_path} ]
          then   
             cd ./
          else
             echo "template file of INCAR is not exit"
             return 1
          fi
       fi 
       sed -e "s/EXTERNAL_ISTART/0/g"   \
           -e "s/EXTERNAL_ICHARG/1/g"   \
           -e "s/EXTERNAL_NEDOS/305/g"  \
           -e "s/EXTERNAL_ISMEAR/0/g"   \
           ${incar_temp_path} > ./INCAR 
     fi
     
   
     if [ `check ${path_str}/${DOS_SCF_PATH}` = "ERROR" ]
     then
         echo " ${path_str} folder has no files required by VASP calculations!" >> ${pwd_str}/ERROR
         return 1
     fi
  
     ##### submit         
     cp -rf ${pwd_str}/${pbs_file} ./

     
     na=`echo $1 | awk -F '/' '{print $NF}'`

     sed -i '1c #PBS -N '${na}'_'${DOS_SCF_PATH}'' ./${pbs_file} 
     
     res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
     
     echo "$res   ${path_str}/${DOS_SCF_PATH}  " >> ${pwd_str}/${tmp_ID} 
        
     taskindex=$[$taskindex + 1]
}

function submit_dos_noscf(){
     ####  $1: path1
     ####  $2: sub-path
     path_str=""
     i=$[0]
     for s in "$@"
      do
            if [ $i -eq 0 ];then
               path_str=${s}
            else
               path_str=${path_str}/${s} 
            fi
            i=$[$i + 1]
      done  

###  echo "dos_noscf: $1  $2  "

     cd ${path_str}/${DOS_NOSCF_PATH}  

     if [ `checkfile ${path_str}/${DOS_NOSCF_PATH}/OUTCAR` = "TRUE" ];then
       grep "General timing and accounting informations" ./OUTCAR >/dev/null
       if [ $? -eq 0 ] 
       then
        return 0
       else
        return 0
       fi
     fi
     
     if [ `checkfile ${path_str}/${DOS_SCF_PATH}/OUTCAR` = "TRUE" ];then
     
        grep "General timing and accounting informations" ${path_str}/${DOS_SCF_PATH}/OUTCAR  >/dev/null
        
        if [ $? -eq 0 ];then
        
         cp -rf ${path_str}/${DOS_SCF_PATH}/WAVECAR ./
         cp -rf ${path_str}/${DOS_SCF_PATH}/CHGCAR ./
         
         if [ `checkfile ${path_str}/${DOS_NOSCF_PATH}/POSCAR` = "FALSE" ];then
            cp -rf ${path_str}/${DOS_SCF_PATH}/POSCAR ./
         fi
         if [ `checkfile ${path_str}/${DOS_NOSCF_PATH}/KPOINTS` = "FALSE" ];then       
            cp -rf ${path_str}/${DOS_SCF_PATH}/KPOINTS ./
         fi
         if [ `checkfile ${path_str}/${DOS_NOSCF_PATH}/POTCAR` = "FALSE" ];then
            cp -rf ${path_str}/${DOS_SCF_PATH}/POTCAR ./
         fi
         if [ `checkfile ${path_str}/${DOS_NOSCF_PATH}/INCAR` = "FALSE" ];then
            cp -rf ${path_str}/${DOS_SCF_PATH}/INCAR ./
         fi
         
         if [ `checkfile ${path_str}/${INCAR_PARA_FILE}` = "TRUE" ]
         then
           numi=0
           for cmdValue in `cat ${path_str}/INCAR_para.in`
            do
               newkeyword=`echo ${cmdValue} | awk -F '=' '{print $1}'`
               row=`grep -n ${newkeyword}  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
               numi=$[ $numi + 2 ]
               if [ x${row} = "x" ]
               then
                  sed -i ''${numi}''a' '${cmdValue}'' ./INCAR
               else
                  sed -i ''${row}''c' '${cmdValue}''  ./INCAR 
               fi
            done
         fi
         
         
#         row=`grep -n "ISTART"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
#         if [ x${row} = "x" ]
#         then
#           sed -i '3a ISTART = 1' ./INCAR
#         else
#           sed -i ''${row}''c' ISTART = 1' ./INCAR 
#         fi
#         
#         row=`grep -n "ICHARG"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
#         if [ x${row} = "x" ]
#         then
#           sed -i '4a ICHARG = 11' ./INCAR
#         else
#           sed -i ''${row}''c' ICHARG = 11' ./INCAR
#         fi
#         
#         row=`grep -n "NEDOS"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
#         if [ x${row} = "x" ]
#         then
#           sed -i '10a NEDOS = 2000' ./INCAR
#         else
#           sed -i ''${row}''c' NEDOS = 2000' ./INCAR 
#         fi
#         
#         row=`grep -n "ISMEAR"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
#         if [ x${row} = "x" ]
#         then
#           sed -i '8a ISMEAR = -5' ./INCAR
#         else
#           sed -i ''${row}''c' ISMEAR = -5' ./INCAR 
#         fi 
            
        else
          return 1
        fi
     else
        return 1
     fi
     
     if [ `checkfile ${path_str}/${DOS_NOSCF_PATH}` = "ERROR" ]
     then
         echo " ${path_str} folder has no files required by VASP calculations!" >> ${pwd_str}/ERROR
         exit 1
     fi
  
     ##### submit         
     cp -rf ${pwd_str}/${pbs_file} ./
     ###echo "pre=$1"
    
     na=`echo $1 | awk -F '/' '{print $NF}'`
     ##echo "$1 = ${na}"
     sed -i '1c #PBS -N '${na}'_'${DOS_NOSCF_PATH}'' ./${pbs_file} 

     
     res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
     echo "$res     ${path_str}/${DOS_NOSCF_PATH}     Q" >> ${pwd_str}/${tmp_ID}
 
     taskindex=$[$taskindex + 1]
}

function submit_dos(){
     LScmd=""
     currpath=""
     if [ x$1 = "x" ]
        then
        cd ${pwd_str}
        currpath=`pwd`
        LScmd="ls"
     else
        cd $1
        currpath=`pwd`
        LScmd="ls $1"
     fi
     res="yes"
     
     ####$LScmd
     
     for a in `$LScmd`
     do
        run_bol="TRUE"
        if [ ${IS_Series_Running}xo = "Txo" ] || [ ${IS_Series_Running}xo = "txo" ] ;then
           if [ `check_isNormalFinish ${currpath}/${a}/${OPT_PATH}/OUTCAR` = "TRUE" ];then
           
              if [ `checkfile ${currpath}/${a}/${OPT_PATH}/CONTCAR` = "TRUE" ];then
              
                 cp ${currpath}/${a}/${OPT_PATH}/CONTCAR  ${currpath}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}/POSCAR
                 
              else
                 echo "${currpath}/${a}/${OPT_PATH}/CONTCAR isnot exist! DOS calculation was suspended" >> bash.out
                 continue
              fi
           else
              run_bol="FALSE"
              continue
           fi 
        fi
        if [ -d ${currpath}/$a ] && [ ${run_bol} = "TRUE" ]
        then   
          res=`checkfile ${pwd_str}/${tmp_ID}`
          if [ ${res} = "FALSE" ];then
             cd $currpath/$a
             str=`pwd`  
                 
             submit_dos_scf   $str  ${RUNNING_PATH}
             submit_dos_noscf $str  ${RUNNING_PATH}
             cd $currpath
          else         
            grep "${a}/DOS/${DOS_SCF_PATH}" ${pwd_str}/${tmp_ID} >/dev/null      
            if [ $? -ne 0 ]
            then
              cd $currpath/$a      
              str=`pwd`
              
              submit_dos_scf $str  ${RUNNING_PATH}
              cd $currpath
            fi
            
            ###echo "${a}_DOS_${DOS_NOSCF_PATH}" 
            grep "${a}/DOS/${DOS_NOSCF_PATH}" ${pwd_str}/${tmp_ID}  >/dev/null
            if [ $? -ne 0 ]
            then
              cd $currpath/$a
              str=`pwd`
              
              submit_dos_noscf $str ${RUNNING_PATH}
              cd $currpath
            fi
          fi         
        fi    
     done
}

###### main shell ################
if [ `checkfile ${pwd_str}/${pbs_file}` = "FALSE" ];then
   echo "PBS file in ${pwd_str} is not found!!!"
   exit 1
fi

if [ `checkIsRunningShell` = "TRUE" ];then
   time_str=`date --date="-24 hour" +%H:%M`   
   echo "Current shell in ${pwd_str} is running! Please check it"
   ps -ef | grep "${Shellname}" | grep -v "grep\|${time_str}" 
   exit 1
fi


rm -rf ${pwd_str}/bash.out
rm -rf ${pwd_str}/${tmp_ID}

cat>dos_para.in<<EOF
ISTART = 1
ICHARG = 11
NEDOS = 2000
ISMEAR = -5
EOF

cat>charge_para.in<<EOF
ISTART = 1
ICHARG = 11
NEDOS = 2000
ISMEAR = -5
EOF

#######del_jobs
##########
while true
do
  INCAR_PARA_FILE=""
  RUNNING_PATH="OPT"
  submit_job
  
  ###############echo "submit job do"
  #INCAR_PARA_FILE="dos_para.in"
  #RUNNING_PATH="DOS"
  #submit_dos
  
  #INCAR_PARA_FILE="charge_para.in"
  #RUNNING_PATH="CHARGE"
  #submit_job    
   
  if [ "`check_all_jobs_state`x" = "TRUEx" ];then
    break
  fi
  sleep 120
done

echo "${taskindex} jobs are finished!" >> ${pwd_str}/bash.out
echo "Corresponding data is presented as following:!" >> bash.out
sort -t " " -k 3n ${pwd_str}/${tmp_ID} >> ${pwd_str}/bash.out
