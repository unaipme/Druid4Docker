#!/bin/bash

function addext {
	_EXTENSIONS_LOADLIST[${#_EXTENSIONS_LOADLIST[@]}]=$1
}

_DEF_CONF=
function addcnf {
	if [ "$2" != "" ]; then
		_DEF_CONF="$_DEF_CONF$1=$2\n"
	fi
}

_DEF_ARGS=
function addarg {
	_DEF_ARGS="$_DEF_ARGS$1\n"
}

function warn {
	echo -e "\033[1;33m"$1"\033[0m"
}

function err {
	echo -e "\033[1;31m"$1"\033[0m"
}

_COMP=$DRUID_COMPONENT
case $_COMP in
	broker)
		_HEAP_SIZE=${HEAP_SIZE-24g}
		;;
	coordinator)
		_HEAP_SIZE=${HEAP_SIZE-3g}
		;;
	historical)
		_HEAP_SIZE=${HEAP_SIZE-8g}
		;;
	middleManager)
		_HEAP_SIZE=${HEAP_SIZE-64m}
		;;
	overlord)
		_HEAP_SIZE=${HEAP_SIZE-3g}
		;;
	"")
		err "You must define which component to launch: DRUID_COMPONENT={historical, broker, coordinator, overlord, middleManager}"
		exit 1
		;;
	*)
		err "Variable DRUID_COMPONENT must be one of {historical, broker, coordinator, overlord, middleManager}"
		exit 1
		;;
esac

_HDFS_CONF_DIR=${HDFS_CONF_DIR-/etc/hadoop/conf}
_CONF_DIR=conf/druid/_common
_CONF_FILE=$_CONF_DIR/common.runtime.properties
_JVM_ARG_FILE=conf/druid/$_COMP/jvm.config
_EXTENSIONS_LOADLIST=("druid-kafka-eight" "druid-s3-extensions" "druid-histogram" "druid-datasketches" "druid-lookups-cached-global" "mysql-metadata-storage")
if [ "$ZK_SERVICE_HOST" == "" ]; then
	err "Zookeeper hosts must be set: ZK_SERVICE_HOST=<host>:<port>[, <host2>:<port2>...]"
	exit 1
fi
_ZK_SERVICE_HOST=$ZK_SERVICE_HOST
_ZK_PATHS_BASE=${ZK_PATHS_BASE-/druid}
if [ "$METADATA_URI" == "" ] && [ "$METADATA_HOST" == "" ]; then
	err "Either the whole metadata database URI or the host must be defined."
	err "To define the whole URI:"
	err "METADATA_URI=jdbc:<db_type>://<db_host>:<db_port>/<db_name>[?options...]"
	err "Take advantage of the default values by setting only the host:"
	err "METADATA_HOST=<hostname or ip of db>"
	err "METADATA_PORT=<db port>, defaults to 3306 for MySQL, 5432 for PostgreSQL and 1527 for Derby"
	err "METADATA_DBNAME=<db name>, defaults to druid"
	exit 1
elif [ "$METADATA_USER" == "" ]; then
	err "The username for the metadata database must be set. METADATA_USER=<username>"
	exit 1
elif [ "$METADATA_PASSWORD" == "" ]; then
	err "The password for the metadata database must be set. METADATA_PASSWORD=<password>"
	exit 1
fi

case $METADATA_TYPE in
	mysql)
		_METADATA_TYPE=mysql
		addext "mysql-metadata-storage"
		_METADATA_URI=${METADATA_URI-jdbc:mysql://$METADATA_HOST:${METADATA_PORT-3306}/${METADATA_DBNAME-druid}}
		_METADATA_USER=$METADATA_USER
		_METADATA_PASSWORD=$METADATA_PASSWORD
		if [ ! -d extensions/mysql-metadata-storage ]; then
			if [ -d /mnt/mesos/sandbox/mysql-metadata-storage ]; then
				ln -s /mnt/mesos/sandbox/mysql-metadata-storage extensions/mysql-metadata-storage
			else
				wget http://static.druid.io/artifacts/releases/mysql-metadata-storage-0.11.0.tar.gz
				tar -xzf mysql-metadata-storage-0.11.0.tar.gz -C extensions
				rm mysql-metadata-storage-0.11.0.tar.gz -f
			fi

		fi
		;;
	postgresql | postgres)
		_METADATA_TYPE=postgresql
		addext "postgresql-metadata-storage"
		_METADATA_URI=${METADATA_URI-jdbc:postgresql://$METADATA_HOST:${METADATA_PORT-5432}/${METADATA_DBNAME-druid}}
		_METADATA_USER=$METADATA_USER
		_METADATA_PASSWORD=$METADATA_PASSWORD
		;;
	derby)
		warn "Using Derby is only viable in a cluster with a single Coordinator, no fail-over. Do not use Derby on production"
		_METADATA_TYPE=derby
		_METADATA_URI=${METADATA_URI-jdbc:derby://$METADATA_HOST:${METADATA_PORT-1527}/${DERBY_DBPATH-var/druid/metadata.db};create=true}
		;;
	"")
		err "You have not set any metadata storage type. METADATA_TYPE={mysql, postgresql, derby}."
		exit 1
		;;
	*)
		err "The metadata storage type ($METADATA_TYPE) you chose is not supported. METADATA_TYPE={mysql, postgresql, derby}."
		exit 1
		;;
esac

case $STORAGE_TYPE in
	hdfs)
		_STORAGE_TYPE=hdfs
		_STORAGE_DIR=${STORAGE_DIR-/druid/segments}
		if [ ! -f $_HDFS_CONF_DIR/core-site.xml ] && [ ! -f $_HDFS_CONF_DIR/hdfs-site.xml ]; then
			err "To use HDFS as the deep storage, files core-site.xml and hdfs-site.xml are needed."
			err "These files are searched for in the directory set with variable HDFS_CONF_DIR, which defaults to /etc/hadoop/conf"
			err "Create a volume that points to the directory where the xml files are."
			exit 1
		else
			cp $_HDFS_CONF_DIR/core-site.xml $_CONF_DIR
			cp $_HDFS_CONF_DIR/hdfs-site.xml $_CONF_DIR
		fi
		;;
	s3)
		err "Not yet supported"
		exit 1
		;;
	local)
		warn "Using local segment storage is only viable in a cluster if this is a network mount"
		_STORAGE_TYPE=local
		_STORAGE_DIR=${STORAGE_DIR-var/druid/segments}
		;;
	"")
		err "You have not set any deep storage type. STORAGE_TYPE={hdfs, s3, local}"
		exit 1
		;;
	*)
		err "The deep storaget type ($STORAGE_TYPE) you chose is not supported. STORAGE_TYPE={hdfs, s3, local}"
		exit 1
		;;
esac

mv "$_CONF_FILE" "$_CONF_FILE.backup"

_DEF_CONF="druid.extensions.loadList=["
for i in $(seq 1 ${#_EXTENSIONS_LOADLIST[@]})
do
	_DEF_CONF="$_DEF_CONF\"${_EXTENSIONS_LOADLIST[$(($i - 1))]}\""
	if [ "$i" != "${#_EXTENSIONS_LOADLIST[@]}" ]; then
		_DEF_CONF="$_DEF_CONF, "
	fi
done
_DEF_CONF="$_DEF_CONF]\n\n"

addcnf "druid.zk.service.host" $_ZK_SERVICE_HOST
addcnf "druid.zk.paths.base" $_ZK_PATHS_BASE

addcnf "druid.metadata.storage.type" $_METADATA_TYPE
addcnf "druid.metadata.storage.connector.connectURI" $_METADATA_URI
addcnf "druid.metadata.storage.connector.user" $_METADATA_USER
addcnf "druid.metadata.storage.connector.password" $_METADATA_PASSWORD

addcnf "druid.storage.type" $_STORAGE_TYPE
addcnf "druid.storage.storageDirectory" $_STORAGE_DIR

addcnf "druid.startup.logging.logProperties" "true"
addcnf "druid.selectors.indexing.serviceName" "druid/overlord"
addcnf "druid.selectors.coordinator.serviceName" "druid/coordinator"
addcnf "druid.monitoring.monitors" "[\"com.metamx.metrics.JvmMonitor\"]"
addcnf "druid.emitter" "logging"
addcnf "druid.emitter.logging.logLevel" "info"
addcnf "druid.indexing.doubleStorage" "double"

mv "$_JVM_ARG_FILE" "$_JVM_ARG_FILE.backup"

addarg "-server"
addarg "-Xms$_HEAP_SIZE"
addarg "-Xmx$_HEAP_SIZE"
_MAX_DIRECT_MEMORY=$MAX_DIRECT_MEMORY
if [ "$_MAX_DIRECT_MEMORY" != "" ]; then
	addarg "-XX:MaxDirectMemorySize=$_MAX_DIRECT_MEMORY"
fi
addarg "-Duser.timezone=UTC"
addarg "-Dfile.encoding=UTF-8"
addarg "-Djava.io.tmpdir=var/tmp"
addarg "-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager"

printf "$_DEF_CONF" > "$_CONF_FILE"
printf -- "$_DEF_ARGS" > "$_JVM_ARG_FILE"
java $(cat conf/druid/$_COMP/jvm.config | xargs) -cp "conf/druid/_common:conf/druid/$_COMP:lib/*" io.druid.cli.Main server $_COMP
