load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.multiservers.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip 'only used to call setup_file from setup'
}

@test "check: each certificate is copied on different servers" {

  # wait until certificates is generated
  run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_traefik_1 | grep -F \"Adding certificate for domain(s) mail.localhost.com\""

  # test certificate is dumped
  run repeat_until_success_or_timeout 30 sh -c "docker exec ${TEST_STACK_NAME}_mailserver-traefik_1 ls /tmp/ssl | grep mail.localhost.com"


  # test presence of certificate
  run docker exec "${TEST_STACK_NAME}_mailserver-traefik_1" ls /tmp/ssl/mail.localhost.com/
  assert_output --partial 'fullchain.pem'
  assert_output --partial 'privkey.pem'
  # register fingerprint of certificates
  fp_mailserver=$( docker exec "${TEST_STACK_NAME}_mailserver-traefik_1" sha256sum /tmp/ssl/mail.localhost.com/fullchain.pem | awk '{print $1}' )


  # test posthook certificate is triggered on each server
  run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F '[INFO] server1.localhost.com - Cert update: new certificate copied into container'"
  assert_success
  run repeat_until_success_or_timeout 10 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F '[INFO] server2.localhost.com - Cert update: new certificate copied into container'"
  assert_success

  # test presence of certificates
  run docker exec "${TEST_STACK_NAME}_mailserver1_1" ls /etc/postfix/ssl/
  assert_output --partial 'cert'
  assert_output --partial 'key'
  run docker exec "${TEST_STACK_NAME}_mailserver2_1" ls /etc/postfix/ssl/
  assert_output --partial 'cert'
  assert_output --partial 'key'

  # compare fingerprints in mailserver container
  fp_mailserver1_target=$( docker exec "${TEST_STACK_NAME}_mailserver1_1" sha256sum /etc/postfix/ssl/cert | awk '{print $1}')
  assert_equal "$fp_mailserver1_target" "$fp_mailserver"
  fp_mailserver2_target=$( docker exec "${TEST_STACK_NAME}_mailserver2_1" sha256sum /etc/postfix/ssl/cert | awk '{print $1}' )
  assert_equal "$fp_mailserver2_target" "$fp_mailserver"
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
