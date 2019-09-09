############################################
####                                    ####
####  Author: Guilin Zhuang             ####
####  E-mail: glzhuang@zjut.edu.tn      ####
####                                    ####
############################################

#!/bin/bash

pbs_file=vasp-sugon-new.pbs


############# for dos
DOS_SCF_PATH=1
DOS_NOSCF_PATH=2
INCAR_template=INCAR.in
#############

############# for normal submit
#   current path: /XXX/qqq/
#   sub_path="OPT"
#   sumit the all jobs in the OPT folder of all folers in current path
#########
SUB_PATH="OPT"
####################

############## donot need to be modified
machine_name=`uname -a | awk '{print $2}'`
pwd_str=`pwd`
VASP_FILES="INCAR KPOINTS POSCAR POTCAR"
tmp_ID=".work_ID"
tmp_Path="work_path"
tmp_IDPath="workpathIDstate"
taskindex=$[0]
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

####submit work_1
function submit_work_wait(){

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
      if [ -d $a ];then
        if [ ${SUB_PATH}null = "null" ];then
               cd ${str}/$a
        else
            if [ -d ${str}/$a/${SUB_PATH} ];then
               cd ${str}/$a/${SUB_PATH}
            else
               echo "${str}/$a/${SUB_PATH} is not exit!"
               return 1
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
               
               sed -i '1c #PBS -N '${a}'_'${SUB_PATH}'' ./${pbs_file} 
               
               res=`qsub ${pbs_file} | awk -F "." '{print $1}' `

               if [ ${SUB_PATH}null = "null" ];then
                  echo "$res     ${str}/$a" >>${pwd_str}/${tmp_ID} 
               else
                  echo "$res     ${str}/$a/${SUB_PATH}" >>${pwd_str}/${tmp_ID}  
               fi
               taskindex=$[$taskindex + 1]
               break 
            fi 
        done 
      fi    
     done

}

####submit work_2
function submit_work(){

     rm -rf ${pwd_str}/${tmp_ID}  
      
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
          cd ${str}
        else
          echo "${str} is not exit!"
          return 1
        fi
     fi
     
     for a in `$LScmd`
     do
      if [ -d $a ];then
        if [ ${SUB_PATH}null = "null" ];then
            cd ${str}/$a
        else
            if [ -d ${str}/$a/${SUB_PATH} ];then
               cd ${str}/$a/${SUB_PATH}
            else
               echo "${str}/$a/${SUB_PATH} is not exit!"
               return 1
            fi
        fi
        ##### submit       
        cp -rf ${pwd_str}/${pbs_file} ./
        
        sed '1c #PBS -N '${a}'_'${SUB_PATH}'' ./${pbs_file} > .pbs-tmp
        mv .pbs-tmp ./${pbs_file}
        
        res=`qsub ${pbs_file} | awk -F "." '{print $1}' `
        if [ ${SUB_PATH}null = "null" ];then
             echo "$res     ${str}/$a" >>${pwd_str}/${tmp_ID} 
        else
             echo "$res     ${str}/$a/${SUB_PATH}" >>${pwd_str}/${tmp_ID} 
        fi
        taskindex=$[$taskindex + 1]
        cd  ${str}
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
       sed -e "s/EXTERNAL_ISTART/0/g"  \
           -e "s/EXTERNAL_ICHARG/1/g"  \
           -e "s/EXTERNAL_NEDOS/305/g"  \
           -e "s/EXTERNAL_ISMEAR/0/g"  \
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
         mv -rf ${path_str}/${DOS_SCF_PATH}/WAVECAR ./
         mv -rf ${path_str}/${DOS_SCF_PATH}/CHGCAR ./
         
         cp -rf ${path_str}/${DOS_SCF_PATH}/POSCAR ./       
         cp -rf ${path_str}/${DOS_SCF_PATH}/KPOINTS ./
         cp -rf ${path_str}/${DOS_SCF_PATH}/POTCAR ./
         cp -rf ${path_str}/${DOS_SCF_PATH}/INCAR ./
         
         row=`grep -n "ISTART"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
         if [ x${row} = "x" ]
         then
           sed -i '3a ISTART = 1' ./INCAR
         else
           sed -i ''${row}''c' ISTART = 1' ./INCAR 
         fi
         
         row=`grep -n "ICHARG"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
         if [ x${row} = "x" ]
         then
           sed -i '4a ICHARG = 11' ./INCAR
         else
           sed -i ''${row}''c' ICHARG = 11' ./INCAR
         fi
         
         row=`grep -n "NEDOS"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
         if [ x${row} = "x" ]
         then
           sed -i '10a NEDOS = 2000' ./INCAR
         else
           sed -i ''${row}''c' NEDOS = 2000' ./INCAR 
         fi
         
         row=`grep -n "ISMEAR"  ./INCAR | awk '{print $1}'| awk -F ':' '{print $1}'`
         if [ x${row} = "x" ]
         then
           sed -i '8a ISMEAR = -5' ./INCAR
         else
           sed -i ''${row}''c' ISMEAR = -5' ./INCAR 
         fi    
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
        ##echo "$a"
        if [ -d $a ];then
          
         res=`checkfile ${pwd_str}/${tmp_ID}`
          
         #### echo "res = $res"
          
          if [ ${res} = "FALSE" ];then
             cd $currpath/$a
             str=`pwd`  
                 
             submit_dos_scf   $str  ${SUB_PATH}
             submit_dos_noscf $str  ${SUB_PATH}
             cd $currpath
          else
             
            grep "${a}/DOS/${DOS_SCF_PATH}" ${pwd_str}/${tmp_ID} >/dev/null
            
            if [ $? -ne 0 ]
            then
              cd $currpath/$a      
              str=`pwd`
              
              submit_dos_scf $str  ${SUB_PATH}
              cd $currpath
            fi
            
            ###echo "${a}_DOS_${DOS_NOSCF_PATH}" 
            grep "${a}/DOS/${DOS_NOSCF_PATH}" ${pwd_str}/${tmp_ID}  >/dev/null
            if [ $? -ne 0 ]
            then
              cd $currpath/$a
              str=`pwd`
              
              submit_dos_noscf $str ${SUB_PATH}
              cd $currpath
            fi
          fi         
        fi    
     done
}
#####check work
function check_isNormalFinish(){
   if [ -f $1 ];then
     grep "General timing and accounting informations" $1 >/dev/null
     if [ $? -eq 0 ];then
        echo "TRUE"
     else
        echo "FALSE"
     fi 
   fi
}
function check_work(){  
    
 ###   echo "check_work()"
    
    rm -rf ${pwd_str}/.workstate
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
       ###echo "b=$b   row=$row  uuuuuu "
   
       state=`qstat ${b}.${machine_name} | tail -1 | awk '{print $5}'`
       workpath=`grep $b ${pwd_str}/${file} | awk '{print $2}'`
       if [ ${state}O = "O" ]
       then
         if [ `check_isNormalFinish $workpath/OUTCAR` = "TRUE" ];then      
            enery=`read_single_energy $workpath`
            sed -i ''${row}''c' '$b'     '${workpath}'     '$energy'' ${pwd_str}/${file}
         else
            sed -i ''${row}''c' '$b'     '${workpath}'      ERROR' ${pwd_str}/${file} 
         fi
       else
            sed -i ''${row}''c' '$b'     '${workpath}'     'State_${state}'' ${pwd_str}/${file}
       fi
     done
    #### rm -rf ${pwd_str}/.tmpfile
    #### cp -rf ${pwd_str}/${file} ${pwd_str}/.workstate
}
function check_work_state(){

     check_work ${tmp_ID}
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
           qdel $b
        done
     else
        return 1
     fi
}
###### main shell ################
if [ `checkfile ${pwd_str}/${pbs_file}` = "FALSE" ];then
   echo "pbs file is not found!!!"
   exit 1
fi

del_jobs
rm -rf bash.out


submit_work

while true
do
  ####submit_dos    
  if [ "`check_work_state`x" = "TRUEx" ];then
    break
  fi
  sleep 120
done
echo "Finished!" >> bash.out
