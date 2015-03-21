***This document is best viewed in [flatdoc format](http://oraopensource.github.io/flatdoc?repo=logger&path=docs%2FDevelopment+Guide.md)***
#Logger Developer Guide
This document describes how to develop and build Logger. 

#Developing
When developing with Logger you should work on the main source files, but never in the `releases` folder. The content in there is automatically generated as part of the [build process](#build-process).

##Conditional Compilation	
Logger uses [conditional compilation](http://docs.oracle.com/cd/E11882_01/appdev.112/e25519/fundamentals.htm#LNPLS00210) to enable/disable features. It is highly recommended that you understand how conditional compilation works before working on Logger.

When installing Logger, the `plsql_ccflags` are automatically defined in the `logger_configure` procedure. It is not reasonable to constantly run `logger_configure` after each change to the source code.

An easy way to control the `plsql_ccflags` is manually set them in your current session. This will allow you to quickly test various situations. The following is an example of how to set your session's conditional compilation flags: 

```sql
alter session set plsql_ccflags = 'no_op:false, logger_debug:true, APEX:true, logger_plugin_error: true';
```

##Tables
Logger has one installation script that will either update or install Logger. Because of this notion, any changes to tables must assume that the user can re-run the build script at any time and it will not fail.

A good example of this, is when adding a new column to a table. The script will check if that column exists. The column will be created only if it does not currently exist.

###$$logger_debug PLSQL_CCFLAG
They're some times when you want to debug some code in Logger. There is a catch since you may not want to use Logger to test. Instead, you can add `dbms_output.put_line` statements. If you do add any debug code be sure to wrap in the conditional compilation flag `logger_debug`. Example:

```sql
...

$if $$logger_debug $then
  dbms_output.put_line('testing...');
$end
...
```

###$$no_op
Logger supports the concept of a `no_op` build. For various reasons, primarily performance releated, you may not want to run Logger on a production system. The `no_op` version allows all the references to Logger however nothing will be executed since each method either returns a minimal result or the procedure is just one `null;` statement.

If developing a new method you must support the `no_op` conditional compilation flag. For examples, look at any of the existing methods.

When [building](#build-process) a version of logger the `logger_no_op.pkb` installation file will automatically be generated based on the results of the `no_op` conditional compilation flag.

The generated version of `logger_no_op.pkb` is stored in `source/packages/` and then the build script copies the file over to the `releases` folder as part of the build. There is no need to commit `logger_no_op.pkb` to Git for version control. By default there is a reference to `source/packages/logger_no_op.pkb` in the `.gitignore` file to ignore this from Git checkins.


##Issues
Unless an change is very small, please register an [issue](https://github.com/OraOpenSource/Logger/issues) for it in Github. This way it is easy to reference this issue in the code and we can keep track of all the features in a given release.


##Testing
We plan to implement a test suite in the future which each build must pass in order to be certified.

<a href="build-process"></a>
#Building Logger
Logger has a build script which will take all the source files and merge them into installation files in the `releases` folder. The following demonstrates how to build Logger:

```bash
#The build script assumes that you run it directly in its folder
cd Logger/build

#This will create version 3.0.0 and create a 3.0.0 release folder
#More on parameters below
./build.sh 3.0.0 giffy/giffy@localhost:1521/xe Y

```

`build.sh` has a few parameters: `./build.sh <version> <connection> <optional: include_release_folder (Y/N)>`

- **Version**: Logger uses [Semantic Versioning](http://semver.org/) that follows the `major.minor.patch` numbering system.
- **Connection**: connection string to database that current version is installed on.
  - This is required to generate the `logger_no_op` package.
- **Include release folder**: When set to Y, this optional Y/N paramter will create a folder in the `releases` folder with the contents of the release. This is useful when testing builds to see what is included in the `.zip` files.
  - You should not commit these subfolders into git as their contents are already found in the `.zip` files.
