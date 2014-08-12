Cloudera Search: Apache Solr in the “Data Hub”
==============================================

This project contains all the files needed to my demo at BigDataUtah on Aust 13th, 2014. This README is a walk-through of the demo. This is not expected to be useful outside the context of that presentation, for which the slides are included.

The files under search-samples are taken from Cloudera Search, as included in CDH 5.1.0. They are redistributed under the terms of the Apache Software Licence, version 2.0. The original files can be found here:

    http://github.mtv.cloudera.com/CDH/search/raw/cdh5-1.0.0_5.1.0/samples/solr-nrt/collection1/conf/schema.xml
    http://github.mtv.cloudera.com/CDH/search/raw/cdh5-1.0.0_5.1.0/samples/solr-nrt/test-morphlines/tutorialReadAvroContainer.conf
    http://github.mtv.cloudera.com/CDH/search/raw/cdh5-1.0.0_5.1.0/samples/solr-nrt/twitter-flume.conf
    http://github.mtv.cloudera.com/CDH/search/raw/cdh5-1.0.0_5.1.0/samples/test-documents/sample-statuses-20120906-141433.avro
    http://github.mtv.cloudera.com/CDH/search/raw/cdh5-1.0.0_5.1.0/samples/test-documents/sample-statuses-20120906-141433-medium.avro
    http://github.mtv.cloudera.com/CDH/search/raw/cdh5-1.0.0_5.1.0/NOTICE.txt

Other files in this repository were created for this demo and are redistributable under the same license.

Creating a Solr Collection
--------------------------

For all 3 data sources below, the process for creating a collection in Solr will be the same. First, set the name of the collection in a variable:

    COLLECTION_NAME=example_tweets

Next, create a skeleton configuration:

    solrctl instancedir --generate ~/${COLLECTION_NAME}_configs

Replace the initial schema definition with one for tweets:

    cp -f search-samples/schema.xml ~/${COLLECTION_NAME}_configs/conf/

Upload the configuration to ZooKeeper:

    solrctl instancedir --create ${COLLECTION_NAME} ~/${COLLECTION_NAME}_configs

And finally, create the collection in Solr:

    solrctl collection --create ${COLLECTION_NAME} -s 1

Searching in Hue
----------------

Once a collection has been created, dashboards can be created in Hue's Search app to either display the results of various searches, or as an interface to interactive searching. Some read-only dashboards have been set up, and you can install these examples here:

    http://quickstart.cloudera:8888/about/#step2

After each collection is created below, create a new dashboard using the single-frame layout. Drag an HTML element to the frame, and add the following to the HTML editor:

    <div class="row-fluid">
        <div class="row-fluid">
            <div class="row-fluid">
            <div class="span1">
                <img src="http://twitter.com/api/users/profile_image/{{user_screen_name}}" class="avatar" />
            </div>
            <div class="span11">
                <a href="https://twitter.com/{{user_screen_name}}/status/{{id}}" class="btn openTweet">
                <i class="icon-twitter"></i>
                </a>
                <b>{{user_name}}</b>
                <br />
                {{text}}
                <br />
                <div class="created">{{#fromnow}}{{created_at}}{{/fromnow}}</div>
            </div>
            </div>
            <br />
        </div>
    </div>

Add the following to the CSS / JavaScript editor:

    <style type="text/css">

        em {
            font-weight: bold;
            background-color: yellow;
        }

        .avatar {
            margin: 10px;
        }

        .created {
            margin-top: 10px;
            color: #CCC;
        }

        .openTweet {
            float: right;
            margin: 10px;
        }

    </style>

Reload the dashboard, and you will be able to search for words in the indexed tweets, with the matching portion of each record highlighted, and the relevant account image retrieved from Twitter.

Indexing in MapReduce
---------------------

Create a collection (using the process described above):

    COLLECTION_NAME=mapreduce_tweets

Load the tweets into HDFS (these tweets are just a numerical sequence):

    hadoop fs -mkdir -p /user/cloudera/mapreduce_tweets_indir
    hadoop fs -copyFromLocal search-samples/sample-statuses-*.avro /user/cloudera/mapreduce_tweets_indir/

Launch the MapReduce job to index the tweets:

    hadoop --config /etc/hadoop/conf jar /usr/lib/solr/contrib/mr/search-mr-*-job.jar \
        org.apache.solr.hadoop.MapReduceIndexerTool \
        -D 'mapred.child.java.opts=-Xmx500m' \
        --log4j search-samples/log4j.properties \
        --morphline-file search-samples/tutorialReadAvroContainer.conf \
        --output-dir hdfs://quickstart.cloudera:8020/user/cloudera/mapreduce_tweets_outdir \
        --verbose --go-live \
        --zk-host quickstart.cloudera:2181/solr \
        --collection ${COLLECTION_NAME} \
        hdfs://quickstart.cloudera:8020/user/cloudera/mapreduce_tweets_indir

Create a dashboard for this collection in Hue, and you will see the sequence.

Indexing in Flume
-----------------

Create a collection (using the process described above):

    COLLECTION_NAME=flume_tweets

Copy the collection's configuration to flume:

    sudo cp -r /home/cloudera/${COLLECTION_NAME}_configs /etc/flume-ng/conf/${COLLECTION_NAME}

Configure Flume to use Twitter as a data source, and "sink" the events into Solr through Morphlines as Avro records:

    sudo cp search-samples/twitter-flume.conf /etc/flume-ng/conf/flume.conf
    sudo cp search-samples/tutorialReadAvroContainer.conf /etc/flume-ng/conf/morphline.conf
    sudo sed -i -e "s#collection1#${COLLECTION_NAME}#" /etc/flume-ng/conf/morphline.conf

And another tweak to the default Flume configuration to point it at our Solr server:

    sudo cp /etc/flume-ng/conf/flume-env.sh.template /etc/flume-ng/conf/flume-env.sh
    JAVA_OPTS='JAVA_OPTS="-Xmx500m -Dsolr.host=quickstart.cloudera"'
    sudo bash -c "echo '${JAVA_OPTS}' >> /etc/flume-ng/conf/flume-env.sh"

Replace the agent.sources.twitterSrc.\* properties in Flume's configuration with API keys from a Twitter Developer account:

    sudo vim /etc/flume-ng/conf/flume.conf

Ensure the system clock is synchronized properly (required for Twitter authentication):

    sudo ntpdate pool.ntp.org
    # or...
    sudo service ntpd start

And start the Flume agent:

    sudo service flume-ng-agent start

Once the agent has started, you will be able to see it looking the number of "tweet" documents indexed:

    tail -f /var/log/flume-ng/flume.log

Indexing in HBase
-----------------

Create a collection (using the process described above):

    COLLECTION_NAME=hbase_tweets

Enable replication in HBase:

    sudo cp -f hbase-site.xml /etc/hbase/conf/hbase-site.xml
    for role in master regionserver; do sudo service hbase-${role} restart; done

Create the HBase table to index:

    $ hbase shell
    hbase> create 'tweets',
        { NAME => 'tweet', REPLICATION_SCOPE => '1' },
        { NAME => 'user', REPLICATION_SCOPE => '1' }

Start the HBase indexer service:

    sudo service hbase-solr-indexer start

Create an indexer:

    hbase-indexer add-indexer -n ${COLLECTION_NAME}_indexer -c hbase-indexer.xml -cp solr.zk=localhost:2181/solr -cp solr.collection=${COLLECTION_NAME}

Use the Hue HBase app to add rows, update existing rows, and delete rows. Updates should propagate to Solr immediately. Example tweet:

| Field                   | Value                            |
| ----------------------- |:--------------------------------:|
| Row ID                  | 1                                |
| tweet:id                | 123456789                        |
| tweet:created\_at       | 2014-08-13T18:45:00Z             |
| tweet:text              | @BigDataUtah I'm tweeting at you |
| user:user\_name         | SeanMackrory                     |
| user:user\_screen\_name | SeanMackrory                     |

Securing Data in Sentry
-----------------------

Using Sentry for authorization in Solr requires the cluster to be configured with Kerberos authentication. The details of Kerberos are outside the scope of this demo, and using Cloudera Manager to configure the cluster to use Kerberos is significantly faster and more reliable, so we'll take that approach.

Some of the encryption used by Kerberos will require the Unlimited JCE Policy files for JDK 7 from Oracle. Download them to /home/cloudera/Downloads from this site after accepting the terms:

    http://www.oracle.com/technetwork/java/javase/downloads/jce-7-download-432124.html

Install and configure Kerberos, set the root password and create a principal for Cloudera Manager to use, then start the Kerberos services:

    sudo ./kerberos.sh

    kdb5_util create -s                            # provide 'cloudera' as the password
    kadmin.local -q "addprinc cloudera-scm/admin"  # provide 'cloudera' as the password

    service krb5kdc start
    service kadmin start

Navigate to the 'Cloudera Manager' bookmark in Firefox and follow the directions on the page. In short, ensure the VM has 8 GB of RAM, then invoke the 'Launch Cloudera Manager' shortcut on the desktop. When prompted, login with the credentials cloudera / cloudera.

Using the drop-down menu on the "Cloudera QuickStart" cluster, stop all services, and then enable CM. Ignore the Active Directory settings, and specify "quickstart.cloudera" as the host, "CLOUDERA" as the realm, and "cloudera-scm/admin@CLOUDERA" as the principal, and "cloudera" as the password. Then follow the prompts to restart the cluster.

Create the users and their UNIX groups for the example. In Hue's "Manage User's" app, create the same users as well as an 'hdfs' user):

    sudo useradd restricted
    sudo passwd restricted

    sudo groupadd admins
    sudo groupadd users

    sudo usermod -G admins cloudera
    sudo usermod -G users restricted

Using Hue's File Manager application, upload sentry-provider.ini to /user/solr/sentry/ and chown /user/solr to solr:solr recursively.

In Cloudera Manager, open the configuration for the Solr Service and check the box to enable Sentry authorization, and accept the other defaults. Restart the service.

In addition to configuring Kerberos, Cloudera Manager will modify Solr's environment as follows (you can set these in /etc/default/solr if you are using CDH without Cloudera Manager):

    SOLR_SENTRY_ENABLED=true
    SOLR_AUTHORIZATION_SENTRY_SITE=/path/to/sentry-site.xml
    SOLR_AUTHORIZATION_SUPERUSER=solr
    SOLR_AUTHENTICATION_TYPE=kerberos # and other Kerberos configuration

It will also include the following in Solr's configuration (which can be included in /etc/solr/conf/sentry-site.xml if you are using CDH without Cloudera Manager):

    <property>
        <name>sentry.provider</name>
        <value>org.apache.sentry.provider.file.HadoopGroupResourceAuthorizationProvider</value>
    </property>

Log in to Hue as both the 'cloudera' user and the 'restricted' user, and see what collections can be queried.

