#!/bin/bash
DIR="${PWD}"
nondex_version="2.1.7"
runNondex () {
    start_time=$(date +%s)
    cd $1
    echo "========= try to build the project $1"
    mvn install -DskipTests -Dspotbugs.skip=true > build.log
    mvn -Dexec.executable='echo' -Dexec.args='${project.artifactId}' exec:exec -q -fn | tee modnames
    if grep -q "[ERROR]" modnames; then
        echo "========= ERROR IN PROJECT $1"
	printf '%b\n' "$1,F,,,,,,,$(( ($(date +%s)-${start_time})/60 ))" >> ${DIR}/result.csv
        exit 1
    fi
    mkdir .runNondex
    mkdir ./.runNondex/LOGS
    input="modnames"
    while IFS= read -u3 -r line
    do
	echo "========= counting tests in the project $1:$line"
        mvn test -pl :$line -Drat.skip=true -Dlicense.skip=true > maven_build_$line.out
	total_tests=$(cat maven_build_$line.out | grep "Tests run" | grep -v "Time elapsed" | cut -d , -f 1 | awk -F' ' '{sum3+=$3;sum4+=$4} END{print sum3+sum4;}')
        failed_tests=$(cat maven_build_$line.out | grep "Tests run" | grep -v "Time elapsed" | cut -d , -f 2 | awk -F' ' '{sum1+=$1;sum2+=$2} END{print sum1+sum2;}')
        errored_tests=$(cat maven_build_$line.out | grep "Tests run" | grep -v "Time elapsed" | cut -d , -f 3 | awk -F' ' '{sum1+=$1;sum2+=$2} END{print sum1+sum2;}')
        skipped_tests=$(cat maven_build_$line.out | grep "Tests run" | grep -v "Time elapsed" | cut -d , -f 4 | awk -F' ' '{sum1+=$1;sum2+=$2} END{print sum1+sum2;}')
        succeeded_tests=$((total_tests-failed_tests-errored_tests-skipped_tests))
        echo $total_tests
	echo "========= run nondex in the project $1:$line"
	mvn edu.illinois:nondex-maven-plugin:$nondex_version:nondex -pl :$line -Drat.skip=true -Dlicense.skip=true | tee ./.runNondex/LOGS/$line.log
    	grep "NonDex SUMMARY:" ./.runNondex/LOGS/$line.log
    	if ( grep "NonDex SUMMARY:" ./.runNondex/LOGS/$line.log ); then
		flaky_tests=$(sed -n -e '/Across all seeds:/,/Test results can be found at: / p' ./.runNondex/LOGS/$line.log | sed -e '1d;$d' | wc -l)
		if [[ $flaky_tests != '0' ]]; then
			sha=$(git rev-parse HEAD)
			sed -n -e '/Across all seeds:/,/Test results can be found at: / p' ./.runNondex/LOGS/$line.log | sed -e '1d;$d' | cut -f1 -d' ' --complement | while read flaky_line
				do echo "https://$1,${sha},${line},${flaky_line}" >> ${DIR}/flaky.csv
			done
		fi
    	else
		echo "========== error or no test in the project $1:$line"
		if ( grep "BUILD SUCCESSFUL" ./.runNondex/LOGS/$line.log ); then flaky_tests="no test"
		else flaky_tests="error"; fi
    	fi
    	printf '%b\n' "$1:$line,T,${flaky_tests},${total_tests},${succeeded_tests},${failed_tests},${errored_tests},${skipped_tests},$(( ($(date +%s)-${start_time})/60 ))" >> ${DIR}/result.csv
    done 3<"$input"
    grep -rnil "There are test failures" ./.runNondex/LOGS/* | tee ./.runNondex/LOGresult
    input=".runNondex/LOGresult"
    while IFS= read -r line
    do
        grep "test_results.html" $line | tee ./.runNondex/htmlOutput
    done < "$input"
    if [ -e $1/.runNondex/htmlOutput ]
    then
        python3 $DIR/showmarkdown.py $1/.runNondex/htmlOutput
    else
        echo "No flaky tests detected"
    fi
}

if [ ! "$2" ]
then
    runNondex $1
else
    for file in $1/$2/*
        do
            echo "start running nondex in module: $file"
            if test -d $file
            then
                runNonDex.sh $file
            fi
        done
fi
