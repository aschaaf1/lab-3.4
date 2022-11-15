#!/bin/bash

function signalCaught {
    echo "++++ caught signal while running script ++++"
}

function signalCtrlC {
    echo "Caught Control-C"
    echo "You will neeed to clean up some files"
    exit
}

function signalSegFault {
    echo "+++++++ Caught Segmentation Fault from your program! OUCH!  ++++++++"
    exit
}

function showHelp {

    # The following is called a "here file."
    cat <<EOF

This script can be used to test lab8_1 (generating prime numbers with
a multi-threaded program).

By default, all tests will be run. The options below allow you to limit
the tests when you are early in your development cycle.

Command line options:
    -h   : show this helpful text and exit.
           Have a good day.
    -p name : the default (and ONLY accepted for grading) name of the program
           to test is ${PROG}. If you are early in your devalopment, you can
           finagle this. But, do not try this for check-off.
    -C   : run a shortened set of correctness tests. By default, correctness
           will be tested for prime numbers up to: ${TEST_CORRECT}, ${TEST_CORRECT}0,
           ${TEST_CORRECT}00, and ${TEST_CORRECT}000. Setting this will limit the
           correctness tests to 100 and 1000.
           Correctness tests are run for thread counts of: 1 2 3 4 5 6 7 8 12.
           This will not cut for check-off.
    -L   : Skip the valgrind leaks test. If you are early in your development, you
           might want to skip this test.
           You need to also be aware that the PThreads code will show false positives
           for memory leaks. I am aware of those and they will not hurt your grade.
           Leak tests are run for thread counts of: 1 2 3 4 8.
           This will not cut for check-off.
    -u # : the required argument establishes a new initial bound used for the
           timing tests. The default initial bound is ${TIME_PRIMES}. Additional
           timing tests will be run for ${TIME_PRIMES}0 to ${TIME_PRIMES}000.
           If it takes longer than ${TWENTY_THREAD_TO} seconds to complete a 20 thread timing 
           test, any following larger timing tests will be skiped.
           See also the -T option below.
    -T   : Skip the timing tests. If you are early in the development, you might
           not want to wait for all these tests to complete. The default group of
           timing tests is: ${TIME_PRIMES} to ${TIME_PRIMES}000 for thread counts
           of 1 2 3 4 5 6 7 8 12 16 20.
    -c   : By deafult, all the temporary files created during the script are deleted,
           and there are a bunch of files. If you want to keep them around for some
           debugging, use this option.
    -x   : You REALLY REALLY REALLY want to watch everything happen.

If you experience problems with this script, please let me know. Send me email

    ${OWNER}

or call me over.

This is a testing script, but there may be things sooooo bad that it does not
catch them. Doing well with the script does not guarantee success on the lab.

EOF

    exit 0
}

function coreDumpMessage {
    if [ $1 -eq 139 ]
    then
        echo "      >>> core dump during $2 testing"
	    ((CORE_COUNT++))
    elif [ $1 -eq 137 ]
    then
        echo "      >>> core dump during $2 testing"
	    ((CORE_COUNT++))
    elif [ $1 -eq 134 ]
    then
        echo "      >>> abort during $2 testing"
	    ((CORE_COUNT++))
    elif [ $1 -eq 124 ]
    then
        echo "      >>> timeout during $2 testing"
    #else
	    #echo "$1 is a okay"
    fi
    sync
}

function testCorrectPrimes {

    PRIMES=$1

    ERR_COUNT=0
    TEST_COUNT=0
    CORE_COUNT=0
    LINE_COUNT=$(zcat ${TEST_DIR}/Primes${PRIMES}.txt.gz | wc -l)
    DIFF=zdiff
    > coreDump.log
    echo "primes ${PRIMES} begin"
    for T in 1 2 3 4 5 6 7 8 12 16 20
    do
	    ((TEST_COUNT++))
	    { timeout ${TOS} ${TO} ${PROG} -u ${PRIMES} -t ${T} | gzip > TestPrimes${PRIMES}_${T}.txt.gz 2> /dev/null ; } >> coreDump.log 2>&1
	    CORE_DUMP=$?
	    coreDumpMessage ${CORE_DUMP} "testing primes ${PRIMES}   threads ${T}"
	    ${DIFF} -q -w TestPrimes${PRIMES}_${T}.txt.gz ${TEST_DIR}/Primes${PRIMES}.txt.gz > /dev/null
	    RES=$?
	    if [ ${RES} -ne 0 ]
	    then
	        ((ERR_COUNT++))
	        ERR_LINE_COUNT=$(${DIFF} -w TestPrimes${PRIMES}_${T}.txt.gz ${TEST_DIR}/Primes${PRIMES}.txt.gz | grep -e "^<\|^>" | wc -l)
	        echo "    *** error on ${PRIMES}  threads = ${T}   ${ERR_LINE_COUNT}  of  ${LINE_COUNT}"
	        if [ ${DO_CLEANUP} -ne 1 ]
	        then
		        echo "        ${DIFF} TestPrimes${PRIMES}_${T}.txt.gz ${TEST_DIR}/Primes${PRIMES}.txt.gz"
	        fi
	    fi
    done
    echo "  ** Found $ERR_COUNT non-matches of $TEST_COUNT tests for ${PRIMES}"
    echo "  ** Found $CORE_COUNT seg faults of $TEST_COUNT tests for ${PRIMES}"
    echo "primes ${PRIMES} end"
    echo " "
    
    if [ $ERR_COUNT -gt 5 ]
    then
	    echo "Maybe you should fix the errors before bigger tests."
	    exit 1
    fi
}

function testLeakyPrimes {

    PRIMES=$1

    ERR_COUNT=0
    TEST_COUNT=0
    CORE_COUNT=0
    LEAK_FILE=leakLog.err
    > coreDump.log
    echo "The PThreads library will show false leaks."
    echo "  So, don't fret too much if your code shows some reachable leaks."
    echo "  The PTheads library leave some stuff allocated."
    echo "leaks ${PRIMES} begin"
    for T in 1 2 3 4 8
    do
	    ((TEST_COUNT++))
	    { timeout ${TOS} ${TO} valgrind --leak-check=full --show-leak-kinds=all ${PROG} -t ${T} -u ${PRIMES} > /dev/null 2> ${LEAK_FILE} ; } >> coreDump.log 2>&1
	    coreDumpMessage $? "valgrind primes ${PRIMES}   threads ${T}"
	    grep "All heap blocks were freed -- no leaks are possible" leakLog.err > /dev/null
	    if [ $? != 0 ]
	    then
	        echo "    *** leaky     primes ${PRIMES}   threads ${T}"
	        ((ERR_COUNT++))
	    fi
    done
    echo "  ** Found $ERR_COUNT leak-test failures of $TEST_COUNT tests for ${PRIMES}"
    echo "  ** Found $CORE_COUNT leak-test seg faults of $TEST_COUNT tests for ${PRIMES}"
    echo "  ** Look at the leakLog.err file for more information"
    echo "  **   These may be false positives. CHECK THE FILE!!! ${LEAK_FILE}"
    echo "leaks ${PRIMES} end"
    echo " "
}

function timePrimes {

    PRIMES=$1

    ERR_COUNT=0
    TEST_COUNT=0
    CORE_COUNT=0
    >> timeResults.log
    echo "timing tests ${PRIMES} begin"
    for T in 1 2 3 5 7 9 12 16 20 25 30
    do
	    echo "  ${PRIMES} ${T}"
	    ((TEST_COUNT++))
	    RESULT=$(/usr/bin/time -p timeout ${TOS} ${TO} ${PROG} -u ${PRIMES} -t ${T} 2>&1 > /dev/null | grep -e "real\|core")
	    CORE=$(echo $RESULT | grep "dumped core")
	    REAL=$(echo $RESULT | grep "real")
	    if [ ! -z "$CORE" ]
	    then
	        coreDumpMessage 139 "timing primes ${PRIMES}   threads ${T}"
	        ((ERR_COUNT++))
	    else
	        #echo "time ${PRIMES} ${T} end"
	        echo "  ${PRIMES} ${T} ${REAL}" >> timeResults.log
	    fi
    done
    echo "  ** Found $ERR_COUNT timing-test failures of $TEST_COUNT tests for ${PRIMES}"
    echo "  ** Found $CORE_COUNT timing-test seg faults of $TEST_COUNT tests for ${PRIMES}"
    echo "timing tests ${PRIMES} end"
    
    RTIME=$(echo ${REAL} | cut -f2 -d' ')
    TOO_LONG=$(expr ${RTIME} '>' ${TWENTY_THREAD_TO})
    if [ ${TOO_LONG} -gt 0 ]
    then
	    echo -e "Mmmmmmmaybe you need to make it bit faster before you try larger upperbounds.\n\n"
    fi
}

function buildPart {
    echo "    Trying \"make $1\""

    rm -f $1
    make clean > /dev/null 2>&1
    make $1 > /dev/null 2>&1 
    if [ $? -ne 0 ]
    then
	    echo "      >> Failed \"make $1\""
	    echo "         Missing the $1 target in Makefile or too many errors during compilation."
    fi
}

function build {
    BuildFailed=0

    echo -e "\nTesting ${FUNCNAME} (the Makefile)"

    if [ ! -f Makefile -a ! -f makefile ]
    then
	    echo "      >>> There is no makefile or Makefile. This is bad. <<<"
	    echo "      >>>   Nothing can be built, all tests fail.        <<<"
	    echo "      >>>                                                <<<"
	    BuildFailed=1
	    return
    fi
    
    make clean > /dev/null
    if [ $? -eq 0 ]
    then
	    echo "    Passed \"make clean\" A good start. Keep it up."
    else
	    echo "    >> Failed \"make clean\""
	    echo "       Missing the clean target in Makefile?"
    fi

    for TARG in ${PROG}.o ${PROG} all
    do
	    buildPart ${TARG}
    done

    make clean > /dev/null 2>&1
    make 2> WARN.err > WARN.out

    NUM_BYTES=`wc -c < WARN.err`
    if [ ${NUM_BYTES} -eq 0 ]
    then
	    echo "      You had no warnings messages. Excellent!"
    else
	    echo "      >> You have warnings messages.  Bummer."
    fi

    for FLAG in -Wall -Wshadow -Wunreachable-code -Wredundant-decls \
	                  -Wmissing-declarations -Wold-style-definition -Wmissing-prototypes \
	                  -Wdeclaration-after-statement -Werror -Wunsafe-loop-optimizations
    do
	    echo "    Looking for \"${FLAG}\" in build log"
        
	    grep -c -- ${FLAG} WARN.out > /dev/null
	    if [ $? -ne 0 ]
	    then
	        echo "      >> Failed gcc flag ${FLAG}"
	        echo "         Missing from compiler flags; ${FLAG}"
	    fi
    done
    
    if [ ${DO_CLEANUP} -eq 1 ]
    then
	    rm -f ./WARN*
    fi

    if [ ! -x ${PROG} ]
    then
	    echo "      >>> The ${PROG} program failed to build. This is bad. <<<"
	    echo "      >>>   VERY VERY BAD                                    <<<"
	    BuildFailed=1
    fi
}

# Number of seconds for timeout. This is a REALLLLLLLLLLY long time.
TO=180s
# Signal to send on timout. Stands for "Time-Out-Signal"
TOS="-s 9"

TEST_CORRECT=1000
TIME_PRIMES=100000
PROG_BASE=primesMT
PROG=./${PROG_BASE}
TEST_DIR=~rchaney/Classes/cs333/Labs/Lab3
SHORT_CORRECT=0
DO_CLEANUP=1
DO_LEAKS=1
DO_TIME=1
GO_BIG=1
TWENTY_THREAD_TO=60
OWNER=rchaney@pdx.edu

while getopts "hu:p:BcCTLx" opt
do
    case $opt in
	h)
	    showHelp
	    ;;
	u)
	    TIME_PRIMES=$OPTARG
	    ;;
	p)
	    PROG=$OPTARG
	    ;;
	C)
	    SHORT_CORRECT=1
	    TEST_CORRECT=100
	    ;;
	L)
	    DO_LEAKS=0
	    ;;
	T)
	    DO_TIME=0
	    ;;
	c)
	    DO_CLEANUP=0
	    ;;
    B)
        GO_BIG=0
        ;;
	x)
	    set -x
	    ;;
	\?)
            echo "Invalid option" >&2
            echo ""
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac

done

trap 'signalCaught;' SIGTERM SIGQUIT SIGKILL SIGSEGV
trap 'signalCtrlC;' SIGINT
#trap 'signalSegFault;' SIGCHLD

build
if [ ${BuildFailed} -ne 0 ]
then
    echo "Since the program build failed (using make), ending test"
    exit 1
fi

testCorrectPrimes ${TEST_CORRECT}
testCorrectPrimes ${TEST_CORRECT}0
if [ ${SHORT_CORRECT} -eq 0 ]
then
    testCorrectPrimes ${TEST_CORRECT}00
    testCorrectPrimes ${TEST_CORRECT}000
fi

if [ ${DO_LEAKS} -eq 1 ]
then
    testLeakyPrimes ${TEST_CORRECT}0
fi

rm -f timeResults.log

if [ ${DO_TIME} -eq 1 ]
then
    timePrimes ${TIME_PRIMES}
    if [ ${TOO_LONG} -eq 0 ]
    then
	    timePrimes ${TIME_PRIMES}0
    fi
    if [ ${TOO_LONG} -eq 0 ]
    then
	    timePrimes ${TIME_PRIMES}00
    fi
    if [ ${TOO_LONG} -eq 0 ]
    then
	    timePrimes ${TIME_PRIMES}000
    fi
    if [ ${TOO_LONG} -eq 0 -a ${GO_BIG} -eq 1 ]
    then
	    timePrimes ${TIME_PRIMES}0000
    fi

    cat timeResults.log
fi

if [ ${DO_CLEANUP} -eq 1 ]
then
    rm -f TestPrimes100*.txt TestPrimes100*.txt.gz coreDump.log timeResults.log
fi
