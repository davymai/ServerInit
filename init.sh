#!/bin/bash
#################################################
# Function      : Server Initialization script
# Platform      : CentOS 7, Rocky 8-9, Ubuntu 20+ Based Platform
# Author        : davymai(大威)
# Contact       : i@davymai.com
# Link          : https://github.com/davymai/ServerInit
# Filename      : init.sh
# Usage         : bash init.sh
# Description   : This is a Bash script for initializing servers, which includes the installation of various development environments and tools. It supports multiple Linux distributions (such as CentOS 7, Rocky 8-9, Ubuntu 20+), and includes the installation and configuration of Docker, MySQL, Redis, etc.
#################################################

# 初始化脚本设置 {{{
# 脚本版本
scriptdate='2024-07-03'
scriptVer='0.3.2'

# 1. 检测系统类型
source /etc/os-release
OS=$NAME
OS_VER=$VERSION_ID

# 2. 设置时区
if [[ "$OS" != **"CentOS"** ]]; then
  rtc_time=$(timedatectl | awk '/RTC time/ {print $4, $5}') && cn_time=$(date -d "$rtc_time 8 hours" +"%Y-%m-%d %H:%M:%S") && sudo timedatectl set-time "$cn_time"
fi

# 3. 中文支持
# 检查 /etc/profile 是否包含 "export LC_ALL=en_US.UTF-8"
if [[ "$OS" == **"Rocky"** ]]; then
  if ! sudo grep -q "export LC_ALL=en_US.UTF-8" /etc/profile; then
    # 如果不包含，则添加该行
    echo "export LC_ALL=en_US.UTF-8" | sudo tee -a /etc/profile >/dev/null
    # 重新加载 /etc/profile 以应用更改
    source /etc/profile
  fi
fi

# 4. CentOS 设置参数
if [[ "$OS" == **"CentOS"** ]]; then
  . /etc/rc.d/init.d/functions
fi

# 5. 当前用户
currUser=$(whoami)

# 6. 设置要备份的文件夹路径
source_directory="/etc/yum.repos.d"

# 7. 设置备份目录路径
backup_directory="/etc/yum.repos.d/backup"

# 8. 获取当前日期
current_date=$(date -d "$rtc_time 8 hours" +"%Y%m%d")

# 9. 获取IP地址
#外网IP地址
MYIP=$(curl -s ip.sb)
# 内网IP地址
IPADD=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')

# 10. shell目录
ShellFolder=$(cd "$(dirname -- "$0")" || exit pwd)

# 11. 设置颜色变量
SS='\033[5m'   # 文字闪烁
CF='\033[0m'   # 关闭文字属性
C00='\E[0;30m' # 黑色
C01='\E[0;31m' # 红色
C02='\E[0;32m' # 绿色
C03='\E[0;33m' # 黄色
C04='\E[0;34m' # 蓝色
C05='\E[0;35m' # 紫色
C06='\E[0;36m' # 青色
C07='\E[0;37m' # 白色
C0='\E[1;30m'  # 高亮黑色
C1='\E[1;31m'  # 高亮红色
C2='\E[1;32m'  # 高亮绿色
C3='\E[1;33m'  # 高亮黄色
C4='\E[1;34m'  # 高亮蓝色
C5='\E[1;35m'  # 高亮紫色
C6='\E[1;36m'  # 高亮青色
C7='\E[1;37m'  # 高亮白色

# 12. 定义 成功/信息/错误/警告 等日志文字
msg() {
  printf '%b\n' "$1" >&2
}

info() {
  msg "${C4}[➮]${CF} ${1}${2}"
}

cont() {
  msg "${C3}[►]${CF} ${1}${2}"
}

warn() {
  msg "${C5}[⚠️ WARNING]${CF} ${1}${2}"
}
error() {
  msg "${C1}[✘ ERROR]${CF} ${1}${2}"
  exit 1
}
success() {
  msg "${C2}[✔]${CF} ${1}${2}"
}
# 删除线
strike() {
  printf '%b\n' "\E[33;9m$1\E[0m" >&2
}
# 文字闪烁
blink() {
  printf '%b\n' "\E[33;5m$1\E[0m" >&2
}

#倒计时参数
cd_num=5
delay=1

# }}}

welcome() {
  clear
  msg "${C06}
     ____     _ __              ____                    
    /  _/__  (_) /_            / __/__ _____  _____ ____
   _/ // _ \/ / __/           _\ \/ -_) __/ |/ / -_) __/
  /___/_//_/_/\__/           /___/\__/_/  |___/\__/_/

     Ubuntu & Rocky Linux 8,9 & CentOS 7 初始化脚本
              初始化系统以确保安全性和性能

        ${C7}系统默认${SS}${C1}禁止${C7}密码登陆, 请提前准备好公钥${C06}

        Version: ${scriptVer}    Update: ${scriptdate}
        By: 大威(Davy)    System: ${C2}${OS} ${C05}${OS_VER}
        ${CF}"
}

#倒计时
CD() {

  while [ $cd_num -gt 0 ]; do
    echo -ne "\r        ${C06}初始化脚本 ${C1}$cd_num${C06} 秒后开始, 按 ${C3}ctrl C ${C06}取消${CF}"
    sleep $delay
    ((cd_num--))
  done

  echo -e "\r        ${C06}初始化脚本 ${C1}0${C06} 秒后开始, 按 ${C3}ctrl C ${C06}取消${CF}"
  sleep $delay
  echo -ne "\033[A\r\033[K"
  msg "                ${C06}开始执行初始化脚本...${CF}\n"
}

cmdCheck() {
  if ! hash "$1" >/dev/null 2>&1 && [[ "$OS" == **"Rocky"** ]]; then
    error "Command [${C1}${1}${CF}] not found, 请先安装 ${1} 再运行脚本。\n\n安装命令: \nsudo dnf install -y ${1}\n"
    return 1
  elif ! hash "$1" >/dev/null 2>&1 && [[ "$OS" == **"CentOS"** ]]; then
    error "Command [${C1}${1}${CF}] not found, 请先安装 ${1} 再运行脚本。\n\n安装命令: \nsudo yum install -y ${1}\n"
    return 1
  elif ! hash "$1" >/dev/null 2>&1 && [[ "$OS" == **"Ubuntu"** ]]; then
    error "Command [${C1}${1}${CF}] not found, 请先安装 ${1} 再运行脚本。\n\n安装命令: \nsudo apt-get install -y ${1}\n"
    return 0
  fi
}

aptInstall() {
  info "安装 ${1}..."
  sudo apt-get install -y $1
}

dnfInstall() {
  info "安装 ${1}..."
  sudo dnf install -y $1
}

yumInstall() {
  info "安装 ${1}..."
  sudo yum install -y $1
}

# Change the source of the package
update_source_for_china() {
  info "*** 把源地址改为中国🇨🇳  ***"
  case ${1} in
  1)
    if [[ "$OS" == *"Ubuntu"* ]]; then
      # Ubuntu /etc/sources.list
      # 创建备份
      cont "备份 /etc/apt/sources.list"
      sudo cp /etc/apt/sources.list{,.bak"$(date +%Y%m%d%-H%M%S)"}
      sudo sed -Ei 's/[a-zA-Z]*.archive.ubuntu.com/mirrors.cloud.tencent.com/g' /etc/apt/sources.list
      # 可选择使用其他源，比如阿里云
      # sudo sed -Ei 's/[a-zA-Z]*.archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
      success "[${C03}sources${CF}] 源修改为 [${C02}USTC中科大${CF}] 完成\n"
      sudo apt-get update >/dev/null
    else
      # Rocky & CentOS /etc/yum.repos.d/ 创建备份目录
      sudo mkdir -p "$backup_directory"
      # 进入源文件夹
      cd "$source_directory"
      # 检查服务器类型和版本
      if [[ "$OS" == **"Rocky"** ]]; then
        if [[ "$OS_VER" == *"9"* ]]; then
          # Rocky Linux 9
          config_files=$(sudo find /etc/yum.repos.d/ -maxdepth 1 -type f -name 'rocky*.repo')
        elif [[ "$OS_VER" == *"8"* ]]; then
          # Rocky Linux 8
          config_files=$(sudo find /etc/yum.repos.d/ -maxdepth 1 -type f -name 'Rocky*.repo')
        fi
        # 备份并修改配置文件
        cont "备份 /etc/yum.repos.d/"
        for file in $config_files; do
          if [[ -f $file ]]; then
            # 获取文件名和后缀
            filename=$(basename "$file")
            extension="${filename##*.}"

            # 移除原有后缀
            filename_no_ext="${filename%.*}"

            # 修改后缀并添加日期
            new_filename="$filename_no_ext-$current_date.$extension"

            # 备份文件
            sudo cp "$file" "$backup_directory/$new_filename"
            cont "备份: $file -> $backup_directory/$new_filename"
          fi
          sudo sed -e 's!^mirrorlist=!#mirrorlist=!g' \
            -e 's!^#baseurl=http://dl.rockylinux.org/$contentdir!baseurl=https://mirrors.cloud.tencent.com/rocky!g' \
            -e 's!//mirrors\.cloud\.aliyuncs\.com!//mirrors.cloud.tencent.com!g' \
            -e 's!http://mirrors!https://mirrors!g' \
            -i "$file"
        done
        success "[${C03}repo${CF}] 源修改为 [${C02}腾讯云${CF}] 完成\n"
        # 更新缓存
        sudo yum makecache >/dev/null

      # CentOS Linux /etc/yum.repos.d/
      elif [[ "$OS" == **"CentOS"** ]]; then
        # CentOS
        config_files=$(sudo find /etc/yum.repos.d/ -maxdepth 1 -type f -name 'CentOS-*.repo')
        # 备份并修改配置文件
        cont "备份 /etc/yum.repos.d/"
        for file in $config_files; do
          if [[ -f $file ]]; then
            # 获取文件名和后缀
            filename=$(basename "$file")
            extension="${filename##*.}"

            # 移除原有后缀
            filename_no_ext="${filename%.*}"

            # 修改后缀并添加日期
            new_filename="$filename_no_ext-$current_date.$extension"

            # 备份文件
            sudo cp "$file" "$backup_directory/$new_filename"
            cont "备份: $file -> $backup_directory/$new_filename"
          fi

          sudo sed -e 's!^mirrorlist=!#mirrorlist=!g' \
            -e 's!^#baseurl=http://mirror.centos.org!baseurl=https://mirrors.cloud.tencent.com!g' \
            -e 's!//mirrors\.cloud\.aliyuncs\.com!//mirrors.cloud.tencent.com!g' \
            -e 's!http://mirrors!https://mirrors!g' \
            -i "$file"
        done
        # 更新缓存
        sudo yum makecache fast >/dev/null
        success "[${C03}repo${CF}] 源修改为 [${C02}腾讯云${CF}] 完成\n"
      fi
    fi
    # epel
    # 检查服务器类型
    if [[ "$OS" == **"Rocky"** ]]; then
      # 如果是Rocky Linux，安装epel-release包
      dnfInstall "epel-release"
      sudo /usr/bin/crb enable

      # 备份并修改配置文件
      cont "备份并修改 ${C4}$OS${CF} 的 epel 配置文件为[tsinghua清华]源"
      # 使用find命令查找/etc/yum.repos.d/目录下所有包含"epel"的文件，但不包括epel-cisco-openh264.repo
      config_files=$(sudo find /etc/yum.repos.d/ -maxdepth 1 -type f -name 'epel*.repo' ! -name 'epel-cisco-openh264.repo')
      for file in $config_files; do
        if [[ -f $file ]]; then
          # 获取文件名和后缀
          filename=$(basename "$file")
          extension="${filename##*.}"

          # 移除原有后缀
          filename_no_ext="${filename%.*}"

          # 修改后缀并添加日期
          new_filename="$filename_no_ext-$current_date.$extension"

          # 备份文件
          sudo cp "$file" "$backup_directory/$new_filename"
          cont "备份: $file -> $backup_directory/$new_filename"
        fi
        sudo sed -e 's!^metalink=!#metalink=!g' \
          -e 's!^#baseurl=!baseurl=!g' \
          -e 's!//download\.fedoraproject\.org/pub!//mirrors.tuna.tsinghua.edu.cn!g' \
          -e 's!//download\.example/pub!//mirrors.tuna.tsinghua.edu.cn!g' \
          -e 's!//mirrors\.cloud\.aliyuncs\.com!//mirrors.tuna.tsinghua.edu.cn!g' \
          -e 's!http://mirrors!https://mirrors!g' \
          -i "$file"
      done
      success "[${C03}epel${CF}] 源修改为 [${C02}tsinghua清华${CF}] 完成\n"

    elif [[ "$OS" == **"CentOS"** ]]; then
      # 如果是CentOS，安装epel-release包
      yumInstall "epel-release"
      # 备份并修改配置文件
      cont "备份并修改 ${C4}$OS${CF} 的 epel 配置文件\n"
      config_files=$(sudo find /etc/yum.repos.d/ -maxdepth 1 -type f -name 'epel*.repo')
      for file in $config_files; do
        if [[ -f $file ]]; then
          # 获取文件名和后缀
          filename=$(basename "$file")
          extension="${filename##*.}"

          # 移除原有后缀
          filename_no_ext="${filename%.*}"

          # 修改后缀并添加日期
          new_filename="$filename_no_ext-$current_date.$extension"

          # 备份文件
          sudo cp "$file" "$backup_directory/$new_filename"
          cont "备份: $file -> $backup_directory/$new_filename"
        fi
        sudo sed -e 's!^metalink=!#metalink=!g' \
          -e 's!^#baseurl=!baseurl=!g' \
          -e 's!//download\.fedoraproject\.org/pub!//mirrors.cloud.tencent.com!g' \
          -e 's!//download\.example/pub!//mirrors.cloud.tencent.com!g' \
          -e 's!//mirrors\.cloud\.aliyuncs\.com!//mirrors.cloud.tencent.com!g' \
          -e 's!http://mirrors!https://mirrors!g' \
          -i "$file"
      done

      success "[${C03}epel${CF}] 源修改为 [${C02}腾讯云${CF}] 完成\n"
    fi
    ;;
  2)
    # python pip sources
    cont "[tsinghua清华] python pip ~/.pip/pip.conf"
    mkdir -p ~/.pip
    echo -e "[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple" >>~/.pip/pip.conf
    ;;
  3)
    # docker dameon.json
    cont "[USTC中科大] docker /etc/docker/daemon.json"
    sudo echo -e "{\n\"registry-mirrors\": [\"https://docker.mirrors.ustc.edu.cn\"]\n}" >/etc/docker/daemon.json
    ;;
  esac
}

# Update the system
update_and_upgrade_system() {
  info "*** 更新升级系统 ***"
  if [[ "$OS" == *"Ubuntu"* ]]; then
    # rm -rf /var/lib/dpkg/lock
    # rm -rf /var/cache/apt/archives/lock
    sudo apt-get update >/dev/null
    sudo apt-get upgrade -y -q
  else
    sudo yum makecache >/dev/null && sudo yum update -y && sudo yum upgrade -y
  fi
  success "系统更新完成。\n"
}

# Install the necessary packages
basic_tools_install() {
  info "*** 安装基础工具 ***"

  # 安装LSB提升系统兼容
  cont "安装 ${C3}LSB${CF}..."
  # 检查 lsb 是否已安装
  if command -v lsb_release >/dev/null 2>&1; then
    warn "${C3}LSB${CF} 已安装，跳过。\n"
  else
    # 安装 lsb
    case "$OS" in
    *"Ubuntu"*)
      aptInstall "lsb"
      ;;
    **"Rocky"**)
      sudo yum config-manager --set-enabled devel
      yumInstall "redhat-lsb-core"
      ;;
    **"CentOS"**)
      yumInstall "redhat-lsb-core"
      ;;
    *)
      warn "未知系统，无法安装 LSB。\n"
      ;;
    esac

    wait # 等待安装完成

    if command -v lsb_release >/dev/null 2>&1; then
      success "${C3}LSB${CF} 安装完成。\n"
    fi
  fi

  # Install basic tools
  cont "安装 ${C3}基础工具${CF}..."

  # 定义基础工具列表
  tools=("vim" "curl" "wget" "git" "zip" "htop")

  for tool in "${tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      warn "${tool} 已安装，跳过。"
    else
      if [[ "$OS" == *"Ubuntu"* ]]; then
        aptInstall "$tool"
      else
        yumInstall "$tool"
      fi
    fi
  done

  if command -v rz &>/dev/null && command -v sz &>/dev/null; then
    warn "lrzsz 已安装，跳过。"
  else
    if [[ "$OS" == *"Ubuntu"* ]]; then
      aptInstall "lrzsz"
    else
      yumInstall "lrzsz"
    fi
  fi

  if command -v mii-tool &>/dev/null; then
    warn "net-tools 已安装，跳过。"
  else
    if [[ "$OS" == *"Ubuntu"* ]]; then
      aptInstall "net-tools"
    else
      yumInstall "net-tools"
    fi
  fi
  # 守护进程
  if [ -e "/etc/supervisord.conf" ] || [ -e "/etc/supervisor/supervisord.conf" ]; then
    warn "supervisor 已安装，跳过。"
  else
    if [[ "$OS" == *"Ubuntu"* ]]; then
      aptInstall "supervisor"
    else
      yumInstall "supervisor"
    fi
  fi

  success "基础工具安装完成。\n"

}

# Disable unused services
disable_services() {
  info "*** 精简开机启动 ***"
  if [[ "$OS" == *"Ubuntu"* ]]; then
    success "$OS 无需优化。\n"
  elif [[ "$OS" == **"Rocky"** ]]; then
    # 定义要禁用的服务列表
    success "$OS 无需优化。\n"

  elif [[ "$OS" == **"CentOS"** ]]; then
    # 在CentOS上，额外禁用postfix服务
    services_to_disable+=("postfix")

    # 循环禁用服务
    for service in "${services_to_disable[@]}"; do
      cont "正在禁用 ${C1}${service}${CF} 服务..."
      sudo systemctl stop "${service}.service"
      sudo systemctl disable "${service}.service"
    done

    # 显示已禁用的服务列表
    echo '# systemctl list-unit-files | grep -E "'$(IFS=\| echo "${services_to_disable[*]}")'"'
    sudo systemctl list-unit-files | grep -E "$(IFS=\| echo "${services_to_disable[*]}")"

    success "精简开机启动完成。\n"
  fi
}

# Disable SELinux
disable_selinux() {
  info "*** 禁用 selinux ***"
  if [[ "$OS" == *"Ubuntu"* ]] && [ ! -f "/etc/selinux/config" ]; then
    success "Ubuntu 没有 selinux，跳过。\n"
  else
    SELINUX=$(grep -c '\b^SELINUX=disabled' /etc/selinux/config)
    if [ "$SELINUX" -eq 1 ]; then
      success "selinux 已禁用"
    else
      sudo setenforce 0
      sudo sed -Ei 's!SELINUX=enforcing!SELINUX=disabled!g' /etc/selinux/config
      success "禁用 selinux 完成。\n"
    fi
  fi
}

# Password rule configuration
password_rules() {
  info "*** 设置系统密码规则，提升安全性 ***"

  cont "正在设置密码规则...\n至少${C1}8${CF}个字符,必须包含${C1}大小${CF}写字母"

  # /etc/login.defs
  sudo sed -Ei "/^PASS_MIN_LEN/s!5!8!g" /etc/login.defs

  # /etc/security/pwquality.conf
  if [[ "$OS" == *"Ubuntu"* || "$OS" == **"Rocky"** ]]; then
    pwquality_conf="/etc/security/pwquality.conf"
    sudo touch "$pwquality_conf"
    sudo tee -a "$pwquality_conf" >/dev/null <<EOL
minlen = 8
minclass = 2
maxrepeat = 3
EOL
  elif [[ "$OS" == **"CentOS"** ]]; then
    # 至少 8 个字符
    sudo authconfig --passminlen=8 --update
    # 至少 2 种字符类别
    sudo authconfig --passminclass=2 --update
    # 至少 1 个小写字母
    sudo authconfig --enablereqlower --update
    # 至少 1 个大写字母
    sudo authconfig --enablerequpper --update
  fi

  success "系统密码规则设置完成。\n"
}

# Delete useless users and groups
delete_users_and_groups() {
  info "*** 删除无用的用户和组 ***"

  # 备份 /etc/passwd 和 /etc/group
  sudo cp /etc/passwd{,.bak"$(date +%Y%m%d-%H%M%S)"}
  sudo cp /etc/group{,.bak"$(date +%Y%m%d-%H%M%S)"}

  # 需要删除的用户列表
  users_to_delete=("adm" "bin" "ftp" "games" "gopher" "halt" "lp" "news" "operator" "postfix" "sync" "shutdown" "uucp")

  # 需要删除的组列表
  groups_to_delete=("adm" "dip" "lp" "news" "games" "uucp" "video" "ftp")

  # 删除用户
  for user in "${users_to_delete[@]}"; do
    sudo userdel "$user" 2>/dev/null # 避免显示错误信息
  done

  # 删除组
  for group in "${groups_to_delete[@]}"; do
    sudo groupdel "$group" 2>/dev/null # 避免显示错误信息
  done

  success "删除无用的用户和组完成。\n"
}

# Create new user
create_new_user() {
  case ${1} in
  1)
    info "*** 创建新用户 ***"

    # 用户名规则
    while :; do
      read -p "用户名: " userName
      if [[ "$userName" =~ .*root.* || "$userName" =~ .*admin.* ]]; then
        warn "用户名不能以 ${C01}admin${CF} 或 ${C01}root${CF} 开头, 请重新输入\n"
      elif echo "$userName" | grep -qP '[\p{Han}]'; then
        warn "用户名不能包含<中文>, 请重新输入\n"
      elif [ -z "$userName" ]; then
        warn "用户名不能为<空>, 请重新输入\n"
      else
        break
      fi
    done

    # 密码规则确认
    while :; do
      read -rp "输入密码(密码输入已隐藏): " -s userPass
      echo ''
      read -rp "再次确认密码: " -s userPasswd
      echo ''

      if [ "$userPass" != "$userPasswd" ]; then
        warn "两次密码验证失败，请重新输入\n"
      elif [ -z "$userPasswd" ]; then
        warn "密码不能为<空>，请重新输入\n"
      elif [[ ${#userPass} -lt 8 || ! "$userPass" =~ [A-Z] || ! "$userPass" =~ [a-z] ]]; then
        warn "密码必须至少8个字符，包括至少1个大写字母和1个小写字母，请重新输入\n"
      else
        break
      fi
    done

    # 为新增用户添加密钥
    printf "请输入您的公钥: "
    read -r user_rsa

    # 添加用户及密码
    if [[ "$OS" == *"Ubuntu"* ]]; then
      sudo useradd -m -s /bin/bash -G sudo "$userName"
      sudo echo "$userName:$userPasswd" | sudo chpasswd >/dev/null 2>&1
    else
      useradd -G wheel "$userName"
      sudo echo "$userPasswd" | passwd --stdin "$userName" >/dev/null 2>&1
    fi

    # 新增 ssh 目录
    sudo mkdir -p /home/$userName/.ssh
    sudo chown "$userName":"$userName" /home/$userName/.ssh
    sudo chmod +xr /home/$userName/.ssh

    # 新增 authorized_keys 文件
    sudo touch /home/$userName/.ssh/authorized_keys
    sudo chown "$userName:$userName" /home/$userName/.ssh/authorized_keys
    sudo chmod o+rw /home/$userName/.ssh/authorized_keys
    sudo echo "$user_rsa" >>/home/$userName/.ssh/authorized_keys
    sudo chmod 600 /home/$userName/.ssh/authorized_keys
    sudo chmod 700 /home/$userName/.ssh

    # 添加用户到 /etc/sudoers
    # 设置标志用于检测是否已成功添加用户
    userAdded=false
    # 循环尝试添加用户到 /etc/sudoers
    while [ "$userAdded" != true ]; do
      # 检查 /etc/sudoers 是否存在 $userName 用户
      if ! sudo grep -q "^$userName" /etc/sudoers; then
        # 将 $userName 用户添加到 /etc/sudoers
        echo "$userName ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers >/dev/null
        if [ $? -eq 0 ]; then
          success "成功创建用户 ${C4}$userName${CF} 并添加到 /etc/sudoers。\n"
          userAdded=true
        else
          warn "在尝试添加${C01}$userName${CF}到 /etc/sudoers 文件时发生错误。稍等片刻后将尝试再次添加。\n"
          sleep $delay # 可以根据需要调整等待时间
          userAdded=false
        fi
      else
        warn "用户 ${C02}$userName${CF} 已存在于 /etc/sudoers。\n"
        userAdded=false
      fi
    done
    ;;
  2)
    # 为现有用户添加密钥
    info "🔐 为现有用户添加密钥"
    while :; do
      read -p "用户名: " userName

      # 检测用户名是否不存在
      if [ -z "$userName" ]; then
        warn "用户名不能为<空>，请重新输入\n"
      elif echo "$userName" | grep -qP '[\p{Han}]'; then
        warn "用户名不能包含<中文>, 请重新输入\n"
      elif ! id "$userName" &>/dev/null; then
        warn "用户 $userName 不存在，请重新输入\n"
      else
        break
      fi
    done

    root_ssh_path="/root/.ssh"
    root_auth_file="/root/.ssh/authorized_keys"
    user_ssh_path="/home/$userName/.ssh"
    user_auth_file="/home/$userName/.ssh/authorized_keys"

    printf "请输入您的密钥: "
    read -r rsa_key

    cont "为 ${C02}$userName${CF} 添加密钥..."
    if [ "$userName" == "root" ]; then
      # 为 root 用户添加密钥

      if [ ! -d "$root_ssh_path" ]; then
        # 如果 /root/.ssh 目录不存在，先创建它
        sudo mkdir -p "$root_ssh_path"
        sudo chmod 700 "$root_ssh_path"
      fi

      # 新增 authorized_keys 文件
      echo "$rsa_key" | sudo tee -a "$root_auth_file" >/dev/null
      sudo chmod 600 "$root_auth_file"

    elif [ "$userName" != "root" ]; then
      # 为普通用户添加密钥

      if [ ! -d "$user_ssh_path" ]; then
        # 如果用户的 .ssh 目录不存在，先创建它
        sudo mkdir -p "$user_ssh_path"
        sudo chown "$userName":"$userName" "$user_ssh_path"
        sudo chmod 700 "$user_ssh_path"
      fi

      # 新增 authorized_keys 文件
      echo "$rsa_key" | sudo tee -a "$user_auth_file" >/dev/null
      sudo chmod 600 "$user_auth_file"
    fi

    success "用户: ${C2}$userName${CF} 密钥添加完成。\n"

    ;;
  esac
}

# 配置 ssh 权限
sshd_setting() {
  info "*** 开始配置 SSH 权限 ***"
  # 输入错误密码时锁定用户 root 3分钟 其他用户 10分钟
  cont "正在设置密码错误锁定规则...\nroot用户锁定: ${C1}3${CF} 分钟\n其他用户锁定: ${C1}10${CF} 分钟"
  sudo sed -Ei '1a auth required pam_tally2.so deny=3 unlock_time=600 even_deny_root root_unlock_time=180' /etc/pam.d/sshd
  success "用户密码错误锁定规则完成。\n"
  cont "设置 SSH 端口..."
  while :; do
    read -rp "请输入 SSH 端口号(留空默认: 22): " sshPort
    sshPort="${sshPort:-22}"

    if [[ ! $sshPort =~ ^[0-9]+$ ]]; then
      warn "端口仅支持数字，请重新输入!"
    #elif [ "$sshPort" -lt "1024" ]; then
    #  warn "端口号不能小于 1024，请重新输入!"
    elif [ "$sshPort" -gt "65535" ]; then
      warn "端口号不能大于 65535，请重新输入!"
    else
      break
    fi
  done

  # 修改 /etc/ssh/sshd_config 配置
  ssh_auth_file="/etc/ssh/sshd_config"
  sudo sed -Ei 's/^#Port [0-9]{1,5}/Port '"$sshPort"'/g' "$ssh_auth_file"

  # 禁止密码登陆
  if [[ "$OS" == *"Ubuntu"* || "$OS" == **"Rocky"** && "$OS_VER" == *"9"* ]]; then
    sudo sed -Ei '/^#?(PasswordAuthentication|GSSAPIAuthentication)/s/#//g' "$ssh_auth_file"
  elif [[ "$OS" == **"Rocky"** && "$OS_VER" == *"9"* ]]; then
    sudo sed -Ei 's/^#UsePAM.*/UsePAM yes/g' "$ssh_auth_file"
  elif [[ "$OS" == **"CentOS"** || "$OS" == **"Rocky"** && "$OS_VER" == *"8"* ]]; then
    sudo sed -Ei '/^GSSAPIAuthentication/s/yes/no/g' "$ssh_auth_file"
  fi
  sudo sed -Ei '/^PasswordAuthentication/s/yes/no/g' "$ssh_auth_file"
  sudo sed -Ei '/^#?PermitEmptyPasswords/s/#//g' "$ssh_auth_file"

  # 禁止 root 用户登录
  if [[ "$OS" == **"Rocky"** && "$OS_VER" == *"8"* ]]; then
    sudo sed -Ei '/^PermitRootLogin/s/yes/no/g' "$ssh_auth_file"
  else
    sudo sed -Ei 's/^#PermitRootLogin.*/PermitRootLogin no/g' "$ssh_auth_file"
  fi

  # 重启 SSH 服务
  if ! sudo systemctl restart sshd; then
    error "sshd 重启失败，请检查配置。"
  else
    success "${C05}${OS}${CF} ${C02}$ssh_auth_file${CF} 修改完成。\n"
  fi

  # 防火墙设置
  cont "防火墙放通 SSH 端口 ${C02}$sshPort${CF}..."
  if command -v firewall-cmd &>/dev/null; then
    # CentOS 和 Rocky Linux 上使用 firewalld
    if ! rpm -qa | grep firewalld >>/dev/null; then
      cont "未安装 firewalld，开始安装...\n"
      yumInstall "firewalld"
      sudo systemctl enable --now firewalld
    fi
    sudo firewall-cmd --permanent --add-port="$sshPort"/tcp
    # 开启 NAT 转发，默认关闭。
    #sudo firewall-cmd --permanent --add-masquerade
    sudo firewall-cmd --reload
    sudo firewall-cmd --list-all
    success "防火墙已放通 ${C02}$sshPort${CF} SSH 端口。\n"
  elif command -v ufw &>/dev/null; then
    # Ubuntu 上使用 ufw
    if ! dpkg-query -W -f='${Status}' ufw 2>/dev/null | grep -q "ok installed"; then
      cont "未安装 ufw，开始安装...\n"
      sudo apt-get update
      aptInstall "ufw"
    fi
    cont "放通 SSH ${C3}$sshPort${CF} 端口..."
    sudo ufw allow "$sshPort"/tcp
    sudo ufw --force enable
    success "防火墙已放通 ${C02}$sshPort${CF} SSH 端口。\n"
  else
    warn "不支持的防火墙管理工具。\n"
  fi

}

# 配置bashrc
bashrc_setting() {
  info "*** 配置 bashrc alias ***"

  backup_bashrc() {
    backup_file="${1}.bak$(date +%Y%m%d%-H%M%S)"
    sudo cp "$1" "$backup_file"
  }

  if [[ "$OS" == *"Ubuntu"* ]]; then
    backup_bashrc /home/$currUser/.bashrc
    backup_bashrc /root/.bashrc

    sudo chmod o+rw /root/.bashrc
    sudo tee -a /root/.bashrc >/dev/null <<EOF
#终端颜色
C0='\[\e[0m\]'    # 终端默认颜色
C1='\[\e[1;31m\]' # 红色
C2='\[\e[1;32m\]' # 绿色
C3='\[\e[1;33m\]' # 黄色
C4='\[\e[1;34m\]' # 蓝色
C5='\[\e[1;35m\]' # 紫色
C6='\[\e[1;36m\]' # 青色
C7='\[\e[1;37m\]' # 白色
export PS1='\${C5}\t \${C1}\u\${C3}@\${C2}\h \${C6}\w \${C0}\\$ '
EOF
    sudo chmod o-w /root/.bashrc

    sudo tee -a /home/$currUser/.bashrc >/dev/null <<EOF
#终端颜色
C0='\[\e[0m\]'    # 终端默认颜色
C1='\[\e[1;31m\]' # 红色
C2='\[\e[1;32m\]' # 绿色
C3='\[\e[1;33m\]' # 黄色
C4='\[\e[1;34m\]' # 蓝色
C5='\[\e[1;35m\]' # 紫色
C6='\[\e[1;36m\]' # 青色
C7='\[\e[1;37m\]' # 白色
export PS1='\${C5}\t \${C4}\u\${C3}@\${C2}\h \${C6}\w \${C0}\\$ '
EOF

    sudo tee -a /home/$userName/.bashrc >/dev/null <<EOF
#终端颜色
C0='\[\e[0m\]'    # 终端默认颜色
C1='\[\e[1;31m\]' # 红色
C2='\[\e[1;32m\]' # 绿色
C3='\[\e[1;33m\]' # 黄色
C4='\[\e[1;34m\]' # 蓝色
C5='\[\e[1;35m\]' # 紫色
C6='\[\e[1;36m\]' # 青色
C7='\[\e[1;37m\]' # 白色
export PS1='\${C5}\t \${C4}\u\${C3}@\${C2}\h \${C6}\w \${C0}\\$ '
EOF

    echo $'\nset -o vi\nalias vi="vim"\nalias ll="ls -ahlF --color=auto --time-style=long-iso"\nalias ls="ls --color=auto --time-style=long-iso"\nalias grep="grep --color=auto"' | sudo tee -a /root/.bashrc /home/$currUser/.bashrc /home/$userName/.bashrc >/dev/null

  else
    backup_bashrc /etc/bashrc

    sudo tee -a /etc/bashrc >/dev/null <<EOF
#终端颜色
C0='\[\e[0m\]'    # 终端默认颜色
C1='\[\e[1;31m\]' # 红色
C2='\[\e[1;32m\]' # 绿色
C3='\[\e[1;33m\]' # 黄色
C4='\[\e[1;34m\]' # 蓝色
C5='\[\e[1;35m\]' # 紫色
C6='\[\e[1;36m\]' # 青色
C7='\[\e[1;37m\]' # 白色
if [ \$(whoami) = "root" ]; then # 设置 root 用户提示符为红色
    PS1="\${C5}\t \${C1}\u\${C3}@\${C2}\h \${C6}\w \${C0}\\$ "
else
    PS1="\${C5}\t \${C4}\u\${C3}@\${C2}\h \${C6}\w \${C0}\\$ "
fi

EOF
    echo $'\nset -o vi\nalias vi="vim"\nalias ll="ls -ahlF --color=auto --time-style=long-iso"\nalias ls="ls --color=auto --time-style=long-iso"\nalias grep="grep --color=auto"' | sudo tee -a /etc/bashrc >/dev/null

  fi

  success "bashrc alias 设置完成。\n"
}

# 配置 vimrc
vimrc_setting() {
  info "*** 开始配置vim ***"
  if [ -f "/etc/redhat-release" ]; then
    # CentOS 或 Rocky Linux
    VIMRC_PATH="/etc/vimrc"
  elif [[ "$OS" == *"Ubuntu"* ]]; then
    # Ubuntu
    VIMRC_PATH="/etc/vim/vimrc"
  else
    # 默认路径（可根据需要修改）
    VIMRC_PATH="/etc/vimrc"
  fi

  # 检查是否已存在 Vim 配置文件，如果不存在则创建
  if [ ! -f "$VIMRC_PATH" ]; then
    sudo touch "$VIMRC_PATH"
  fi

  # 使用 tee 命令以普通用户身份将配置写入 Vim 配置文件
  if ! grep pastetoggle $VIMRC_PATH >>/dev/null; then
    echo -e "set pastetoggle=<F9>\nsyntax on\nset tabstop=4\nset softtabstop=4\nset shiftwidth=4\nset expandtab\nset bg=dark\nset ruler\ncolorscheme ron" | sudo tee -a "$VIMRC_PATH" >/dev/null
    success "Vim 配置已添加到 $VIMRC_PATH\n"
  else
    warn "vim 已经配置, 进行下一步设置...\n"
    timezone_setting
  fi
}

# 设置系统时区和时间同步
timezone_setting() {
  TZ="Asia/Shanghai"
  curr_TZ=$(timedatectl | awk '/Time zone/ {print $3}')

  info "*** 设置系统时区 ***"

  # 修改系统时区
  if ! timedatectl | grep "Asia/Shanghai" &>/dev/null; then
    info "设置系统时区为: ${C02}$TZ${CF}..."
    sudo timedatectl set-timezone $TZ

  else
    warn "当前系统时区为: ${C02}$TZ${CF}, 跳过时区设置。"
  fi

  # 时间同步
  info "*** 设置时间同步 ***"
  # 根据系统名称选择不同的时间同步方式
  if [[ $OS == **"CentOS"** || $OS == **"Rocky"** ]]; then
    # 对于 CentOS 和 Rocky，使用 chrony 进行时间同步
    yumInstall "chrony"
    # 检查是否存在 pool 参数
    if grep -q "^pool" /etc/chrony.conf; then
      # 在现有的 pool 行之前添加新的 NTP 服务器
      sudo sed -i '/^pool/s/.*rocky.pool.ntp.org/pool cn.ntp.org.cn iburst\npool ntp.aliyun.com iburst\npool ntp.tencent.com iburst\n&/' /etc/chrony.conf
    else
      # 在 server 行前添加新的 NTP 服务器
      sudo sed -i '/^server/s/server 0.centos.pool.ntp.org/server cn.ntp.org.cn iburst\nserver ntp.aliyun.com iburst\nserver ntp.tencent.com iburst\n&/' /etc/chrony.conf
    fi
    sudo firewall-cmd --add-service=ntp --permanent
    sudo firewall-cmd --reload
    sudo systemctl enable --now chronyd
    sudo chronyc -a makestep
    sudo timedatectl status

  elif [[ $OS == *"Ubuntu"* ]]; then
    # 对于 Ubuntu，使用 systemd-timesyncd 进行时间同步
    sudo apt-get update
    aptInstall "systemd-timesyncd"
    # 修改systemd-timesyncd配置文件
    sudo sed -i '/^#NTP/s/.*/NTP=cn.ntp.org.cn ntp.aliyun.com ntp.tencent.com/' /etc/systemd/timesyncd.conf
    sudo ufw allow 123/udp
    sudo systemctl enable --now systemd-timesyncd
    sudo timedatectl status

  else
    warn "未知系统，无法设置时间同步。"
  fi

  success "系统时区已设为：${C02}$TZ${CF} 并${C02}开启${CF}时间同步。\n"
}

# 配置 ulimit
ulimit_setting() {
  ulimit_value=655360
  rc_="/etc/rc."
  limits_conf="/etc/security/limits.conf"

  info "*** 配置 ulimit ***"

  # 在 /etc/rc. 中添加 ulimit 配置
  if [[ -e $rc_ ]]; then
    if [[ ! -z "$(sudo grep ^ulimit $rc_)" && "$(sudo awk '{print $3}' $rc_ | head -1)" != "$ulimit_value" ]]; then
      sudo sed -i "s/^ulimit.*/ulimit -SHn $ulimit_value/g" $rc_
    else
      echo "ulimit -SHn $ulimit_value" | sudo tee -a $rc_
    fi
    sudo chmod +x $rc_
  fi

  # 在 /etc/security/limits.conf 中添加配置
  if [[ -e $limits_conf ]]; then
    if ! sudo grep -q "^* soft nproc 102400" $limits_conf; then
      echo -e "\n* soft nproc 102400\n* hard nproc 102400\n* soft nofile 102400\n* hard nofile 102400" | sudo tee -a $limits_conf
    fi
  fi

  # 设置当前会话的 ulimit
  ulimit -n $ulimit_value
  success "Ulimit 配置完成。\n"
}

# 配置 sysctl
sysctl_setting() {
  info "*** 系统内核优化 ***"
  sudo cp /etc/sysctl.conf{,.bak"$(date +%Y%m%d%-H%M%S)"}
  echo | sudo tee /etc/sysctl.conf >/dev/null
  if [[ "$OS" == **"Rocky"** ]] || [[ "$OS" == **"CentOS"** ]]; then
    sudo tee /etc/sysctl.conf >/dev/null <<EOF
fs.file-max = 655350
fs.suid_dumpable = 0
vm.swappiness = 0
vm.dirty_ratio = 20
# overcommit_memory 内存机制
vm.overcommit_memory=1
vm.dirty_background_ratio = 5
# 调整进程最大虚拟内存区域数量
vm.max_map_count=262144
# 开启重用。允许将TIME-WAIT sockets 重新用于新的TCP 连接
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
#net.ipv4.tcp_tw_recycle = 0
# 开启SYN洪水攻击保护
net.ipv4.tcp_syncookies = 1
# 当keepalive 起用的时候, TCP 发送keepalive 消息的频度。缺省是2 小时
net.ipv4.tcp_keepalive_time = 600
# timewait的数量, 默认18000
net.ipv4.tcp_max_tw_buckets = 36000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 262144
net.ipv4.tcp_max_orphans = 262144
#net.netfilter.nf_conntrack_max = 25000000
#net.netfilter.nf_conntrack_tcp_timeout_established = 180
#net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
#net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
#net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
# 开启反向路径过滤(增强网络安全)
net.ipv4.conf.all.rp_filter = 1
# IP 转发, 默认关闭
#net.ipv4.ip_forward=1
EOF
  elif [[ "$OS" == *"Ubuntu"* ]]; then
    sudo tee /etc/sysctl.conf >/dev/null <<EOF
fs.file-max = 655350
fs.suid_dumpable = 0
vm.swappiness = 0
vm.dirty_ratio = 20
# overcommit_memory 内存机制
vm.overcommit_memory=1
vm.dirty_background_ratio = 5
# 调整进程最大虚拟内存区域数量
vm.max_map_count=262144
# 开启重用。允许将TIME-WAIT sockets 重新用于新的TCP 连接
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
#net.ipv4.tcp_tw_recycle = 0
# 开启SYN洪水攻击保护
net.ipv4.tcp_syncookies = 1
# 当keepalive 起用的时候, TCP 发送keepalive 消息的频度。缺省是2 小时
net.ipv4.tcp_keepalive_time = 600
# timewait的数量, 默认18000
net.ipv4.tcp_max_tw_buckets = 36000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 262144
net.ipv4.tcp_max_orphans = 262144
# 开启反向路径过滤(增强网络安全)
net.ipv4.conf.all.rp_filter = 1
# IP 转发, 默认关闭
#net.ipv4.ip_forward=1
EOF
  fi
  if command -v sysctl &>/dev/null; then
    sudo sysctl -p
    success "sysctl 内核优化完成。\n"
  elif command -v sysctl.d &>/dev/null; then
    sudo sysctl --system
    success "sysctl 内核优化完成。\n"
  else
    warn "无法找到 sysctl 命令，开始安装...\n"
    if [[ "$OS" == *"Ubuntu"* ]]; then
      sudo apt-get update
      aptInstall "procps"
      if command -v sysctl &>/dev/null; then
        sudo sysctl -p
        success "sysctl 内核优化完成。\n"
      fi
    elif [[ "$OS" == **"Rocky"** ]] || [[ "$OS" == **"CentOS"** ]]; then
      yumInstall "procps"
      if command -v sysctl &>/dev/null; then
        sudo sysctl -p
        success "sysctl 内核优化完成。\n"
      else
        warn "不支持的系统类型。\n"
        return 1
      fi
    fi
  fi
}

# 安装 Nginx
install_nginx() {
  info "*** 安装 Nginx ***"
  if ! sudo grep -q "^fs.file-max" /etc/sysctl.conf; then
    sysctl_setting
  fi
  # Nginx 安装逻辑
  if [[ "$OS" == **"CentOS"** ]] || [[ "$OS" == **"Rocky"** ]]; then
    yumInstall "yum-utils"
    sudo tee /etc/yum.repos.d/nginx.repo >/dev/null <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
    yumInstall "nginx"
  elif [[ "$OS" == *"Ubuntu"* ]]; then
    sudo rm -rf /var/lib/dpkg/lock
    sudo rm -rf /var/cache/apt/archives/lock
    aptInstall "software-properties-common"
    sudo add-apt-repository -y ppa:nginx/stable >/dev/null
    sudo apt-get update >/dev/null
    aptInstall "nginx"
  else
    warn "不支持的系统类型，仅支持 Ubuntu, Rocky, CentOS"
    exit 1
  fi

  cont "配置防火墙放通 http & https 端口..."

  while :; do
    read -rp "请输入 http 端口(留空默认: 80): " http_port
    http_port=${http_port:-"80"}
    if [[ ! $http_port =~ ^[0-9]+$ ]] || [ "$http_port" -gt "65535" ]; then
      warn "端口仅支持数字，且不能超过 65535，请重新输入!"
    else
      break
    fi
  done

  while :; do
    read -rp "请输入 https 端口(留空默认: 443): " https_port
    https_port=${https_port:-"443"}
    if [[ ! $https_port =~ ^[0-9]+$ ]] || [ "$https_port" -gt "65535" ]; then
      warn "端口仅支持数字，且不能超过 65535，请重新输入!"
    else
      break
    fi
  done

  if command -v ufw &>/dev/null; then
    sudo ufw allow "$http_port/tcp"
    sudo ufw allow "$https_port/tcp"
    sudo ufw --force enable
  elif command -v firewall-cmd &>/dev/null; then
    sudo firewall-cmd --permanent --add-port="$http_port/tcp"
    sudo firewall-cmd --permanent --add-port="$https_port/tcp"
    sudo firewall-cmd --reload
  else
    warn "不支持的防火墙管理工具，请手动配置防火墙规则!"
  fi

  if ! sudo systemctl enable --now nginx; then
    warn "Nginx 启动失败，请查看配置!"
  else
    success "Nginx 安装启动完成。\n"
  fi

}

# 安装 Tengine
install_tengine() {

  while :; do
    read -rp "请输入 Tengine 版本号(留空默认: 3.1.0): " tengine_version
    tengine_version=${tengine_version:-"3.1.0"}
    # 检查 HTTP 状态码是否为 200
    if [ "$(curl --write-out %{http_code} --silent --output /dev/null "https://tengine.taobao.org/download/tengine-${tengine_version}.tar.gz")" != 200 ]; then
      warn "${C05}\E[33;5m版本号错误,请重新输入！\E[0m"
      warn "版本号查询：https://tengine.taobao.org/download.html"
    else
      break
    fi
  done

  tengine_user="nginx"
  source_path="/server/nginx/sbin/nginx"
  link_path="/usr/sbin/nginx"
  tengine_src="/usr//src/tengine_install_tmp"
  jemalloc_dl="https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2"
  tengine_dl="https://tengine.taobao.org/download/tengine-$tengine_version.tar.gz"

  tools=("wget" "curl" "tar" "make" "bzip2")

  # 安装基础工具
  for tool in "${tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      warn "${tool} 已安装，跳过。"
    else
      yumInstall "$tool"
    fi
  done

  sudo mkdir -p "$tengine_src"
  cd "$tengine_src"
  sudo wget "$jemalloc_dl"
  sudo wget "$tengine_dl"
  sudo tar xjf "$tengine_src/jemalloc-5.3.0.tar.bz2" >/dev/null
  sudo tar xvf "$tengine_src/tengine-$tengine_version.tar.gz" >/dev/null

  info "*** 安装 Tengine 版本 $tdengine_version ***"

  # Tengine 安装逻辑

  if ! sudo grep -q "^fs.file-max" /etc/sysctl.conf; then
    sysctl_setting
  else
    cont "内核已优化，安装 Tengine $tengine_version..."
  fi

  if [[ "$OS" == **"CentOS"** || "$OS" == **"Rocky"** ]]; then
    cont "安装基础工具..."
    # 定义基础工具列表
    #sudo yum groupinstall -y "Development Tools"
    # "jemalloc-devel" 手动安装
    tools=("yum-utils" "gcc" "gcc-c++" "pcre-devel" "openssl-devel" "zlib-devel" "epel-release")

    # 安装基础工具
    for tool in "${tools[@]}"; do
      if command -v "$tool" &>/dev/null; then
        warn "${tool} 已安装，跳过。"
      else
        yumInstall "$tool"
      fi
    done

    cd "$tengine_src/jemalloc-5.3.0"
    sudo ./configure && sudo make && sudo make install

    if grep -q "/usr//lib/" "/etc/ld.so.conf.d/_lib.conf"; then
      sudo ldconfig -v
    else
      echo "/usr//lib/" | sudo tee -a /etc/ld.so.conf.d/_lib.conf >/dev/null
      sudo ldconfig -v
    fi

    cd "$tengine_src/tengine-$tengine_version"
    ./configure --prefix=/server/nginx \
      --user=$tengine_user \
      --group=$tengine_user \
      --conf-path=/server/nginx/conf/nginx.conf \
      --error-log-path=/server/nginx/log/nginx_error.log \
      --http-log-path=/server/nginx/log/nginx_access.log \
      --pid-path=/server/nginx/run/nginx.pid \
      --lock-path=/server/nginx/lock/nginx.lock \
      --with-http_sub_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_mp4_module \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --with-http_addition_module \
      --with-http_secure_link_module \
      --with-http_stub_status_module \
      --with-http_gzip_static_module \
      --with-http_random_index_module \
      --with-jemalloc \
      --with-pcre \
      --http-client-body-temp-path=/server/nginx/tmp/client_body_temp \
      --http-proxy-temp-path=/server/nginx/tmp/proxy_temp \
      --http-fastcgi-temp-path=/server/nginx/tmp/fcgi_temp \
      --http-uwsgi-temp-path=/server/nginx/tmp/uwsgi_temp \
      --http-scgi-temp-path=/server/nginx/tmp/scgi_temp

    if [ $? -eq 0 ]; then
      sudo make -j 4 && sudo make install
    else
      warn "Tengine 编译参数有误，请检查!"
      exit 1
    fi

    sudo mkdir -p /server/nginx/tmp/client_body_temp \
      /server/nginx/tmp/proxy_temp \
      /server/nginx/tmp/fcgi_temp \
      /server/nginx/tmp/uwsgi_temp \
      /server/nginx/tmp/scgi_temp

    # 检查用户是否存在
    if id "$tenging_user" &>/dev/null; then
      echo "用户 $tengine_user 已存在，跳过创建。"
    else
      # 创建用户
      sudo useradd -r -s /sbin/nologin "$tengine_user"
      echo "用户 $tengine_user 创建成功。"
    fi

    # 检查软链接是否存在
    if [ -e "$link_path" ]; then
      echo "软链接 $link_path 已存在，跳过创建。"
    else
      # 创建软链接
      sudo ln -s "$source_path" "$link_path"
      echo "软链接 $link_path 创建成功。"
    fi

    sudo chown -R nginx:root /server/nginx/tmp/

    cont "配置防火墙放通 http & https 端口..."

    while :; do
      read -rp "请输入 http 端口(留空默认: 80): " http_port
      http_port=${http_port:-"80"}
      if [[ ! $http_port =~ ^[0-9]+$ ]] || [ "$http_port" -gt "65535" ]; then
        warn "端口仅支持数字，且不能超过 65535，请重新输入!"
      else
        break
      fi
    done

    while :; do
      read -rp "请输入 https 端口(留空默认: 443): " https_port
      https_port=${https_port:-"443"}
      if [[ ! $https_port =~ ^[0-9]+$ ]] || [ "$https_port" -gt "65535" ]; then
        warn "端口仅支持数字，且不能超过 65535，请重新输入!"
      else
        break
      fi
    done

    if command -v ufw &>/dev/null; then
      sudo ufw allow "$http_port/tcp"
      sudo ufw allow "$https_port/tcp"
      sudo ufw --force enable
    elif command -v firewall-cmd &>/dev/null; then
      sudo firewall-cmd --permanent --add-port="$http_port/tcp"
      sudo firewall-cmd --permanent --add-port="$https_port/tcp"
      sudo firewall-cmd --reload
    else
      warn "不支持的防火墙管理工具，请手动配置防火墙规则!"
    fi

    nginx_version=$(nginx -v 2>&1 | grep "nginx" | cut -f2 -d "/")

    sudo tee /etc/systemd/system/nginx.service >/dev/null <<EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/server/nginx/run/nginx.pid
ExecStartPre=/server/nginx/sbin/nginx -t
ExecStart=/server/nginx/sbin/nginx
ExecReload=/server/nginx/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload

    SELINUX=$(grep -c '\b^SELINUX=disabled' /etc/selinux/config)
    if [ "$SELINUX" -eq 1 ]; then
      cont "selinux 已禁用。"
    else
      cont "为 Tengine 目录添加 Selinux 权限。"
      sudo chcon -R -t httpd_exec_t /server/nginx/sbin/
      sudo chcon -R -t httpd_log_t /server/nginx/log/
      sudo chcon -R -t httpd_config_t /server/nginx/conf/
      sudo chcon -R -t httpd_var_run_t /server/nginx/run/
      sudo chcon -R -t httpd_sys_content_t /server/nginx/html/
    fi

    sudo systemctl enable nginx
    if ! sudo systemctl start nginx; then
      warn "Tengine 启动失败，请查看配置!"
    else
      success "Tengine 安装启动完成。\n"
    fi
  elif [[ "$OS" == *"Ubuntu"* ]]; then
    cont "安装基础工具..."
    # 定义基础工具列表
    # "libjemalloc-dev" 手动安装
    tools=("wget" "tar" "make" "build-essential" "gcc" "libpcre3" "libpcre3-dev" "zlib1g" "zlib1g-dev" "libssl-dev")

    # 安装基础工具
    for tool in "${tools[@]}"; do
      if command -v "$tool" &>/dev/null; then
        warn "${tool} 已安装，跳过。"
      else
        aptInstall "$tool"
      fi
    done

    cd /usr//src || exit 1
    sudo wget https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2
    sudo tar xjf jemalloc-5.3.0.tar.bz2
    cd jemalloc-5.3.0 || exit 1
    sudo ./configure && sudo make && sudo make install

    if grep -q "/usr//lib/" "/etc/ld.so.conf.d/_lib.conf"; then
      sudo ldconfig -v
    else
      echo "/usr//lib/" | sudo tee -a /etc/ld.so.conf.d/_lib.conf >/dev/null
      sudo ldconfig -v
    fi

    cd /usr//src || exit 1
    sudo wget https://tengine.taobao.org/download/tengine-$tengine_version.tar.gz
    sudo tar xvf tengine-$tengine_version.tar.gz
    cd tengine-$tengine_version || exit 1
    sudo ./configure --prefix=/server/nginx \
      --user=nginx \
      --group=nginx \
      --conf-path=/server/nginx/conf/nginx.conf \
      --error-log-path=/server/nginx/log/nginx_error.log \
      --http-log-path=/server/nginx/log/nginx_access.log \
      --pid-path=/server/nginx/run/nginx.pid \
      --lock-path=/server/nginx/lock/nginx.lock \
      --with-http_sub_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_mp4_module \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --with-http_addition_module \
      --with-http_secure_link_module \
      --with-http_stub_status_module \
      --with-http_gzip_static_module \
      --with-http_random_index_module \
      --with-jemalloc \
      --with-pcre \
      --http-client-body-temp-path=/server/nginx/tmp/client_body_temp \
      --http-proxy-temp-path=/server/nginx/tmp/proxy_temp \
      --http-fastcgi-temp-path=/server/nginx/tmp/fcgi_temp \
      --http-uwsgi-temp-path=/server/nginx/tmp/uwsgi_temp \
      --http-scgi-temp-path=/server/nginx/tmp/scgi_temp

    if [ $? -eq 0 ]; then
      sudo make -j 4 && sudo make install
    else
      warn "Tengine 编译参数有误，请检查!"
      exit 1
    fi

    sudo mkdir -p /server/nginx/tmp/client_body_temp \
      /server/nginx/tmp/proxy_temp \
      /server/nginx/tmp/fcgi_temp \
      /server/nginx/tmp/uwsgi_temp \
      /server/nginx/tmp/scgi_temp

    # 检查用户是否存在
    if id "$tenging_user" &>/dev/null; then
      echo "用户 $tengine_user 已存在，跳过创建。"
    else
      # 创建用户
      sudo useradd -r -s /sbin/nologin "$tengine_user"
      echo "用户 $tengine_user 创建成功。"
    fi

    # 检查软链接是否存在
    if [ -e "$link_path" ]; then
      echo "软链接 $link_path 已存在，跳过创建。"
    else
      # 创建软链接
      sudo ln -s "$source_path" "$link_path"
      echo "软链接 $link_path 创建成功。"
    fi

    sudo chown -R nginx:root /server/nginx/tmp/

    cont "配置防火墙放通 http & https 端口..."

    while :; do
      read -rp "请输入 http 端口(留空默认: 80): " http_port
      http_port=${http_port:-"80"}
      if [[ ! $http_port =~ ^[0-9]+$ ]] || [ "$http_port" -gt "65535" ]; then
        warn "端口仅支持数字，且不能超过 65535，请重新输入!"
      else
        break
      fi
    done

    while :; do
      read -rp "请输入 https 端口(留空默认: 443): " https_port
      https_port=${https_port:-"443"}
      if [[ ! $https_port =~ ^[0-9]+$ ]] || [ "$https_port" -gt "65535" ]; then
        warn "端口仅支持数字，且不能超过 65535，请重新输入!"
      else
        break
      fi
    done

    if command -v ufw &>/dev/null; then
      sudo ufw allow "$http_port/tcp"
      sudo ufw allow "$https_port/tcp"
      sudo ufw --force enable
    elif command -v firewall-cmd &>/dev/null; then
      sudo firewall-cmd --permanent --add-port="$http_port/tcp"
      sudo firewall-cmd --permanent --add-port="$https_port/tcp"
      sudo firewall-cmd --reload
    else
      warn "不支持的防火墙管理工具，请手动配置防火墙规则!"
    fi

    nginx_version=$(nginx -v 2>&1 | grep "nginx" | cut -f2 -d "/")

    sudo tee /etc/systemd/system/nginx.service >/dev/null <<EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/server/nginx/run/nginx.pid
ExecStartPre=/server/nginx/sbin/nginx -t
ExecStart=/server/nginx/sbin/nginx
ExecReload=/server/nginx/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload

    sudo systemctl enable nginx
    if ! sudo systemctl start nginx; then
      warn "Tengine 启动失败，请查看配置!"
    else
      success "Tengine 安装启动完成。\n"
    fi
  else
    error "不支持的系统类型，仅支持 Ubuntu, Rocky, CentOS"

  fi

}

install_golang() {
  info "*** 安装 golang 1.15.15 ***"
  # 安装 golang 1.15.15

  if [ -x "$(command -v wget)" ]; then
    wget https://golang.google.cn/dl/go1.15.15.linux-amd64.tar.gz -P /tmp/
  else
    if [ -x "$(command -v yum)" ]; then
      yumInstall wget
    elif [ -x "$(command -v apt-get)" ]; then
      aptInstall wget
    elif [ -x "$(command -v dnf)" ]; then
      dnfInstall wget
    else
      error "不支持的包管理器。请手动安装 wget 并重新运行脚本。"
      exit 1
    fi
  fi

  tar -zxf /tmp/go1.15.15.linux-amd64.tar.gz -C /usr/
  ln -s /usr/go/bin/* /usr/bin/

  go_version=$(go version | grep "go version" | cut -f4 -d "o" | awk '{print $1}')
  msg "go 版本: ${C3}$go_version${CF}"
  success "golang 安装完成。\n"
}

install_mongodb() {
  info "*** 安装 MongoDB 4 数据库 ***"

  if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Rocky"* ]]; then
    cont "添加 MongoDB ${C3}清华大学${CF} 源镜像..."

    if [[ "$OS" == *"CentOS"* ]]; then
      cat >/etc/yum.repos.d/mongodb.repo <<EOF
[mongodb-org]
name=MongoDB Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mongodb/yum/el7\$releasever/7-4.2/
gpgcheck=0
enabled=1
EOF
      yum makecache fast
    elif [[ "$OS" == *"Rocky"* ]]; then
      releasever=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release) | grep -o '^[^.]\+')
      cat >/etc/yum.repos.d/mongodb.repo <<EOF
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF
      sudo yum makecache
    fi

    yumInstall mongodb-org
    sudo systemctl enable mongod

    if ! sudo systemctl start mongod; then
      error "mongodb 4 启动失败, 请检查配置!\n"
    else
      success "mongodb 4 安装完成。\n"
    fi

    cont "锁定 MongoDB 4 版本，不跟随 yum 升级..."
    sudo sed -i '$ a\exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools' /etc/yum.conf
    mongodb_version=$(mongo --version | grep "version" | cut -f3 -d "v" | awk 'NR==1 {print $1}')
  elif [[ "$OS" == "Ubuntu" ]]; then
    cont "添加 MongoDB ${C3}清华大学${CF} 源镜像..."
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 68B6BDBE9D8F6FD818A4E2D50A928072509AEC16
    echo "deb [ arch=amd64,arm64 ] https://mirrors.tuna.tsinghua.edu.cn/mongodb/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org

    sudo systemctl enable mongod
    if ! sudo systemctl start mongod; then
      error "mongodb 4 启动失败，请检查配置!\n"
    else
      success "mongodb 4 安装完成。\n"
    fi

    mongodb_version=$(mongo --version | grep "version" | cut -f3 -d "v" | awk 'NR==1 {print $1}')
  else
    error "不支持的系统。仅支持 CentOS、Rocky Linux 和 Ubuntu。"
    exit 1
  fi

  info "*** 设置 MongoDB 4 端口 ***"

  if [ -x "$(command -v mongod)" ]; then
    db_name="mongodb"
    #DB_Version=$(mongod --version)
  else
    error "未安装 MongoDB\n"
  fi

  if [ -s /etc/mongod.conf ]; then
    cp /etc/mongod.conf "/etc/mongod.conf.bak.$(date +%Y%m%d)$(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null)"

    # 修改 MongoDB 端口
    cont "修改 MongoDB 端口..."
    while :; do
      printf "请输入 MongoDB 端口(留空默认: 27017): "
      read -r mongodb_port
      if [ -z "$mongodb_port" ]; then
        mongodb_port="27017"
      fi
      if [[ ! $mongodb_port =~ ^[0-9]+$ ]]; then
        warn "端口仅支持${C01}数字${CF}, 请重新输入!\n"
      elif [ "$mongodb_port" -gt "65535" ]; then
        warn "端口号不能超过 ${C01}65535${CF}, 请重新输入!\n"
      else
        break
      fi
    done

    cont "修改 MongoDB 端口为: ${C3}$mongodb_port${CF} ..."
    sudo sed -i '/^  port:/s/  port: 27017/  port: '"$mongodb_port"'/g' /etc/mongod.conf
    cont "开启 MongoDB 外部访问 ..."
    sudo sed -i '/^  bindIp:/s/  bindIp: 127.0.0.1/  bindIp: 0.0.0.0/g' /etc/mongod.conf

    # 开放防火墙端口
    cont "Firewalld 防火墙放通 MongoDB ${C3}$mongodb_port${CF} 端口..."
    if [[ "$OS" == "Ubuntu" ]]; then
      sudo ufw allow "$mongodb_port"/tcp
      sudo systemctl restart mongod
    elif [[ "$OS" == *"Rocky"* ]] || [[ "$OS" == *"CentOS"* ]]; then
      sudo firewall-cmd --permanent --zone=public --add-port="$mongodb_port"/tcp
      sudo firewall-cmd --reload
      if ! sudo systemctl restart mongod; then
        error "MongoDB 重启失败, 请检查配置!\n"
      else
        success "MongoDB 端口: ${C3}$mongodb_port${CF} 设置完成。\n"
      fi
    fi
  else
    error "未找到 MongoDB 配置文件 /etc/mongod.conf。\n"
  fi

}

pythonDevelopEnv() {
  case ${1} in
  1)
    info "pip3"
    if [[ "$OS" == *"Ubuntu"* ]]; then
      aptInstall "python3-dev python3-pip"
    else
      yumInstall "python3-dev python3-pip"
    fi
    ;;
  2)
    info "pyenv: Simple Python version management"
    if [[ "$OS" == *"Ubuntu"* ]]; then
      aptInstall "make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev"
    else
      yumInstall "make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev"
    fi
    curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
    echo '# pyenv' >>~/.bashrc
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >>~/.bashrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >>~/.bashrc
    echo 'eval "$(pyenv init -)"' >>~/.bashrc
    echo 'eval "$(pyenv virtualenv-init -)"' >>~/.bashrc
    ;;
  3)
    info "pipenv: Python Development Workflow for Humans"
    if cmdCheck pip3 -eq 0; then
      # why not use pip3: https://stackoverflow.com/questions/49836676/error-after-upgrading-pip-cannot-import-name-main
      python3 -m pip install --user pipenv
    fi
    echo '# pipenv' >>~/.bashrc
    echo 'alias pipenv="$HOME/./bin/pipenv"' >>~/.bashrc
    ;;
  esac
}

dockerDevelopEnv() {
  case ${1} in
  1)
    info "*** 安装 docker-ce ***"
    if [[ "$OS" == *"Ubuntu"* ]] || [ "$OS" == **"CentOS"** ]; then
      curl https://get.docker.com/ | bash
    else
      yumInstall "dnf-plugins-core"
      yum config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
      yumInstall "docker-ce docker-ce-cli containerd.io"
    fi
    ;;
  2)
    info "docker-compose: a tool for defining and running multi-container Docker applications"
    if cmdCheck pip3 -eq 0; then
      python3 -m pip install --user docker-compose
    fi
    ;;
  esac
}

install_mysql8() {
  info "*** 安装 MySQL 8 数据库 ***"

  cont "添加 ${C3}MySQL Community${CF} 源镜像..."

  if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Rocky"* ]]; then
    # 下载 MySQL 8.0 的 rpm 仓库源
    if [[ "$OS" == *"CentOS"* ]]; then
      sudo yum install -y "http://repo.mysql.com/mysql-community-release-el7.rpm"
    elif [[ "$OS" == *"Rocky"* ]]; then
      releasever=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release) | grep -o '^[^.]\+')
      sudo yum install -y "http://repo.mysql.com/mysql80-community-release-el$releasever.rpm"
    fi

    # 更新 MySQL 公钥
    sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
    sudo yum makecache

    # 安装 MySQL Community Server 8.0.31
    sudo yum module disable -y mysql
    sudo yum install -y mysql-community-server-8.0.31
  elif [[ "$OS" == "Ubuntu" ]]; then
    sudo wget -P /usr//src https://dev.mysql.com/get/mysql-apt-config_0.8.17-1_all.deb
    sudo dpkg -i /usr//src/mysql-apt-config_0.8.17-1_all.deb
    sudo apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
    sudo rm -rf mysql-apt-config_0.8.17-1_all.deb
  else
    error "不支持的系统。仅支持 CentOS、Rocky Linux 和 Ubuntu。"
    exit 1
  fi

  # 备份 MySQL 配置
  if [ -s /etc/my.cnf ]; then
    sudo cp /etc/my.cnf{,.bak"$(date +%Y%m%d%-H%M%S)"}
    # 关闭 MySQL X plugin
    sudo sed -i '$ a\mysqlx=0' /etc/my.cnf
  elif [ -s /etc/mysql/my.cnf ]; then
    sudo cp /etc/mysql/my.cnf{,.bak"$(date +%Y%m%d%-H%M%S)"}
    # 关闭 MySQL X plugin
    sudo sed -i '$ a\mysqlx=0' /etc/mysql/my.cnf
  else
    error "未找到 MySQL 配置文件。"
  fi

  sudo systemctl enable mysqld
  if ! sudo systemctl start mysqld; then
    error "MySQL 启动失败, 请检查配置!\n"
  else
    success "MySQL 8 安装启动完成。\n"
  fi

  if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Rocky"* ]]; then
    sudo rm -rf ./mysql-community-release-el7.rpm
  fi

  mysql_version=$(mysql -V | grep "Ver" | awk '{print $3}')

  info "*** 设置 MySQL 8 端口 ***"

  if [ -x "$(command -v mysql)" ]; then
    db_name="mysql"
    #DB_Version=$(mysql --version)
  else
    error "未安装 MySQL\n"
  fi

  # 修改 MySQL 端口
  cp /etc/my.cnf{,.bak"$(date +%Y%m%d%-H%M%S)"}
  while :; do
    printf "请输入 MySQL 端口(留空默认: 3306): "
    read -r mysql_port
    if [ -z "$mysql_port" ]; then
      mysql_port="3306"
    fi
    if [[ ! $mysql_port =~ ^[0-9]+$ ]]; then
      warn "端口仅支持${C01}数字${CF}, 请重新输入!\n"
    elif [ "$mysql_port" -gt "65535" ]; then
      warn "端口号不能超过 ${C01}65535${CF}, 请重新输入!\n"
    else
      break
    fi
  done

  if [ -s /etc/my.cnf ]; then
    sudo sed -i "/\[mysqld\]/a\port=$mysql_port" /etc/my.cnf
  elif [ -s /etc/mysql/my.cnf ]; then
    sudo sed -i "/\[mysqld\]/a\port=$mysql_port" /etc/mysql/my.cnf
  else
    error "未找到 MySQL 配置文件 /etc/my.cnf 或 /etc/mysql/my.cnf。\n"
  fi

  # 开放防火墙端口
  cont "Firewalld 防火墙放通 ${C3}$mysql_port${CF} 端口..."

  if [[ "$OS" == "Ubuntu" ]]; then
    sudo ufw allow "$mysql_port"/tcp
    sudo systemctl restart mysqld
  elif [[ "$OS" == *"Rocky"* ]] || [[ "$OS" == *"CentOS"* ]]; then
    sudo firewall-cmd --permanent --zone=public --add-port="$mysql_port"/tcp
    sudo firewall-cmd --reload
    if ! sudo systemctl restart mysqld; then
      error "mysqld 服务重启失败, 请检查配置!\n"
    else
      success "成功设置 MySQL 端口为: ${C3}$mysql_port${CF}\n"
    fi
  fi

  info "*** 设置 MySQL 8 密码 ***"

  if [ -x "$(command -v mysql)" ]; then
    db_name="mysql"
    #DB_Version=$(mysql --version)
  else
    error "未安装 MySQL\n"
  fi

  while :; do
    msg "请输入 MySQL root 密码(留空默认: 123456): "
    read -r mysql_pass
    msg "再次确认 MySQL root 密码(留空默认: 123456): "
    read -r mysql_passwd
    if [ -z "$mysql_pass" ] && [ -z "$mysql_passwd" ]; then
      mysql_pass="123456"
      mysql_passwd="123456"
    fi
    if [ "$mysql_pass" != "$mysql_passwd" ]; then
      warn "两次密码验证失败, 请重新输入\n"
    else
      break
    fi
  done

  cont "正在更新 $db_name root 密码..."

  # 获取 MySQL 初始密码：$random_passwd"
  random_passwd=$(grep "temporary password" /var/log/mysqld.log | awk '{print $NF}')
  # 调试使用***
  # printf "MySQL 默认密码: $random_passwd\n"
  if [ "$mysql_passwd" = "123456" ]; then
    # MySQL 启用简单密码, 开启远程访问
    mysql_temp_pass="#PFu>N)9aZw3i2iZAwjB#2bb8"
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$random_passwd" --connect-expired-password -e "alter user 'root'@'localhost' identified with mysql_native_password by '$mysql_temp_pass';set global validate_password.policy=LOW;set global validate_password.length=6;alter user 'root'@'host' identified with mysql_native_password by '$mysql_passwd';use mysql;update user set host='%' where user='root';flush privileges;"
  else
    # 写入新 MySQL 密码并开启外部连接
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$random_passwd" --connect-expired-password -e "alter user 'root'@'localhost' identified with mysql_native_password by '$mysql_passwd';use mysql;update user set host='%' where user='root';flush privileges;"
  fi

  cont "设置 root 密码成功。正在重启 mysqld..."
  if ! sudo systemctl restart mysqld; then
    error "mysqld 服务重启失败, 请检查配置!\n"
  else
    success "MySQL root 密码设置为: ${C3}$mysql_passwd${CF}\n"
  fi

  info "*** 添加 MySQL 用户 ***"

  if [ -x "$(command -v mysql)" ]; then
    db_name="mysql"
    #DB_Version=$(mysql --version)
  else
    error "未安装 MySQL\n"
  fi

  while :; do
    printf "请输入 MySQL 用户名: "
    read -r mysql_user_name
    if [[ "$mysql_user_name" =~ .*root.* || "$mysql_user_name" =~ .*adm.* ]]; then
      warn "用户名不能为 ${C1}root${CF} 或 ${C1}admin{CF},  请重新输入\n"
    else
      break
    fi
  done

  while :; do
    msg "请输入 MySQL ${C03}$mysql_user_name${CF} 用户密码(留空默认: 123456): "
    read -r mysql_user_pass
    msg "再次确认 MySQL ${C03}$mysql_user_name${CF} 用户密码(留空默认: 123456): "
    read -r mysql_user_passwd
    if [ -z "$mysql_user_pass" ] && [ -z "$mysql_user_passwd" ]; then
      mysql_user_pass="123456"
      mysql_user_passwd="123456"
    fi
    if [ "$mysql_user_pass" != "$mysql_user_passwd" ]; then
      printf "两次密码验证失败, 请重新输入\n\n"
    else
      break
    fi
  done

  if [ "$mysql_user_passwd" = "123456" ]; then
    # MySQL 启用简单密码, 开启远程访问
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$mysql_passwd" --connect-expired-password -e "set global validate_password.policy=LOW;set global validate_password.length=6;use mysql;create user $mysql_user_name identified by '$mysql_user_passwd';update user set host='%' where user='$mysql_user_name';flush privileges;grant all privileges on *.* to '$mysql_user_name'@'%' with grant option;flush privileges;"
  else
    # 写入 MySQL 新用户密码并开启外网连接($mysql_passwd 为 root 密码变量)
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$mysql_passwd" --connect-expired-password -e "use mysql;create user $mysql_user_name identified by '$mysql_user_passwd';update user set host='%' where user='$mysql_user_name';flush privileges;grant all privileges on *.* to '$mysql_user_name'@'%' with grant option;flush privileges;"
  fi

  cont "设置 $mysql_user_name 密码成功。正在重启 mysqld..."

  if ! sudo systemctl restart mysqld; then
    error "mysqld 服务重启失败, 请检查 create_mysql_user 配置!\n"
  else
    success "MySQL 密码成功设置为: ${C3}$mysql_user_passwd${CF}\n\n"
  fi

}

install_redis() {
  info "*** 安装 Redis ***"

  cont "添加 remi ${C3}清华大学${CF} 源镜像..."

  if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Rocky"* ]]; then
    releasever=""
    if [[ "$OS" == *"Rocky"* ]]; then
      releasever=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release) | grep -o '^[^.]\+')
    fi

    sudo yum install -y https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-${releasever}.rpm
    sudo yum --enablerepo=remi install -y redis
  elif [[ "$OS" == "Ubuntu" ]]; then
    sudo add-apt-repository ppa:remi/php
    sudo apt-get update
    sudo apt-get install -y redis-server
  else
    error "不支持的系统。仅支持 CentOS、Rocky Linux 和 Ubuntu。"
    exit 1
  fi

  # 备份 redis 设置
  if [ -s /etc/redis.conf ]; then
    sudo cp /etc/redis.conf{,.bak"$(date +%Y%m%d%-H%M%S)"}
    # 开启 redis 外网连接
    sudo sed -i 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis.conf
  else
    error "未找到 Redis 配置文件 /etc/redis.conf。\n"
  fi

  sudo systemctl enable redis
  if ! sudo systemctl start redis; then
    error "Redis 安装失败, 请检查 install_redis 配置!\n"
  else
    success "Redis 安装启动完成。\n"
  fi

  redis_version=$(redis-server --version | grep "v=" | cut -f2 -d "=" | awk '{print $1}')

  info "*** 设置 Redis 访问端口 ***"

  if [ -s /var/lib/redis ]; then
    if [ -s /etc/redis.conf ]; then
      sudo cp /etc/redis.conf{,.bak"$(date +%Y%m%d%-H%M%S)"}
      #DB_Version=$(mysql --version)
    else
      error "未找到 Redis 配置文件 /etc/redis.conf。\n"
    fi
  else
    error "没安装 Redis\n"
  fi

  while :; do
    printf "请输入 Redis 端口(留空默认: 6379): "
    read -r Redis_port
    if [ -z "$Redis_port" ]; then
      Redis_port="6379"
    fi
    if [[ ! $Redis_port =~ ^[0-9]+$ ]]; then
      warn "端口仅支持${C01}数字${CF}, 请重新输入!\n"
    elif [ "$Redis_port" -gt "65535" ]; then
      warn "端口号不能超过 ${C01}65535${CF}, 请重新输入!\n"
    else
      break
    fi
  done

  if [ -s /etc/redis.conf ]; then
    sudo sed -i "s/^port.*/port $Redis_port/g" /etc/redis.conf
  else
    error "未找到 Redis 配置文件 /etc/redis.conf。\n"
  fi

  if [[ "$OS" == *"Ubuntu"* ]]; then
    sudo ufw allow "$Redis_port"/tcp
    sudo systemctl restart redis
  elif [[ "$OS" == *"Rocky"* ]] || [[ "$OS" == *"CentOS"* ]]; then
    sudo firewall-cmd --permanent --zone=public --add-port="$Redis_port"/tcp
    sudo firewall-cmd --reload
    if ! sudo systemctl restart redis; then
      error "Redis 服务重启失败, 请检查 config_redis_port 配置!\n"
    else
      success "成功设置 Redis 端口为: ${C3}$Redis_port${CF}\n"
    fi
  fi

  info "*** 设置 Redis 访问密码 ***"

  if [ -s /var/lib/redis ]; then
    if [ -s /etc/redis.conf ]; then
      sudo sudo cp /etc/redis.conf{,.bak"$(date +%Y%m%d%-H%M%S)"}
      #DB_Version=$(mysql --version)
    else
      error "未找到 Redis 配置文件 /etc/redis.conf。\n"
    fi
  else
    error "没安装 Redis\n"
  fi

  while :; do
    msg "请输入 Redis 连接密码: "
    read -r Redis_pass
    msg "再次确认 Redis 连接密码: "
    read -r Redis_passwd
    echo ''
    if [ "$Redis_pass" != "$Redis_passwd" ]; then
      printf "两次密码验证失败, 请重新输入\n\n"
    else
      break
    fi
  done

  if [ "$Redis_passwd" = "" ]; then
    if ! sudo systemctl restart redis; then
      error "Redis 服务重启失败, 请检查 config_redis_password 配置!\n"
    else
      success "成功设置 Redis 访问密码为: <空>\n"
    fi
  else
    if [ -s /etc/redis.conf ]; then
      sudo sed -i '/# requirepass foobared/a\requirepass '"$Redis_passwd"'' /etc/redis.conf
      if ! sudo systemctl restart redis; then
        error "Redis 服务重启失败, 请检查 config_redis_password 配置!\n"
      else
        success "成功设置 Redis 访问密码为: ${C1}$Redis_passwd${CF}\n"
      fi
    else
      error "未找到 Redis 配置文件 /etc/redis.conf。\n"
    fi
  fi

}

finish() {
  msg "${C06} 
 当前系统时间：${C3}$(date)${C06}
 +------------------------------------------------------------------------+
 |             ${C02}系统初始化完成，请保存好以下信息并执行重启系统!${C06}            |
 +------------------------------------------------------------------------+${CF}\n"
  # 判断 go 是否存在
  if [ -f "/usr/bin/go" ]; then
    msg "${C07}go 版本: ${C6}$go_version${CF}"
  else
    printf ''
  fi
  # 判断 git 是否存在
  if [ -f "/usr/bin/git" ]; then
    git_version=$(git version | grep "version" | awk '{print $3}')
    msg "${C07}git 版本: ${C6}$git_version${CF}"
  else
    printf ''
  fi
  msg "${C04}================
${C07}SSH 端口: ${C02}$sshPort
${C07}IP 地址: ${C03}$MYIP
${C07}用户名: ${C04}$userName
${C07}密码: ${C01}$userPasswd \E[33;5m👈 ${C05}\E[33;5m请牢记密码${CF}
${C06}*** 系统默认${C01}禁止${C06}密码登陆, 需要密码登陆请使用以下命令设置:${CF}
sed -Ei '/^PasswordAuthentication no/s/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd
${C06}*** 系统默认${C01}禁止🙅${C01}\E[33;9m\$root${CF}${C06}🙅登陆, 需要${C01}root${C06}登陆请使用以下命令设置: ${CF}"
  if [[ "$OS" == **"CentOS"** ]]; then
    msg "sudo sed -Ei 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config"

  else
    msg "sudo sed -Ei '/^PermitRootLogin no/s/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config"
    msg "sudo sed -Ei '/^UsePAM/s//#/g' /etc/ssh/sshd_config"
  fi
  msg "${C04}================
${C07}内网连接:${CF} ssh -p ${C02}$sshPort${CF} -i ${C03}私钥文件 ${C07}$userName${C02}@${C04}$IPADD${CF}
${C07}互联网连接:${CF} ssh -p ${C02}$sshPort${CF} -i ${C03}私钥文件 ${C07}$userName${C02}@${C04}$MYIP${CF}"
  # 判断 nginx 是否存在
  if [ -f "/usr/sbin/nginx" ]; then
    msg "${C04}================\n${C07}nginx 版本: ${C6}$nginx_version${CF}\n${C07}nginx http 端口: ${C3}$http_port${CF}\n${C07}nginx https 端口: ${C3}$https_port${CF}"
  else
    printf ''
  fi
  # 判断 mysql 是否存在
  if [ -f "/usr/bin/mysql" ]; then
    msg "${C04}================\n${C04}MySQL 版本: ${C6}$mysql_version\n${C04}MySQL 端口: ${C3}$mysql_port\n${C04}MySQL ${C7}root ${C04}密码: ${C1}$mysql_passwd${CF}\n${C04}MySQL 新用户: ${C5}$mysql_user_name${CF}\n${C04}MySQL ${C7}$mysql_user_name ${C04}用户密码: ${C1}$mysql_user_passwd${CF}"
  else
    printf ''
  fi
  # 判断 redis 是否存在
  if [ -d "/run/redis" ]; then
    msg "${C04}================\n${C05}Redis 版本: ${C6}$redis_version\n${C05}Redis 端口: ${C3}$Redis_port${C05}\nRedis 密码: ${C3}$Redis_passwd${CF}"
  else
    printf ''
  fi
  # 判断 mongodb 是否存在
  if [ -f "/usr/bin/mongod" ]; then
    msg "${C04}================\n${C02}MongoDB 版本: ${C6}$mongodb_version\n${C02}MongoDB 端口: ${C3}$mongodb_port${CF}"
  else
    printf ''
  fi
  # 清除历史记录
  cat /dev/null >~/.bash_history && history -cw
  printf "\n\n系统环境初始化完毕, 是否立即重启服务器?[y/n]"
  read -p ": " is_reboot
  while [[ ! $is_reboot =~ ^[y,n]$ ]]; do
    warn "输入有误, 只能输入[y/n]"
    read -p "[y/n]: " is_reboot
  done
  if [ "$is_reboot" = 'y' ]; then
    sudo reboot
  fi
}

help() {
  echo "Usage: bash init.sh [type] [target] [options]"
  echo
  echo "TYPE and TARGET"
  echo
  echo "[init]"
  echo "	The system initializes by default."
  echo "[update]"
  echo "	The system undergoes updates and upgrades periodically to enhance its functionality and capabilities."
  echo
  echo "[source]"
  echo "[source]"
  echo "	sys: Automatic modification of source address based on system assessment."
  echo "	Ubuntu:    https://mirrors.cloud.tencent.com/ubuntu/"
  echo "	Rocky:     https://mirrors.cloud.tencent.com/rocky/"
  echo "	CentOS:    https://mirrors.cloud.tencent.com/centos/"
  echo "	pip:       https://pypi.tuna.tsinghua.edu.cn/simple"
  echo "	docker:    https://docker.mirrors.ustc.edu.cn"
  echo
  echo "[key]"
  echo "  Supplementing cryptographic keys for existing users."
  echo "  Usage: bash init.sh key"
  echo
  echo "[nginx]"
  echo "  Install the Nginx web server."
  echo "  Usage: bash init.sh nginx"
  echo
  echo "[tengine]"
  echo "  Install the Tengine web server."
  echo "  Usage: bash init.sh tengine"
  echo
  echo "[golang]"
  echo "  Set up the golang programming language development environment."
  echo "  Usage: bash init.sh golang"
  echo
  echo "[python]"
  echo "	pip: pip3"
  echo "	pyenv: Simple Python version management"
  echo "	pipenv: Python Development Workflow for Humans"
  echo "[java]"
  echo "	jdk: openjdk-11"
  echo "	maven: A software project management and comprehension tool"
  echo "[javascript]"
  echo "	nvm: Node Version Manager - Simple bash script to manage multiple active node.js versions"
  echo "[docker]"
  echo "	docker-ce: "
  echo "	docker-compose: A tool for defining and running multi-container Docker applications"
  echo
  echo "OPTIONS"
  echo
  echo " -b,--basic 	Basic Tools Install: curl,git,vim,wget,zip,unzip,lrzsz,net-tools,htop"
  echo " -v,--Version 	Show version"
  echo " -h,--help 	Show this help message and exit"
  echo
  echo "Example:"
  echo
  echo "	Update System"
  echo "		bash init.sh update"
  echo "	Install java maven"
  echo "		bash init.sh java meven"
  echo "	Install all python tools"
  echo "		bash init.sh python"
}

main() {
  if [ $# -eq 0 ]; then
    welcome
    echo "Usage: bash init.sh [type] [target] [options]"
    echo
    echo "init.sh [-h|--help] [-v|--version] [-b|--basic]"
    echo "	{init,update,source,key,nginx,tengine,go,python,java,javascript,docker,shell} [target]"
    echo
    cmdCheck curl
    cmdCheck git
    cmdCheck wget
  else
    case $1 in
    "init")
      welcome
      CD
      update_source_for_china 1
      update_and_upgrade_system
      basic_tools_install
      disable_services
      disable_selinux
      password_rules
      delete_users_and_groups
      create_new_user 1
      sshd_setting
      bashrc_setting
      vimrc_setting
      timezone_setting
      ulimit_setting
      sysctl_setting
      #install_nginx
      #install_mongodb
      #install_mysql8
      #install_redis
      finish
      ;;
    "update")
      update_and_upgrade_system
      ;;
    "source")
      changeSourceForChina 1
      changeSourceForChina 2
      changeSourceForChina 3
      ;;
    "source sys")
      changeSourceForChina 1
      ;;
    "source pip")
      changeSourceForChina 2
      ;;
    "source docker")
      changeSourceForChina 3
      ;;
    "key")
      create_new_user 2
      ;;
    "nginx")
      install_nginx
      ;;
    "tengine")
      install_tengine
      ;;
    "golang")
      install_golang
      ;;
    "mongodb")
      install_mongodb
      ;;
    "mysqld")
      install_mysql8
      ;;
    "redis")
      install_redis
      ;;
    "python")
      pythonDevelopEnv 1
      pythonDevelopEnv 2
      pythonDevelopEnv 3
      ;;
    "python pip")
      pythonDevelopEnv 1
      ;;
    "python pyenv")
      pythonDevelopEnv 2
      ;;
    "python pipenv")
      pythonDevelopEnv 3
      ;;
    "java")
      javaDevelopEnv 1
      javaDevelopEnv 2
      ;;
    "java jdk")
      javaDevelopEnv 1
      ;;
    "java maven")
      javaDevelopEnv 2
      ;;
    "javascript")
      javaScriptDevelopEnv 1
      ;;
    "javascript nvm")
      javaScriptDevelopEnv 1
      ;;
    "docker")
      dockerDevelopEnv 1
      dockerDevelopEnv 2
      ;;
    "docker docker-ce")
      dockerDevelopEnv 1
      ;;
    "docker docker-compose")
      dockerDevelopEnv 2
      ;;
    --basic | -b)
      basic_tools_install
      ;;
    --version | -v)
      echo "Version: ${scriptVer}"
      ;;
    --help | -h)
      help
      ;;
    esac
  fi
}

main $@
