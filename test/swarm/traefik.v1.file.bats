load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../test_helper/common'


function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/../files/docker-compose.swarm.traefik.v1.file.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: SWARM $( basename $BATS_TEST_FILENAME )"
}

@test "check: initial pull certificates in mailserver with 1 mailserver" {
    cert_renewer_id=$(getFirstContainerOfServiceName "cert-renewer")
    mailserver_id=$(getFirstContainerOfServiceName "mailserver")

    # test certificates are dumped
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker exec ${cert_renewer_id} ls /tmp/ssl | grep mail.localhost.com"
    assert_success

    # test posthook certificate is triggered
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${cert_renewer_id} | grep -F '[INFO] ${mailserver_id} - Cert update: new certificate copied into container'"
    assert_success

    # test presence of certificates
    run docker exec "${mailserver_id}" ls /etc/postfix/ssl/
    assert_output --partial 'cert'
    assert_output --partial 'key'
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  docker stack rm "$TEST_STACK_NAME"
  waitSwarmStackDown
  autoCleanSwarmStackVolumes

  initSwarmAcmejson
  docker stack deploy --compose-file "$DOCKER_FILE_TESTS" "$TEST_STACK_NAME"
  waitUntilStackCountRunningServices 5
  waitUntilTraefikReady
  statusStack
}

teardown_file() {
  docker stack rm "$TEST_STACK_NAME"
  waitSwarmStackDown
  autoCleanSwarmStackVolumes
}

