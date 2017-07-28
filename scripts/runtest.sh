#!/usr/bin/env bash

# Pass the script a tag to identify this testrun (e.g. memcache module version being tested)
TAG=$1

if [ "$TAG" == "" ]
then
  echo "You must pass a tag to the script -- will be appeneded to the output directory for this test."
  exit 1
fi

DOMAIN="http://loadtest.dev"

LOCUST=/usr/local/bin/locust
LOCUST_PLAN=/root/drupal-loadtest/locust_testplan.py

RESTART_MYSQL="/usr/local/etc/rc.d/mysql-server restart"
RESTART_APACHE="service apache24 restart"
RESTART_MEMCACHED="service memcached restart"

USERS=100
RAMPUP=10
REQUESTS=50000

DATE=`date +%d-%m-%y--%H:%M:%S-$TAG`
WEBROOT="/var/www/html"
OUTPUT="$WEBROOT/$DATE"

mkdir $OUTPUT

NC="/usr/bin/nc -N"

IPADDR="ConfigureMe"

# This is output by preptest.sh...
SQL_DUMP=/root/drupal_with_test_content.sql.gz
DB_NAME=drupal6loadtest

# Load the database into MySQL so each test starts with the same base data.
echo "Reloading DB, this will likely take a few minutes..."
mysql -e "DROP DATABASE $DB_NAME"
mysql -e "CREATE DATABASE $DB_NAME"
gunzip -c $SQL_DUMP | mysql $DB_NAME

$RESTART_MYSQL 2>&1 > $OUTPUT/mysql_restart.log
$RESTART_APACHE 2>&1 > $OUTPUT/apache_restart.log
$RESTART_MEMCACHED 2>&1 > $OUTPUT/memcached_restart.log

# Run loadtest
$LOCUST -f $LOCUST_PLAN --host=$DOMAIN --no-web -c $USERS -r $RAMPUP -n $REQUESTS --only-summary --logfile=$OUTPUT/locust.txt

rm -f "$WEBROOT/latest"
ln -s $OUTPUT "$WEBROOT/latest"

# Add .htaccess to override Drupal's default of disabling indexes.
echo "Options +Indexes" > $WEBROOT/latest/.htaccess
echo 'stats' | $NC localhost 11211 > "$WEBROOT/latest/memcached.stats.txt"

SUMMARY="$WEBROOT/latest/summary.tsv"

grep "STAT total_connections" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' > $SUMMARY 2>&1
grep "STAT cmd_get" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT cmd_set" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT get_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT get_misses" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT delete_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT delete_misses" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT incr_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT bytes_read" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT bytes_written" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT evictions" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT total_items" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

GETS=`grep "STAT cmd_get" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
HITS=`grep "STAT get_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
MISSES=`grep "STAT get_misses" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
RATE=`echo "scale=4;$HITS / $GETS * 100" | bc` >> $SUMMARY 2>&1
echo "\"Hit rate\"	$RATE%" >> $SUMMARY 2>&1
RATE=`echo "scale=4;$MISSES / $GETS * 100" | bc` >> $SUMMARY 2>&1
echo "\"Miss rate\"	$RATE%" >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

echo $OUTPUT/locust.txt >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

cat $SUMMARY

echo "Complete results can be found in $WEBROOT/latest."
echo "Or at http://$IPADDR/$DATE"
echo "TSV-formatted summary at http://$IPADDR/$DATE/summary.tsv"
