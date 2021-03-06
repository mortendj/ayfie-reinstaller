#!/bin/bash

port=
data_dir=
version=
port_offset=
dot_env_file_from_path=
application_custom_yml_file_path=
groovy_script_path=
install_dir_path=
ram=
quay=
quay_user=
quay_password=
install_dir_name_prefix=
port_base_number=
base_port=20000
block_execution=false
base_url="http://docs.ayfie.com/ayfie-platform/release/"
stop=false
remove=false
bounce=false
alerting=false
frontend=false

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
  echo "  -a                    Install alerting and messaging"
  echo "  -b                    bounce (or start) ayfie (for default install dir only)"
  echo "  -c <file path>        Path to application-custom.yml. Default: No path"  
  echo "  -d <data dir>         Default: <install dir>/data"
  echo "  -e <file path>        The .env file location. Default: file auto generated"
  echo "  -f                    Install front end / search page"  
#  echo "  -g <file path>        Groovy ingestion script file location. Default: No path" 
  echo "  -h                    This help"
  echo "  -i <install dir>      Default: ./<version number>"  
  echo "  -m <GB of RAM>        Default: 64" 
  echo "  -n <name>             Name to prefix the install directory name" 
  echo "  -N <number>           Base for version derived port number, Default 20000"  
  echo "  -o                    Do installation only, does not start up ayfie"    
  echo "  -p <port>             Default: base port nunber (-N) + version number (-v)"
  echo "  -q <user>:<password>  User and password to Quay Docker image storage"  
  echo "  -r                    Stop and remove ayfie (for default install dir only)"   
  echo "  -s                    Stop ayfie (for default install directory only)" 
  echo "  -v <version>          Mandatory: 1.13.7, 1.13.9, 1.14.0 etc." 
  echo  
  exit 1
}

validate_and_process_input_parameters() {
    if [[ $quay ]]; then
      user_pwd=(${quay//:/ })
      if [[ ${#user_pwd[@]} == 2 ]]; then      
        quay_user=${user_pwd[0]}
        quay_password=${user_pwd[1]}
      else
        show_usage_and_exit "Quay user and password not in requested format"
      fi
    fi
    logged_into_quay=false
    if is_logged_into_quay; then
      logged_into_quay=true   
    fi
    if [[ ! $quay_user ]] || [[ ! $quay_password ]]; then
      if [[ $logged_into_quay == false ]]; then
        show_usage_and_exit "Either first log into quay or use option -q user:password"
      fi
    fi
    if [[ $port_base_number ]]; then
      if [[ ! $port_base_number =~ ^[0-6]0000+$ ]]; then
        show_usage_and_exit "The base port number has to be '[0-6]0000' "
      fi
      base_port=$port_base_number
    fi
    if [[ ! $ayfie_version ]]; then
      show_usage_and_exit "The -v '<version>' option is mandatory"
    fi
    if [[ ! $ayfie_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        show_usage_and_exit "The version format has to be x.y.z (e.g 1.10.3)"
    fi
    if [[ $install_dir_path ]]; then
      if [[ $install_dir_name_prefix ]]; then
        show_usage_and_exit "Name prefix (-n) does not work with install path (-i)"
      fi
      if [[ ! "${install_dir_path:0:1}" = "/" ]]; then
        show_usage_and_exit "The install path must be an absolute path"
      fi
    else
      install_dir_path="$PWD/$install_dir_name_prefix$ayfie_version"  
    fi
    if [[ -d "$install_dir_path" ]]; then
      if [[ ! ( $stop == true || $remove == true || $bounce == true) ]]; then
        show_usage_and_exit "Install dir '$install_dir_path' already exists"
      fi
    fi
    if [[ ! $data_dir ]]; then
      data_dir="$install_dir_path/data"
    fi
    if [[ $dot_env_file_from_path ]]; then
      if [[ ! -f $dot_env_file_from_path ]]; then
        show_usage_and_exit "File '$dot_env_file_from_path' does not exist"
      fi
      if [[ $port ]]; then
        show_usage_and_exit "Option -p and -e cannot be used together. Set the port in the .env file."
      else
        port="To have been set in $dot_env_file_from_path"    
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
    if [[ $remove == true ]] || [[ $stop == true ]] || [[ $bounce == true ]]; then
      if [[ -d "$install_dir_path" ]]; then
        true
      else
        show_usage_and_exit "There is no directory $install_dir_path"
      fi
    fi
    
    ayfie_installer_file_name="ayfie-installer-v$ayfie_version.zip"
    ayfie_installer_file_path=$(readlink -m "$install_dir_path/$ayfie_installer_file_name")
    download_url="$base_url$ayfie_installer_file_name"
    dot_env_file_to_path="$install_dir_path/.env"
    docker_compose_yml_file_path="$install_dir_path/docker-compose.yml"
    ayfie_stop_script="$install_dir_path/stop-ayfie.sh"
    
    echo
    echo "  Version:              $ayfie_version"
    echo "  Install dir:          $install_dir_path"
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
      echo "  Port:                 $port"
      echo "  Data dir:             $data_dir"
      if [[ $dot_env_file_from_path ]]; then
        echo "  .env file:            $dot_env_file_from_path"
      else
        echo "  Total RAM:            $ram" 
        echo "  .env file:            Will be generated"    
      fi
      if [[ $application_custom_yml_file_path ]]; then
        echo "  application.yml:      $application_custom_yml_file_path"
      else
        echo "  application.yml:      No custom file"      
      fi 
#      if [[ $groovy_script_path ]]; then
#        echo "  Groovy script:        $groovy_script_path"
#      else
#        echo "  Groovy script:        No script"      
#      fi        
      if [[ $application_custom_yml_file_path ]] || [[ $groovy_script_path ]]; then
        echo "  docker-compose.yml:   Will be updated"
      else
        echo "  docker-compose.yml:   Unchanged"      
      fi
      if [[ $frontend == true ]]; then
        echo "  Frontend:             To be included"
      else
        echo "  Frontend:             Not to be included"      
      fi
      if [[ $alerting == true ]]; then
        echo "  Alerting:             To be included"
      else
        echo "  Alerting:             Not to be included"      
      fi
      quay_login_info=""
      if [[ $logged_into_quay == true ]]; then
        quay_login_info="(some quay user already logged in)"
      fi
      if [[ $quay_user ]]; then
        echo "  Quay user:            $quay_user $quay_login_info" 
      else
        echo "  Quay user:            None given $quay_login_info"
      fi
      if [[ $quay_password ]]; then
        echo "  Quay password:        *******"
      else
        echo "  Quay password:        None given"  
      fi                        
      echo
      echo "Do you want to go ahead with the ayfie Inspector installation (y/n)?"
    fi
    read reply
    if [[ $reply != 'y' ]]; then
      exit 1
    fi
}

get_file_deployment_type() {
  if [[ -x "$@" ]]; then
    echo "SCRIPT"
  else
    command -v "$@" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      echo "COMMAND"
    elif [[ -e "$@" ]]; then
      echo "FILE"
    else
      echo "NONE"
    fi
  fi
}

is_already_installed() {
  file_deployment_type=$(get_file_deployment_type "$@")
  if [[ $file_deployment_type == "SCRIPT" ]] || [[ $file_deployment_type == "COMMAND" ]]; then
    return 0
  else
    return 1
  fi
}

gen_or_copy_dot_env_file() {
  if [[ $dot_env_file_from_path ]]; then
    cp $dot_env_file_from_path $dot_env_file_to_path
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
    printf $lines > $dot_env_file_to_path
  fi
}

gen_application_custom_yml_file() {
    script_name="$@"
    local lines="ingestion:"
    lines="$lines\n  pipeline:"
    lines="$lines\n   preScriptTransformer:"
    lines="$lines\n      skip: false"
    lines="$lines\n      scriptPath: \"/home/dev/restapp/${script_name}\""
    printf $lines > $dot_env_file_to_path
}

add_mapping_to_docker_compose_yml_file() {
  cp "$@" $install_dir_path
  org_file="$install_dir_path/$(basename $@)"
  f=$docker_compose_yml_file_path
  f_copy="$f.copy"
  cp $f $f_copy
  python -c "open(\"$f\",\"w\").write(open(\"$f_copy\",\"r\").read().replace(\"  elasticsearch:\", \"    - ${org_file}:/home/dev/restapp/$@\n  elasticsearch:\"))"
  rm $f_copy
}

update_docker_compose_yml_file() {
  if [[ $application_custom_yml_file_path ]]; then
    if ! grep -q application-custom.yml "$docker_compose_yml_file_path"; then
      add_mapping_to_docker_compose_yml_file $application_custom_yml_file_path 
    fi
  fi
  if [[ $groovy_script_path ]]; then
    if ! grep -q $groovy_script_path "$docker_compose_yml_file_path"; then
      add_mapping_to_docker_compose_yml_file $groovy_script_path 
    fi
    if [[ ! $application_custom_yml_file_path ]]; then
      application_custom_yml_file_path="$install_dir_path/application-custom.yml"
      if ! grep -q application-custom.yml "$docker_compose_yml_file_path"; then
        gen_application_custom_yml_file "$install_dir_path/application-custom.yml"
        add_mapping_to_docker_compose_yml_file application-custom.yml
      fi
    fi
  fi
}

download_installer_zip_file() {
  $(curl -s $download_url --output $ayfie_installer_file_path)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  token="404 Not Found"
  output=$(cat $ayfie_installer_file_path | grep "$token")
  if [[ $output =~ $token ]]; then
    return 2
  fi
  return 0
}

unzip_installer_file() {
  if ! is_already_installed "unzip"; then
    apt-get update
    apt-get install unzip
  fi
  eval "unzip $ayfie_installer_file_path -d $install_dir_path"
  if [[ $? -ne 0 ]]; then
    show_usage_and_exit "Unzip operation failed for file '$ayfie_installer_file_path'"
  fi
}

install_ayfie() {
  mkdir $install_dir_path
  download_installer_zip_file
  zip_download_error_code=$?
  if [[ $zip_download_error_code -ne 0 ]]; then
    rm -r $install_dir_path
  fi
  if [[ $zip_download_error_code -eq 1 ]]; then
    show_usage_and_exit "cURL failed for url '$download_url'"
  fi
  if [[ $zip_download_error_code -eq 2 ]]; then
    show_usage_and_exit "A 404 download error, is $ayfie_version a valid version number?"
  fi
  unzip_installer_file
  gen_or_copy_dot_env_file
  update_docker_compose_yml_file
}

install_docker() {
  if ! is_already_installed "docker"; then
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    apt-get update
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    apt-key fingerprint 0EBFCD88
    apt-get update
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install docker-ce
  fi
}

install_docker_compose() {
  pushd $PWD
  cd $install_dir_path
  if ! is_already_installed "docker-compose"; then 
    curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o docker-compose
    chmod +x docker-compose
  fi
  popd
}

add_user_to_docker_group() {
  if [ $(getent group docker) ]; then
    true  
  else
    groupadd docker
  fi
  usermod -aG docker $USER
}

is_logged_into_quay() {
  if grep -Fq quay.io ~/.docker/config.json
  then
     return 0
  else
    return 1
  fi
}

log_into_quay() {
  if [[ $quay_user ]] && [[ $quay_password ]]; then
    docker login --username=$quay_user --password=$quay_password "quay.io"
  fi
}

update_sysctl() {
    grep -q -F 'vm.max_map_count=262144' /etc/sysctl.conf || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
    grep -q -F 'vm.swappiness=1' /etc/sysctl.conf || echo 'vm.swappiness=1' >> /etc/sysctl.conf
    sysctl -p
}

do_ayfie_prerequisites() {
  install_docker
  add_user_to_docker_group
  log_into_quay
  install_docker_compose
  update_sysctl
}

start_ayfie() {
  if [[ $block_execution == false ]]; then 
    pushd $PWD
    cd $install_dir_path
    docker_compose_start_cmd="docker-compose -f docker-compose.yml"
    if [[ $frontend == true ]]; then
        docker_compose_start_cmd="$docker_compose_start_cmd -f docker-compose-frontend.yml"
    fi
    if [[ $alerting == true ]]; then
        docker_compose_start_cmd="$docker_compose_start_cmd -f docker-compose-alerting.yml"
    fi
    eval "$docker_compose_start_cmd up -d"
    popd
  fi
}

stop_ayfie() {
  pushd $PWD
  cd $install_dir_path
  if [[ $? -ne 0 ]]; then
    show_usage_and_exit "Failed to change to directory '$install_dir_path'"
  fi
  eval "docker-compose -f docker-compose.yml -f docker-compose-frontend.yml -f docker-compose-alerting.yml down"
  popd
}

while getopts "abc:d:e:fg:hi:m:n:N:op:q:rsv:" option; do
  case $option in
    a)
      alerting=true ;;
    b)
      bounce=true ;;
    c)
      application_custom_yml_file_path=$OPTARG ;;      
    d)
      data_dir=$OPTARG ;;
    e)
      dot_env_file_from_path=$OPTARG ;;
    f)
      frontend=true ;;      
    g)
      groovy_script_path=$OPTARG ;;  
    h)
      show_usage_and_exit ;;
    i)
      install_dir_path=$OPTARG ;;
    m)
      ram=$OPTARG ;; 
    n)
      install_dir_name_prefix=$OPTARG ;; 
    N)
      port_base_number=$OPTARG ;;        
    o)
      block_execution=true ;;    
    p)
      port=$OPTARG ;;
    q)
      quay=$OPTARG ;;
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
  if [[ "$EUID" -ne 0 ]] ; then 
    show_usage_and_exit "The script has to be run as root (sudo)"
  fi
  validate_and_process_input_parameters
  if [[ $remove == true || $stop == true || $bounce == true ]]; then
    stop_ayfie
    if [[ $remove == true ]]; then
        rm -r $install_dir_path
    fi
    if [[ $bounce == true ]]; then
      start_ayfie
    fi
  else
    install_ayfie
    do_ayfie_prerequisites
    start_ayfie
  fi
}

main

