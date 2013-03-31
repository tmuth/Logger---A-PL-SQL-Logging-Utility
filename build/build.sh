#!/cygdrive/c/cygwin/bin/bash
#!/bin/bash

#*** PARAMETERS ***
#	$1 = VERSION_NUMBER x.x.x (ex 1.0.5)
#		This will be used to generate the release folder etc
#		OLD: #read -p "New Version Number x.x.x ?" VERSION_NUMBER

VERSION_NUMBER=$1


{
if [ -z "${VERSION_NUMBER}" ]; then 
	echo "VERSION_NUMBER (parameter 1) is not defined"
	exit 0
fi
}

echo "Building release $VERSION_NUMBER"



#*** VARIABLES ***
INSTALL="logger_install.sql"
NO_OP="logger_no_op.sql"


#Clear release folder (if it exists) and make directory
rm -rf ../releases/$VERSION_NUMBER
mkdir ../releases/$VERSION_NUMBER


#Build files

#rm -f ../build/logger_install.sql
#rm -f ../build/logger_latest.zip
#rm -f ../build/logger_no_op.sql

#TODO sort out the tables etc
cat logger.sql > $INSTALL
printf '\n' >> $INSTALL

#TABLES
cat ../source/tables/logger_logs.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/tables/logger_prefs.sql >> $INSTALL
printf '\n' >> $INSTALL


#CONTEXTS
cat ../source/contexts/logger_context.sql >> $INSTALL
printf '\n' >> $INSTALL

#JOBS
cat ../source/jobs/logger_purge_job.sql >> $INSTALL
printf '\n' >> $INSTALL

#VIEWS
cat ../source/views/logger_logs_5_min.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/views/logger_logs_60_min.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/views/logger_logs_terse.sql >> $INSTALL
printf '\n' >> $INSTALL


cat logger.pks >> $INSTALL
printf '\n' >> $INSTALL
cat logger.pkb >> $INSTALL
printf '\n' >> $INSTALL
cat logger_configure.sql >> $INSTALL
printf '\n\nbegin \n\tlogger_configure; \n end;\n/\n\n' >> $INSTALL
printf "begin \n\tlogger.set_level('DEBUG'); \nend;\n/\n\n" >> $INSTALL
printf 'prompt \n'  >> $INSTALL
printf 'prompt ************************************************* \n'  >> $INSTALL
printf 'prompt Now executing LOGGER.STATUS...\n'  >> $INSTALL
printf 'prompt \n'  >> $INSTALL
printf '\nbegin \n\tlogger.status; \nend;\n/\n\n' >> $INSTALL
printf 'prompt ************************************************* \n'  >> $INSTALL
printf "begin \n\tlogger.log_permanent('Logger version '||logger.get_pref('LOGGER_VERSION')||' installed.'); \nend;\n/\n\n" >> $INSTALL
printf '\n\n' >> $INSTALL


printf "\x2d\x2d This file installs a NO-OP version of the logger package that has all of the same procedures and functions,\n " > $NO_OP
printf "\x2d\x2d but does not actually write to any tables. Additionally, it has no other object dependencies.\n" >> $NO_OP
printf "\x2d\x2d You can review the documentation at https://logger.samplecode.oracle.com/ for more information.\n" >> $NO_OP
printf '\n' >> $NO_OP
cat logger.pks >> $NO_OP
printf '\n' >> $NO_OP
cat logger_no_op.pkb >> $NO_OP
printf '\n\nprompt\n' >> $NO_OP
printf 'prompt *************************************************\n' >> $NO_OP
printf 'prompt Now executing LOGGER.STATUS...\n' >> $NO_OP
printf 'prompt ' >> $NO_OP
printf '\nbegin \n\tlogger.status; \nend;\n/\n\n' >> $NO_OP
printf 'prompt *************************************************\n' >> $NO_OP
printf '\n\n' >> $NO_OP


cp -f drop_logger.sql ../build/
cp -f create_user.sql ../build/

sed -i "s/tags\/[0-9]\.[0-9]\.[0-9]\/logger_[0-9]\.[0-9]\.[0-9].zip/tags\/$VERSION_NUMBER\/logger_$VERSION_NUMBER\.zip/g" ../www/index.html
cp -f ../www/index.html ../build/readme.html

chmod 777 ../build/*.*

sed -i "s/x\.x\.x/$VERSION_NUMBER/g" ../build/logger_install.sql


7za a -tzip ../build/logger_$VERSION_NUMBER.zip ../build/*.sql ../build/*.html

