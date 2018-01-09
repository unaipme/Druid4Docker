# Druid

Druid is an open-source data store designed for sub-second queries on real-time and historical data. It is primarily used for business intelligence (OLAP) queries on event data. Druid provides low latency (real-time) data ingestion, flexible data exploration, and fast data aggregation. Existing Druid deployments have scaled to trillions of events and petabytes of data. Druid is most commonly used to power user-facing analytic applications.

## Building the image

Clone the repository and run the following command from directory `druid/`:

```bash
docker build -t druid .
```

## Running a container

The same image is used to run all the components that form a Druid cluster, in a one-per-container fashion. Those components are the historical node, the broker node, the coordinator node, the overlord node and the middle manager node. To find out how the architecture works and which are the functions of each component, read the [druid documentation](http://druid.io/docs/0.11.0/design/design.html).

The container configuration is done by defining environmental variables. Druid configuration files are generated with the information passed to the container via these environmental variables. The list of availables variables is the following (the required ones are in bold):

* __DRUID_COMPONENT__: The component to run on the container. To choose between: `{historical, broker, coordinator, overlord, middleManager}`.
* __ZK_SERVICE_HOST__: The host(s) and port on which Zookeeper runs, if more than one, separated by commas, like in the example: `172.16.8.19:2181,172.16.8.20:2181`.
* ZK_PATHS_BASE: Zookeeper base _znode_ path, defaults to `/druid`.
* __METADATA_URI__: Whole URI to the metadata storage to use. Must follow pattern `jdbc:<db_type>://<db_host>:<db_port>/<db_name>[?options...]`. All of the parameters in the URI pattern can be, instead, individually set. In that case, this variable won't be required. They can be set as listed below:
  * __METADATA_TYPE__: Write the storage type to use for metadata. To choose between: `{mysql, [postgresql | postgres], derby}`. If MySQL is chosen, the required extension will be downloaded automatically.
  * __METADATA_HOST__: Host of the database.
  * METADATA_PORT: Port on which the database listens. Each database type has its own default value. For MySQL, it's 3306; for PostgreSQL, it's 5432; for Derby, 1527.
  * METADATA_DBNAME: Name of the database on which to store. Defaults to `druid`.
* __METADATA_USER__: Username with which to connect to the database.
* __METADATA_PASSWORD__: Password of the username previously defined.
* __STORAGE_TYPE__: Deep storage type in which to store the segments. To choose between: `{hdfs, s3, local}`. S3 is still not supported by this image and local storage is not recommended for production, though. If HDFS is chosen, the following configuration must also be provided:
  * HDFS_CONF_DIR: Druid needs to know about the Hadoop cluster. To do so, it requires the `core-site.xml` and `hdfs-site.xml` files to be in the configuration directory. For this Docker image, that can be managed by using a volume. Mount the directory in which the two files are as a volume and optionally set this variable to the directory inside the container to which the volume was mounted. Defaults to `/etc/hadoop/conf`.

Run the container with the following command:

```bash
docker run -d [-e <configuration key>=<value> [-e ...]] [-v /path/to/hadoop/conf:/etc/hadoop/conf] --name <container name> -p <host port>:<component port> druid
```

`-d` means that the container will run detached from the console. If, instead, you want to see the logs on the console, use `-it`. But if you close the console or press ctrl+c, the docker will stop.
`-e` is used to set an environmental variable. Use this to define the configuration with the variable names listed above.
`-v` is used to mount a volume. If HDFS will be the deep storage, you need to mount the directory with the HDFS configuration files to the container's `/etc/hadoop/conf` directory.
`--name` gives a name to the container. The recommendation is to give the container the same name as the Druid component it's running.
`-p` exposes a port and binds it to one port of the host. If you use `-P` instead, all ports mentioned in the Dockerfile will be exposed. This is not recommended though, because ports that will never be used (and moreover can cause trouble) will be open to the public. Check the list below to know what ports to expose depending on component you are running.
* The __coordinator__ uses port 8081.
* The __broker__ uses port 8082.
* The __historical__ uses port 8083.
* The __overlord__ uses port 8090.
* The __middle manager__ uses the port 8091 at all times, and its peons use ports in range 8100-8199.

If anything's wrong with the configuration, the log will let you know.

