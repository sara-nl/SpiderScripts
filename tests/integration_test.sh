#!/usr/bin/env bash
# file: tests/integration_test.sh


# Check if version is as expected
test_ada_version() {
    result=`ada/ada --version`
    assertEquals "Check ada version:" "v2.3" ${result}
}

# Create directory on dCache
test_ada_mkdir() {
    ada/ada --tokenfile ${token_file} --mkdir "/${disk_path}/${dirname}/${testdir}/${subdir}" --recursive --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not create the directory" $? || return
    get_locality "/${disk_path}/${dirname}/${testdir}/${subdir}"
    assertTrue "could not get locality" $?
}

# Move a file (created in oneTimeSetUp) to folder created in above test
test_ada_mv1() {
    echo "ada/ada --tokenfile ${token_file} --mv "/${disk_path}/${dirname}/${testfile}" "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api}"
    ada/ada --tokenfile ${token_file} --mv "/${disk_path}/${dirname}/${testfile}" "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not move the file" $?
}

# List file
test_ada_list_file() {
    ada/ada --tokenfile ${token_file} --list "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "ada could not list the correct file" "/${disk_path}/${dirname}/${testdir}/${testfile}" "$result"
}

# Set label on a file
test_ada_setlabel() {
    ada/ada --tokenfile ${token_file} --setlabel "/${disk_path}/${dirname}/${testdir}/${testfile}" "testlabel" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "success" "$result"
}

# Find files in directory with specified label
test_ada_findlabel() {
    ada/ada --tokenfile ${token_file} --findlabel "/${disk_path}/${dirname}/${testdir}" "testlabel" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not find file with findlabel" $?
}

# List label of file
test_ada_lslabel() {
    ada/ada --tokenfile ${token_file} --lslabel "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "testlabel" "$result"
}


# Remove label of file
test_ada_rmlabel() {
    ada/ada --tokenfile ${token_file} --rmlabel "/${disk_path}/${dirname}/${testdir}/${testfile}" "testlabel" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "success" "$result"
}

# Set extended attribute of file
test_ada_setxattr() {
    echo "test=attribute" > ${outputDir}/attr_file
    ada/ada --tokenfile ${token_file} --setxattr "/${disk_path}/${dirname}/${testdir}/${testfile}" ${outputDir}/attr_file --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not set extended attribute" $?
}

# List extended attribute of file
test_ada_lsxattr() {
    ada/ada --tokenfile ${token_file} --lsxattr "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep '"test": "attribute"' "${stdoutF}" >/dev/null
    assertTrue "ada could not list extended attribute" $?
}

# Find file with attribute with key-value pair
test_ada_findxattr() {
    ada/ada --tokenfile ${token_file} --findxattr "/${disk_path}/${dirname}/${testdir}" "test" "attribute" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not find file with extended attribute" $?
}

# Remove all attributes of file
test_ada_rmxattr() {
    ada/ada --tokenfile ${token_file} --rmxattr "/${disk_path}/${dirname}/${testdir}/${testfile}" --all --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not list extended attribute" $?
    ada/ada --tokenfile ${token_file} --lsxattr "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=`cat "${stdoutF}"`
    assertEquals "{}" "$result"
}

# Get checksum of file
test_ada_checksum_file() {
    ada/ada --tokenfile ${token_file} --checksum "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}

# Get checksum of files in a directory
test_ada_checksum_dir() {
    ada/ada --tokenfile ${token_file} --checksum "/${disk_path}/${dirname}/${testdir}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}

# List files in directory
test_ada_list_dir() {
    ada/ada --tokenfile ${token_file} --list "/${disk_path}/${dirname}/${testdir}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not list the correct directory" $?
}

# List files in directory with details
test_ada_longlist() {
    ada/ada --tokenfile ${token_file} --longlist "/${disk_path}/${dirname}/${testdir}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not longlist the correct file" $?
}


# Show all details of file or directory
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

# Stage a file
test_ada_stage_file() {
    ada/ada --tokenfile ${token_file} --stage "/${tape_path}/${dirname}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    sleep 2 # needed if request is still RUNNING
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "COMPLETED" $state
}

# Unstage a file
test_ada_unstage_file() {
    ada/ada --tokenfile ${token_file} --unstage "/${tape_path}/${dirname}/${testfile}" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    sleep 2 # needed if request is still RUNNING
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "COMPLETED" $state
}

# Stages files in file_list
test_ada_stage_filelist() {
    echo  "/${tape_path}/${dirname}/${testfile}" > ${outputDir}/file_list
    ada/ada --tokenfile ${token_file} --stage --from-file ${outputDir}/file_list  --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    sleep 2 # needed if request is still RUNNING
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "COMPLETED" $state
}

# Unstage files in file_list
test_ada_unstage_filelist() {
    ada/ada --tokenfile ${token_file} --unstage --from-file ${outputDir}/file_list --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    sleep 2 # needed if request is still RUNNING    
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "COMPLETED" $state
}

# Test if ada exits with error when staging non-existing file
test_ada_stage_file_error() {
    ada/ada --tokenfile ${token_file} --stage "/${tape_path}/${dirname}/testerror" --api ${api} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 1 ${result}
}

# Set up for tests
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
    . ada/ada

    # Check if macaroon is valid. If not, try to create one.
    token=$(sed -n 's/^bearer_token *= *//p' "$token_file")
    check_token "$token"
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
    rclone -P copyto --config=${token_file} ${PWD}/$testfile  $(basename "${token_file%.*}"):/${disk_path}/${dirname}/${testfile} 
}


tearDown() {
  rm -f $testfile
}


# Load and run shunit2
. shunit2