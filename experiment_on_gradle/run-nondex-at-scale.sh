path=$(pwd)
result_file=${path}/result.csv


function download_compile() {
    start_time=$(date +%s)
    cd $path
    user=$(dirname $1)
    repo=$(basename $1)
    dir=github.com/${user}/${repo}
    url=http://github.com/${user}/${repo}.git
    git clone $url ${dir}
    cd $dir

	chmod +x gradlew
    # -------------------------------NonDex 2.1.7 supports gradle 5.0 ~ 8.5, so change Gradle version if not in the range.--------------------------------------------------------#
	ver=$(grep distributionUrl gradle/wrapper/gradle-wrapper.properties | sed 's/.*gradle-//' | cut -f1 -d-)
	echo gradle version: $ver
	bigger_ver=$(printf "$ver\n5.0" | sort -rV | head -n 1)
	smaller_ver=$(printf "$ver\n8.5" | sort -V | head -n 1)
	if [[ "$bigger_ver" != "$smaller_ver" ]]; then # the version is not in range 5.0 ~ 8.5
		if [[ "$ver" != "$bigger_ver" ]]; then
			new_ver="5.0"
		else
			new_ver="8.5"
		fi
		original_wrapper_file=gradle/wrapper/gradle-wrapper.properties
		sed -i 's/distributionUrl.*//' ${original_wrapper_file}
		echo "distributionUrl=https\://services.gradle.org/distributions/gradle-${new_ver}-bin.zip" >> ${original_wrapper_file}
		build_file=build.gradle
		if grep -q "wrapper" ${build_file} ; then
			sed -i "s/.*gradleVersion.*/    gradleVersion = \"$new_ver\"/" ${build_file} 
		fi
	fi

    echo ========= try to build the project
	./gradlew tasks 1> build.log 2> build-err.log
    grep "BUILD SUCCESSFUL" build.log
    
    if [ $? == 0 ]; then
		build="error with test"
		./gradlew projects | grep "No sub-projects"
		sub=$?	# sub=0 if no subprojects; sub=1 if there are subprojects
		projects=$(./gradlew projects | grep Project | cut -f3 -d" " | tr -d "':")
		echo ========= projects: ${projects}
		buildFile=$(./gradlew properties | grep buildFile | awk '{print $2}')
		echo '
		allprojects {
  			tasks.withType(Test) {
    			testLogging {
      				afterSuite { desc, result ->
        				if (!desc.parent) { 
          					println "+++Results: ${result.resultType} ${result.testCount},${result.successfulTestCount},${result.failedTestCount},${result.skippedTestCount}"
        				}
      				}
    			}
  			}
		}' >> ${buildFile}
		./gradlew cleanTest test --no-build-cache | grep "+++Results"
		if [ $? == 0 ]; then build="T"; else echo "========== error with test"; fi # able to run test

        echo ========== try to add the plugin
		grep "classpath 'edu.illinois.nondex'" ${buildFile}
		if [ $? != 0 ]; then
			if [ $sub == 0 ]; then # no subprojects
				printf '%b\n' "\napply plugin: 'edu.illinois.nondex'" >> ${buildFile}
			else
				printf '%b\n' "\nsubprojects {\n    apply plugin: 'edu.illinois.nondex'\n}" >> ${buildFile}
			fi
        	echo "buildscript {
				repositories {
					maven {
    					url = uri(\"https://plugins.gradle.org/m2/\")
    				}
  				}
  				dependencies {
					classpath(\"edu.illinois:plugin:2.2.1\")
  				}
			}
			$(cat ${buildFile})" > ${buildFile}
        fi

		# change test closures to tasks.withType(Test)
		sed -i 's/^\( \|\t\)*test /tasks.withType(Test) /' ${buildFile}
		if [[ $sub != 0 ]]; then
			for p in ${projects}; do
				subBuildFile=$(./gradlew :$p:properties | grep buildFile | awk '{print $2}')
				sed -i 's/^\( \|\t\)*test /tasks.withType(Test) /' ${subBuildFile}
			done
		fi

        echo ========== try to run nondexTest
		./gradlew clean	> /dev/null
		cur_project_test_count=0
		if [[ $sub == 0 ]]; then
			total_tests=$(./gradlew cleanTest test --no-build-cache | grep "+++Result" | cut -f3 -d' ')
			if [[ ${total_tests} == '' ]]; then 
				total_tests=",,," 
				echo "========== error with tests in $1"
			else 
				total_tests_arr=($(echo "$total_tests" | tr ',' '\n'))
				total_tests_not_ignored=$((total_tests_arr[0]-total_tests_arr[3]))
				cur_project_test_count=$((cur_project_test_count+total_tests_not_ignored))
			fi
			echo "========== run NonDex on $1"
			./gradlew nondexTest --nondexRuns=4 1> nondex.log 2> nondex-err.log
			if ( grep "NonDex SUMMARY:" nondex.log ); then # if nondexTest is actually executed
				flaky_tests=$(sed -n -e '/Across all seeds:/,/Test results can be found at: / p' nondex.log | sed -e '1d;$d' | wc -l)
				if [[ $flaky_tests != '0' ]]; then 
					sha=$(git rev-parse HEAD)
					sed -n -e '/Across all seeds:/,/Test results can be found at: / p' nondex.log | sed -e '1d;$d' | cut -f1 -d' ' --complement | while read line
					do echo "https://github.com/$1,${sha},.,${line}" >> ${path}/flaky.csv
					done	
				fi
			else
				echo "========== error or no test in the project $1"
				if ( grep "BUILD SUCCESSFUL" nondex.log ); then flaky_tests="no test"
				else flaky_tests="error"; cp nondex-err.log ${path}/error_log/nondex-${user}-${repo}.log; fi
			fi
			printf '%b\n' "$1,${build},${ver},${flaky_tests},${total_tests},$(( ($(date +%s)-${start_time})/60 ))" | tee -a ${path}/result.csv
		else
			for p in ${projects}; do 
				total_tests=$(./gradlew :$p:cleanTest :$p:test --no-build-cache | grep "+++Result" | cut -f3 -d' ')
				if [[ ${total_tests} == '' ]]; then 
					total_tests=",,," 
					echo "========== error with tests in $1:$p" 
				else 
					total_tests_arr=($(echo "$total_tests" | tr ',' '\n'))
					total_tests_not_ignored=$((total_tests_arr[0]-total_tests_arr[3]))
					cur_project_test_count=$((cur_project_test_count+total_tests_not_ignored))
				fi
				echo "========== run NonDex on $1:$p"
				./gradlew :$p:nondexTest  --nondexRuns=4 1> nondex:$p.log 2> nondex-err:$p.log
				if ( grep "NonDex SUMMARY:" nondex:$p.log ); then # if nondexTest is actually executed
					flaky_tests=$(sed -n -e '/Across all seeds:/,/Test results can be found at: / p' nondex:$p.log | sed -e '1d;$d' | wc -l)
					if [[ $flaky_tests != '0' ]]; then
						sha=$(git rev-parse HEAD)
						sed -n -e '/Across all seeds:/,/Test results can be found at: / p' nondex:$p.log | sed -e '1d;$d' | cut -f1 -d' ' --complement | while read line
						do echo "https://github.com/$1,${sha},$p,${line}" >> ${path}/flaky.csv
						done
					fi
				else
					echo "========== error or no test in the project $1:$p"
					if ( grep "BUILD SUCCESSFUL" nondex:$p.log ); then flaky_tests="no test"
					else flaky_tests="error"; cp nondex-err:$p.log ${path}/error_log/nondex-${user}-${repo}:$p.log; fi
				fi
				printf '%b\n' "$1:$p,${build},${ver},${flaky_tests},${total_tests},$(( ($(date +%s)-${start_time})/60 ))" | tee -a ${path}/result.csv
			done
		fi
		echo "https://github.com/$1,${sha},${cur_project_test_count}" >> ${path}/project_test_count.csv
    else 
        build="F"
        flaky_tests="N/A"
		total_tests=",,,"
        echo "project $1 has error"
        cp build-err.log ${path}/error_log/build-${user}-${repo}.log
		printf '%b\n' "$1,${build},${ver},${flaky_tests},${total_tests},$(( ($(date +%s)-${start_time})/60 ))" >> ${path}/result.csv
    fi
}

touch result.csv
touch flaky.csv
touch project_test_count.csv
echo "project name,compile,gradle version,flaky tests,total tests,successful tests,failed tests,skipped tests,time (minutes)" > result.csv
echo "Project URL,SHA Detected,Subproject Name,Fully-Qualified Test Name (packageName.ClassName.methodName)" > flaky.csv
echo "Project URL,SHA Detected,Test Count" > project_test_count.csv
mkdir error_log
for f in $(cat $1); do
    echo ========== trying to download $f
    download_compile $f
done
