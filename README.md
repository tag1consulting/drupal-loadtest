Drupal Loadtest
===============

Locust load test and support scripts for testing Drupal sites.

This locust test plan and scripts are used to test out the [Drupal Memcache module](https://drupal.org/project/memcache).

Assumptions
-----------
These scripts assume:
 1.  A Drupal installation -- webroot and database.
 2.  [Locust](http://locust.io/) installed

Running Tests
-------------
There are two scripts in the scripts/ directory: `preptest.sh` and `runtest.sh`.

The `preptest.sh` script only needs to be run once per-VM. The VM should already have a Drupal webroot setup. The script will install the devel and memcache modules (there's a configurable setting for which memcache module version to install), and then use drush devel_generate calls to generate content -- the amount of content is also configurable.

In addition, `preptest.sh` prepares the site for tests by populating it with content and configuring some settings (memcache module, user logins, etc.).

Once that is complete, it will create a database dump in /root so that the same database can be reloaded for subsequent tests.


The `runtest.sh` script restarts services (mysqld, httpd, memcached) to ensure consistency between tests. Then it runs the locust load test, copies test output data to the webroot, and outputs memcached stats from the test run into a summary report.

`runtest.sh` requires one argument, a tag which will be appended to the output directory as a test identifier.
