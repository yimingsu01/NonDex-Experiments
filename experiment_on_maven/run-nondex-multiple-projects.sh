#!/bin/bash
DIR="${PWD}"
touch result.csv
touch flaky.csv
touch project_test_count.csv
echo "project name,compile,flaky tests,total tests,successful tests,failed tests,errored tests,skipped tests,time (minutes)" > result.csv
echo "Project URL,SHA Detected,Subproject Name,Fully-Qualified Test Name (packageName.ClassName.methodName)" > flaky.csv
echo "Project URL,SHA Detected,Test Count" > project_test_count.csv


for repo in $(cat $1)
    do
	user=$(dirname $repo)
	cur_repo=$(basename $repo)
	dir=github.com/${user}/${cur_repo}
	url=http://github.com/${user}/${cur_repo}.git
        git clone $url ${dir}
        echo $repo
        ./run-nondex.sh ${dir}

        if [ -e ${dir}/.runNondex/htmlOutput ]
        then
            echo "Flaky tests detected"
        else
            echo "Consider removing this directory to save space"
        fi

    done

