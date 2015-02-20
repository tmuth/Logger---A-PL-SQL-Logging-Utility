##!/cygdrive/c/cygwin/bin/bash
#!/bin/bash

#*** PARAMETERS ***
#	$1 = VERSION_NUMBER x.x.x (ex 1.0.5)
#		This will be used to generate the release folder etc
#		OLD: #read -p "New Version Number x.x.x ?" VERSION_NUMBER

VERSION_NUMBER=$1
SQL_CONNECTION=$2

{
if [ -z "${VERSION_NUMBER}" ]; then
  echo "VERSION_NUMBER (parameter 1) is not defined"
  exit 0
fi
if [ -z "${SQL_CONNECTION}" ]; then
	echo "SQL_CONNECTION (parameter 2) is not defined"
	exit 0
fi
}

echo "Building release $VERSION_NUMBER"


#TODO testing no_ops
START_DIR="$PWD"
cd ../source/packages
sqlplus $SQL_CONNECTION @../gen_no_op.sql
cd $START_DIR


#*** VARIABLES ***
RELEASE_FOLDER=../releases/$VERSION_NUMBER
INSTALL=$RELEASE_FOLDER/"logger_install.sql"
NO_OP=$RELEASE_FOLDER/"logger_no_op.sql"


#Clear release folder (if it exists) and make directory
rm -rf ../releases/$VERSION_NUMBER
mkdir ../releases/$VERSION_NUMBER


#Build files

#rm -f ../build/logger_install.sql
#rm -f ../build/logger_latest.zip
#rm -f ../build/logger_no_op.sql

#PREINSTALL
cat ../source/install/logger_install_prereqs.sql > $INSTALL
printf '\n' >> $INSTALL

#TABLES
printf 'PROMPT tables/logger_logs.sql \n' >> $INSTALL
cat ../source/tables/logger_logs.sql >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT tables/logger_prefs.sql \n' >> $INSTALL
cat ../source/tables/logger_prefs.sql >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT tables/logger_logs_apex_items.sql \n' >> $INSTALL
cat ../source/tables/logger_logs_apex_items.sql >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT tables/logger_prefs_by_client_id.sql \n' >> $INSTALL
cat ../source/tables/logger_prefs_by_client_id.sql >> $INSTALL
printf '\n' >> $INSTALL


#CONTEXTS
printf 'PROMPT contexts/logger_context.sql \n' >> $INSTALL
cat ../source/contexts/logger_context.sql >> $INSTALL
printf '\n' >> $INSTALL

#JOBS
printf 'PROMPT jobs/logger_purge_job.sql \n' >> $INSTALL
cat ../source/jobs/logger_purge_job.sql >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT jobs/logger_unset_prefs_by_client.sql \n' >> $INSTALL
cat ../source/jobs/logger_unset_prefs_by_client.sql >> $INSTALL
printf '\n' >> $INSTALL

#VIEWS
printf 'PROMPT views/logger_logs_5_min.sql \n' >> $INSTALL
cat ../source/views/logger_logs_5_min.sql >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT views/logger_logs_60_min.sql \n' >> $INSTALL
cat ../source/views/logger_logs_60_min.sql >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT views/logger_logs_terse.sql\n' >> $INSTALL
cat ../source/views/logger_logs_terse.sql >> $INSTALL
printf '\n' >> $INSTALL

#PACKAGES
printf 'PROMPT packages/logger.pks \n' >> $INSTALL
cat ../source/packages/logger.pks >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT packages/logger.pkb \n' >> $INSTALL
cat ../source/packages/logger.pkb >> $INSTALL
printf '\n' >> $INSTALL


#PROCEDURES
printf 'PROMPT procedures/logger_configure.sql \n' >> $INSTALL
cat ../source/procedures/logger_configure.sql >> $INSTALL
printf '\n' >> $INSTALL


#Post install
printf 'PROMPT install/post_install_configuration.sql \n' >> $INSTALL
cat ../source/install/post_install_configuration.sql >> $INSTALL
printf '\n' >> $INSTALL



#NO OP Code
printf "\x2d\x2d This file installs a NO-OP version of the logger package that has all of the same procedures and functions,\n" > $NO_OP

#TODO mdsouza: use gen_no_op.sql to build this
printf "\x2d\x2d This file installs a NO-OP version of the logger package that has all of the same procedures and functions,\n " > $NO_OP

printf "\x2d\x2d but does not actually write to any tables. Additionally, it has no other object dependencies.\n" >> $NO_OP
printf "\x2d\x2d You can review the documentation at https://logger.samplecode.oracle.com/ for more information.\n" >> $NO_OP
printf '\n' >> $NO_OP
cat ../source/packages/logger.pks >> $NO_OP
printf '\n' >> $NO_OP
cat ../source/packages/logger_no_op.pkb >> $NO_OP
printf '\n\nprompt\n' >> $NO_OP
printf 'prompt *************************************************\n' >> $NO_OP
printf 'prompt Now executing LOGGER.STATUS...\n' >> $NO_OP
printf 'prompt ' >> $NO_OP
printf '\nbegin \n\tlogger.status; \nend;\n/\n\n' >> $NO_OP
printf 'prompt *************************************************\n' >> $NO_OP
printf '\n\n' >> $NO_OP



#Copy "other" scripts
cp -f ../source/install/create_user.sql $RELEASE_FOLDER
cp -f ../source/install/drop_logger.sql $RELEASE_FOLDER

#Copy main package file for developers to easily review
cp -f ../source/packages/logger.* $RELEASE_FOLDER

#Copy README
cp -f ../README.md $RELEASE_FOLDER

#Copy demo scripts
cp -fr ../demos $RELEASE_FOLDER


chmod 777 $RELEASE_FOLDER/*.*


#Replace any references for the version number
sed -i.del "s/x\.x\.x/$VERSION_NUMBER/g" $RELEASE_FOLDER/logger_install.sql
sed -i.del "s/x\.x\.x/$VERSION_NUMBER/g" $RELEASE_FOLDER/logger.pks
#need to remove the backup file required for sed call
rm -rf $RELEASE_FOLDER/*.del



#By CDing into the release_folder we don't get the full path in the zip file
cd $RELEASE_FOLDER
zip -r logger_$VERSION_NUMBER.zip .
