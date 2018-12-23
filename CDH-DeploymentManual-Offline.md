# CDH 完全离线安装
## 前置环境准备
### 配置host
**略**
### 卸载OPENJDK，安装OracleJDK
执行`rpm -qa | grep java-1.* | xargs -I {} rpm -e --nodeps {}`  
下载地址 [jdk-8u191](https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)  
执行`rpm -ivh jdk-8u191-linux-x64.rpm  `  
配置环境变量，在`/etc/profile`中添加如下变量 
```bash
JAVA_HOME=/usr/java/latest
JRE_HOME=/usr/java/latest/jre
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin
export JAVA_HOME
export JRE_HOME
export CLASS_PATH
export PATH
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
#### 禁用透明大页面压缩
`echo never > /sys/kernel/mm/transparent_hugepage/defrag`  
`echo never > /sys/kernel/mm/transparent_hugepage/enabled`  
并将上面的两条命令写入开机自启动  
`vim /etc/rc.local`  
#### 优化交换分区
vim /etc/sysctl.conf  
vm.swappiness = 10  
sysctl -p /etc/sysctl.conf
### 配置本地yum镜像源
>**由于依赖众多复杂，可以下载CentOS-Everything镜像作为本地的yum镜像源，同时注意，如果你使用的1511的版本，配置的源也要使用1511版本，避免出现一些问题**

下载地址 :[CentOS-7-x86_64-Everything-1804.iso](https://mirrors.aliyun.com/centos/7.5.1804/isos/x86_64/CentOS-7-x86_64-Everything-1804.iso)
`/mnt/iso` 新建ISO存放目录  
`/mnt/cdrom` 新建镜像挂载目录  
`mount -o loop /mnt/iso/CentOS-7-x86_64-Everything-1804.iso /mnt/cdrom` 挂载镜像  
创建repo文件  
```
[local]
name=local
#注：这里的baseurl就是你挂载的目录，在这里是/mnt/cdrom
baseurl=file:///mnt/cdrom    
#注：这里的值enabled一定要为1  
enabled=1                    
gpgcheck=0
#注：这个你cd /mnt/cdrom/可以看到这个key，这里仅仅是个例子
gpgkey=file:///mnt/cdrom/RPM-GPG-KEY-CentOS-7
```
`yum clean all` 清除缓存  
`yum makecache`  创建缓存  
如果出错，把除了刚配置的repo文件放到别处去即可
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
> 如果是用RPM安装，密码可以去此处查看 grep 'temporary password' /var/log/mysqld.log  
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
### 安装MySQL jdbc Driver
解压后将jar包放入`/usr/share/java`中  
```
tar zxvf mysql-connector-java-5.1.46.tar.gz
mkdir -p /usr/share/java/
cd mysql-connector-java-5.1.46
cp mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar
```
>注：因为cloudera-manager需要这个driver，并且指定了driver存放路径是/usr/share/java,并且名字必须是mysql-connector-java.jar
### 创建必要的数据库
```sql
create database scm default character set utf8 default collate utf8_general_ci;
grant all on scm.* to 'scm'@'%' identified by 'root';
create database amon default character set utf8 default collate utf8_general_ci;
grant all on amon.* to 'amon'@'%' identified by 'root';
create database rman default character set utf8 default collate utf8_general_ci;
grant all on rman.* to 'rman'@'%' identified by 'root';
create database hue default character set utf8 default collate utf8_general_ci;
grant all on hue.* to 'hue'@'%' identified by 'root';
create database metastore default character set utf8 default collate utf8_general_ci;
grant all on metastore.* to 'hive'@'%' identified by 'root';
create database sentry default character set utf8 default collate utf8_general_ci;
grant all on sentry.* to 'sentry'@'%' identified by 'root';
create database nav default character set utf8 default collate utf8_general_ci;
grant all on nav.* to 'nav'@'%' identified by 'root';
create database oozie default character set utf8 default collate utf8_general_ci;
grant all on oozie.* to 'oozie'@'%' identified by 'root';
flush privileges;
```
将上面的语句存成create-db.sql，放在opt目录下，登录mysql  
`source /opt/create-db.sql` 执行即可  
## 安装Cloudera Manager
`mkdir /opt/cloudera` 新建目录  
使用rpm -ivh进行安装，安装顺序：`daemon -> server -> server-db -> agent `  
安装server-db的时候，会提示需要postgresql-server这个依赖`yum install -y postgresql-server`,使用之前配置的镜像源安装即可  
安装agent的时候会提示缺少较多的依赖，此处一并给出，方便执行  
`yum install -y libxslt cyrus-sasl-gssapi fuse portmap fuse-libs lsb httpd mod_ssl openssl_devel python-psycopg2 MySQL-python`  
如果有依赖yum找不到，可以去/mnt/cdrom/Package/目录下寻找  
  
给相关目录赋权 	
`chown cloudera-scm:cloudera-scm /opt/cloudera/ -R`  
`chown cloudera-scm:cloudera-scm /var/log/cloudera-scm-agent -R`  
`chgrp cloudera-scm /opt/cloudera/ -R`  
`chgrp cloudera-scm /var/log/cloudera-scm-agent -R`  
### 配置Cloudera Manager连接MySQL配置信息
执行` /opt/cloudera/cm/schema/scm_prepare_database.sh <databaseType> <databaseName> <databaseUser> <datapasswd>`，会生成`/etc/cloudera-scm-server/db.properties`,里面是数据库的连接信息，如果这个文件有误，或者不存在，后面的服务无法启动。如果数据库连接有误，可以手动修改db.properties这个文件。当看见**All done ,your SCM database is configured correctly**表示数据库连接成功
### 将CDH离线二进制安装包放入指定目录
将之前下载的CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel、manifest.json 放入`/opt/cloudera/parcel-repo/`目录中，执行`sha1sum CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel > /opt/cloudera/parcel-repo/sha1sum CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel.sha`
>注意：如果manifest.json文件中hash与文件本身的hash(sha1)和CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel.sha不匹配，系统也会重新下载CDH包。因为sha256里面存的是文件的sha256，而manifest.json里面存的是hash(sha1)，所以不能直接匹配，sha1可以使用sha1sum来计算生成。
### 启动Cloudera Manager
切换为cloudera-scm用户  
`systemctl start cloudera-scm-server`   
看到此条信息，说明启动完成   
`INFO WebServerImpl:com.cloudera.server.cmf.WebServerImpl: Started Jetty server.`
## CDH安装
此步开始，进入图形化安装界面
## CDH 安装遇到的问题
### Can't open /var/run/cloudera-scm-agent/process/94-yarn-JOBHISTORY/supervisor_status: 权限不够
如遇到 `Can't open /var/run/cloudera-scm-agent/process/94-yarn-JOBHISTORY/supervisor_status: 权限不够`类似的错误，可以去`/var/log/`下查看日志去查找真正的错误，CM上报的错一般不是真实的错误信息
  
### the last packet sent successfully to the server was 0 milliseconds ago
数据库地址的问题，可以手动修改db.properties中的数据库连接信息。
### 一些Hbase，yarn,无法启动
有可能是没有HDFS的写入权限
