#!/usr/bin/env bash
# file: tests/integration_test.sh


test_ada_version() {
    result=`ada/ada --version`
    assertEquals "Check ada version:" "v2.1" ${result}
}

test_ada_mkdir() {
    ada/ada --tokenfile ${token_file} --mkdir "/${disk_path}/${dirname}/${testdir}/${subdir}" --recursive --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not create the directory" $? || return
    get_locality "/${disk_path}/${dirname}/${testdir}/${subdir}"
    assertTrue "could not get locality" $?
}


test_ada_mv1() {
    ada/ada --tokenfile ${token_file} --mv "/${disk_path}/${dirname}/${testfile}" "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not move the file" $?
}


test_ada_list_file() {
    ada/ada --tokenfile ${token_file} --list "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "ada could not list the correct file" "/${disk_path}/${dirname}/${testdir}/${testfile}" "$result"
}


test_ada_checksum_file() {
    ada/ada --tokenfile ${token_file} --checksum "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}


test_ada_checksum_dir() {
    ada/ada --tokenfile ${token_file} --checksum "/${disk_path}/${dirname}/${testdir}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}


test_ada_list_dir() {
    ada/ada --tokenfile ${token_file} --list "/${disk_path}/${dirname}/${testdir}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not list the correct directory" $?
}


test_ada_longlist() {
    ada/ada --tokenfile ${token_file} --longlist "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not longlist the correct file" $?
}


test_ada_stat() {
    ada/ada --tokenfile ${token_file} --stat "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not stat the correct file" $?
}


# Move file back to original folder
test_ada_mv2() {
    ada/ada --tokenfile ${token_file} --mv "/${disk_path}/${dirname}/${testdir}/${testfile}" "/${disk_path}/${dirname}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not move the file back" $?
}

# Delete test directory
test_ada_delete() {
    ada/ada --tokenfile ${token_file} --delete "/${disk_path}/${dirname}/${testdir}" --recursive --api ${api} --force >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not delete the directory" $?
}


test_ada_stage_file() {
    ada/ada --tokenfile ${token_file} --stage "/${tape_path}/${dirname}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "COMPLETED" $state
}


test_ada_unstage_file() {
    ada/ada --tokenfile ${token_file} --unstage "/${tape_path}/${dirname}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "COMPLETED" $state
}


oneTimeSetUp() {
    outputDir="${SHUNIT_TMPDIR}/output"
    # outputDir="output"
    mkdir "${outputDir}"
    stdoutF="${outputDir}/stdout"
    stderrF="${outputDir}/stderr"
    debug=false
    dry_run=false
    test="prod"

    # Import test configuration file
    . "$(dirname "$0")"/test.conf

    # Import functions
    . ada/ada_functions.inc

    # Check if macaroon is valid. If not, try to create one.
    token=$(sed -n 's/^bearer_token *= *//p' "$token_file")
    check_macaroon "$token"
    error=$?
    if [ $error -eq 1 ]; then
        echo "The tests expect a valid macaroon. Please enter your CUA credentials to create one."
        get-macaroon --url "${webdav_url}"/"${user_path}" --duration P1D --user $user --permissions DOWNLOAD,UPLOAD,DELETE,MANAGE,LIST,READ_METADATA,UPDATE_METADATA --output rclone $(basename "${token_file%.*}")
        if [ $? -eq 1 ]; then 
            echo "Failed to create a macaroon. Aborting." 
            exit 
        fi
    fi
    # curl options for various activities;
    curl_options_common=(
                        -H "accept: application/json"
                        --fail --silent --show-error
                        )

    curl_options_post=(
                        -H "content-type: application/json"
                    )
    # Save the header in the file
    curl_authorization_header_file="${outputDir}/authorization_header"
    echo "header \"Authorization: Bearer $token\"" > "$curl_authorization_header_file"
    # Refer to the file with the header
    curl_authorization=( "--config" "$curl_authorization_header_file" )

 
    # Define test files and directories
    dirname="integration_test"
    testfile="1GBfile"
    testdir="testdir"
    subdir="subdir"

    # Create test data and transfer to dCache:
    case $OSTYPE in
      darwin* )
        mkfile 1g $testfile   
        ;;
      * )
        fallocate -x -l 1G $testfile
        ;;
    esac
    rclone -P copyto --config=${token_file} ${PWD}/$testfile  $(basename "${token_file%.*}"):/${tape_path}/${dirname}/${testfile} 

}

tearDown() {
  rm -f $testfile
}


# Load and run shunit2
. shunit2