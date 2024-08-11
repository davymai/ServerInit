#!/bin/bash
#################################################
# Function      : Server Initialization script
# Platform      : CentOS 7/Rocky Linux 8-9/Ubuntu 20+ Based Platform
# Author        : davymai(大威)
# Contact       : i@davymai.com
# Link          : https://github.com/davymai/ServerInit
# Filename      : init.sh
# Usage         : bash init.sh
# Description   : This is a Bash script for initializing servers, which includes the installation of various development environments and tools. It supports multiple Linux distributions (such as CentOS 7, Rocky 8-9, Ubuntu 20+), and includes the installation and configuration of Docker, MySQL, Redis, etc.
#################################################

# 初始化脚本设置 {{{

# 脚本版本
SCRIPT_DATE='2024-07-03'
SCRIPT_VERSION='0.3.2'
# 版本号格式正则表达式
VERSION_REGEX="^[0-9]+\.[0-9]+\.[0-9]+$"

# 设置严格模式
set -eo pipefail # -e: 当命令失败时退出; -o pipefail: 管道中任何命令失败时返回非零状态

# 定义常量
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # 脚本所在目录
readonly LOG_FILE="${SCRIPT_DIR}/init.log"                          # 日志文件路径

# 函数: 日志记录
log() {
  local message="\$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" >>"${LOG_FILE}"
}

# 1. 检测系统类型
source /etc/os-release
OS=$NAME
OS_VER=$VERSION_ID

# 2. 设置时区
# 检查 timedatectl 的 NTP 服务状态
NTP_STATUS=$(timedatectl show -p NTPSynchronized --value)
if [ "$NTP_STATUS" != "yes" ]; then
  echo "NTP 服务未启用。设置时区和时间。"
  if [[ "$OS" != **"CentOS"** ]]; then
    # 获取当前 RTC 时间
    RTC_TIME=$(timedatectl | awk '/RTC time/ {print $4, $5}')
    # 检查 RTC_TIME 是否成功获取
    if [ -n "$RTC_TIME" ]; then
      # 计算中国标准时间 (CST)
      CN_TIME=$(date -d "$RTC_TIME + 8 hours" +"%Y-%m-%d %H:%M:%S")
      # 设置系统时间为中国标准时间
      sudo timedatectl set-time "$CN_TIME"
      echo "时区已设置为中国标准时间 (CST)。"
    fi
    # 获取当前日期
    if [ -n "$RTC_TIME" ]; then
      CURRENT_DATE=$(date -d "$RTC_TIME + 8 hours" +"%Y%m%d")
    fi
  fi
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

# 7. 设置备份目标目录路径
backup_directory="/etc/yum.repos.d/backup"

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

        ${C7}系统默认${SS}${C1}禁止${C7}密码登陆，请提前准备好公钥${C06}

        Version: ${SCRIPT_VERSION}    Update: ${SCRIPT_DATE}
        By: 大威(Davy)    System: ${C2}${OS} ${C05}${OS_VER}
        ${CF}"
}

#倒计时
CD() {

  while [ $cd_num -gt 0 ]; do
    echo -ne "\r        ${C06}初始化脚本 ${C1}$cd_num${C06} 秒后开始，按 ${C3}ctrl C ${C06}取消${CF}"
    sleep $delay
    ((cd_num--))
  done

  echo -e "\r        ${C06}初始化脚本 ${C1}0${C06} 秒后开始，按 ${C3}ctrl C ${C06}取消${CF}"
  sleep $delay
  echo -ne "\033[A\r\033[K"
  msg "                ${C06}开始执行初始化脚本...${CF}\n"
}

cmdCheck() {
  # 检查命令是否存在
  if ! hash "$1" >/dev/null 2>&1; then
    info "命令 $1 未找到，正在尝试安装...\n"
    # 根据操作系统类型进行安装
    if ! hash "$1" >/dev/null 2>&1 && [[ "$OS" == **"Rocky"** ]]; then
      sudo dnf install -y $1
    elif ! hash "$1" >/dev/null 2>&1 && [[ "$OS" == **"CentOS"** ]]; then
      sudo yum install -y $1
    elif ! hash "$1" >/dev/null 2>&1 && [[ "$OS" == **"Ubuntu"** ]]; then
      sudo apt-get install -y $1
    else
      warn "不支持的操作系统类型: $OS\n"
      return 1 # 返回错误状态
    fi

    # 检查安装是否成功
    if hash "$1" >/dev/null 2>&1; then
      success "命令 $1 安装成功！\n"
      return 0 # 安装成功返回 0
    else
      error "命令 $1 安装失败！请检查错误信息。\n"
    fi
  else
    success "命令 $1 已存在，无需安装。\n"
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

# 检查软件下载目录 /data/download 是否存在
SOFTWARW_DL_DIR=/data/download
if [ ! -d "$SOFTWARW_DL_DIR" ]; then
  # 如果不存在，则创建目录，静默模式
  mkdir -p "$SOFTWARW_DL_DIR" >/dev/null 2>&1
fi

# Change the source of the package
changeSourceForChina() {
  info "*** 把源地址改为中国源地址🇨🇳  ***"
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
      success "[${C03}sources${CF}] 源修改为 [${C02}腾讯云${CF}] 完成\n"
      sudo apt-get update >/dev/null
    elif [[ "$OS" == **"Rocky"** ]]; then
      # Rocky & CentOS /etc/yum.repos.d/ 创建备份目录
      sudo mkdir -p "$backup_directory"
      # 进入源文件夹
      cd "$source_directory"
      # 检查服务器类型和版本
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
          new_filename="$filename_no_ext-$CURRENT_DATE.$extension"

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
          new_filename="$filename_no_ext-$CURRENT_DATE.$extension"

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
          new_filename="$filename_no_ext-$CURRENT_DATE.$extension"

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
          new_filename="$filename_no_ext-$CURRENT_DATE.$extension"

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
  info "*** 删除多余的用户和组 ***"

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

  #删除 /usr/bin/ 失效的软链接
  find /usr/bin/ -type l ! -exec test -e {} \; -print | while read symlink; do
    echo "删除失效的软链接: $symlink"
    rm -rf "$symlink"
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
        warn "用户名不能包含 ${C01}admin${CF} 或 ${C01}root${CF} ，请重新输入\n"
      elif id -u "$userName" >/dev/null 2>&1; then
        warn "用户 \"$userName\" 已存在，请重新输入\\n"
      elif echo "$userName" | grep -qP '[\p{Han}]'; then
        warn "用户名不能包含<中文>，请重新输入\n"
      elif [[ "$userName" =~ ^[0-9]+$ ]]; then
        warn "用户名不能为纯数字，请重新输入\n"
      elif [ -z "$userName" ]; then
        warn "用户名不能为<空>，请重新输入\n"
      else
        break
      fi
    done

    # 提示输入密码
    while :; do
      read -rp "输入密码(密码输入已隐藏): " -s PASSWD
      echo ''
      if [ -z "$PASSWD" ]; then
        warn "密码不能为<空>，请重新输入\n"
        continue
      elif [[ ${#PASSWD} -lt 8 || ! "$PASSWD" =~ [A-Z] || ! "$PASSWD" =~ [a-z] ]]; then
        warn "密码必须至少8个字符，包括至少1个大写字母和1个小写字母，请重新输入\n"
        continue
      fi
      read -rp "再次确认密码: " -s PASSWORD
      echo ''

      if [ "$PASSWD" != "$PASSWORD" ]; then
        warn "两次密码验证失败，请重新输入\n"
        continue
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
      sudo echo "$userName:$PASSWORD" | sudo chpasswd >/dev/null 2>&1
    else
      useradd -G wheel "$userName"
      sudo echo "$PASSWORD" | passwd --stdin "$userName" >/dev/null 2>&1
    fi

    # 用户创建通知
    if id "$userName" &>/dev/null; then
      success "用户 $userName 密码 $PASSWORD 创建完毕。"
    else
      error "用户创建失败，请重新创建。"
      exit 1
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
        warn "用户名不能包含<中文>，请重新输入\n"
      elif [[ "$userName" =~ ^[0-9]+$ ]]; then
        warn "用户名不能为纯数字，请重新输入\n"
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
  3)
    #添加非登陆用户
    info "创建 非登陆用户"

    # 提示输入用户名
    while :; do
      read -p "用户名: " userName
      if [[ "$userName" =~ .*root.* || "$userName" =~ .*admin.* ]]; then
        warn "用户名不能包含 ${C01}admin${CF} 或 ${C01}root${CF} ，请重新输入\n"
      elif id -u "$userName" >/dev/null 2>&1; then
        warn "用户 \"$userName\" 已存在，请重新输入\\n"
      elif echo "$userName" | grep -qP '[\p{Han}]'; then
        warn "用户名不能包含<中文>，请重新输入\n"
      elif [[ "$userName" =~ ^[0-9]+$ ]]; then
        warn "用户名不能为纯数字，请重新输入\n"
      elif [ -z "$userName" ]; then
        warn "用户名不能为<空>，请重新输入\n"
      else
        break
      fi
    done

    # 提示输入密码
    while :; do
      read -rp "输入密码(密码输入已隐藏): " -s PASSWD
      echo ''
      if [ -z "$PASSWD" ]; then
        warn "密码不能为<空>，请重新输入\n"
        continue
      elif [[ ${#PASSWD} -lt 8 || ! "$PASSWD" =~ [A-Z] || ! "$PASSWD" =~ [a-z] ]]; then
        warn "密码必须至少8个字符，包括至少1个大写字母和1个小写字母，请重新输入\n"
        continue
      fi
      read -rp "再次确认密码: " -s PASSWORD
      echo ''

      if [ "$PASSWD" != "$PASSWORD" ]; then
        warn "两次密码验证失败，请重新输入\n"
        continue
      else
        break
      fi
    done

    # 创建用户并指定其 shell 为 /sbin/nologin
    sudo useradd -s /sbin/nologin "$userName"

    # 设置用户密码
    if [[ "$OS" == *"Ubuntu"* ]]; then
      sudo echo "$userName:$PASSWORD" | sudo chpasswd >/dev/null 2>&1
    else
      sudo echo "$PASSWORD" | passwd --stdin "$userName" >/dev/null 2>&1
    fi

    # 用户创建通知
    if id "$userName" &>/dev/null; then
      success "非登陆用户 $userName 密码 $PASSWORD 创建完毕。"
    else
      error "用户创建失败，请重新创建。"
    fi

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
    # 禁止自动断链
    sudo sed -Ei 's/^#ClientAliveInterval 0/ClientAliveInterval 60/g' "$ssh_auth_file"
    sudo sed -Ei 's/^#ClientAliveCountMax 3/ClientAliveCountMax 360/g' "$ssh_auth_file"
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
    warn "vim 已经配置，进行下一步设置...\n"
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
    warn "当前系统时区为: ${C02}$TZ${CF}，跳过时区设置。"
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
# 当keepalive 起用的时候，TCP 发送keepalive 消息的频度。缺省是2 小时
net.ipv4.tcp_keepalive_time = 600
# timewait的数量，默认18000
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
# IP 转发，默认关闭
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
# 当keepalive 起用的时候，TCP 发送keepalive 消息的频度。缺省是2 小时
net.ipv4.tcp_keepalive_time = 600
# timewait的数量，默认18000
net.ipv4.tcp_max_tw_buckets = 36000
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 262144
net.ipv4.tcp_max_orphans = 262144
# 开启反向路径过滤(增强网络安全)
net.ipv4.conf.all.rp_filter = 1
# IP 转发，默认关闭
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

# 修改主机名
Set_Hostname() {
  info "设置服务器主机名..."
  get_and_confirm_hostname() {
    local hostname
    read -p "请输入新的主机名: " hostname
    read -p "请再次输入新的主机名以确认: " confirm_hostname

    if [ "$hostname" != "$confirm_hostname" ]; then
      warn "两次输入的主机名不一致，请重新输入。"
      return 1
    else
      success "主机名确认一致: $hostname"
      echo "$hostname"
      return 0
    fi
  }

  # Attempt to get and confirm the hostname up to 3 times
  attempt=0
  max_attempts=3
  while [ $attempt -lt $max_attempts ]; do
    if hostname=$(get_and_confirm_hostname); then
      break
    fi
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
      error "多次输入的主机名不一致，脚本退出。"
    fi
  done

  # Set the new hostname
  sudo hostnamectl set-hostname "$hostname"
  if [ $? -eq 0 ]; then
    success "主机名已成功更改为: $hostname"
  else
    warn "更改主机名失败。"
  fi
}

# 安装 Nginx
install_nginx() {
  info "*** 安装 Nginx ***"
  if ! sudo grep -q "^fs.file-max" /etc/sysctl.conf; then
    cont "系统内核优化..."
    sysctl_setting
  fi
  # Nginx 安装逻辑
  if [[ "$OS" == **"CentOS"** ]] || [[ "$OS" == **"Rocky"** ]]; then
    yumInstall "yum-utils"
    cont "添加 ${C04}Nginx${CF} [${C02}USTC中科大${CF}] 下载源"
    sudo tee /etc/yum.repos.d/nginx.repo >/dev/null <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://mirrors.ustc.edu.cn/nginx/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=https://mirrors.ustc.edu.cn/nginx/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://mirrors.ustc.edu.cn/nginx/keys/nginx_signing.key
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
    warn "不支持的系统类型，仅支持 Ubuntu/Rocky Linux/CentOS"
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
    success "防火墙放通 http ${C02}$http_port${CF} 端口完成。\n"
    sudo firewall-cmd --permanent --add-port="$https_port/tcp"
    success "防火墙放通 https ${C02}$https_port${CF} 端口完成。\n"
    sudo firewall-cmd --reload
    success "Nginx 安装启动完成。\n"
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
  jemalloc_dl="https://gh.api.99988866.xyz/https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2"
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

  mkdir -p $SOFTWARW_DL_DIR/tengine
  sudo wget -P $SOFTWARW_DL_DIR/tengine "$jemalloc_dl"
  sudo wget -P $SOFTWARW_DL_DIR/tengine "$tengine_dl"
  sudo tar xjf "$SOFTWARW_DL_DIR/jemalloc-5.3.0.tar.bz2" >/dev/null
  sudo tar xvf "$SOFTWARW_DL_DIR/tengine-$tengine_version.tar.gz" >/dev/null

  info "*** 安装 Tengine 版本 $tdengine_version ***"

  # Tengine 安装逻辑

  if ! sudo grep -q "^fs.file-max" /etc/sysctl.conf; then
    cont "系统内核优化..."
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

    cd $SOFTWARW_DL_DIR/tengine || exit 1
    sudo wget https://gh.api.99988866.xyz/https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2
    sudo tar xjf jemalloc-5.3.0.tar.bz2
    cd jemalloc-5.3.0 || exit 1
    sudo ./configure && sudo make && sudo make install

    if grep -q "/usr/lib/" "/etc/ld.so.conf.d/_lib.conf"; then
      sudo ldconfig -v
    else
      echo "/usr/lib/" | sudo tee -a /etc/ld.so.conf.d/_lib.conf >/dev/null
      sudo ldconfig -v
    fi

    cd $SOFTWARW_DL_DIR/tengine || exit 1
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
    error "不支持的系统类型，仅支持 Ubuntu/Rocky Linux/CentOS"

  fi

}

Install_Go() {

  # 默认参数
  # 软件名称
  SOFTWARW_NAME="Golang"
  # 默认版本号 go 1.15.15
  GO_DEFAULT_VERSION="1.15.15"
  GO_INSTALL_DIR="/usr/local/go"
  sudo mkdir -p "$GO_INSTALL_DIR"

  info "*** 安装 $SOFTWARW_NAME ***"

  # 安装
  while :; do
    # 提示用户输入版本号
    read -rp "输入 $SOFTWARW_NAME 版本号(留空默认: $GO_DEFAULT_VERSION): " GO_VER

    # 如果用户没有输入版本号，则使用默认版本号
    if [[ -z "$GO_VER" ]]; then
      GO_VER="$GO_DEFAULT_VERSION"
    fi
    # 检查版本号格式
    if [[ "$GO_VER" =~ $VERSION_REGEX ]]; then
      # 拼接下载地址
      GO_BASE_URL="https://$SOFTWARW_NAME.google.cn/dl"
      GO_FILENAME="go$GO_VER.linux-amd64.tar.gz"
      GO_DL_URL="$GO_BASE_URL/$GO_FILENAME"
      # 检查下载地址是否有效
      if wget --spider "$GO_DL_URL" 2>&1 | grep -q '200'; then

        cont "下载地址有效，开始下载 $SOFTWARW_NAME $GO_VER..."
        if [ -x "$(command -v wget)" ]; then
          wget -P "$SOFTWARW_DL_DIR" "$GO_DL_URL"
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

          success "下载完成，文件保存在 $SOFTWARW_DL_DIR"
        fi

        # 解压下载的文件到 $GO_INSTALL_DIR
        cont "开始解压文件到 $GO_INSTALL_DIR..."
        sudo tar xvf "$SOFTWARW_DL_DIR/$GO_FILENAME" -C "$GO_INSTALL_DIR" >/dev/null
        sudo mv "$GO_INSTALL_DIR/go" "$GO_INSTALL_DIR/go$GO_VER"

        # 设置环境变量

        ln -s "$GO_INSTALL_DIR"/go"$GO_VER"/bin/* /usr/bin/
        success "解压完成，$SOFTWARW_NAME $GO_VER 已安装在 $GO_INSTALL_DIR"

        GO_VERSION=$(go version | grep "go version" | cut -f4 -d "o" | awk '{print $1}')
        if [[ "$GO_VER" == "$GO_VERSION" ]]; then
          success "$SOFTWARW_NAME $GO_VER 安装完成。\n"
        else
          warn "$SOFTWARW_NAME 系统版本 $GO_VERSION 与当前安装版本 $GO_VER 不一致，请检查。"
        fi
        break
      else
        warn "下载地址无效，请重新输入版本号。"
      fi
    else
      warn "版本号格式不正确，请输入类似 '$GO_DEFAULT_VERSION' 的格式。"
    fi
  done
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
      error "mongodb 4 启动失败，请检查配置!\n"
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
        warn "端口仅支持${C01}数字${CF}，请重新输入!\n"
      elif [ "$mongodb_port" -gt "65535" ]; then
        warn "端口号不能超过 ${C01}65535${CF}，请重新输入!\n"
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
        error "MongoDB 重启失败，请检查配置!\n"
      else
        success "MongoDB 端口: ${C3}$mongodb_port${CF} 设置完成。\n"
      fi
    fi
  else
    error "未找到 MongoDB 配置文件 /etc/mongod.conf。\n"
  fi

}

javaDevelopEnv() {
  case ${1} in
  1)
    OpenJDK_URL="https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/linux/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz"

    # 检查 Java 是否已安装
    if [[ "$OS" == *"Rocky"* ]]; then
      if command -v java &>/dev/null; then
        INSTALLED_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
        success "Java 已安装，当前版本: $INSTALLED_VERSION."
      else
        warn "Java 未安装，正在进行安装..."
        JAVA_INSTALL_DIR="/usr/local/java"
        sudo mkdir -p "$JAVA_INSTALL_DIR"

        # 下载 JDK
        cont "正在下载 OpenJDK..."
        wget -P "$SOFTWARW_DL_DIR" "$OpenJDK_URL"

        # 解压 JDK
        cont "正在解压 OpenJDK..."
        sudo tar -xzf "/$SOFTWARW_DL_DIR/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz" -C "$JAVA_INSTALL_DIR"

        # 设置环境变量
        JAVA_HOME_DIR="$JAVA_INSTALL_DIR/jdk-21.0.4+7/"
        sudo rm -rf /etc/profile.d/java.sh
        echo "export JAVA_HOME=$JAVA_HOME_DIR" | sudo tee -a /etc/profile.d/java.sh
        echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/profile.d/java.sh

        # 重新加载环境变量
        source /etc/profile.d/java.sh

        # 更新 alternatives
        sudo update-alternatives --install /usr/bin/java java "$JAVA_HOME_DIR/bin/java" 1
        sudo update-alternatives --install /usr/bin/javac javac "$JAVA_HOME_DIR/bin/javac" 1

        # 清理下载的文件
        #rm "/tmp/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz"

        success "Java 安装完成，您可以使用 'java -version' 来验证安装成功."
        java -version
      fi
    fi
    ;;
  2)
    info "maven: A software project management and comprehension tool"
    if [[ "$OS" == **"Rocky"** ]]; then
      dnfInstall maven
    elif [[ "$OS" == *"Ubuntu"* ]]; then
      aptInstall maven
    elif [[ "$OS" == *"CentOS"* ]]; then
      yumInstall maven
    fi
    ;;
  esac
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
    curl -L https://gh.api.99988866.xyz/https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
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
    error "MySQL 启动失败，请检查配置!\n"
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
      warn "端口仅支持${C01}数字${CF}，请重新输入!\n"
    elif [ "$mysql_port" -gt "65535" ]; then
      warn "端口号不能超过 ${C01}65535${CF}，请重新输入!\n"
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
      error "mysqld 服务重启失败，请检查配置!\n"
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
      warn "两次密码验证失败，请重新输入\n"
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
    # MySQL 启用简单密码，开启远程访问
    mysql_temp_pass="#PFu>N)9aZw3i2iZAwjB#2bb8"
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$random_passwd" --connect-expired-password -e "alter user 'root'@'localhost' identified with mysql_native_password by '$mysql_temp_pass';set global validate_password.policy=LOW;set global validate_password.length=6;alter user 'root'@'host' identified with mysql_native_password by '$mysql_passwd';use mysql;update user set host='%' where user='root';flush privileges;"
  else
    # 写入新 MySQL 密码并开启外部连接
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$random_passwd" --connect-expired-password -e "alter user 'root'@'localhost' identified with mysql_native_password by '$mysql_passwd';use mysql;update user set host='%' where user='root';flush privileges;"
  fi

  cont "设置 root 密码成功。正在重启 mysqld..."
  if ! sudo systemctl restart mysqld; then
    error "mysqld 服务重启失败，请检查配置!\n"
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
      warn "用户名不能为 ${C1}root${CF} 或 ${C1}admin{CF}，请重新输入\n"
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
      printf "两次密码验证失败，请重新输入\n\n"
    else
      break
    fi
  done

  if [ "$mysql_user_passwd" = "123456" ]; then
    # MySQL 启用简单密码，开启远程访问
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$mysql_passwd" --connect-expired-password -e "set global validate_password.policy=LOW;set global validate_password.length=6;use mysql;create user $mysql_user_name identified by '$mysql_user_passwd';update user set host='%' where user='$mysql_user_name';flush privileges;grant all privileges on *.* to '$mysql_user_name'@'%' with grant option;flush privileges;"
  else
    # 写入 MySQL 新用户密码并开启外网连接($mysql_passwd 为 root 密码变量)
    sudo /usr/bin/mysql -S /var/lib/mysql/mysql.sock -p"$mysql_passwd" --connect-expired-password -e "use mysql;create user $mysql_user_name identified by '$mysql_user_passwd';update user set host='%' where user='$mysql_user_name';flush privileges;grant all privileges on *.* to '$mysql_user_name'@'%' with grant option;flush privileges;"
  fi

  cont "设置 $mysql_user_name 密码成功。正在重启 mysqld..."

  if ! sudo systemctl restart mysqld; then
    error "mysqld 服务重启失败，请检查 create_mysql_user 配置!\n"
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
    error "Redis 安装失败，请检查 install_redis 配置!\n"
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
      warn "端口仅支持${C01}数字${CF}，请重新输入!\n"
    elif [ "$Redis_port" -gt "65535" ]; then
      warn "端口号不能超过 ${C01}65535${CF}，请重新输入!\n"
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
      error "Redis 服务重启失败，请检查 config_redis_port 配置!\n"
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
      printf "两次密码验证失败，请重新输入\n\n"
    else
      break
    fi
  done

  if [ "$Redis_passwd" = "" ]; then
    if ! sudo systemctl restart redis; then
      error "Redis 服务重启失败，请检查 config_redis_password 配置!\n"
    else
      success "成功设置 Redis 访问密码为: <空>\n"
    fi
  else
    if [ -s /etc/redis.conf ]; then
      sudo sed -i '/# requirepass foobared/a\requirepass '"$Redis_passwd"'' /etc/redis.conf
      if ! sudo systemctl restart redis; then
        error "Redis 服务重启失败，请检查 config_redis_password 配置!\n"
      else
        success "成功设置 Redis 访问密码为: ${C1}$Redis_passwd${CF}\n"
      fi
    else
      error "未找到 Redis 配置文件 /etc/redis.conf。\n"
    fi
  fi

}

Install_elk() {
  info "安装 ELK"
  # 默认参数
  ELK_INSTALL_DIR="/data/server/elk"
  ELK_DL_DIR="$SOFTWARW_DL_DIR/elk"
  # 默认版本号 8.8.1
  ELK_DEFAULT_VERSION="8.8.1"
  # 创建所需的目录
  sudo mkdir -p "$ELK_DL_DIR" "$ELK_INSTALL_DIR"
  case ${1} in
  1)
    if command -v java &>/dev/null; then
      JDK_INSTALLED_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
      success "JDK 已安装，当前版本: $JDK_INSTALLED_VERSION."
    else
      javaDevelopEnv 1
    fi

    # 软件名称
    SOFTWARW_NAME="Elasticsearch"

    info "安装 $SOFTWARW_NAME"
    # 开始安装
    while :; do
      # 提示用户输入版本号
      read -rp "输入 Elasticsearch 版本号(留空默认: $ELK_DEFAULT_VERSION): " ELK_VER

      # 如果用户没有输入版本号，则使用默认版本号
      if [[ -z "$ELK_VER" ]]; then
        ELK_VER="$ELK_DEFAULT_VERSION"
      fi

      # 检查版本号格式
      if [[ "$ELK_VER" =~ $VERSION_REGEX ]]; then
        # 拼接下载地址
        ES_BASE_URL="https://mirrors.huaweicloud.com/elasticsearch/$ELK_DEFAULT_VERSION"
        ES_FILENAME="elasticsearch-$ELK_VER-linux-x86_64.tar.gz"
        ES_DL_URL="$ES_BASE_URL/$ES_FILENAME"

        # 检查下载地址是否有效
        if wget --spider "$ES_DL_URL" 2>&1 | grep -q '200'; then
          cont "创建 ELK 用户"
          # 用户名规则
          while :; do
            read -p "用户名(留空默认: elastic): " ESuserName
            ESuserName="${ESuserName:-elastic}"
            if [[ "$ESuserName" =~ .*root.* || "$ESuserName" =~ .*admin.* ]]; then
              warn "用户名不能包含 ${C01}admin${CF} 或 ${C01}root${CF} ，请重新输入\n"
            elif id -u "$ESuserName" >/dev/null 2>&1; then
              warn "用户 \"$ESuserName\" 已存在，请重新输入\\n"
            elif echo "$ESuserName" | grep -qP '[\p{Han}]'; then
              warn "用户名不能包含<中文>，请重新输入\n"
            elif [ -z "$ESuserName" ]; then
              warn "用户名不能为<空>，请重新输入\n"
            else
              break
            fi
          done

          # 提示输入密码
          while :; do
            read -rp "输入密码(密码输入已隐藏): " -s ESPASSWD
            echo ''
            if [ -z "$ESPASSWD" ]; then
              warn "密码不能为<空>，请重新输入\n"
              continue
            elif [[ ${#ESPASSWD} -lt 8 || ! "$ESPASSWD" =~ [A-Z] || ! "$ESPASSWD" =~ [a-z] ]]; then
              warn "密码必须至少8个字符，包括至少1个大写字母和1个小写字母，请重新输入\n"
              continue
            fi
            read -rp "再次确认密码: " -s ESPASSWORD
            echo ''

            if [ "$ESPASSWD" != "$ESPASSWORD" ]; then
              warn "两次密码验证失败，请重新输入\n"
              continue
            else
              break
            fi
          done

          # 添加用户及密码
          sudo useradd -s /sbin/nologin "$ESuserName"
          if [[ "$OS" == *"Ubuntu"* ]]; then
            sudo echo "$ESuserName:$ESPASSWORD" | sudo chpasswd >/dev/null 2>&1
          else
            sudo echo "$ESPASSWORD" | passwd --stdin "$ESuserName" >/dev/null 2>&1
          fi

          # 用户创建通知
          if id "$ESuserName" &>/dev/null; then
            success "ELK 用户 $ESuserName 密码 $ESPASSWORD 创建完成"
          else
            warn "ELK 用户创建失败，请手动创建。"
          fi

          cont "下载地址有效，开始下载 $SOFTWARW_NAME $ELK_VER..."
          wget -P "$ELK_DL_DIR" "$ES_DL_URL"
          success "下载完成，文件保存在 $ELK_DL_DIR"

          # 解压下载的文件到 $ES_DIR
          cont "开始解压文件到 $ELK_INSTALL_DIR..."
          tar -xzf "$ELK_DL_DIR/$ES_FILENAME" -C "$ELK_INSTALL_DIR"
          success "解压完成，$SOFTWARW_NAME 已安装在 $ELK_INSTALL_DIR"

          ES_HOME_DIR="$ELK_INSTALL_DIR/elasticsearch-$ELK_VER"
          ES_CONFIG_DIR="$ES_HOME_DIR/config"
          ES_BIN_DIR="$ES_HOME_DIR/bin"
          ES_CONFIG_FILE="$ES_CONFIG_DIR/elasticsearch.yml"

          cont "正在修改 $ES_CONFIG_FILE 配置文件..."

          # 确保文件内包含指定的注释行
          grep -q "#node.name: node-1" "$ES_CONFIG_FILE" || echo "#node.name: node-1" >>"$ES_CONFIG_FILE"
          #grep -q "#path.data: /path/to/data" "$ES_CONFIG_FILE" || echo "#path.data: /path/to/data" >>"$ES_CONFIG_FILE"
          #grep -q "#path.logs: /path/to/logs" "$ES_CONFIG_FILE" || echo "#path.logs: /path/to/logs" >>"$ES_CONFIG_FILE"

          # 在指定行下方添加相应的配置
          sed -i "/#node.name: node-1/a ## elastic节点名字\nnode.name: node-1" "$ES_CONFIG_FILE"
          #sed -i "/#path.data: \/path\/to\/data/a ## 数据存放目录\npath.data: $ES_DATA_DIR" "$ES_CONFIG_FILE"
          #sed -i "/#path.logs: \/path\/to\/logs/a ## 日志存放目录\npath.logs: $ES_LOGS_DIR" "$ES_CONFIG_FILE"
          sed -i "/#network.host:/a ## 对所有IP开放，可以根据需求修改\nnetwork.host: 0.0.0.0" "$ES_CONFIG_FILE"

          success "$ES_CONFIG_FILE 配置文件修改完成."

          # 修改 $ES_DATA_DIR 和 $ES_LOGS_DIR 文件夹的所有者为 $ESuserName
          sudo chown -R "$ESuserName": "$ES_HOME_DIR"
          success "已将 $ES_HOME_DIR 的所有者更改为 $ESuserName"

          # 添加启动脚本
          cont "正在添加 $SOFTWARW_NAME 启动脚本..."
          sudo tee /etc/systemd/system/elasticsearch.service >/dev/null <<EOF
[Unit]
Description=ElasticSearch
After=network.target
 
[Service]
Type=simple
User=$ESuserName
Group=$ESuserName
ExecStart=$ES_BIN_DIR/elasticsearch -d -p $ES_HOME_DIR/elasticsearch.pid
ExecStop=$ES_BIN_DIR/elasticsearch stop
PIDFile=$ES_HOME_DIR/elasticsearch.pid
# 修改线程数限制
LimitNPROC=65535
# 修改文件描述符限制
LimitNOFILE=65535
 
[Install]
WantedBy=multi-user.target
EOF

          success "$SOFTWARW_NAME 启动脚本已成功添加到 /etc/systemd/system/elasticsearch.service."

          # 重新加载 systemd 管理器配置
          sudo systemctl daemon-reload

          # 启动 Elasticsearch 服务
          sleep 3
          sudo systemctl start elasticsearch
          sleep 3
          sudo systemctl enable elasticsearch

          success "$SOFTWARW_NAME 服务已启动并设置为开机自启."

          # 检查并更新 PATH
          ES_PROFILE="/etc/profile.d/elasticsearch.sh"
          cont "正在检查 /etc/profile.d/elasticsearch.sh 是否包含 $SOFTWARW_NAME 的 bin 目录..."
          sudo touch $ES_PROFILE

          if ! grep -q "export PATH=.*$ES_BIN_DIR" "$ES_PROFILE"; then
            echo "# Elasticsearch" | sudo tee -a "$ES_PROFILE" >/dev/null
            echo "export PATH=\$PATH:$ES_BIN_DIR" | sudo tee -a "$ES_PROFILE" >/dev/null

            success "已将 $SOFTWARW_NAME 的 bin 目录添加到 PATH 中."

            #cont "为 elastic 创建密码"
            #elasticsearch-reset-password -u elastic -i
            ES_BASE_DIR="$ELK_INSTALL_DIR/elasticsearch"
            ES_OLD_PATH_REGEX="export PATH=\$PATH:$ES_BASE_DIR-[0-9.]+/bin"
          elif grep -q "$ES_OLD_PATH_REGEX" "$ES_PROFILE"; then
            CURRENT_VER=$(grep -oP "$ES_BASE_DIR-\K[0-9.]+" "$ES_PROFILE")

            if [[ "$(printf '%s\n' "$CURRENT_VER" "$ELK_VER" | sort -V | head -n1)" == "$CURRENT_VER" && "$CURRENT_VER" != "$ELK_VER" ]]; then
              sed -i "s|$ES_BASE_DIR-[0-9.]+/bin|$ES_BASE_DIR-$ELK_VER/bin|g" "$ES_PROFILE"
              success "已将 Elasticsearch 的版本从 $CURRENT_VER 更新到 $ELK_VER。"
            else
              success "Elasticsearch 的版本已经是最新的 ($CURRENT_VER)。"
            fi
          else
            warn "Elasticsearch 的 bin 目录已存在于 PATH 中。"
          fi

          # 重新加载环境变量
          source $ES_PROFILE

          # 可选：清理下载的压缩文件
          #rm "$ELK_INSTALL_DIR/elasticsearch-$ELK_VER-linux-x86_64.tar.gz"
          #success "已删除下载的压缩文件。"
          break
        else
          warn "下载地址无效，请重新输入版本号。"
        fi
      else
        warn "版本号格式不正确，请输入类似 '$ELK_DEFAULT_VERSION' 的格式。"
      fi
    done
    ;;
  2)
    # 软件名称
    SOFTWARW_NAME="Logstash"
    info "安装 $SOFTWARW_NAME"

    # 默认参数
    ELK_INSTALL_DIR="/data/server/elk"
    ELK_DL_DIR="$SOFTWARW_DL_DIR/elk"
    # 默认版本号 8.8.1
    ELK_DEFAULT_VERSION="8.8.1"
    # 创建所需的目录
    sudo mkdir -p "$ELK_DL_DIR" "$ELK_INSTALL_DIR"

    # 开始安装
    while :; do
      # 提示用户输入版本号
      read -rp "输入 Logstash 版本号(留空默认: $ELK_DEFAULT_VERSION): " ELK_VER

      # 如果用户没有输入版本号，则使用默认版本号
      if [[ -z "$ELK_VER" ]]; then
        ELK_VER="$ELK_DEFAULT_VERSION"
      fi

      # 检查版本号格式
      if [[ "$ELK_VER" =~ $VERSION_REGEX ]]; then
        # 拼接下载地址
        LS_BASE_URL="https://mirrors.huaweicloud.com/logstash/$ELK_DEFAULT_VERSION"
        LS_FILENAME="logstash-$ELK_VER-linux-x86_64.tar.gz"
        LS_DL_URL="$LS_BASE_URL/$LS_FILENAME"

        # 检查下载地址是否有效
        if wget --spider "$LS_DL_URL" 2>&1 | grep -q '200'; then

          # 用户名规则
          while :; do
            read -p "输入 Elasticsearch 用户名(留空默认: elastic): " ESuserName
            ESuserName="${ESuserName:-elastic}"
            if [[ "$ESuserName" =~ .*root.* || "$ESuserName" =~ .*admin.* ]]; then
              warn "用户名不能包含 ${C01}admin${CF} 或 ${C01}root${CF} ，请重新输入\n"
            elif ! id "$ESuserName" &>/dev/null; then
              warn "用户 $ESuserName 不存在，请重新输入\n"
            elif echo "$ESuserName" | grep -qP '[\p{Han}]'; then
              warn "用户名不能包含<中文>，请重新输入\n"
            elif [ -z "$ESuserName" ]; then
              warn "用户名不能为<空>，请重新输入\n"
            else
              break
            fi
          done

          # 提示输入密码
          while :; do
            read -rp "输入密码(密码输入已隐藏): " -s ESPASSWD
            echo ''
            if [ -z "$ESPASSWD" ]; then
              warn "密码不能为<空>，请重新输入\n"
              continue
            elif [[ ${#ESPASSWD} -lt 8 || ! "$ESPASSWD" =~ [A-Z] || ! "$ESPASSWD" =~ [a-z] ]]; then
              warn "密码必须至少8个字符，包括至少1个大写字母和1个小写字母，请重新输入\n"
              continue
            fi
            read -rp "再次确认密码: " -s ESPASSWORD
            echo ''

            if [ "$ESPASSWD" != "$ESPASSWORD" ]; then
              warn "两次密码验证失败，请重新输入\n"
              continue
            else
              break
            fi
          done

          cont "下载地址有效，开始下载 Logstash $ELK_VER..."
          wget -P "$ELK_DL_DIR" "$LS_DL_URL"
          success "下载完成，文件保存在 $ELK_DL_DIR"

          # 解压下载的文件到 $ELK_VER
          cont "开始解压文件到 $ELK_INSTALL_DIR..."
          tar -xzf "$ELK_DL_DIR/$LS_FILENAME" -C "$ELK_INSTALL_DIR"
          success "解压完成，Logstash 已安装在 $ELK_INSTALL_DIR"

          LS_HOME_DIR="$ELK_INSTALL_DIR/logstash-$ELK_VER"
          LS_CONFIG_DIR="$LS_HOME_DIR/config"
          LS_BIN_DIR="$LS_HOME_DIR/bin"
          LS_CONFIG_FILE="$LS_CONFIG_DIR/logstash.conf"

          ES_HOME_DIR="$ELK_INSTALL_DIR/elasticsearch-$ELK_VER"
          ES_CONFIG_DIR="$ES_HOME_DIR/config"

          cont "正在修改 $LS_CONFIG_FILE 配置文件..."
          mkdir -p $LS_CONFIG_DIR
          sudo touch $LS_CONFIG_FILE
          sudo tee $LS_CONFIG_FILE >/dev/null <<EOF
input {
  beats {
    port => 5044
  }
  file {
    path => "$LS_HOME_DIR/logs/test.log"
    start_position => "beginning"
  }
}

output {
  elasticsearch {
    hosts => ["https://localhost:9200"]
    user => "$ESuserName"
    password => "$ESPASSWORD"
    index => "index-test"
    cacert => "$ES_CONFIG_DIR/certs/http_ca.crt"
  }
  stdout {
    codec => rubydebug
  }
}
EOF

          success "$LS_CONFIG_FILE 配置文件修改完成."

          # 修改 $LS_DATA_DIR 和 $LS_LOGS_DIR 文件夹的所有者为 $ESuserName
          sudo chown -R "$ESuserName": "$LS_HOME_DIR"
          success "已将 $LS_HOME_DIR 的所有者更改为 $ESuserName"

          # 添加启动脚本
          LS_PROFILE="/etc/profile.d/logstash.sh"
          cont "正在添加 Logstash 启动脚本..."
          sudo tee /etc/systemd/system/logstash.service >/dev/null <<EOF
[Unit]
Description=Logstash service
After=network.target
 
[Service]
Type=simple
User=$ESuserName
Group=$ESuserName
ExecStart=$LS_BIN_DIR/logstash -f $LS_CONFIG_FILE
Restart=always
 
[Install]
WantedBy=multi-user.target
EOF

          success "Logstash 启动脚本已成功添加到 /etc/systemd/system/logstash.service."

          # 重新加载 systemd 管理器配置
          sudo systemctl daemon-reload

          # 启动 Logstash 服务
          sleep 3
          sudo systemctl start logstash
          sleep 3
          sudo systemctl enable logstash

          success "Logstash 服务已启动并设置为开机自启."
          # 检查并更新 PATH
          cont "正在检查 /etc/profile.d/logstash.sh 是否包含 Logstash 的 bin 目录..."
          sudo touch $LS_PROFILE

          if ! grep -q "export PATH=.*$LS_BIN_DIR" "$LS_PROFILE"; then
            echo "" | sudo tee -a "$LS_PROFILE" >/dev/null
            echo "# Logstash" | sudo tee -a "$LS_PROFILE" >/dev/null
            echo "export PATH=\$PATH:$LS_BIN_DIR" | sudo tee -a "$LS_PROFILE" >/dev/null

            # 重新加载环境变量
            source $LS_PROFILE

            success "已将 Logstash 的 bin 目录添加到 PATH 中."
            LS_BASE_DIR="$ELK_INSTALL_DIR/logstash"
            LS_OLD_PATH_REGEX="export PATH=\$PATH:$LS_BASE_DIR-[0-9.]+/bin"
          elif grep -q "$LS_OLD_PATH_REGEX" "$LS_PROFILE"; then
            CURRENT_VER=$(grep -oP "$LS_BASE_DIR-\K[0-9.]+" "$LS_PROFILE")

            if [[ "$(printf '%s\n' "$CURRENT_VER" "$ELK_VER" | sort -V | head -n1)" == "$CURRENT_VER" && "$CURRENT_VER" != "$ELK_VER" ]]; then
              sed -i "s|$LS_BASE_DIR-[0-9.]+/bin|$LS_BASE_DIR-$ELK_VER/bin|g" "$LS_PROFILE"
              success "已将 Logstash 的版本从 $CURRENT_VER 更新到 $ELK_VER"
            else
              success "Logstash 的版本已经是最新的 ($CURRENT_VER)。"
            fi
          else
            warn "Logstash 的 bin 目录已存在于 PATH 中。"
          fi
          # 可选：清理下载的压缩文件
          #rm -rf "$ELK_INSTALL_DIR/logstash-$ELK_VER-linux-x86_64.tar.gz"
          #success "已删除下载的压缩文件。"
          break
        else
          warn "下载地址无效，请重新输入版本号。"
        fi
      else
        warn "版本号格式不正确，请输入类似 '$ELK_DEFAULT_VERSION' 的格式。"
      fi
    done
    ;;
  3)
    # 软件名称
    SOFTWARW_NAME="Kibana"
    info "安装 #$SOFTWARW_NAME"

    # 默认参数
    ELK_INSTALL_DIR="/data/server/elk"
    ELK_DL_DIR="$SOFTWARW_DL_DIR/elk"
    # 默认版本号 8.8.1
    ELK_DEFAULT_VERSION="8.8.1"
    # 创建所需的目录
    sudo mkdir -p "$ELK_DL_DIR" "$ELK_INSTALL_DIR"

    # 开始安装
    while :; do
      # 提示用户输入版本号
      read -rp "输入 Kibana 版本号(留空默认: $ELK_DEFAULT_VERSION): " ELK_VER

      # 如果用户没有输入版本号，则使用默认版本号
      if [[ -z "$ELK_VER" ]]; then
        ELK_VER="$ELK_DEFAULT_VERSION"
      fi

      # 检查版本号格式
      if [[ "$ELK_VER" =~ $VERSION_REGEX ]]; then
        # 拼接下载地址
        KB_BASE_URL="https://mirrors.huaweicloud.com/kibana/$ELK_DEFAULT_VERSION"
        KB_FILENAME="kibana-$ELK_VER-linux-x86_64.tar.gz"
        KB_DL_URL="$KB_BASE_URL/$KB_FILENAME"

        # 检查下载地址是否有效
        if wget --spider "$KB_DL_URL" 2>&1 | grep -q '200'; then
          cont "下载地址有效，开始下载 Kibana $ELK_VER..."

          # 用户名规则
          while :; do
            read -p "输入 Elasticsearch 用户名(留空默认: elastic): " ESuserName
            ESuserName="${ESuserName:-elastic}"
            if [[ "$ESuserName" =~ .*root.* || "$ESuserName" =~ .*admin.* ]]; then
              warn "用户名不能包含 ${C01}admin${CF} 或 ${C01}root${CF} ，请重新输入\n"
            elif ! id "$ESuserName" &>/dev/null; then
              warn "用户 $ESuserName 不存在，请重新输入\n"
            elif echo "$ESuserName" | grep -qP '[\p{Han}]'; then
              warn "用户名不能包含<中文>，请重新输入\n"
            elif [ -z "$ESuserName" ]; then
              warn "用户名不能为<空>，请重新输入\n"
            else
              break
            fi
          done

          wget -P "$ELK_DL_DIR" "$KB_DL_URL"
          success "下载完成，文件保存在 $ELK_INSTALL_DIR"

          # 解压下载的文件到 $ELK_INSTALL_DIR
          cont "开始解压文件到 $ELK_INSTALL_DIR..."
          tar -xzf "$ELK_DL_DIR/$KB_FILENAME" -C "$ELK_INSTALL_DIR"
          success "解压完成，Kibana 已安装在 $ELK_INSTALL_DIR"

          KB_HOME_DIR="$ELK_INSTALL_DIR/kibana-$ELK_VER"
          KB_CONFIG_DIR="$KB_HOME_DIR/config"
          KB_BIN_DIR="$KB_HOME_DIR/bin"
          KB_CONFIG_FILE="$KB_CONFIG_DIR/kibana.yml"

          cont "设置 Kibana 访问地址..."

          IP_REGEX="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"

          while :; do
            read -rp "请输入 Kibana 访问地址(留空默认: 0.0.0.0): " KB_Host
            KB_Host="${KB_Host:-0.0.0.0}"

            if [[ ! $KB_Host =~ $IP_REGEX ]]; then
              echo "IP地址格式不正确，请重新输入!"
            else
              break
            fi
          done

          success "Kibana 访问地址为: $KB_Host"

          cont "设置 Kibana 访问端口..."

          while :; do
            read -rp "请输入 Kibana 访问端口(留空默认: 5601): " KB_Port
            KB_Port="${KB_Port:-5601}"

            if [[ ! $KB_Port =~ ^[0-9]+$ ]]; then
              warn "端口仅支持数字，请重新输入!"
            #elif [ "$sshPort" -lt "1024" ]; then
            #  warn "端口号不能小于 1024，请重新输入!"
            elif [ "$KB_Port" -gt "65535" ]; then
              warn "端口号不能大于 65535，请重新输入!"
            else
              break
            fi
          done

          cont "正在修改 $KB_CONFIG_FILE 配置文件..."

          # 确保文件内包含指定的注释行
          grep -q "#server.port: 5601" "$KB_CONFIG_FILE" || echo "#server.port: 5601" >>"$KB_CONFIG_FILE"
          grep -q "#server.host: \"localhost\"" "$KB_CONFIG_FILE" || echo "#server.host: \"localhost\"" >>"$KB_CONFIG_FILE"
          # grep -q "#path.data: data" "$KB_CONFIG_FILE" || echo "#path.data: data" >>"$KB_CONFIG_FILE"
          grep -q "#i18n.locale: \"en\"" "$KB_CONFIG_FILE" || echo "#i18n.locale: \"en\"" >>"$KB_CONFIG_FILE"

          # 在指定行下方添加相应的配置
          sed -i "/#server.port: 5601/a ## 访问端口\nserver.port: $KB_Port" "$KB_CONFIG_FILE"
          sed -i "/#server.host: \"localhost\"/a ## 访问地址\nserver.host: \"$KB_Host\"" "$KB_CONFIG_FILE"
          sed -i "/#elasticsearch.ssl.verificationMode: full/a ## 修改认证模式为 none\nelasticsearch.ssl.verificationMode: none" "$KB_CONFIG_FILE"
          sed -i "/#server.publicBaseUrl: \"\"/a ## 互联网访问地址\nserver.publicBaseUrl: \"http://$MYIP:$KB_Port\"" "$KB_CONFIG_FILE"
          #sed -i "/#path.data: data/a ## 数据存放目录\npath.data: $KB_DATA_DIR" "$KB_CONFIG_FILE"
          sed -i "/#i18n.locale: \"en\"/a ## 使用中文语言\ni18n.locale: \"zh-CN\"" "$KB_CONFIG_FILE"

          success "$KB_CONFIG_FILE 配置文件修改完成."

          # 修改 $KB_DATA_DIR 和 $KB_LOGS_DIR 文件夹的所有者为 $ESuserName
          sudo chown -R "$ESuserName": "$KB_HOME_DIR"
          success "已将 $KB_HOME_DIR 的所有者更改为 $ESuserName"

          # 添加启动脚本
          cont "正在添加 Kibana 启动脚本..."
          sudo tee /etc/systemd/system/kibana.service >/dev/null <<EOF
[Unit]
Description=Kibana service
After=network.target
 
[Service]
Type=simple
User=$ESuserName
Group=$ESuserName
ExecStart=$KB_BIN_DIR/kibana
Restart=always
 
[Install]
WantedBy=multi-user.target
EOF

          success "Kibana 启动脚本已成功添加到 /etc/systemd/system/kibana.service."

          # 重新加载 systemd 管理器配置
          sudo systemctl daemon-reload

          # 启动 Kibana 服务
          sleep 3
          sudo systemctl start kibana
          sleep 3
          sudo systemctl enable kibana

          success "Kibana 服务已启动并设置为开机自启."

          # 检查并更新 PATH
          KB_BASE_DIR="$ELK_INSTALL_DIR/kibana"
          KB_PROFILE="/etc/profile.d/kibana.sh"
          cont "正在检查 /etc/profile.d/kb.sh 是否包含 Kibana 的 bin 目录..."
          sudo touch $KB_PROFILE

          if ! grep -q "export PATH=.*$KB_BIN_DIR" "$KB_PROFILE"; then
            echo "# Kibana" | sudo tee -a "$KB_PROFILE" >/dev/null
            echo "export PATH=\$PATH:$KB_BIN_DIR" | sudo tee -a "$KB_PROFILE" >/dev/null

            success "已将 Kibana 的 bin 目录添加到 PATH 中."

            # 重新加载环境变量
            source $KB_PROFILE
            KB_OLD_PATH_REGEX="export PATH=\$PATH:$KB_BASE_DIR-[0-9.]+/bin"
          elif grep -q "$KB_OLD_PATH_REGEX" "$KB_PROFILE"; then
            CURRENT_VER=$(grep -oP "$KB_BASE_DIR-\K[0-9.]+" "$KB_PROFILE_FILE")

            if [[ "$(printf '%s\n' "$CURRENT_VER" "$ELK_VER" | sort -V | head -n1)" == "$CURRENT_VER" && "$CURRENT_VER" != "$ELK_VER" ]]; then
              sed -i "s|$KB_BASE_DIR-[0-9.]+/bin|$KB_BASE_DIR-$ELK_VER/bin|g" "$KB_PROFILE_FILE"
              success "已将 Kibana 的版本从 $CURRENT_VER 更新到 $ELK_VER"
            else
              success "Kibana 的版本已经是最新的 ($CURRENT_VER)。"
            fi
          else
            warn "Kibana 的 bin 目录已存在于 PATH 中。"
          fi

          # 可选：清理下载的压缩文件
          #rm "$ELK_INSTALL_DIR/logstash-$ELK_VER-linux-x86_64.tar.gz"
          #success "已删除下载的压缩文件。"

          cont "为 ELK 超级用户 elastic 创建密码"
          elasticsearch-reset-password -u elastic -i

          msg "\n使用命令生成 Kibana 令牌: \nelasticsearch-create-enrollment-token -s kibana\n"
          msg "\n使用命令获取 Kibana 验证码: \nkibana-verification-code"

          break
        else
          warn "下载地址无效，请重新输入版本号。"
        fi
      else
        warn "版本号格式不正确，请输入类似 '$ELK_DEFAULT_VERSION' 的格式。"
      fi
    done
    ;;
  esac
}

Install_Filebeat() {
  SOFTWARW_NAME="filebeat"
  info "安装 $SOFTWARW_NAME"
  # 默认参数

  ELK_INSTALL_DIR="/data/server/elk"
  ELK_DL_DIR="$SOFTWARW_DL_DIR/elk"
  # 默认版本号
  FB_DEFAULT_VERSION="7.9.1"
  # 创建所需的目录
  sudo mkdir -p "$ELK_DL_DIR" "$ELK_INSTALL_DIR"

  while :; do
    # 提示用户输入版本号
    read -rp "输入 Filebeat 版本号(留空默认: $FB_DEFAULT_VERSION): " FB_VER

    # 如果用户没有输入版本号，则使用默认版本号
    if [[ -z "$FB_VER" ]]; then
      FB_VER="$FB_DEFAULT_VERSION"
    fi

    # 检查版本号格式
    if [[ "$FB_VER" =~ $VERSION_REGEX ]]; then
      # 拼接下载地址
      FB_BASE_URL="https://mirrors.huaweicloud.com/$SOFTWARW_NAME/$FB_VER"
      FB_FILENAME="$SOFTWARW_NAME-$FB_VER-linux-x86_64.tar.gz"
      FB_DL_URL="$FB_BASE_URL/$FB_FILENAME"

      # 检查下载地址是否有效
      if wget --spider "$FB_DL_URL" 2>&1 | grep -q '200'; then
        cont "下载地址有效，开始下载 Filebeat $FB_VER..."
        wget -P "$ELK_DL_DIR" "$FB_DL_URL"
        success "下载完成，文件保存在 $ELK_DL_DIR"

        # 解压下载的文件到 $FB_VER
        cont "开始解压文件到 $FB_VER..."
        tar -xzf "$ELK_DL_DIR/$FB_FILENAME" -C "$ELK_INSTALL_DIR"
        success "Filebeat 已安装在 $ELK_INSTALL_DIR"

        cont "设置 Elasticsearch 访问地址..."
        IP_REGEX="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
        while :; do
          read -rp "请输入 Elasticsearch 访问地址(留空默认: 127.0.0.1): " ES_UP_Host
          ES_UP_Host="${ES_UP_Host:-127.0.0.1}"
          if [[ ! $ES_UP_Host =~ $IP_REGEX ]]; then
            warn "IP地址格式不正确，请重新输入!"
          else
            break
          fi
        done

        cont "设置 Elasticsearch 访问端口..."
        while :; do
          read -rp "请输入 Elasticsearch 访问端口(留空默认: 29200): " ES_UP_Port
          ES_UP_Port="${ES_UP_Port:-29200}"
          if [[ ! $ES_UP_Port =~ ^[0-9]+$ ]]; then
            warn "端口仅支持数字，请重新输入!"
          elif [ "$ES_UP_Port" -lt "1024" ]; then
            warn "端口号不能小于 1024，请重新输入!"
          elif [ "$ES_UP_Port" -gt "65535" ]; then
            warn "端口号不能大于 65535，请重新输入!"
          else
            break
          fi
        done

        # 提示输入密码
        while :; do
          read -rp "输入 ES超级用户 elastic 的密码(密码输入已隐藏): " -s ESPASSWD
          echo ''
          if [ -z "$ESPASSWD" ]; then
            warn "密码不能为<空>，请重新输入\n"
            continue
          elif [[ ${#ESPASSWD} -lt 8 || ! "$ESPASSWD" =~ [A-Z] || ! "$ESPASSWD" =~ [a-z] ]]; then
            warn "密码必须至少8个字符，包括至少1个大写字母和1个小写字母，请重新输入\n"
            continue
          fi
          read -rp "再次确认密码: " -s ESPASSWORD
          echo ''

          if [ "$ESPASSWD" != "$ESPASSWORD" ]; then
            warn "两次密码验证失败，请重新输入\n"
            continue
          else
            break
          fi
        done

        cont "正在修改 $FB_CONFIG_FILE 配置文件..."

        FB_HOME_DIR="$ELK_INSTALL_DIR/$SOFTWARW_NAME-$FB_VER-linux-x86_64"
        FB_BIN_DIR="$FB_HOME_DIR"
        FB_CONFIG_FILE="$FB_HOME_DIR/$SOFTWARW_NAME.yml"

        # 确保文件内包含指定的行
        grep -q "output.elasticsearch:" "$FB_CONFIG_FILE" || echo "output.elasticsearch:" >>"$FB_CONFIG_FILE"

        # 在指定行下方添加相应的配置
        sed -i "/^output.elasticsearch:/ {
  N
  N
  s/hosts: \[\"localhost:9200\"\]/hosts: \[\"$ES_UP_Host:$ES_UP_Port\"\]/
}" $FB_CONFIG_FILE
        sed -i "/^output.elasticsearch:/ {
  N
  N
  N
  N
  N
  N
  N
  N
  N
  s/#username: \"elastic\"/username: \"elastic\"/
}" $FB_CONFIG_FILE
        sed -i "/^output.elasticsearch:/ {
  N
  N
  N
  N
  N
  N
  N
  N
  N
  N
  s/#password: \"changeme\"/password: \"$ESPASSWORD\"/
}" $FB_CONFIG_FILE
        #sed -i "/#password:/a ## 访问端口\nserver.port: $KB_Port" "$KB_CONFIG_FILE"

        success "$ES_CONFIG_FILE 配置文件修改完成."
        break
      else
        warn "下载地址无效，请重新输入版本号。"
      fi
    else
      warn "版本号格式不正确，请输入类似 '$FB_DEFAULT_VERSION' 的格式。"
    fi
  done
}

Install_frp() {
  case ${1} in
  1)
    SOFTWARW_NAME="frp"
    info "安装 frp 服务端"
    # 默认参数

    FRPS_INSTALL_DIR="/data/server"
    FRPS_DL_DIR="$SOFTWARW_DL_DIR"
    # 默认版本号
    FRPS_DEFAULT_VERSION="0.59.0"
    # 创建所需的目录
    sudo mkdir -p "$FRPS_DL_DIR" "$FRPS_INSTALL_DIR"

    while :; do
      # 提示用户输入版本号
      read -rp "输入 frp 版本号(留空默认: $FRPS_DEFAULT_VERSION): " FRPS_VER

      # 如果用户没有输入版本号，则使用默认版本号
      if [[ -z "$FRPS_VER" ]]; then
        FRPS_VER="$FRPS_DEFAULT_VERSION"
      fi

      # 检查版本号格式
      if [[ "$FRPS_VER" =~ $VERSION_REGEX ]]; then
        # 拼接下载地址
        FRPS_BASE_URL="https://gh.api.99988866.xyz/https://github.com/fatedier/$SOFTWARW_NAME/releases/download/v$FRPS_VER"
        FRPS_FILENAME="${SOFTWARW_NAME}_${FRPS_VER}_linux_amd64.tar.gz"
        FRPS_DL_URL="$FRPS_BASE_URL/$FRPS_FILENAME"

        # 检查下载地址是否有效
        if wget --spider "$FRPS_DL_URL" 2>&1 | grep -q '200'; then

          cont "下载地址有效，设置 frp 访问端口..."
          while :; do
            read -rp "请输入 frp 访问端口(留空默认: 7999): " FRPS_Port
            FRPS_Port="${FRPS_Port:-7999}"
            if [[ ! $FRPS_Port =~ ^[0-9]+$ ]]; then
              warn "端口仅支持数字，请重新输入!"
            elif [ "$FRPS_Port" -lt "1024" ]; then
              warn "端口号不能小于 1024，请重新输入!"
            elif [ "$FRPS_Port" -gt "65535" ]; then
              warn "端口号不能大于 65535，请重新输入!"
            else
              break
            fi
          done

          cont "设置 frp 后台访问地址..."
          IP_REGEX="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
          while :; do
            read -rp "请输入 frp 后台访问地址(留空默认: 0.0.0.0): " FRPS_Host
            FRPS_Host="${FRPS_Host:-0.0.0.0}"
            if [[ ! $FRPS_Host =~ $IP_REGEX ]]; then
              warn "IP地址格式不正确，请重新输入!"
            else
              break
            fi
          done

          cont "设置 frp 后台访问端口..."
          while :; do
            read -rp "请输入 frp 后台访问端口(留空默认: 7500): " FRPS_Host_Port
            FRPS_Host_Port="${FRPS_Host_Port:-7500}"
            if [[ ! $FRPS_Host_Port =~ ^[0-9]+$ ]]; then
              warn "端口仅支持数字，请重新输入!"
            elif [ "$FRPS_Host_Port" -lt "1024" ]; then
              warn "端口号不能小于 1024，请重新输入!"
            elif [ "$FRPS_Host_Port" -gt "65535" ]; then
              warn "端口号不能大于 65535，请重新输入!"
            else
              break
            fi
          done

          # 用户名规则
          while :; do
            read -p "输入 frp 后台管理员用户名(留空默认: frpadmin): " FRPS_Admin
            FRPS_Admin="${FRPS_Admin:-frpadmin}"
            if [[ "$FRPS_Admin" =~ .*root.* || "$FRPS_Admin" =~ .*admin.* ]]; then
              warn "用户名不能包含 ${C01}admin${CF} 或 ${C01}root${CF} ，请重新输入\n"
            elif echo "$FRPS_Admin" | grep -qP '[\p{Han}]'; then
              warn "用户名不能包含<中文>，请重新输入\n"
            elif [ -z "$FRPS_Admin" ]; then
              warn "用户名不能为<空>，请重新输入\n"
            else
              break
            fi
          done

          # 提示输入密码
          while :; do
            read -rp "输入 frp 后台管理员密码(密码输入已隐藏): " -s FRPSPASSWD
            echo ''
            if [ -z "$FRPSPASSWD" ]; then
              warn "密码不能为<空>，请重新输入\n"
              continue
            elif [[ ${#FRPSPASSWD} -lt 8 || ! "$FRPSPASSWD" =~ [A-Z] || ! "$FRPSPASSWD" =~ [a-z] ]]; then
              warn "密码必须至少8个字符，包括至少1个大写字母和1个小写字母，请重新输入\n"
              continue
            fi
            read -rp "再次确认密码: " -s FRPSPASSWORD
            echo ''

            if [ "$FRPSPASSWD" != "$FRPSPASSWORD" ]; then
              warn "两次密码验证失败，请重新输入\n"
              continue
            else
              break
            fi
          done

          cont "开始下载 frp $FRPS_VER..."
          wget -P "$FRPS_DL_DIR" "$FRPS_DL_URL"
          success "下载完成，文件保存在 $FRPS_DL_DIR"

          # 解压下载的文件到 $FRPS_INSTALL_DIR
          cont "开始解压文件到 $FRPS_INSTALL_DIR..."
          tar -xzf "$FRPS_DL_DIR/$FRPS_FILENAME" -C "$FRPS_INSTALL_DIR"
          success "frp 已安装在 $FRPS_INSTALL_DIR"

          FRPS_SOFT_DIR="$FRPS_INSTALL_DIR/${SOFTWARW_NAME}_${FRPS_VER}_linux_amd64"
          mv $FRPS_SOFT_DIR $FRPS_INSTALL_DIR/frps
          FRPS_HOME_DIR="$FRPS_INSTALL_DIR/frps"
          rm -rf $FRPC_HOME_DIR/frpc*
          FRPS_BIN_DIR="$FRPS_HOME_DIR"
          FPRS_CONFIG_FILE="$FRPS_HOME_DIR/frps.toml"

          cont "正在修改 frp 服务端 $FPRS_CONFIG_FILE 配置文件..."

          # 确保文件内包含指定的行
          cat /dev/null >$FPRS_CONFIG_FILE
          sudo tee $FPRS_CONFIG_FILE >/dev/null <<EOF
# 服务端通信端口
bindPort = $FRPS_Port
kcpBindPort = $FRPS_Port
# 鉴权方式
auth.method = "token"
# 自定义token
auth.token = "A3hkfU7S57L3nVH=deRp"

# 后台管理面板配置
# 后台面板端口号
webServer.port = $FRPS_Host_Port
# 后台管理地址
webServer.addr = "$FRPS_Host"
# 后台管理员账号
webServer.user = "$FRPS_Admin"
# 后台管理员密码
webServer.password = "$FRPSPASSWORD"

# 日志配置
# 日志路径
log.to = "$FRPS_HOME_DIR/frps.log"
# 日志等级
log.level = "info"
# 日志保留天数
log.maxDays = 7

EOF

          success "$FPRS_CONFIG_FILE 配置文件修改完成."

          # 添加启动脚本
          cont "正在添加 frps 启动脚本..."
          sudo tee /etc/systemd/system/frps.service >/dev/null <<EOF
[Unit]
# 服务名称，可自定义
Description = FRP Server
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
# 启动frps的命令，需修改为您的frps的安装路径
ExecStart = $FRPS_BIN_DIR/frps -c $FPRS_CONFIG_FILE

[Install]
WantedBy = multi-user.target

EOF

          success "frps 启动脚本已成功添加到 /etc/systemd/system/frps.service."

          # 重新加载 systemd 管理器配置
          sudo systemctl daemon-reload

          # 启动 Kibana 服务
          sleep 3
          sudo systemctl start frps
          sleep 3
          sudo systemctl enable frps

          success "frps 服务已启动并设置为开机自启."

          break
        else
          warn "下载地址无效，请重新输入版本号。"
        fi
      else
        warn "版本号格式不正确，请输入类似 '$FRPS_DEFAULT_VERSION' 的格式。"
      fi
    done
    ;;
  2)
    SOFTWARW_NAME="frp"
    info "安装 frp 客户端"
    # 默认参数

    FRPC_INSTALL_DIR="/data/server"
    FRPC_DL_DIR="$SOFTWARW_DL_DIR"
    # 默认版本号
    FRPC_DEFAULT_VERSION="0.59.0"
    # 创建所需的目录
    sudo mkdir -p "$FRPC_DL_DIR" "$FRPC_INSTALL_DIR"

    while :; do
      # 提示用户输入版本号
      read -rp "输入 frp 版本号(留空默认: $FRPC_DEFAULT_VERSION): " FRPC_VER

      # 如果用户没有输入版本号，则使用默认版本号
      if [[ -z "$FRPC_VER" ]]; then
        FRPC_VER="$FRPC_DEFAULT_VERSION"
      fi

      # 检查版本号格式
      if [[ "$FRPC_VER" =~ $VERSION_REGEX ]]; then
        # 拼接下载地址
        FRPC_BASE_URL="https://gh.api.99988866.xyz/https://github.com/fatedier/$SOFTWARW_NAME/releases/download/v$FRPC_VER"
        FRPC_FILENAME="${SOFTWARW_NAME}_${FRPC_VER}_linux_amd64.tar.gz"
        FRPC_DL_URL="$FRPC_BASE_URL/$FRPC_FILENAME"

        # 检查下载地址是否有效
        if wget --spider "$FRPC_DL_URL" 2>&1 | grep -q '200'; then

          cont "下载地址有效，设置 frp 服务器 访问端口..."
          while :; do
            read -rp "请输入 frp 服务器访问端口(留空默认: 7999): " FRPC_SPort
            FRPC_SPort="${FRPC_SPort:-7999}"
            if [[ ! $FRPC_SPort =~ ^[0-9]+$ ]]; then
              warn "端口仅支持数字，请重新输入!"
            elif [ "$FRPC_SPort" -lt "1024" ]; then
              warn "端口号不能小于 1024，请重新输入!"
            elif [ "$FRPC_SPort" -gt "65535" ]; then
              warn "端口号不能大于 65535，请重新输入!"
            else
              break
            fi
          done

          cont "开始下载 frp $FRPC_VER..."
          wget -P "$FRPC_DL_DIR" "$FRPC_DL_URL"
          success "下载完成，文件保存在 $FRPC_DL_DIR"

          # 解压下载的文件到 $FRPC_INSTALL_DIR
          cont "开始解压文件到 $FRPC_INSTALL_DIR..."
          tar -xzf "$FRPC_DL_DIR/$FRPC_FILENAME" -C "$FRPC_INSTALL_DIR"
          success "frpc 已安装在 $FRPC_INSTALL_DIR"

          FRPC_SOFT_DIR="$FRPC_INSTALL_DIR/${SOFTWARW_NAME}_${FRPC_VER}_linux_amd64"
          mv $FRPC_SOFT_DIR $FRPC_INSTALL_DIR/frpc
          FRPC_HOME_DIR="$FRPC_INSTALL_DIR/frpc"
          rm -rf $FRPC_HOME_DIR/frps*
          FRPC_BIN_DIR="$FRPC_HOME_DIR"
          FPRC_CONFIG_FILE="$FRPC_HOME_DIR/frpc.toml"

          cont "正在修改 frp 客户端 $FPRC_CONFIG_FILE 配置文件..."

          # 确保文件内包含指定的行
          cat /dev/null >$FPRC_CONFIG_FILE
          sudo tee $FPRC_CONFIG_FILE >/dev/null <<EOF
# 服务端IP地址
serverAddr = "$FRPC_SHost"
# 服务端通信端口
serverPort = $FRPC_SPort

# 鉴权方式
auth.method = "token"
# 自定义token
auth.token = "A3hkfU7S57L3nVH=deRp"

# console or real logFile path like ./frpc.log
log.to = "$FRPC_HOME_DIR/frpc.log"
# trace, debug, info, warn, error
log.level = "info"
log.maxDays = 7
# disable log colors when log.to is console, default is false
log.disablePrintColor = false

[[proxies]]
name = "Example"
type = "tcp"
localIP = "127.0.0.1"
#customDomains = ["exp.example.com"]
# frp 本地客户端端口
localPort = 1234
# frp 服务器端口
remotePort = 1234

EOF

          success "$FPRC_CONFIG_FILE 配置文件修改完成."

          # 添加启动脚本
          cont "正在添加 frp 客户端启动脚本..."
          sudo tee /etc/systemd/system/frpc.service >/dev/null <<EOF
[Unit]
# 服务名称，可自定义
Description = FRP Clinet
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
# 启动frps的命令，需修改为您的frpc的安装路径
ExecStart = $FRPC_BIN_DIR/frpc -c $FPRC_CONFIG_FILE

[Install]
WantedBy = multi-user.target

EOF

          success "frpc 启动脚本已成功添加到 /etc/systemd/system/frpc.service."

          # 重新加载 systemd 管理器配置
          sudo systemctl daemon-reload

          # 启动 Kibana 服务
          sleep 3
          sudo systemctl start frpc
          sleep 3
          sudo systemctl enable frpc

          success "frpc 服务已启动并设置为开机自启."

          break
        else
          warn "下载地址无效，请重新输入版本号。"
        fi
      else
        warn "版本号格式不正确，请输入类似 '$FRPC_DEFAULT_VERSION' 的格式。"
      fi
    done
    ;;
  esac
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
${C07}密码: ${C01}$PASSWORD \E[33;5m👈 ${C05}\E[33;5m请牢记密码${CF}
${C06}*** 系统默认${C01}禁止${C06}密码登陆，需要密码登陆请使用以下命令设置:${CF}
sed -Ei '/^PasswordAuthentication no/s/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd
${C06}*** 系统默认${C01}禁止🙅${C01}\E[33;9m\$root${CF}${C06}🙅登陆，需要${C01}root${C06}登陆请使用以下命令设置: ${CF}"
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
  printf "\n\n系统环境初始化完毕，是否立即重启服务器?[y/n]"
  read -p ": " is_reboot
  while [[ ! $is_reboot =~ ^[y,n]$ ]]; do
    warn "输入有误，只能输入[y/n]"
    read -p "[y/n]: " is_reboot
  done
  if [ "$is_reboot" = 'y' ]; then
    sudo reboot
  fi
}

help() {
  echo "用法: $0 [类型] [目标] [选项]"
  echo
  echo "类型和目标"
  echo
  echo "[init]"
  echo "	系统默认初始化。"
  echo "[update]"
  echo "	系统定期进行更新和升级，以增强其功能和能力。"
  echo
  echo "[source]"
  echo "[source]"
  echo "	sys：根据系统评估自动修改源地址。"
  echo "	Ubuntu:    https://mirrors.cloud.tencent.com/ubuntu/"
  echo "	Rocky:     https://mirrors.cloud.tencent.com/rocky/"
  echo "	CentOS:    https://mirrors.cloud.tencent.com/centos/"
  echo "	pip:       https://pypi.tuna.tsinghua.edu.cn/simple"
  echo "	docker:    https://docker.mirrors.ustc.edu.cn"
  echo
  echo "[key]"
  echo "  为现有用户补充加密密钥。"
  echo "  用法: bash $0 key"
  echo
  echo "[nginx]"
  echo "  安装 Nginx Web 服务器。"
  echo "  用法: bash $0 nginx"
  echo
  echo "[tengine]"
  echo "  安装 Tengine Web 服务器。"
  echo "  用法: bash $0 tengine"
  echo
  echo "[go | golang]"
  echo "  设置golang编程语言开发环境。"
  echo "  用法: bash $0 golang"
  echo
  echo "[python]"
  echo "	pip: pip3"
  echo "	pyenv：简单的 Python 版本管理"
  echo "	pipenv： Python 开发工作流程"
  echo "[java]"
  echo "	jdk: OpenJDK-21"
  echo "	maven：一个软件项目管理和理解工具"
  echo "[javascript]"
  echo "	nvm：Node 版本管理器 - 用于管理多个活动 node.js 版本的简单 bash 脚本"
  echo "[docker]"
  echo "	docker-ce: "
  echo "	docker-compose：用于定义和运行多容器 Docker 应用程序的工具"
  echo
  echo "选项"
  echo
  echo " -b,--basic 	基本工具安装：curl、git、vim、wget、zip、unzip、lrzsz、net-tools、htop"
  echo " -v,--Version 	显示版本"
  echo " -h,--help 	显示此帮助消息并退出"
  echo
  echo "示例:"
  echo
  echo "	更新系统"
  echo "		bash $0 update"
  echo "	安装 java maven"
  echo "		bash $0 java meven"
  echo "	安装所有 Python 工具"
  echo "		bash $0 python"
}

main() {
  if [ $# -eq 0 ]; then
    welcome
    echo "用法: bash $0 [type] [target] [options]"
    echo
    echo "$0 [-h|--help] [-v|--version] [-b|--basic]"
    echo "	{init,update,source,key,nginx,tengine,go,python,java,javascript,docker,shell} [target]"
    echo
    cmdCheck curl
    cmdCheck git
    cmdCheck wget
  else
    case $@ in
    "init")
      welcome
      CD
      changeSourceForChina 1
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
    "user add")
      create_new_user 1
      ;;
    "user key")
      create_new_user 2
      ;;
    "user nologin")
      create_new_user 3
      ;;
    "hostname")
      Set_Hostname
      printf "\n系统主机名设置完成，是否立即重启服务器?[y/n]"
      read -p ": " is_reboot
      while [[ ! $is_reboot =~ ^[y,n]$ ]]; do
        warn "输入有误，只能输入[y/n]"
        read -p "[y/n]: " is_reboot
      done
      if [ "$is_reboot" = 'y' ]; then
        sudo reboot
      fi
      ;;
    "nginx")
      install_nginx
      ;;
    "tengine")
      install_tengine
      ;;
    go | golang)
      Install_Go
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
    "elk")
      Install_elk 1
      #Install_elk 2
      Install_elk 3
      printf "\nELK 安装完成，是否立即重启服务器?[y/n]"
      read -p ": " is_reboot
      while [[ ! $is_reboot =~ ^[y,n]$ ]]; do
        warn "输入有误，只能输入[y/n]"
        read -p "[y/n]: " is_reboot
      done
      if [ "$is_reboot" = 'y' ]; then
        sudo reboot
      fi
      ;;
    "frps")
      Install_frp 1
      ;;
    "frpc")
      Install_frp 2
      ;;
    "docker docker-compose")
      dockerDevelopEnv 2
      ;;
    "filebeat")
      Install_Filebeat
      ;;
    --basic | -b)
      basic_tools_install
      ;;
    --version | -v)
      echo "Version: ${VERSION}"
      ;;
    --help | -h)
      help
      ;;
    esac
  fi
}

main $@
