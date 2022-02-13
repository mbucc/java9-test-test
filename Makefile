JUNIT_DETAILS=tree
SKIP_FMT=N


###########################################################################
#
#
#		Jars
#
#
###########################################################################

all: mlib/com.example@1.jar

mlib/com.example@1.jar: compile
	@mkdir -p mlib
	jar --create \
		--file=$@ \
		--main-class com/example/Main \
		--module-version 1 \
		-C classes/$$(echo "$@"|cut -d/ -f2|cut -d@ -f1) \
		.



###########################################################################
#
#
#		Module classes
#
#
###########################################################################

.PHONY: compile
compile:
	javac \
		-d classes \
		-Xlint \
		-Xlint:-requires-automatic \
		--module-source-path src/main \
		$$(find src/main -name '*.java')




###########################################################################
#
#
#		Automated tests
#
#
###########################################################################

TESTCP=classes/com.acsredux.core.admin:classes/com.acsredux.adapter.mailgun:classes/com.acsredux.lib.env:classes/com.example:classes/com.acsredux.core.members:classes/com.acsredux.core.base:classes/com.acsredux.adapter.stub:testlib/*:lib/*

.PHONY: test
test: compiletests
	java \
		-cp "testclasses:testlib/*:$$(echo classes/*|tr ' ' :)" \
		org.junit.platform.console.ConsoleLauncher \
		--disable-banner \
		--details=$(JUNIT_DETAILS) \
		--fail-if-no-tests \
		--exclude-engine=junit-vintage \
		--scan-classpath

# Use classpath so tests have access w/out defining module-info.java
.PHONY: compiletests
compiletests: compile
	javac \
		-d testclasses \
		-cp "testlib/*:$$(echo classes/*|tr ' ' :)" \
		$$(find src/test -name '*.java')




###########################################################################
#
#
#		Delete generated files
#
#
###########################################################################

.PHONY: clean
clean:
	rm -rf mlib
	rm -rf classes
	rm -rf testclasses
