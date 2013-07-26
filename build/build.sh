##!/cygdrive/c/cygwin/bin/bash
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
cat ../source/tables/logger_logs.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/tables/logger_prefs.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/tables/logger_logs_apex_items.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/tables/logger_prefs_by_client_id.sql >> $INSTALL
printf '\n' >> $INSTALL


#CONTEXTS
cat ../source/contexts/logger_context.sql >> $INSTALL
printf '\n' >> $INSTALL

#JOBS
cat ../source/jobs/logger_purge_job.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/jobs/logger_unset_prefs_by_client.sql >> $INSTALL
printf '\n' >> $INSTALL

#VIEWS
cat ../source/views/logger_logs_5_min.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/views/logger_logs_60_min.sql >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/views/logger_logs_terse.sql >> $INSTALL
printf '\n' >> $INSTALL

#PACKAGES
cat ../source/packages/logger.pks >> $INSTALL
printf '\n' >> $INSTALL
cat ../source/packages/logger.pkb >> $INSTALL
printf '\n' >> $INSTALL


#PROCEDURES
cat ../source/procedures/logger_configure.sql >> $INSTALL
printf '\n' >> $INSTALL


#Post install
cat ../source/install/post_install_configuration.sql >> $INSTALL
printf '\n' >> $INSTALL



#NO OP Code
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

#Copy wiki documents
mkdir $RELEASE_FOLDER/wiki
# This is assuming that the wiki directory exists in the same location as the main folder (i.e. same parent)
cp -f ../../Logger---A-PL-SQL-Logging-Utility.wiki/* $RELEASE_FOLDER/wiki/

#sed -i "s/tags\/[0-9]\.[0-9]\.[0-9]\/logger_[0-9]\.[0-9]\.[0-9].zip/tags\/$VERSION_NUMBER\/logger_$VERSION_NUMBER\.zip/g" ../www/index.html
#cp -f ../www/index.html ../build/readme.html
#Generate readme.html
#Using https://github.com/evilstreak/markdown-js to convert Markdown (.md) file to html
#To install: npm install -g markdown
#MD: I've taken this out since it wasn't converting very well
#md2html ../README.md > $RELEASE_FOLDER/readme.html

chmod 777 $RELEASE_FOLDER/*.*

#Replace any references for the version number
sed -i.del "s/x\.x\.x/$VERSION_NUMBER/g" $RELEASE_FOLDER/logger_install.sql
sed -i.del "s/x\.x\.x/$VERSION_NUMBER/g" $RELEASE_FOLDER/logger.pks
#need to remove the backup file required for sed call
rm -rf $RELEASE_FOLDER/*.del 



#Old windows zip7za a -tzip $/logger_$VERSION_NUMBER.zip ../build/*.sql ../build/*.html
zip -r -j $RELEASE_FOLDER/logger_$VERSION_NUMBER.zip $RELEASE_FOLDER

