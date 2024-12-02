#!/usr/bin/env bash
# file: tests/integration_test.sh


test_ada_mkdir() {
    ada/ada --tokenfile ${token_file} --mkdir "/${disk_path}/${dirname}/${testdir}/${subdir}" --recursive --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not create the directory" $?
}


test_ada_mv1() {
    ada/ada --tokenfile ${token_file} --mv "/${disk_path}/${dirname}/${filename}" "/${disk_path}/${dirname}/${testdir}/${filename}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not move the file" $?
}


test_ada_list_file() {
    ada/ada --tokenfile ${token_file} --list "/${disk_path}/${dirname}/${testdir}/${filename}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    result=`cat "${stdoutF}"`
    assertEquals "ada could not list the correct file" "/${disk_path}/${dirname}/${testdir}/${filename}" "$result"
}


test_ada_checksum_file() {
    ada/ada --tokenfile ${token_file} --checksum "/${disk_path}/${dirname}/${testdir}/${filename}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "${filename}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}


test_ada_checksum_dir() {
    ada/ada --tokenfile ${token_file} --checksum "/${disk_path}/${dirname}/${testdir}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "${filename}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}


test_ada_list_dir() {
    ada/ada --tokenfile ${token_file} --list "/${disk_path}/${dirname}/${testdir}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "${filename}" "${stdoutF}" >/dev/null
    assertTrue "ada could not list the correct directory" $?
}


test_ada_longlist() {
    ada/ada --tokenfile ${token_file} --longlist "/${disk_path}/${dirname}/${testdir}/${filename}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "${filename}" "${stdoutF}" >/dev/null
    assertTrue "ada could not longlist the correct file" $?
}


test_ada_stat() {
    ada/ada --tokenfile ${token_file} --stat "/${disk_path}/${dirname}/${testdir}/${filename}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "${filename}" "${stdoutF}" >/dev/null
    assertTrue "ada could not stat the correct file" $?
}


# Move file back to original folder
test_ada_mv2() {
    ada/ada --tokenfile ${token_file} --mv "/${disk_path}/${dirname}/${testdir}/${filename}" "/${disk_path}/${dirname}/${filename}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not move the file back" $?
}

# Delete test directory
test_ada_delete() {
    ada/ada --tokenfile ${token_file} --delete "/${disk_path}/${dirname}/${testdir}" --recursive --api ${api_url} --force >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not delete the directory" $?
}


test_ada_stage_file() {
    ada/ada --tokenfile ${token_file} --stage "${tape_path}/${filestage}" --api ${api_url} >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result}
    grep "${filestage}" "${stdoutF}" >/dev/null
    assertTrue "ada could not stage the file" $?
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
 
    # Define test files and directories
    dirname="integration_test"
    filename="1GBfile"
    filestage="2GBfile"
    testdir="testdir"
    subdir="subdir"

}

# Load and run shunit2
. shunit2