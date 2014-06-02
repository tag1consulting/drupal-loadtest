#!/bin/bash

# Pass the script a tag to identify this testrun (e.g. memcache module version being tested)
TAG=$1

if [ "$TAG" == "" ]
then
  echo "You must pass a tag to the script -- will be appeneded to the output directory for this test."
  exit 1
fi

DATE=`date +%d-%m-%y--%H:%M:%S-$TAG`
BASEDIR="/root/jmeter"
WEBROOT="/var/www/html"
OUTPUT="$BASEDIR/output"
DEST="$WEBROOT/$DATE"
SECONDS=300
IPADDR=$(/sbin/ifconfig eth0 | /bin/grep 'inet addr' | /bin/cut -d':' -f 2 | /bin/cut -d' ' -f 1)
# This is output by preptest.sh...
SQL_DUMP=/root/drupal_with_test_content.sql.gz
DB_NAME=drupal

# Load the database into MySQL so each test starts with the same base data.
echo "Reloading DB, this will likely take a few minutes..."
mysql -e "DROP DATABASE $DB_NAME"
mysql -e "CREATE DATABASE $DB_NAME"
gunzip -c $SQL_DUMP | mysql $DB_NAME

/sbin/service mysqld restart
/sbin/service httpd restart
/sbin/service memcached restart

/usr/local/jmeter/bin/jmeter -n -t ${BASEDIR}/loadtest.jmx -j $BASEDIR/jmeter.log
mv "$BASEDIR/jmeter.log" $OUTPUT
mv $OUTPUT $DEST
rm -f "$WEBROOT/latest"
ln -s $DEST "$WEBROOT/latest"
# Add .htaccess to override Drupal's default of disabling indexes.
echo "Options +Indexes" > $WEBROOT/latest/.htaccess
echo 'stats' | nc localhost 11211 > "$WEBROOT/latest/memcached.stats.txt"

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

C20x=`grep "rc=\"20" "$WEBROOT/latest/all_queries.jtl" | wc -l` >> $SUMMARY 2>&1
C200=`grep "rc=\"200" "$WEBROOT/latest/all_queries.jtl" | wc -l` >> $SUMMARY 2>&1
C30x=`grep "rc=\"30" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
C302=`grep "rc=\"302" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
C40x=`grep "rc=\"40" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
C50x=`grep "rc=\"50" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
TOTAL=`expr $C20x + $C30x + $C40x + $C50x` >> $SUMMARY 2>&1
RATE=`echo "scale=2;$TOTAL / $SECONDS" | bc` >> $SUMMARY 2>&1

echo "\"Pages per second\"	$RATE" >> $SUMMARY 2>&1
echo >> $SUMMARY 2>&1

echo "\"HTTP status 20x Success\"	$C20x" >> $SUMMARY 2>&1
echo "\"HTTP status 30x Redirection\"	$C30x" >> $SUMMARY 2>&1
echo "\"HTTP status 40x Client Error\"	$C40x" >> $SUMMARY 2>&1
echo "\"HTTP status 50x Server Error\"	$C50x" >> $SUMMARY 2>&1
echo >> $SUMMARY 2>&1

echo "\"HTTP status 200 OK\"	$C200" >> $SUMMARY 2>&1
echo "\"HTTP status 302 Found\"	$C302" >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

cat $SUMMARY

echo "Complete results can be found in $WEBROOT/latest."
echo "Or at http://$IPADDR/$DATE"
echo "TSV-formatted summary at http://$IPADDR/$DATE/summary.tsv"
