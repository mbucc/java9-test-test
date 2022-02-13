February 12, 2022

Java Test Test
======================

Questions
----------
1. How to test module code that is not exported by the module?
2. How to set this up so IntelliJ works as expected?
3. Is Maven really that much slower than a Makefile?

Answers
-------

**How to test module code that is not exported by the module?**

**How to set this up so IntelliJ works as expected?**

1. Create file layout on disk.
2. Open project in intellij.
3. Open Project Structure (⌘ ;):
    * Remove src/test/com.example from java-test-test Intellij module
    * com.example Intellij module: change src/main/com.example from test to sources
    * com.example Intellij module: add src/test/com.example as test
1. Copy junit-platform-console-standalone-1.8.2.jar into testlib
2. Open Project Structure:
    * Open Libraries (under project settings)
    * Add Java library
    * Pick junit jar
    * Add to com.example module
    * Click OK

Open the TestUtil and you can now run the test from IntelliJ.


**Is Maven really that much slower than a Makefile?**

* make: 1.32 seconds
* surefire: I gave up.

Despite lots of examples on the web with a variety of approaches, I could
not get this to work.  See maven branch for the last failed attempt.

* [Using Java Modularity (JPMS) in Tests](https://maven.apache.org/surefire/maven-surefire-plugin/examples/jpms.html). Use module-info in test directory.
* [Java 9 + maven + junit: does test code need module-info.java of its own and where to put it?](https://stackoverflow.com/questions/46613214/java-9-maven-junit-does-test-code-need-module-info-java-of-its-own-and-wher/46613986)  Do not use a module info.
* [Run Tests from a different module](https://gist.github.com/aslakknutsen/1081397): use `testClassesDirectory`
* [Testing in a Modular World](https://info.michael-simons.eu/2021/10/19/testing-in-a-modular-world/): use `--add-opens`.
* [ModularClasspathForkConfiguration.java](https://github.com/apache/maven-surefire/blob/master/maven-surefire-common/src/main/java/org/apache/maven/plugin/surefire/booterclient/ModularClasspathForkConfiguration.java)  A src/main/java, src/test/java tree for each module.
* [Add modulepath support](https://issues.apache.org/jira/browse/SUREFIRE-1262)
* [Five Command Line Options To Hack The Java Module System](https://nipafx.dev/five-command-line-options-hack-java-module-system/#Reflectively-Accessing-Internal-APIs-With--add-opens)



```
mark@Marks-MBP java-test-test % make clean
rm -rf mlib
rm -rf classes
rm -rf testclasses
mark@Marks-MBP java-test-test % time make
javac \
                -d classes \
                -Xlint \
                -Xlint:-requires-automatic \
                --module-source-path src/main \
                $(find src/main -name '*.java')
jar --create \
                --file=mlib/com.example@1.jar \
                --main-class com/example/Main \
                --module-version 1 \
                -C classes/$(echo "mlib/com.example@1.jar"|cut -d/ -f2|cut -d@ -f1) \
                .
make  1.32s user 0.17s system 173% cpu 0.853 total
mark@Marks-MBP java-test-test % 
```

Notes
------

Maven's Surefire unit test plugin works with module code by
creating the normal src/main and src/test trees, and then uses the
`--patch-module` option when compiling tests and the `--add-opens` option when
running tests (if you patch the tests into the main module).  The [test-patch-compile.jsh script](https://github.com/junit-team/junit5-samples/blob/main/junit5-modular-world/test-patch-compile.jsh#L15-L17) jshell script in the JUnit 5 module sample 
 is a working example.
 
The makefile trick to use class path to compile and run tests.  When module 
jars are on the class path, you can access public classes even if they are 
not exported by the module info.


Fails
-------------------

**Include tests next to sources.**

If you put test classes next to the module code (like how Go organizes their 
code), then IntelliJ will require you to add a "requires junit" to the 
module-info.java for it to find the classes.

**Share same content in multiple IntelliJ modules**

I created one (IntelliJ) module for com.example, and another for 
the entire tree of test sources (src/test/com/...).  Then I wanted to 
add a content root from the test IntelliJ module to that pointed to
src/main/com.example/, but IntelliJ would not let me---"src/main/com.example" already defined in module "com.example".  Two modules cannot
share the same content root.  (This all works fine with the base java
tools---you just add stuff to the class path as you like.)

**Use --patch-module in Makefile.**

This required a module info in the test code.  And a requires junit line.  
IntelliJ couldn't seem to find it, even though it was a project library.  I
stopped this approach as it was much simpler just to use the classpath trick
in the makefile for tests.

**Use standard surefile plugin to run tests**

```
$ tree src
src
├── main
│   └── java
│       ├── com
│       │   └── example
│       │       ├── Main.java
│       │       └── util
│       │           └── Util.java
│       ├── com.example.iml
│       └── module-info.java
└── test
    └── java
        └── com
            └── example
                └── util
                    └── TestUtil.java
                    
$ mvn -X test
...
[DEBUG] args file content:
--module-path
"/Users/mark/src/mycode/java-test-test/target/classes"
--class-path
...
--patch-module
com.example="/Users/mark/src/mycode/java-test-test/target/test-classes"
--add-exports
com.example/com.example.util=ALL-UNNAMED
--add-modules
com.example
--add-reads
com.example=ALL-UNNAMED
org.apache.maven.surefire.booter.ForkedBooter
...
[ERROR] com.example.util.TestUtil.test2x2  
  Time elapsed: 0.024 s  <<< ERROR!
  java.lang.reflect.InaccessibleObjectException: 
    Unable to make void com.example.util.TestUtil.test2x2() 
    accessible: 
      module com.example does not "opens com.example.util" 
      to unnamed module @5cee5251
```

New lines added to error message for readability.

**Add open configuration option to surefire plugin (try 1)**

```
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-surefire-plugin</artifactId>
  <version>3.0.0-M5</version>
  <configuration combine.self="append">
    <argLine>--add-opens com.example=ALL-UNNAMED</argLine>
  </configuration>
</plugin>
...
$ mvn test
...
[ERROR] Error occurred during initialization of boot layer
...
[WARNING] Corrupted STDOUT by directly writing to native stream in forked JVM 1.

$ cat $(find target -name '*.dumpstream') 
      # Created at 2022-02-13T10:25:04.904
      Corrupted STDOUT by directly writing to native stream in forked JVM 1. Stream 'Error occurred during initialization of boot layer'.
      
      # Created at 2022-02-13T10:25:04.906
      Corrupted STDOUT by directly writing to native stream in forked JVM 1. Stream 'java.lang.RuntimeException: Unable to parse --add-opens <module>/<package>:'.
      
      # Created at 2022-02-13T10:25:04.906
      Corrupted STDOUT by directly writing to native stream in forked JVM 1. Stream 'com.example'.
```

**Add open configuration option to surefire plugin (try 2)**

```

[ERROR] Tests run: 1, Failures: 0, Errors: 1, Skipped: 0, Time elapsed: 0.041 s <<< FAILURE! - in com.example.util.TestUtil
[ERROR] com.example.util.TestUtil.test2x2  Time elapsed: 0.023 s  <<< ERROR!
java.lang.reflect.InaccessibleObjectException: Unable to make void com.example.util.TestUtil.test2x2() accessible: module com.example does not "opens com.example.util" to unnamed module @5cee5251


surefire10872153133116271936tmp
----------------
#surefire
#Sun Feb 13 10:35:32 EST 2022
classPathUrl.4=/Users/mark/.m2/repository/org/junit/platform/junit-platform-commons/1.8.1/junit-platform-commons-1.8.1.jar
testSuiteDefinitionTestSourceDirectory=/Users/mark/src/mycode/java-test-test/src/test/java
includes1=**/*Test.java
classPathUrl.5=/Users/mark/.m2/repository/org/junit/jupiter/junit-jupiter-api/5.8.1/junit-jupiter-api-5.8.1.jar
includes2=**/*Tests.java
runOrder=filesystem
classPathUrl.6=/Users/mark/.m2/repository/org/apiguardian/apiguardian-api/1.1.2/apiguardian-api-1.1.2.jar
includes0=**/Test*.java
reportsDirectory=/Users/mark/src/mycode/java-test-test/target/surefire-reports
tc.0=com.example.util.TestUtil
mainCliOptions4=SHOW_ERRORS
surefireClassPathUrl.0=/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-junit-platform/3.0.0-M5/surefire-junit-platform-3.0.0-M5.jar
mainCliOptions3=LOGGING_LEVEL_DEBUG
classPathUrl.0=/Users/mark/src/mycode/java-test-test/target/test-classes
mainCliOptions0=LOGGING_LEVEL_ERROR
systemExitTimeout=30
classPathUrl.1=/Users/mark/.m2/repository/org/junit/jupiter/junit-jupiter-engine/5.8.1/junit-jupiter-engine-5.8.1.jar
failFastCount=0
classPathUrl.2=/Users/mark/.m2/repository/org/junit/platform/junit-platform-engine/1.8.1/junit-platform-engine-1.8.1.jar
requestedTest=
includes3=**/*TestCase.java
mainCliOptions2=LOGGING_LEVEL_INFO
classPathUrl.3=/Users/mark/.m2/repository/org/opentest4j/opentest4j/1.2.0/opentest4j-1.2.0.jar
mainCliOptions1=LOGGING_LEVEL_WARN
testClassesDirectory=/Users/mark/src/mycode/java-test-test/target/test-classes
preferTestsFromInStream=false
useManifestOnlyJar=true
runStatisticsFile=/Users/mark/src/mycode/java-test-test/.surefire-73332DD9C5B99B78771ECBD65536BC826E28E9E0
providerConfiguration=org.apache.maven.surefire.junitplatform.JUnitPlatformProvider
rerunFailingTestsCount=0
failIfNoTests=false
isTrimStackTrace=true
surefireClassPathUrl.5=/Users/mark/.m2/repository/org/junit/platform/junit-platform-launcher/1.8.1/junit-platform-launcher-1.8.1.jar
forkNodeConnectionString=pipe\://1
surefireClassPathUrl.3=/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-shared-utils/3.0.0-M4/surefire-shared-utils-3.0.0-M4.jar
surefireClassPathUrl.4=/Users/mark/.m2/repository/org/apache/maven/surefire/common-java5/3.0.0-M5/common-java5-3.0.0-M5.jar
surefireClassPathUrl.1=/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-api/3.0.0-M5/surefire-api-3.0.0-M5.jar
surefireClassPathUrl.2=/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-logger-api/3.0.0-M5/surefire-logger-api-3.0.0-M5.jar
excludes0=**/*$*
enableAssertions=true
childDelegation=false
pluginPid=46940
useSystemClassLoader=true
shutdown=EXIT


surefire_013621402358715858175tmp
----------------
#surefire_0
#Sun Feb 13 10:35:32 EST 2022
basedir=/Users/mark/src/mycode/java-test-test
user.dir=/Users/mark/src/mycode/java-test-test
localRepository=/Users/mark/.m2/repository


surefireargs5815653060016048109
----------------
--module-path
"/Users/mark/src/mycode/java-test-test/target/classes"
--class-path
"/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-booter/3.0.0-M5/surefire-booter-3.0.0-M5.jar:/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-api/3.0.0-M5/surefire-api-3.0.0-M5.jar:/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-logger-api/3.0.0-M5/surefire-logger-api-3.0.0-M5.jar:/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-shared-utils/3.0.0-M4/surefire-shared-utils-3.0.0-M4.jar:/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-extensions-spi/3.0.0-M5/surefire-extensions-spi-3.0.0-M5.jar:/Users/mark/src/mycode/java-test-test/target/test-classes:/Users/mark/.m2/repository/org/junit/jupiter/junit-jupiter-engine/5.8.1/junit-jupiter-engine-5.8.1.jar:/Users/mark/.m2/repository/org/junit/platform/junit-platform-engine/1.8.1/junit-platform-engine-1.8.1.jar:/Users/mark/.m2/repository/org/opentest4j/opentest4j/1.2.0/opentest4j-1.2.0.jar:/Users/mark/.m2/repository/org/junit/platform/junit-platform-commons/1.8.1/junit-platform-commons-1.8.1.jar:/Users/mark/.m2/repository/org/junit/jupiter/junit-jupiter-api/5.8.1/junit-jupiter-api-5.8.1.jar:/Users/mark/.m2/repository/org/apiguardian/apiguardian-api/1.1.2/apiguardian-api-1.1.2.jar:/Users/mark/.m2/repository/org/apache/maven/surefire/surefire-junit-platform/3.0.0-M5/surefire-junit-platform-3.0.0-M5.jar:/Users/mark/.m2/repository/org/apache/maven/surefire/common-java5/3.0.0-M5/common-java5-3.0.0-M5.jar:/Users/mark/.m2/repository/org/junit/platform/junit-platform-launcher/1.8.1/junit-platform-launcher-1.8.1.jar"
--patch-module
com.example="/Users/mark/src/mycode/java-test-test/target/test-classes"
--add-exports
com.example/com.example.util=ALL-UNNAMED
--add-modules
com.example
--add-reads
com.example=ALL-UNNAMED
org.apache.maven.surefire.booter.ForkedBooter
```

I gave up at this point trying to get a timing with maven surefire.


Links
-----

* [Project Jigsaw: Module System Quick-Start Guide](https://openjdk.java.net/projects/jigsaw/quick-start), Oracle.
* [Testing In The Modular World](https://sormuras.github.io/blog/2018-09-11-testing-in-the-modular-world.html), Christian Stein, 2021-03-24.
* [Support running unit tests in named Java 9 modules](https://issues.apache.org/jira/browse/SUREFIRE-1420), Maven Surefire Project, 2017-09-22.