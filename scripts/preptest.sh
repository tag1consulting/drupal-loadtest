#!/bin/bash
#
# Prep a base Drupal install for memcache testing.
# This assumes that $WEBDIR contains a working Drupal install.

WEBDIR=/var/www/vagrant-multi1.tag1consulting.com
MEMCACHE_SETTINGS_FILE=memcache.settings.inc
MEMCACHE_VERSION=6.x-1.11-rc1
DATABASE_NAME=vagrant

USER_COUNT=5000
CONTENT_COUNT=10000
MAX_COMMENTS=20

# Get the full directory for the memcache settings file (same dir as this script).
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MEMCACHE_SETTINGS_FILE=${DIR}/${MEMCACHE_SETTINGS_FILE}

# Create modules directory if it doesn't already exist.
mkdir -p ${WEBDIR}/sites/all/modules

# Install devel module and enable devel_generate.
drush dl devel --destination=${WEBDIR}/sites/all/modules
drush -r ${WEBDIR} -y en devel_generate

# Create content.
echo "Creating ${USER_COUNT} users, this may take a while..."
drush -r ${WEBDIR} generate-users ${USER_COUNT}
echo "Creating ${CONTENT_COUNT} nodes with up to ${MAX_COMMENTS} comments each, this may take a while..."
drush -r ${WEBDIR} generate-content ${CONTENT_COUNT} ${MAX_COMMENTS}

# Install memcache module
drush dl memcache-${MEMCACHE_VERSION} --destination=${WEBDIR}/sites/all/modules

# Add memcache configuration to settings.php
cat ${MEMCACHE_SETTINGS_FILE} >> ${WEBDIR}/sites/default/settings.php

# Update user names and passwords (sets passwords to 'supersecrettestuser').
# The CSV data for the test expects these specific usernames (e.g. 'user1', 'user2' from 1-5000).
echo "Setting Drupal usernames and passwords to those that the test expects..."
for i in $(seq 2 5001)
do
  mysql -e "UPDATE ${DATABASE_NAME}.users SET name='user${i}', pass='\$S\$DDHmqnax8wgiX9XxV5D9if52hnqvvk2O9KWVGDL1UP5mAdwGov8i' WHERE uid = ${i};"
done

echo "Updating permissions: allow anonymous to access user profiles."
# Update permissions -- the test attempts to view user profiles as an anoymous user, need to allow that.
drush -r ${WEBDIR} role-add-perm 'anonymous user' 'access user profiles'

echo "Creating a mysqldump of the drupal install with test data..."
mysqldump --single-transaction ${DATABASE_NAME} | gzip > /root/drupal_with_test_content.sql.gz
ls -lh  /root/drupal_with_test_content.sql.gz

echo "All done with test prep -- run tests using the runtest.sh script."
