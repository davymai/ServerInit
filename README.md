<p align="center">
	<a><img src="https://img.shields.io/badge/platform-Ubuntu20+%20RockyLinux%208--9-CentOS%207"/>
    </a>
	<a href="https://github.com/davymai/ServerInit">
		<img src="https://img.shields.io/badge/license-GPLv3.0"/>
	</a>
</p>

# init.sh
This is a Bash script for initializing servers, which includes the installation of various development environments and tools. It supports multiple Linux distributions (such as CentOS 7, Rocky 8-9, Ubuntu 20+), and includes the installation and configuration of Docker, MySQL, Redis, etc.
>这个脚本是一个用于初始化服务器的 Bash 脚本，包含安装各种开发环境和工具的功能。它支持多种 Linux 发行版（如 CentOS 7 、Rocky 8-9、Ubuntu 20），并包含 Docker、MySQL、Redis 等工具的安装和配置。


# Functions
📝 The script is divided into several modules, which can be modified and extended by yourself.
>脚本分为多个模块，可自行修改和扩展
- Please see the comments in the script for details.
- >具体内容请查看脚本中的注释
- [x] Change the source of the package
- [x] Change time zone
- [x] Change the hostname
- [x] Update the system
- [x] Disable unused services
- [x] Disable SELinux
- [x] Password rule configuration
- [x] Delete useless users and groups
- [x] Create new user
- [x] Supplementing cryptographic keys for existing users
- [x] Install the necessary packages
- [x] Install the necessary tools
- [x] Install basic tools
- [x] Install Docker
- [x] Install MySQL
- [x] Install Redis
- [x] Install Nginx
- [x] Install Tengine
- [x] Install Git
- [x] Install Python
- [x] Install Go
- [x] Install Java
