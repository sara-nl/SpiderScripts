#!/usr/bin/env bash
# file: tests/unit_test.sh


test_urlencode() {
  result=`urlencode "/test/a/b/c"`
  expected="%2Ftest%2Fa%2Fb%2Fc"
  assertEquals \
      "the result of url_encode() was wrong" \
      "${expected}" "${result}"
}


test_pathtype() {
  result=`pathtype "/test/a/b/c"`
  expected='$debug && set -x
          curl "${curl_authorization[@]}" \
          -H "accept: application/json" \
          --silent \
          -X GET "$api/namespace/$encoded_path"'
  assertEquals \
      "the result of pathtype() was wrong" \
      "${expected}" "${result}"
}


test_create_path() {
  # Check error handling when incorrect path is given  
  counter=0
  ( create_path "/test/a" true >${stdoutF} 2>${stderrF} )
  result=$?
  assertFalse "expecting return code of 1 (false)" ${result}
  grep "ERROR: Unable to create dirs. Check the specified path" "${stderrF}" >/dev/null
  assertTrue "STDERR message incorrect" $?

  # Check error handling when parent does not exist
  ( create_path "/test/a" false >${stdoutF} 2>${stderrF} )
  result=$?
  assertFalse "expecting return code of 1 (false)" ${result}
  grep "ERROR: parent dir '/test' does not exist. To recursively create dirs, add --recursive" "${stderrF}" >/dev/null
  assertTrue 'STDERR message incorrect' $?

  # Check error handling when max number of directories is exceeded 
  counter=10
  ( create_path "/test/a" true >${stdoutF} 2>${stderrF} )
  result=$?
  assertFalse "expecting return code of 1 (false)" ${result}
  grep "ERROR: max number of directories that can be created at once is 10" "${stderrF}" >/dev/null
  assertTrue "STDERR message incorrect" $?
}


test_get_pnfsid() {
  result=`get_pnfsid "/test/a/b/c"`
  expected='curl "${curl_authorization[@]}" \
           "${curl_options_no_errors[@]}" \
           -X GET "$api/namespace/$path" \
           | jq -r .pnfsId'
  assertEquals \
      "the result of get_pnfsid() was wrong" \
      "${expected}" "${result}"  
}


test_is_online() {
  result=`is_online "/test/a/b/c"`
  expected='curl "${curl_authorization[@]}" \
           "${curl_options_no_errors[@]}" \
           -X GET "$api/namespace/$path?locality=true&qos=true" \
           | jq -r ".fileLocality" \
           | grep --silent "ONLINE"'
  assertEquals \
      "the result of is_online() was wrong" \
      "${expected}" "${result}"  
}


test_get_subdirs() {
  result=`get_subdirs "/test/a/b/c"`
  expected='curl "${curl_authorization[@]}" \
           "${curl_options_common[@]}" \
           -X GET "$api/namespace/$path?children=true" \
           | jq -r "$str"'
  assertEquals \
      "the result of get_subdirs() was wrong" \
      "${expected}" "${result}"
}


test_get_files_in_dir() {
  result=`get_files_in_dir "/test/a/b/c"`
  expected='curl "${curl_authorization[@]}" \
           "${curl_options_common[@]}" \
           -X GET "$api/namespace/$path?children=true" \
           | jq -r "$str"'
  assertEquals \
      "the result of get_files_in_dir() was wrong" \
      "${expected}" "${result}"
}


test_get_children() {
  result=`get_files_in_dir "/test/a/b/c"`
  expected='curl "${curl_authorization[@]}" \
           "${curl_options_common[@]}" \
           -X GET "$api/namespace/$path?children=true" \
           | jq -r "$str"'
  assertEquals \
      "the result of get_files_in_dir() was wrong" \
      "${expected}" "${result}"
}


test_get_permissions() {
  result=`get_permissions "${stdoutF}"`
  expected='-rw-r-----'  #check if default permission is 744
  assertEquals \
      "the result of get_permissions() was wrong" \
      "${expected}" "${result}"
}


test_check_authentication() {
  result=`check_authentication`
  expected='$debug && set -x
           curl "${curl_authorization[@]}" \
           "${curl_options_common[@]}" \
           -X GET "$api/user" \
           | jq -r .status '
  assertEquals \
      "the result of check_authentication() was wrong" \
      "${expected}" "${result}"
}


oneTimeSetUp() {
  # We need a predictable umask for the test_get_permissions.
  umask 027
  #
  outputDir="${SHUNIT_TMPDIR}/output"
  mkdir "${outputDir}"
  stdoutF="${outputDir}/stdout"
  stderrF="${outputDir}/stderr"
  debug=false
  dry_run=true

  # Load functions to test
  . ada/ada
}


# Load and run shunit2
. shunit2
