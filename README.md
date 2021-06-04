# check_repl.sh
## Bash script for checking Mariadb  replication status

First of all it need to set executable:  

```
chown +x check_repl.sh
```
### usage:
```
./check_repl.sh --m MASTER_IP [--mp MASTER_PORT] --s SLAVE_IP [--sp SLAVE_PORT] --cn SLAVE_CONNECTION_NAME --user USER --passwd PASSWORD
```
**MASTER_IP** - IPv4 or FQDN of a mariadb replication master  
**MASTER_PORT** - mariadb replication master port if not set used 3306  
**SLAVE_IP** - IPv4 or FQDN of a mariadb replication slave  
**SLAVE_PORT** - mariadb replication slave port if not set used 3306  
**SLAVE_CONNECTION_NAME** - mariadb slave name  
**USER** - mysql connection user. **User must have replication rights**
**PASSWORD** -- mysql connection password  

### example: 
```
check_repl.sh --m 192.168.1.2 --s 192.168.1.4 --sp 3310 --cn DB10 --user replicant --passwd 'veryStrongPassword'
```
### ANSWER:
```
MASTER=192.168.1.2
MASTER_PORT=3306
SLAVE=192.168.1.4
SLAVE_PORT=3310
CONNECTION_NAME=DB10
MYSQL_USER=replicant
LAST_ERRNO = 0
SECONDS_BEHIND_MASTER = 0
IO_IS_RUNNING = Yes
SQL_IS_RUNNING = Yes
SLAVE_MASTER_LOG_FILE = mariadb-bin.000088
SLAVE_READ_POS = 297404030
MASTER_LOG_FILE = mariadb-bin.000088
MASTER_LOG_POS = 297404030

all OK!
```





