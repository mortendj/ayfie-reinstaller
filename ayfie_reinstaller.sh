#!/bin/bash

port=
data_dir=
version=
port_offset=
old_dot_env_file_path=
install_dir=
ram=
block_execution=false
base_port=20000
base_url="http://docs.ayfie.com/ayfie-platform/release/"
stop=false
remove=false
bounce=false

show_usage_and_exit() {
  local error_msg=$1
  echo
  if [[ $error_msg ]]; then
    echo "ERROR: $error_msg"
    echo
  fi
  echo "Usage: $0 <options>"
  echo
  echo "Options:"
  echo "  -b                    bounce (or start) ayfie (for default install dir only)" 
  echo "  -d <data dir>         Default: ./data (corresponds to <install dir>/data)"
  echo "  -e <.env file path>   The .env source location. Default: file auto generated"
  echo "  -h                    This help"
  echo "  -i <install dir>      Default: ./<version number>"  
  echo "  -m <GB of RAM>        Default: 64"  
  echo "  -o                    Do installation only, don't start up ayfie"    
  echo "  -p <port>             Default: $base_port + version number"
  echo "  -r                    Stop and remove ayfie (for default install dir only)"  
  echo "  -s                    Stop ayfie (for default install directory only)" 
  echo "  -v <version>          Mandatory: 1.8.3, 1.9.0, 1.10.3, etc." 
  echo  
  exit 1
}

validate_and_process_input_parameters() {
    if [[ ! $ayfie_version ]]; then
      show_usage_and_exit "The '-v <version>' option is mandatory"
    fi
    if [[ ! $ayfie_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        show_usage_and_exit "The version format has to be x.y.z (e.g 1.10.3)"
    fi
    if [[ ! $install_dir ]]; then
      install_dir="./$ayfie_version"
    fi
    if [[ -d "$install_dir" ]]; then
      if [[ ! ( $stop == true || $remove == true || $bounce == true) ]]; then
        show_usage_and_exit "Install dir '$install_dir' already exists"
      fi
    fi
    if [[ ! $data_dir ]]; then
      data_dir="./data"
    fi
    if [[ $old_dot_env_file_path ]]; then
      if [[ ! -f $old_dot_env_file_path ]]; then
        show_usage_and_exit "File '$old_dot_env_file_path' does not exist"
      fi
      if [[ $port ]]; then
        show_usage_and_exit "Option -p and -e cannot be used together. Set the port in the .env file."
      else
        port="To have been set in $ $old_dot_env_file_path"    
      fi
      if [[ $ram ]]; then
        show_usage_and_exit "Option -m and -e cannot be used together. Set memory limits in the .env file."
      fi
    else 
      if [[ ! $ram ]]; then
        ram="64"
      fi
      if [[ ! $port ]]; then
        port_offset="${ayfie_version//\./}" 
        port=$((base_port + port_offset))
      fi
      if [[ ! $port =~ ^[0-9]+$ ]]; then
        show_usage_and_exit "The port number has to be an integer"
      fi
    fi
    
    ayfie_installer_file_name="ayfie-installer-v$ayfie_version.zip"
    ayfie_installer_file_path=$(readlink -m "$install_dir/$ayfie_installer_file_name")
    download_url="$base_url$ayfie_installer_file_name"
    new_dot_env_file_path="$install_dir/.env"
    ayfie_start_up_script="$install_dir/start-ayfie.sh"
    ayfie_stop_script="$install_dir/stop-ayfie.sh"
    
    echo
    echo "  Version:     $ayfie_version"
    if [[ $remove == true ]]; then
      echo
      echo "Do you want to go ahead with removing installation (y/n)?"
    elif [[ $stop == true ]]; then
      echo
      echo "Do you want to go ahead with stopping the ayfie Inspector (y/n)?"
    elif [[ $bounce == true ]]; then
      echo
      echo "Do you want to go ahead with restarting the ayfie Inspector (y/n)?"
    else
      echo "  Port:        $port"
      echo "  Install dir: $install_dir"
      echo "  Data dir:    $data_dir"
      if [[ $old_dot_env_file_path ]]; then
        echo "  .env file:   $old_dot_env_file_path"
      else
        echo "  Total RAM:   $ram" 
        echo "  .env file:   To be generated"    
      fi
      echo
      echo "Do you want to go ahead with the ayfie Inspector installation (y/n)?"
    fi
    read reply
    if [[ $reply != 'y' ]]; then
      exit 1
    fi
}

gen_or_copy_dot_env_file() {
  if [[ $old_dot_env_file_path ]]; then
    cp $old_dot_env_file_path $new_dot_env_file_path
  else
    local lines="AYFIE_PORT=$port"
    local extract_mem
    local ayfie_mem
    local elastic_mem
    let "extract_mem = $ram / 16"
    if [[ $extract_mem < 1 ]]; then
      extract_mem=1
    fi
    let "ayfie_mem = 3 * $ram / 4"
    let "elastic_mem = $ram / 4"
    lines="$lines\nEXTRACTION_MEM_LIMIT=${extract_mem}G"
    lines="$lines\nAYFIE_MEM_LIMIT=${ayfie_mem}G"
    lines="$lines\nELASTICSEARCH_MEM_LIMIT=${elastic_mem}G"
    lines="$lines\nDATA_VOLUME=$data_dir"
    printf $lines > $new_dot_env_file_path
  fi
}

download_installer_zip_file() {
  dummy=$(curl -s $download_url --output $ayfie_installer_file_path)
  status=$?
  if [[ $status -ne 0 ]]; then
    show_usage_and_exit "cURL failed with error code $status, check\nhttps://curl.haxx.se/libcurl/c/libcurl-errors.html"
  fi
  token="404 Not Found"
  output=$(cat $ayfie_installer_file_path | grep "$token")
  if [[ $output =~ $token ]]; then
    show_usage_and_exit "Downloading failed with '$token', check if correct ayfie version number"
  fi
}

unzip_installer_zip_file() {
  eval "unzip $ayfie_installer_file_path -d $install_dir"
  status=$?
  if [[ $status -ne 0 ]]; then
    show_usage_and_exit "Unzip operation failed with error code $status"
  fi
}

install_ayfie() {
  mkdir $install_dir
  download_installer_zip_file
  unzip_installer_zip_file
  gen_or_copy_dot_env_file
}

start_ayfie() {
  if [[ $block_execution == false ]]; then
    eval ". $ayfie_start_up_script"
  fi
}

while getopts "bd:e:hi:m:op:rsv:" option; do
  case $option in
    b)
      bounce=true ;; 
    d)
      data_dir=$OPTARG ;;
    e)
      old_dot_env_file_path=$OPTARG ;;
    h)
      show_usage_and_exit ;;
    i)
      install_dir=$OPTARG ;;
    m)
      ram=$OPTARG ;;      
    o)
      block_execution=true ;;    
    p)
      port=$OPTARG ;;
    r) 
      stop=true; remove=true ;;
    s)
      stop=true; remove=false  ;;    
    v)
      ayfie_version=$OPTARG ;;
    \?)
      show_usage_and_exit ;;
  esac
done

main() {
  validate_and_process_input_parameters
  if [[ $remove == true ]]; then
    eval ". $ayfie_stop_script"
    rm -r $install_dir
    exit 0
  fi
  if [[ $stop == true ]]; then
    eval ". $ayfie_stop_script"
    exit 0
  fi
  if [[ $bounce == true ]]; then
    eval ". $ayfie_stop_script"
    eval ". $ayfie_start_up_script"
    exit 0
  fi
  install_ayfie
  start_ayfie
}

main