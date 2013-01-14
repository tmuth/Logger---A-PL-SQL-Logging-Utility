#!/cygdrive/c/cygwin/bin/bash
INSTALL="../build/logger_install.sql"
NO_OP="../build/logger_no_op.sql"

read -p "New Version Number x.x.x ?" VERSION_NUMBER
echo $VERSION_NUMBER


rm -f ../build/logger_install.sql
rm -f ../build/logger_latest.zip
rm -f ../build/logger_no_op.sql

cat logger.sql > $INSTALL
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

