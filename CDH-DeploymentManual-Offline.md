# CDH 完全离线安装
## 前置环境准备
### 卸载OPENJDK，安装OracleJDK
执行`rpm -qa | grep java-1.* | xargs -I {} rpm -e --nodeps {}`  
下载地址 [jdk-8u191](https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)  
执行`rpm -ivh jdk-8u191-linux-x64.rpm  `  
配置环境变量，在`/etc/profile`中添加如下变量 
```bash
JAVA_HOME=/usr/java/jdk1.8.0_191-amd64
JRE_HOME=/usr/java/jdk1.8.0_191-amd64/jre
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin
export JAVA_HOME JRE_HOME CLASS_PATH PATH
```
执行`source /etc/profile`使环境变量生效  
### 检查时间是否正确
`date -s 2018/12/06` 设置年月日  
`date -s 19:00:00` 设置时分秒  
`hwclock -w` 将当前时间写入硬件，避免重启失效  
### 关闭防火墙，SELINUX
`systemctl stop firewalld.service`  
`systemctl disable firewalld.service`  
`setenforce 0`  
修改/etc/selinux/config 文件，SELINUX=disabled  
### 配置SSH免密
`ssh-keygen -t rsa -P ''` 生成RSA秘钥  
```bash
 for i in {101..103}; do ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.$i;done
```
将公钥发送到集群其他节点  
### Linux内核部分
####禁用透明大页面压缩
`echo never > /sys/kernel/mm/transparent_hugepage/defrag`  
`echo never > /sys/kernel/mm/transparent_hugepage/enabled`  
并将上面的两条命令写入开机自启动  
`vim /etc/rc.local`  
####优化交换分区
vim /etc/sysctl.conf  
vm.swappiness = 10  
sysctl -p /etc/sysctl.conf  
## 安装MySQL
下载地址：[MySQL](https://dev.mysql.com/downloads/file/?id=481117)  
`tar -zxvf mysql-5.7.24-linux-glibc2.12-x86_64.tar.gz -C /opt/mysql`解压至指定目录，并将解压后产生的文件移入mysql目录，删除mysql-5.7.24-linux-glibc2.12-x86_64目录，在mysql目录下新建data目录用于存放数据文件
### 新建mysql用户组和mysql用户
`groupadd mysql` 新建用户组  
`useradd -r -g mysql mysql`  新建用户，`-r` 新建系统用户 `-g `指定组  
`chown -R mysql:mysql /opt/mysql`  
`chown -R mysql /opt/mysql`  
`chmod -R 755 /opt/mysql`  
设定目录所有者,并赋权  
进入/opt/mysql/bin  
`./mysqld --user=mysql --basedir=/opt/mysql --datadir=/opt/mysql/data --initialize`  初始化mysql，要特别注意  
**[Note] A temporary password is generated for root@localhost: o*s#gqh)F4Ck**  
最后的就是初始密码
### 修改MySQL配置文件
`vim /opt/mysql/support-files/mysql.server`  
填写完整basedir,datadir即可  
`cp /opt/mysql/support-files/mysql.server  /etc/init.d/mysqld`  
`chmod 755 /etc/init.d/mysqld`  
### 修改my.cnf文件
`vi /etc/my.cnf`  
将下面内容复制替换当前的my.cnf文件中的内容  
```
[client]
no-beep
socket =/opt/mysql/mysql.sock
# pipe
# socket=0.0
port=3306
[mysql]
default-character-set=utf8
[mysqld]
basedir=/opt/mysql
datadir=/opt/mysql/data
port=3306
pid-file=/opt/mysql/mysqld.pid
#skip-grant-tables
skip-name-resolve
socket = /opt/mysql/mysql.sock
character-set-server=utf8
default-storage-engine=INNODB
explicit_defaults_for_timestamp = true
# Server Id.
server-id=1
max_connections=2000
query_cache_size=0
table_open_cache=2000
tmp_table_size=246M
thread_cache_size=300
#限定用于每个数据库线程的栈大小。默认设置足以满足大多数应用
thread_stack = 192k
key_buffer_size=512M
read_buffer_size=4M
read_rnd_buffer_size=32M
innodb_data_home_dir = /opt/mysql/data
innodb_flush_log_at_trx_commit=0
innodb_log_buffer_size=16M
innodb_buffer_pool_size=256M
innodb_log_file_size=128M
innodb_thread_concurrency=128
innodb_autoextend_increment=1000
innodb_buffer_pool_instances=8
innodb_concurrency_tickets=5000
innodb_old_blocks_time=1000
innodb_open_files=300
innodb_stats_on_metadata=0
innodb_file_per_table=1
innodb_checksum_algorithm=0
back_log=80
flush_time=0
join_buffer_size=8M
max_allowed_packet=32M
max_connect_errors=2000
open_files_limit=4161
query_cache_type=0
sort_buffer_size=32M
table_definition_cache=1400
binlog_row_event_max_size=8K
sync_master_info=10000
sync_relay_log=10000
sync_relay_log_info=10000
#批量插入数据缓存大小，可以有效提高插入效率，默认为8M
bulk_insert_buffer_size = 64M
interactive_timeout = 120
wait_timeout = 28800
log-bin-trust-function-creators=1
sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES
#
# include all files from the config directory
#
!includedir /etc/my.cnf.d
```
建立mysql的软连接，方便使用  
`ln -s /opt/mysql/bin/mysql /usr/bin/mysql`  
### 启动mysql
service start mysqld  
### 如果忘记初始密码
在/etc/my.cnf最后加上`skip-grant-tables` 重启mysql  
`mysql -uroot -p `登录mysql  
执行如下SQL语句  
```sql
use mysql;
update user set authentication_string = PASSWORD("root") where user = "root";
flush privileges;
```
去除my.cnf中的`skip-grant-tables`  重启mysql  

### 配置MYSQL可以远程访问
```sql
grant all privileges on *.* to root@'%' identified by 'root';
flush privileges;
```
如果提示 ERROR 1820(HY000) You must reset your password........  
先执行修改密码语句`set password = PASSWORD('root')`  
### 配置mysql可使用systemctl进行管理
