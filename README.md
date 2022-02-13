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

* 1.32 seconds for make
* 

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

**Use --patch-module in Makfile.**

This required a module info in the test code.  And a requires junit line.  
IntelliJ couldn't seem to find it, even though it was a project library.  I
stopped this approach as it was much simpler just to use the classpath trick
in the makefile for tests.


Links
-----

* [Project Jigsaw: Module System Quick-Start Guide](https://openjdk.java.net/projects/jigsaw/quick-start), Oracle.
* [Testing In The Modular World](https://sormuras.github.io/blog/2018-09-11-testing-in-the-modular-world.html), Christian Stein, 2021-03-24.
* [Support running unit tests in named Java 9 modules](https://issues.apache.org/jira/browse/SUREFIRE-1420), Maven Surefire Project, 2017-09-22.