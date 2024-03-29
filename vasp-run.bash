############################################
####                                    ####
####  Author: Guilin Zhuang             ####
####  E-mail: glzhuang@zjut.edu.tn      ####
####                                    ####
############################################

#!/bin/bash

######pbs file is required 
pbs_file=vasp-sugon-new.pbs

############# for normal calculations
INCAR_PARA_FILE=""
#####   current path: /XXX/qqq/
#####   sub_path="OPT"
#####   sumit the all jobs in the OPT folder of all folers in current path
RUNNING_PATH="OPT"
RUNNING_KPOINTS_FILE=""
############## T: restart even if this OUTCAR is completed;  F: donot excute when this OUTCAR is completed.
IS_RESTART=F
####################Following keywords must be setted in the series_running 
######## IS_Series_Running=T    Or   F
IS_Series_Running=T
########optimization folder
OPT_PATH=""
##################

############# only effective for dos calculations
IS_RESTART_DOS_SCF=F
IS_RESTART_DOS_NOSCF=F
DOS_SCF_PATH=1
DOS_NOSCF_PATH=2
DOS_NOSCF_INCAR_FILE=""
DOS_SCF_KPOINTS_FILE=""
DOS_NOSCF_KPOINTS_FILE=""
#############

############## Public variables are not needed to be modified
machine_name=`uname -a | awk '{print $2}'`
pwd_str=`pwd`
VASP_FILES="INCAR KPOINTS POSCAR POTCAR"
taskindex=0
Shellname="$0"
PrefixShellname=`echo ${Shellname} | awk -F '.' '{print $1}'`
tmp_ID=".${PrefixShellname}_job_ID"
Is_Waiting_Mode=F
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
           echo " $1 file has no $file_name required by VASP calculations!" >> ${pwd_str}/${PrefixShellname}_ERROR
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
        err="FALSE"
     fi
     echo $err
}
function checkVASPFiles(){
     cd ${pwd_str}
       ###rm -rf ${pwd_str}/ERROR
     err="TRUE"
     LScmd=""
     
     
     if [ $# -eq 0 ]
     then
        LScmd="ls ${pwd_str}"
        str=${pwd_str}
     else
        LScmd="ls $1"
        str=$1
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
     
     if [ ${err} = "FALSE" ]
     then
       cat ${pwd_str}/${PrefixShellname}_ERROR >> ${pwd_str}/${PrefixShellname}_bash.out
     fi
     echo $err
}
function checkIsRunningJob(){
##### $1:  jobing path of testing jobs

   res="FALSE"
   
   qstat | awk '{print $1}' | awk -F '.' '{print $1}' | tail -n +3 >${pwd_str}/.${Shellname}_tmpRunningID
   
   for b in `cat ${pwd_str}/.${Shellname}_tmpRunningID`
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
    rm -rf ${pwd_str}/.${Shellname}_tmpRunningID
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
    
    ps -ef | grep "${Shellname}" | grep -v "grep\|${time_str}" > ${pwd_str}/.${Shellname}_tmp_shell
    
    cat ${pwd_str}/.${Shellname}_tmp_shell | awk '{print $2}' > ${pwd_str}/.${Shellname}_tmp_shell2
    
    res="FALSE"
    for idi in `cat ${pwd_str}/.${Shellname}_tmp_shell2`
      do
         ls -la /proc/${idi} | grep "cwd" | awk -F '->' '{print $2}' | grep ${pwd_str} >/dev/null
         if [ $? -eq 0 ];then
           res="TRUE"
           break
         fi
      done
     rm -rf ${pwd_str}/.${Shellname}_tmp_shell ${pwd_str}/.${Shellname}_tmp_shell2
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
    
    rm -rf ${pwd_str}/.${Shellname}_jobstate
    #####  #1: ID_Forlder
    if [ x$1 = "x" ]
     then
     file="${tmp_ID}"
    else
     file=$1
    fi
    
    if [ `checkfile ${pwd_str}/${file}` = "FALSE" ];then
       echo "FALSE"
       return 1
    fi
    
    awk '{print $1}' ${pwd_str}/${file} > ${pwd_str}/.${Shellname}_tmpfile
    
    for b in `cat ${pwd_str}/.${Shellname}_tmpfile`
     do
       row=`grep -n $b ${pwd_str}/${file} | awk '{print $1}' | awk -F ':' '{print $1}'`
       
       jobpath=`grep $b ${pwd_str}/${file} | awk '{print $2}'` 
       
       n_state_tmp=`qstat | grep ${b}.${machine_name}` > /dev/null
       if [ $? -eq 0 ]
       then   
          state=`echo ${n_state_tmp} | awk '{print $5}'`
          sed -i ''${row}''c' '$b'     '${jobpath}'     'State_${state}'' ${pwd_str}/${file}
       else
          if [ `check_isNormalFinish $jobpath/OUTCAR` = "TRUE" ];then      
               energy=`read_single_energy $jobpath`
               sed -i ''${row}''c' '$b'     '${jobpath}'     '$energy'' ${pwd_str}/${file}
          else
               sed -i ''${row}''c' '$b'     '${jobpath}'      ERROR' ${pwd_str}/${file} 
          fi
       fi
     done
    rm -rf ${pwd_str}/.${Shellname}_tmpfile
    
    echo "TRUE"
}
function check_all_jobs_state(){

     if [ `check_job ${tmp_ID}`x = "FALSEx" ];then
        echo "FALSE"
        return 0
     fi
     
     res="TRUE"
     
     awk '{print $3}' ${pwd_str}/${tmp_ID} >${pwd_str}/.${Shellname}_tmp_state_check
     
     grep "State_R" ${pwd_str}/.${Shellname}_tmp_state_check >/dev/null
     if [ $? -eq 0 ] 
     then
        res="FALSE"
     fi
     
     grep "State_Q" ${pwd_str}/.${Shellname}_tmp_state_check >/dev/null
     if [ $? -eq 0 ] 
     then
        res="FALSE"
     fi
     
     rm -rf ${pwd_str}/.${Shellname}_tmp_state_check
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
          echo "${str} in reading energy is not exist!"
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
     if [ x$1 = "x" ];then
       cd ${pwd_str} 
       for a in `ls ./`
        do
         if [ -d $a ];then
            energy=`read_single_energy ${pwd_str}/${RUNNING_PATH}/$a`
            echo "${pwd_str}/${RUNNING_PATH}/$a    ${energy}" >>${pwd_str}/energy_out
         fi
       done  
     fi
}
###delete jobs
function del_jobs(){
     
     if [ `checkfile ${pwd_str}/${tmp_ID}` = "TRUE" ];then
        if [ x_$1 = "x_" ];then 
           awk '{print $1}' ${pwd_str}/${tmp_ID} > ${pwd_str}/.${Shellname}_tmpfile     
        else
           label="${pwd_str}/$1"
           grep "${label}" ${pwd_str}/${tmp_ID} | awk '{print $1}'  > ${pwd_str}/.${Shellname}_tmpfile 
        fi
       for b in `cat ${pwd_str}/.${Shellname}_tmpfile`
       do
          state=`qstat ${b} | tail -1 | awk '{print $5}'`
          if [ ${state}_state = "R_state" ] || [ ${state}_state = "Q_state" ]
          then
              qdel $b >/dev/null
          fi       
       done
       rm -rf ${pwd_str}/.${Shellname}_tmpfile
     else
        return 1
     fi
     
}
function del_files(){
    for s in "$@"
    do
      rm -rf ${pwd_str}/s
    done
}
####submit job_1
function submit_job_wait(){
 
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
          echo "${str} folder is not exist!"
          return 1
        fi
     fi
     
     Is_Waiting_Mode=T
     
     for a in `$LScmd`
     do
      if [ -d ${str}/$a ];then
        if [ ${RUNNING_PATH}null = "null" ];then
               cd ${str}/$a
        else
            if [ -d ${str}/$a/${RUNNING_PATH} ];then
               cd ${str}/$a/${RUNNING_PATH}
            else
               echo "${str}/$a/${RUNNING_PATH} is not exist!"
               return 1
            fi
        fi
        
        #### check whether the job will be run
        current_job_path=`pwd`
        
        if [ ${IS_RESTART}xx = "Fxx" ] && [ `check_isNormalFinish ${current_job_path}/OUTCAR` = "TRUE" ] ;then
           energy=`read_single_energy ${current_job_path}`
           pre_file_name=`echo ${RUNNING_PATH} | sed 's/\//_/g'`
           
           if [ -f ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy ];then
              grep ${current_job_path} ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy >/dev/null
              if [ $? = 0 ];then
                 continue
              else
                 echo "${current_job_path}       ${energy}" >> ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy
              fi
           else
              echo "${current_job_path}       ${energy}" >> ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy
           fi
           continue
        fi
        
        if [ `checkIsRecordedJob ${current_job_path}`x = "TRUEx" ];then
           continue
        else
           ##echo "checkIsRunningJob in ${current_job_path}"
           if [ `checkIsRunningJob ${current_job_path} RECORD`x = "TRUEx" ];then          
               continue
           fi
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
               
               run_bol="TRUE"
               if [ ${IS_Series_Running}x = "Tx" ] || [ ${IS_Series_Running}x = "tx" ] && [ ${OPT_PATH} != ${RUNNING_PATH} ];then
                   if [ `check_isNormalFinish ${pwd_str}/${a}/${OPT_PATH}/OUTCAR` = "TRUE" ];then
                      for file_name in ${VASP_FILES}
                       do
                         if [ `checkfile ${pwd_str}/${a}/${RUNNING_PATH}/${file_name}` = "FALSE" ];then  
                            if [ `checkfile ${pwd_str}/${a}/${OPT_PATH}/${file_name}` = "TRUE" ];then         
                               cp -rf ${pwd_str}/${a}/${OPT_PATH}/${file_name}  ${pwd_str}/${a}/${RUNNING_PATH}/ 
                            else
                               echo "The ${file_name} in ${pwd_str}/${a}/${OPT_PATH} and ${pwd_str}/${a}/${RUNNING_PATH}/ isnot exist! DOS calculation was suspended" >> ${PrefixShellname}_bash.out
                               continue
                            fi        
                         fi
                       done
                     if [ `checkfile ${pwd_str}/${a}/${OPT_PATH}/CONTCAR` = "TRUE" ];then             
                        cp -rf ${pwd_str}/${a}/${OPT_PATH}/CONTCAR  ${pwd_str}/${a}/${RUNNING_PATH}/POSCAR              
                     else
                        echo "${pwd_str}/${a}/${OPT_PATH}/CONTCAR isnot exist! DOS calculation was suspended" >> ${PrefixShellname}_bash.out
                        continue
                     fi
                  else
                     run_bol="FALSE"
                     continue
                  fi 
               fi
               
               if [ `checkfile ${pwd_str}/${RUNNING_KPOINTS_FILE}` = "TRUE" ];then
                  cp -rf ${pwd_str}/${RUNNING_KPOINTS_FILE} ${pwd_str}/${a}/${RUNNING_PATH}/KPOINTS
               fi
               
               ##### according to INCAR_para.in file, revise INCAR file  
               if [ `checkfile ${pwd_str}/${INCAR_PARA_FILE}` = "TRUE" ]
               then
                  sed -i 's/[[:space:]]//g' ${pwd_str}/${INCAR_PARA_FILE}
                  sed -i '/^$/d' ${pwd_str}/${INCAR_PARA_FILE}
                  numi=0
                 for cmdValue in `cat ${pwd_str}/${INCAR_PARA_FILE}`
                  do
                    newkeyword=`echo ${cmdValue} | awk -F '=' '{print $1}'`
                    row=`grep -n ${newkeyword}  ./INCAR | grep -v "^#" |awk '{print $1}'| awk -F ':' '{print $1}'`
                    if [ x${row} = "x" ]
                    then
                       sed -i ''${numi}''a' '${cmdValue}'' ./INCAR
                    else
                       sed -i ''${row}''c' '${cmdValue}'' ./INCAR 
                    fi
                    numi=$[ $numi + 2 ]
                 done
               fi
               
               if [ ${run_bol} = "TRUE" ];then
                  cp -rf ${pwd_str}/${pbs_file} ${pwd_str}/${a}/${RUNNING_PATH}/
                  sed -i '1c #PBS -N '${a}'_'${RUNNING_PATH}'' ${pwd_str}/${a}/${RUNNING_PATH}/${pbs_file}  
                  
                  res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
                  
                  if [ ${RUNNING_PATH}null = "null" ];then
                     echo "$res     ${str}/$a" >>${pwd_str}/${tmp_ID} 
                  else
                     echo "$res     ${str}/$a/${RUNNING_PATH}" >>${pwd_str}/${tmp_ID}  
                  fi
                  taskindex=$[ ${taskindex} + 1 ]
                  break 
               fi
            fi 
        done 
     fi    
  done
}

####submit job_2
function submit_job(){
      
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
          echo "${str} is not exist!"
          return 1
        fi
     fi
     if [ ${IS_RESTART}xx = "Txx" ];then
        for a in `$LScmd`
        do
          if [ -d ${str}/$a ];then
             if [ -f ${str}/$a/${RUNNING_PATH}/OUTCAR ];then
                 mv ${str}/$a/${RUNNING_PATH}/OUTCAR  ${str}/$a/${RUNNING_PATH}/backup_OUTCAR
             elif [ `checkpath ${str}/$a/${RUNNING_PATH}` = "FALSE" ];then
                if [ ${OPT_PATH} = ${RUNNING_PATH} ];then
                   echo "ERROR: ${str}/$a/${RUNNING_PATH} in optimization calculations is not exist!" >>${pwd_str}/${PrefixShellname}_bash.out
                   exit 1
                else
                  mkdir ${str}/$a/${RUNNING_PATH} > /dev/null
                  echo "Note: ${str}/$a/${RUNNING_PATH} is not exist! Shell creates it!" >>${pwd_str}/${PrefixShellname}_bash.out
                fi 
            fi
          fi
        done
        IS_RESTART=F
     fi
     
     for a in `$LScmd`
     do
       
      if [ -d ${str}/$a ];then
        if [ ${RUNNING_PATH}null = "null" ];then
            cd ${str}/$a
        else
            if [ -d ${str}/$a/${RUNNING_PATH} ];then
               cd ${str}/$a/${RUNNING_PATH}
            elif [ ${OPT_PATH} = ${RUNNING_PATH} ];then
               echo "ERROR: ${str}/$a/${RUNNING_PATH} in optimization calculations is not exist!" >>${pwd_str}/${PrefixShellname}_bash.out
               exit 1
            else
               mkdir ${str}/$a/${RUNNING_PATH} > /dev/null
               echo "Note: ${str}/$a/${RUNNING_PATH} is not exist! Shell creates it!" >>${pwd_str}/${PrefixShellname}_bash.out
               return 1
            fi
        fi

        #### check whether the job will be run
        current_job_path=`pwd`     

        if [ ${IS_RESTART}xx = "Fxx" ] && [ `check_isNormalFinish ${current_job_path}/OUTCAR` = "TRUE" ] ;then
           energy=`read_single_energy ${current_job_path}`
           pre_file_name=`echo ${RUNNING_PATH} | sed 's/\//_/g'`     
           if [ -f ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy ];then
              grep ${current_job_path} ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy >/dev/null
              if [ $? = 0 ];then
                 continue
              else
                 echo "${current_job_path}       ${energy}" >> ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy
              fi
           else
                 echo "${current_job_path}       ${energy}" >> ${pwd_str}/${PrefixShellname}_${pre_file_name}.energy
           fi
           continue
        fi
        
        if [ `checkIsRecordedJob ${current_job_path}`x = "TRUEx" ];then
           continue
        else
           if [ `checkIsRunningJob ${current_job_path} RECORD`x = "TRUEx" ];then          
               continue
           fi
        fi
        ##### submit       
        cp -rf ${pwd_str}/${pbs_file} ./
       
         run_bol="TRUE"
         if [ ${IS_Series_Running}_o = "T_o" ] || [ ${IS_Series_Running}_o = "t_o" ] && [ ${OPT_PATH} != ${RUNNING_PATH} ];then
             if [ `check_isNormalFinish ${pwd_str}/${a}/${OPT_PATH}/OUTCAR` = "TRUE" ];then
              
               for file_name in ${VASP_FILES}
               do
                 if [ `checkfile ${pwd_str}/${a}/${RUNNING_PATH}/${file_name}` = "FALSE" ];then  
                    if [ `checkfile ${pwd_str}/${a}/${OPT_PATH}/${file_name}` = "TRUE" ];then        
                       cp -rf ${pwd_str}/${a}/${OPT_PATH}/${file_name}  ${pwd_str}/${a}/${RUNNING_PATH}/ 
                    else
                       echo "The ${file_name} in ${pwd_str}/${a}/${OPT_PATH} and ${pwd_str}/${a}/${RUNNING_PATH}/ isnot exist! DOS calculation was suspended" >> ${PrefixShellname}_bash.out
                       continue
                    fi        
                 fi
               done
               if [ `checkfile ${pwd_str}/${a}/${OPT_PATH}/CONTCAR` = "TRUE" ];then             
                  cp -rf ${pwd_str}/${a}/${OPT_PATH}/CONTCAR  ${pwd_str}/${a}/${RUNNING_PATH}/POSCAR              
               else
                  echo "${pwd_str}/${a}/${OPT_PATH}/CONTCAR isnot exist! DOS calculation was suspended" >> ${pwd_str}/${PrefixShellname}_bash.out
                  continue
               fi
               
            else
               run_bol="FALSE"
               continue
            fi 

         fi
         
         if [ `checkfile ${pwd_str}/${RUNNING_KPOINTS_FILE}` = "TRUE" ];then
            cp -rf ${pwd_str}/${RUNNING_KPOINTS_FILE} ${pwd_str}/${a}/${RUNNING_PATH}/KPOINTS
         fi
         
         if [ `checkfile ${pwd_str}/${INCAR_PARA_FILE}` = "TRUE" ]
         then
           numi=0
           
           sed -i 's/[[:space:]]//g' ${pwd_str}/${INCAR_PARA_FILE}
           sed -i '/^$/d' ${pwd_str}/${INCAR_PARA_FILE}
           
           for cmdValue in `cat ${pwd_str}/${INCAR_PARA_FILE}`
            do
               newkeyword=`echo ${cmdValue} | awk -F '=' '{print $1}'`
               row=`grep -n ${newkeyword}  ./INCAR |  grep -v "^#" |awk '{print $1}'| awk -F ':' '{print $1}'`
               numi=$[ $numi + 2 ]
               if [ x${row} = "x" ]
               then
                  sed -i ''${numi}''a' '${cmdValue}'' ./INCAR
               else
                  sed -i ''${row}''c' '${cmdValue}'' ./INCAR 
               fi
            done
         fi
         
         if [ ${run_bol} = "TRUE" ];
            then
            cp -rf ${pwd_str}/${pbs_file} ${pwd_str}/${a}/${RUNNING_PATH}/
            sed -i '1c #PBS -N '${a}'_'${RUNNING_PATH}'' ${pwd_str}/${a}/${RUNNING_PATH}/${pbs_file} 
              
            res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
            if [ ${RUNNING_PATH}null = "null" ];then
                 echo "$res     ${str}/$a" >>${pwd_str}/${tmp_ID} 
            else
                 echo "$res     ${str}/$a/${RUNNING_PATH}" >>${pwd_str}/${tmp_ID} 
            fi
            taskindex=$[ ${taskindex} + 1 ]
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
      
     if [ -d ${path_str}/${DOS_SCF_PATH} ];then
       cd ./
     else
       echo "${path_str}/${DOS_SCF_PATH} is not exist" >>${pwd_str}/${PrefixShellname}_bash.out
       return 1
     fi
     
     
     cd ${path_str}/${DOS_SCF_PATH}
       
     ##### submit 
     if [ `checkfile ${pwd_str}/${DOS_SCF_KPOINTS_FILE}` = "TRUE" ];then
            cp -rf ${pwd_str}/${DOS_SCF_KPOINTS_FILE} ${path_str}/${DOS_SCF_PATH}/KPOINTS
     fi
     ####
     if [ `checkVASPFiles ${path_str}/${DOS_SCF_PATH}` = "ERROR" ];then
         echo " ${path_str} folder has no files required by VASP calculations!" >> ${pwd_str}/ERROR
         return 1
     fi
     
     if [ `checkfile ${pwd_str}/${INCAR_PARA_FILE}` = "TRUE" ];then
           numi=0
           
           sed -i 's/[[:space:]]//g' ${pwd_str}/${INCAR_PARA_FILE}
           sed -i '/^$/d' ${pwd_str}/${INCAR_PARA_FILE}
           
           for cmdValue in `cat ${pwd_str}/${INCAR_PARA_FILE}`
            do
               newkeyword=`echo ${cmdValue} | awk -F '=' '{print $1}'`
               row=`grep -n ${newkeyword}  ./INCAR | grep -v "^#" | awk '{print $1}'| awk -F ':' '{print $1}'`
               numi=$[ $numi + 2 ]
               if [ x${row} = "x" ]
               then
                  sed -i ''${numi}''a' '${cmdValue}'' ./INCAR
               else
                  sed -i ''${row}''c' '${cmdValue}''  ./INCAR 
               fi
            done
     fi 
     #### modified pbs file        
     cp -rf ${pwd_str}/${pbs_file} ./
     na=`echo $1 | awk -F '/' '{print $NF}'`
     sed -i '1c #PBS -N '${na}'_'${RUNNING_PATH}'_'${DOS_SCF_PATH}'' ./${pbs_file} 
     
     ####submit
     res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
     
     echo "$res   ${path_str}/${DOS_SCF_PATH}" >> ${pwd_str}/${tmp_ID} 
        
     taskindex=$[ ${taskindex} + 1 ]
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

     if [ -d ${path_str}/${DOS_NOSCF_PATH}  ];then
       cd ./
     else
       echo "${path_str}/${DOS_NOSCF_PATH} is not exist" >>${pwd_str}/${PrefixShellname}_bash.out
       return 1
     fi
     cd ${path_str}/${DOS_NOSCF_PATH}  
     
     if [ `check_isNormalFinish ${path_str}/${DOS_SCF_PATH}/OUTCAR` = "TRUE" ];then
        
            cp -rf ${path_str}/${DOS_SCF_PATH}/WAVECAR ./
            cp -rf ${path_str}/${DOS_SCF_PATH}/CHGCAR  ./
            
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
            
            if [ `checkfile ${pwd_str}/${DOS_NOSCF_INCAR_FILE}` = "TRUE" ]
            then
              numi=0
              
              sed -i 's/[[:space:]]//g' ${pwd_str}/${DOS_NOSCF_INCAR_FILE}
              sed -i '/^$/d' ${pwd_str}/${DOS_NOSCF_INCAR_FILE}
              
              for cmdValue in `cat ${pwd_str}/${DOS_NOSCF_INCAR_FILE}`
               do
                  newkeyword=`echo ${cmdValue} | awk -F '=' '{print $1}'`
                  row=`grep -n ${newkeyword}  ./INCAR | grep -v "^#" | awk '{print $1}'| awk -F ':' '{print $1}'`
                  numi=$[ $numi + 2 ]
                  if [ x${row} = "x" ]
                  then
                     sed -i ''${numi}''a' '${cmdValue}'' ./INCAR
                  else
                     sed -i ''${row}''c' '${cmdValue}''  ./INCAR 
                  fi
               done
            fi 
     else
        return 1
     fi
       
     if [ `checkfile ${pwd_str}/${DOS_NOSCF_KPOINTS_FILE}` = "TRUE" ];then
        cp -rf ${pwd_str}/${DOS_NOSCF_KPOINTS_FILE} ${path_str}/${DOS_NOSCF_PATH}/KPOINTS
     fi
     
     if [ `checkVASPFiles ${path_str}/${DOS_NOSCF_PATH}` = "ERROR" ]
     then
         echo " ${path_str} folder has no files required by VASP calculations!" >> ${pwd_str}/${PrefixShellname}_bash.out
         exit 1
     fi
     ##### submit         
     cp -rf ${pwd_str}/${pbs_file} ./
     ###echo "pre=$1"
    
     na=`echo $1 | awk -F '/' '{print $NF}'`
     ##echo "$1 = ${na}"
     sed -i '1c #PBS -N '${na}'_'${RUNNING_PATH}'_'${DOS_NOSCF_PATH}'' ./${pbs_file} 

     
     res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
     echo "$res     ${path_str}/${DOS_NOSCF_PATH}" >> ${pwd_str}/${tmp_ID}
 
     taskindex=$[ ${taskindex} + 1 ]
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
     if [ ${IS_RESTART_DOS_SCF}xx = "Txx" ] || [ ${IS_RESTART_DOS_NOSCF}xx = "Txx" ];then
        for a in `$LScmd`
        do
         if [ -d ${pwd_str}/${a} ];then
           if [ `checkpath ${pwd_str}/${a}/${RUNNING_PATH}` = "FALSE" ];then
              mkdir ${pwd_str}/${a}/${RUNNING_PATH} >/dev/null
              echo "${pwd_str}/${a}/${RUNNING_PATH} is not exist! Shell creates it" >>${pwd_str}/${PrefixShellname}_bash.out
           fi
           if [ `checkpath ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}` = "FALSE" ];then
              mkdir ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}>/dev/null
              echo "${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH} is not exist! Shell creates it" >>${pwd_str}/${PrefixShellname}_bash.out
           fi
           if [ `checkpath ${pwd_str}/$a/${RUNNING_PATH}/${DOS_NOSCF_PATH}` = "FALSE" ];then
              mkdir ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH}>/dev/null
              echo "${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH} is not exist! Shell creates it" >>${pwd_str}/${PrefixShellname}_bash.out
           fi
           if [ ${IS_RESTART_DOS_SCF}xx = "Txx" ];then
              if [ -f ${pwd_str}/$a/${RUNNING_PATH}/${DOS_SCF_PATH}/OUTCAR ];then
               mv  ${pwd_str}/$a/${RUNNING_PATH}/${DOS_SCF_PATH}/OUTCAR    ${pwd_str}/$a/${RUNNING_PATH}/${DOS_SCF_PATH}/backup_OUTCAR
              fi
              if [ -f ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH}/OUTCAR ];then
               mv  ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH}/OUTCAR    ${pwd_str}/$a/${RUNNING_PATH}/${DOS_NOSCF_PATH}/backup_OUTCAR
              fi   
           fi
           if [ ${IS_RESTART_DOS_NOSCF}xx = "Txx" ];then
              if [ -f ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH}/OUTCAR ];then
               mv  ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH}/OUTCAR    ${pwd_str}/$a/${RUNNING_PATH}/${DOS_NOSCF_PATH}/backup_OUTCAR
              fi   
           fi
         fi
       done
       IS_RESTART_DOS_SCF=F
       IS_RESTART_DOS_NOSCF=F
     fi
     
     for a in `$LScmd`
     do       
        if [ -d ${pwd_str}/$a ];then
           if [ `checkpath ${pwd_str}/${a}/${RUNNING_PATH}` = "FALSE" ];then
                 mkdir ${pwd_str}/${a}/${RUNNING_PATH}>/dev/null
                 echo "${pwd_str}/${a}/${RUNNING_PATH} is not exist! Shell creates it" >>${pwd_str}/${PrefixShellname}_bash.out
           fi
           if [ `checkpath ${pwd_str}/$a/${RUNNING_PATH}/${DOS_SCF_PATH}` = "FALSE" ];then
                 mkdir ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}>/dev/null
                 echo "${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH} is not exist! Shell creates it" >>${pwd_str}/${PrefixShellname}_bash.out
           fi
           if [ `checkpath ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH}` = "FALSE" ];then
                 mkdir ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH}>/dev/null
                 echo "${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH} is not exist! Shell creates it" >>${pwd_str}/${PrefixShellname}_bash.out
           fi
           #### running label
           run_bol="TRUE"
           
           if [ ${IS_Series_Running}xo = "Txo" ] || [ ${IS_Series_Running}xo = "txo" ] ;then
               if [ `check_isNormalFinish ${pwd_str}/${a}/${OPT_PATH}/OUTCAR` = "TRUE" ];then
                 
                  for file_name in ${VASP_FILES}
                   do
                    if [ `checkfile ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}/${file_name}` = "FALSE" ];then  
                       if [ `checkfile ${pwd_str}/${a}/${OPT_PATH}/${file_name}` = "TRUE" ];then         
                          cp -rf ${pwd_str}/${a}/${OPT_PATH}/${file_name}  ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}/ 
                       else
                          echo "The ${file_name} in ${pwd_str}/${a}/${OPT_PATH} and ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH} isnot exist! DOS calculation was suspended" >> ${PrefixShellname}_bash.out
                          continue
                       fi        
                    fi
                   done
                   
                 if [ `checkfile ${pwd_str}/${a}/${OPT_PATH}/CONTCAR` = "TRUE" ];then
                 
                    cp ${pwd_str}/${a}/${OPT_PATH}/CONTCAR  ${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH}/POSCAR
                    
                 else
                    echo "${pwd_str}/${a}/${OPT_PATH}/CONTCAR isnot exist! DOS calculation was suspended" >> ${PrefixShellname}_bash.out
                    continue
                 fi
              else
                 run_bol="FALSE"
                 continue
              fi 
           fi
           if [ ${run_bol} = "TRUE" ]
           then          
             current_job_path=${pwd_str}/${a}/${RUNNING_PATH}/${DOS_SCF_PATH} 
                if [ `check_isNormalFinish ${current_job_path}/OUTCAR`x = "FALSEx" ] ;then   
                   if [ `checkIsRecordedJob ${current_job_path}`x = "FALSEx" ];then
                      if [ `checkIsRunningJob ${current_job_path} RECORD`x = "FALSEx" ];then                    
                         submit_dos_scf   ${pwd_str}/${a}  ${RUNNING_PATH}
                      fi          
                   fi 
                fi
             
             current_job_path=${pwd_str}/${a}/${RUNNING_PATH}/${DOS_NOSCF_PATH} 
               if [ `check_isNormalFinish ${current_job_path}/OUTCAR`x = "FALSEx" ] ;then   
                  if [ `checkIsRecordedJob ${current_job_path}`x = "FALSEx" ];then
                    if [ `checkIsRunningJob ${current_job_path} RECORD`x = "FALSEx" ];then                     
                        submit_dos_noscf ${pwd_str}/${a}  ${RUNNING_PATH}          
                    fi 
                  fi
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


rm -rf ${pwd_str}/${PrefixShellname}_bash.out
rm -rf ${pwd_str}/${tmp_ID}

#### grep -v "^#" INCAR | grep -v -e '^[[:space:]]*$' 
############INCAR modified part for scf calculation in DOS###############
cat>${PrefixShellname}_dos_scf_para.in<<EOF
ISTART = 0
LCHARG = T
LWAVE = T
ISPIN=2
LREAL  = Auto                                                           
NSW    = 0             
IBRION =  -1                    
LORBIT = 11                                                                                                                 
IVDW=11
EOF

############INCAR modified part for noscf calculation in DOS###############
cat>${PrefixShellname}_dos_noscf_para.in<<EOF
ISTART = 1
ICHARG = 11
NSW    = 0             
IBRION =  -1
NEDOS = 2000
ISMEAR = -5
EOF

############INCAR modified part for charge###############
cat>${PrefixShellname}_charge_para.in<<EOF
NSW = 0
LAECHG = T
LCHARG = T
LWAVE=T
LREAL=Auto
IBRION=-1
SIGMA=0.1
EOF

############KPOINTS file for DOS SCF###############
cat>${PrefixShellname}_dos_scf_kpoints.in<<EOF
Automatic mesh
0
G
3  3  1
0. 0. 0.
EOF

############KPOINTS file for DOS NOSCF###############
cat>${PrefixShellname}_dos_noscf_kpoints.in<<EOF
Automatic mesh
0
G
6  6  1
0. 0. 0.
EOF

#######Set KPOINTS file for other calculations
RUNNING_KPOINTS_FILE=""

##########Set KPOINTS file for DOS
DOS_SCF_KPOINTS_FILE="${PrefixShellname}_dos_scf_kpoints.in"
DOS_NOSCF_KPOINTS_FILE="${PrefixShellname}_dos_noscf_kpoints.in"

######## IS_Series_Running=T    Or   F
IS_Series_Running=T
########optimization folder
OPT_PATH="N/OPT"

################## bool value for restart calculation
IS_RESTART=F
IS_RESTART_DOS_SCF=F
IS_RESTART_DOS_NOSCF=F
################

#del_jobs

DOS_NOSCF_INCAR_FILE="${PrefixShellname}_dos_noscf_para.in"

while true
do
  INCAR_PARA_FILE=""
  RUNNING_PATH="N/OPT"
  IS_RESTART=F
  submit_job

  ###############echo "submit job do"
  INCAR_PARA_FILE="${PrefixShellname}_dos_scf_para.in"
  RUNNING_PATH="N/dos"
  submit_dos   
  
  INCAR_PARA_FILE="${PrefixShellname}_charge_para.in"
  RUNNING_PATH="N/bader"
  submit_job  
  
   
  if [ ${Is_Waiting_Mode}_x = "T_x" ];then
     if [ "`check_all_jobs_state`x" = "TRUEx" ];then
       break
     fi
  else
     if [ "`check_all_jobs_state`x" = "TRUEx" ] || [ ${taskindex} = "0" ];then
        break
     fi
  fi
  
  sleep 60
  
done

echo "${taskindex} jobs are finished!" >> ${pwd_str}/${PrefixShellname}_bash.out
echo "Corresponding data is presented as following:!" >> ${PrefixShellname}_bash.out

#####sort energy by ascending order
for ene_file in `ls ${pwd_str}/${PrefixShellname}_*.energy`
  do
     sort -t " " -k 2n ${ene_file} >${ene_file}
  done

