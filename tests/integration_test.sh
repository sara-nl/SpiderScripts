#!/usr/bin/env bash
# file: tests/integration_test.sh


# Check if version is as expected
test_ada_version() {
    result=`ada/ada --version`
    assertEquals "Check ada version:" "v3.1" ${result}
}

# Check whoami
test_ada_whoami() {
    command="ada/ada --whoami --tokenfile ${token_file} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep $user "${stdoutF}" >/dev/null
    assertTrue "ada whoami did not give correct username" $?
}

# Create directory on dCache
test_ada_mkdir() {
    command="ada/ada --tokenfile ${token_file} --mkdir /${disk_path}/${dirname}/${testdir}/${subdir} --recursive --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not create the directory" $? || return
    is_dir "/${disk_path}/${dirname}/${testdir}/${subdir}"
    assertTrue "is not a directory" $?
}


# List channels
test_ada_channels() {
    for channelname in test1 test2; do    
        command="ada/ada --tokenfile ${token_file} --channels ${channelname} --api ${api}"
        echo "Running command:"
        echo $command
        eval $command >${stdoutF} 2>${stderrF}
        result=$?
        assertEquals "ada returned error code ${result}" 0 ${result} || return
        if [[ -z $(grep '[^[:space:]]' $stdoutF) ]] ; then
            echo "Channel ${channelname} does not exist yet, creating it."
            command="ada/ada --tokenfile ${token_file} --events ${channelname} /${disk_path}/${dirname}/${testdir} --recursive --api ${api} --timeout 60"
            eval $command >${stdoutE} 2>${stderrF} &
            sleep 3
            #check if the channel has been created
            command="ada/ada --tokenfile ${token_file} --channels ${channelname} --api ${api}"
            eval $command >${stdoutF} 2>${stderrF}
            if [[ -z $(grep '[^[:space:]]' $stdoutF) ]] ; then
                assertTrue "Unable to create channel ${channelname}" 1
            fi
        fi
    done
}

# Subscribe to events in dCache folder
test_ada_events() {
    command="ada/ada --tokenfile ${token_file} --events test1 /${disk_path}/${dirname}/${testdir} --recursive --api ${api} --timeout 60 --resume --force"
    echo "Running command:"
    echo $command
    eval $command >${stdoutE} 2>${stderrF} &
    sleep 3
    grep "path=/${disk_path}/${dirname}/${testdir}" "${stdoutE}" >/dev/null
    assertTrue "ada could not subscribe to events" $?
}

# Test error if channelname is already used
test_ada_events_duplicate_channelname() {
    command="ada/ada --tokenfile ${token_file} --events test1 /${disk_path}/${dirname}/${testdir} --recursive --api ${api} --timeout 60"
    echo "Running command:"
    echo $command
    eval $command >${stdoutE} 2>${stderrF}
    result=$?
    assertEquals "ada did not return error code 1 as expected" 1 ${result} || return    
    grep "ERROR" "${stderrF}" >/dev/null
    assertTrue "ada events did not return ERROR message as expected" $?
}

# Move a file (created in oneTimeSetUp) to folder created in above test
test_ada_mv1() {
    command="ada/ada --tokenfile ${token_file} --mv /${disk_path}/${dirname}/${testfile} /${disk_path}/${dirname}/${testdir}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not move the file" $?
}

# Check detection of event in dCache folder
test_ada_detect_event() {
    sleep 3
    grep "inotify  /${disk_path}/${dirname}/${testdir}/${testfile}  IN_MOVED_TO" "${stdoutE}"
    assertTrue "ada did not detect event IN_MOVED_TO" $?
}

# List file
test_ada_list_file() {
    command="ada/ada --tokenfile ${token_file} --list /${disk_path}/${dirname}/${testdir}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "ada could not list the correct file" "/${disk_path}/${dirname}/${testdir}/${testfile}" "$result"
}

# Set label on a file
test_ada_setlabel() {
    command="ada/ada --tokenfile ${token_file} --setlabel /${disk_path}/${dirname}/${testdir}/${testfile} testlabel --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "success" "$result"
}

# Find files in directory with specified label
test_ada_findlabel() {
    command="ada/ada --tokenfile ${token_file} --findlabel /${disk_path}/${dirname}/${testdir} testlabel --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not find file with findlabel" $?
}

# List label of file
test_ada_lslabel() {
    command="ada/ada --tokenfile ${token_file} --lslabel /${disk_path}/${dirname}/${testdir}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "testlabel" "$result"
}

# Remove label of file
test_ada_rmlabel() {
    command="ada/ada --tokenfile ${token_file} --rmlabel "/${disk_path}/${dirname}/${testdir}/${testfile}" "testlabel" --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    result=`cat "${stdoutF}"`
    assertEquals "success" "$result"
}

# Set extended attribute of file
test_ada_setxattr() {
    command="ada/ada --tokenfile ${token_file} --setxattr /${disk_path}/${dirname}/${testdir}/${testfile} ${outputDir}/attr_file --api ${api}"
    echo "test=attribute" > ${outputDir}/attr_file
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not set extended attribute" $?
}

# List extended attribute of file
test_ada_lsxattr() {
    command="ada/ada --tokenfile ${token_file} --lsxattr /${disk_path}/${dirname}/${testdir}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep '"test": "attribute"' "${stdoutF}" >/dev/null
    assertTrue "ada could not list extended attribute" $?
}

# Find file with attribute with key-value pair
test_ada_findxattr() {
    command="ada/ada --tokenfile ${token_file} --findxattr /${disk_path}/${dirname}/${testdir} test attribute --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not find file with extended attribute" $?
}

# Remove all attributes of file
test_ada_rmxattr() {
    command="ada/ada --tokenfile ${token_file} --rmxattr /${disk_path}/${dirname}/${testdir}/${testfile} --all --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
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
    command="ada/ada --tokenfile ${token_file} --checksum /${disk_path}/${dirname}/${testdir}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}

# Get checksum of files in a directory
test_ada_checksum_dir() {
    command="ada/ada --tokenfile ${token_file} --checksum /${disk_path}/${dirname}/${testdir} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not get checksum of file" $?
}

# List files in directory
test_ada_list_dir() {
    command="ada/ada --tokenfile ${token_file} --list /${disk_path}/${dirname}/${testdir} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not list the correct directory" $?
}

# List files in directory with details
test_ada_longlist() {
    command="ada/ada --tokenfile ${token_file} --longlist /${disk_path}/${dirname}/${testdir}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not longlist the correct file" $?
}

# Show all details of file or directory
test_ada_stat() {
    command="ada/ada --tokenfile ${token_file} --stat /${disk_path}/${dirname}/${testdir}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "${testfile}" "${stdoutF}" >/dev/null
    assertTrue "ada could not stat the correct file" $?
}

# Move file back to original folder
test_ada_mv2() {
    command="ada/ada --tokenfile ${token_file} --mv /${disk_path}/${dirname}/${testdir}/${testfile} /${disk_path}/${dirname}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not move the file back" $?
}

# Delete test directory
test_ada_delete() {
    command="ada/ada --tokenfile ${token_file} --delete /${disk_path}/${dirname}/${testdir} --recursive --api ${api} --force"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    grep "success" "${stdoutF}" >/dev/null
    assertTrue "ada could not delete the directory" $?
}

# Subscribe to staging events in dCache folder
test_ada_report_staged() {
    command="ada/ada --tokenfile ${token_file} --report-staged test2 /${tape_path}/${dirname} --recursive --api ${api} --timeout 60 --resume --force"
    echo "Running command:"
    echo $command
    eval $command >${stdoutR} 2>${stderrF} &
    sleep 3
    grep "path=/${tape_path}/${dirname}" "${stdoutR}" >/dev/null
    assertTrue "ada could not subscribe to staging events" $?
}

# Test error if channelname is already used
test_ada_report_staged_duplicate_channelname() {
    command="ada/ada --tokenfile ${token_file} --report-staged test2 /${disk_path}/${dirname}/${testdir} --recursive --api ${api} --timeout 60"
    echo "Running command:"
    echo $command
    eval $command >${stdoutE} 2>${stderrF}
    result=$?
    assertEquals "ada did not return error code 1 as expected" 1 ${result} || return    
    grep "ERROR" "${stderrF}" >/dev/null
    assertTrue "ada report-staged did not return ERROR message as expected" $?
}

# Delete channels
test_ada_delete_channels() {
    for channelname in test1 test2; do    
        command="ada/ada --tokenfile ${token_file} --delete-channel ${channelname} --api ${api}"
        echo "Running command:"
        echo $command
        eval $command
        result=$?
        assertEquals "ada returned error code ${result}" 0 ${result} || return
        #check if the channel has been deleted
        command="ada/ada --tokenfile ${token_file} --channels ${channelname} --api ${api}"
        eval $command >${stdoutF} 2>${stderrF}
        if [[ -z $(grep '[^[:space:]]' $stdoutF) ]] ; then
            echo "Channel ${channelname} has been deleted"
        else
            assertTrue "Unable to delete channel ${channelname}"  1    
        fi
    done
}

# Stage a file
test_ada_stage_file() {
    command="ada/ada --tokenfile ${token_file} --stage /${tape_path}/${dirname}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
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
    command="ada/ada --tokenfile ${token_file} --unstage /${tape_path}/${dirname}/${testfile} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    sleep 2 # needed if request is still RUNNING
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "COMPLETED" $state
}

# Stage a directory
test_ada_stage_dir() {
    command="ada/ada --tokenfile ${token_file} --stage /${tape_path}/${dirname} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    sleep 2 # needed if request is still RUNNING
    # directory should be SKIPPED
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "SKIPPED" $state
    # file should COMPLETED   
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[1].state'`
    assertEquals "State of target:" "COMPLETED" $state    
}

# Unstage a directory based on request_id
# And get status of request_id
# Note: this function uses ${stdoutF} from previous function
# So do not overwrite in between
test_ada_request_id() {
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    request_id=$(basename "$request_url")
    command="ada/ada --tokenfile ${token_file} --unstage /${tape_path}/${dirname}/${dirfile} --request-id ${request_id} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    request_url=`grep "request-url" "${stdoutF}" | awk '{print $2}' | tr -d '\r'`
    assertNotNull "No request-url found" $request_url || return
    sleep 2 # needed if request is still RUNNING
    # directory should be SKIPPED    
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[0].state'`
    assertEquals "State of target:" "SKIPPED" $state
    # file should COMPLETED      
    state=`curl -X GET "${request_url}" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.targets[1].state'`
    assertEquals "State of target:" "COMPLETED" $state

    # Test status of request id, we do this in same test function because we need same request-id
    command="ada/ada --tokenfile ${token_file} --stat-request ${request_id} --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
    result=$?
    assertEquals "ada returned error code ${result}" 0 ${result} || return
    uid=`cat "${stdoutF}" | jq -r '.uid'`
    echo $uid
    assertEquals ${uid} ${request_id}
}

# Stages files in file_list
test_ada_stage_filelist() {
    command="ada/ada --tokenfile ${token_file} --stage --from-file ${outputDir}/file_list  --api ${api}"
    echo  "/${tape_path}/${dirname}/${testfile}" > ${outputDir}/file_list
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
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
    command="ada/ada --tokenfile ${token_file} --unstage --from-file ${outputDir}/file_list --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
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
    command="ada/ada --tokenfile ${token_file} --stage /${tape_path}/${dirname}/testerror --api ${api}"
    echo "Running command:"
    echo $command
    eval $command >${stdoutF} 2>${stderrF}
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
    stdoutE="${outputDir}/events"
    stdoutR="${outputDir}/report-staged"
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
    # Check if root: caveat is set correctly.
    ada/ada --viewtoken --tokenfile "$token_file" | grep "cid root"  >/dev/null
    result=$?
    if [ $chroot = true ] && [ $result -eq 1 ] ; then # expecting macaroon with root: caveat
        error=1
    elif [ $chroot = false ] && [ $result -eq 0 ] ; then # expecting macaroon without root: caveat    
        error=1
    fi
    if [ $error -eq 1 ]; then
        echo "The tests expect a valid macaroon. Please enter your CUA credentials to create one."
        if [ $chroot = true ] ; then
           get-macaroon --chroot --url "${webdav_url}"/"${user_path}" --duration P1D --user $user --permissions DOWNLOAD,UPLOAD,DELETE,MANAGE,LIST,READ_METADATA,UPDATE_METADATA,STAGE --output rclone $(basename "${token_file%.*}")
        else
           get-macaroon --url "${webdav_url}"/"${user_path}" --duration P1D --user $user --permissions DOWNLOAD,UPLOAD,DELETE,MANAGE,LIST,READ_METADATA,UPDATE_METADATA,STAGE --output rclone $(basename "${token_file%.*}")
        fi
        if [ $? -eq 1 ]; then 
            echo "Failed to create a macaroon. Aborting." 
            exit 
        fi
        token=$(sed -n 's/^bearer_token *= *//p' "$token_file")
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
