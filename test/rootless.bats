#!/usr/bin/env bats

: ${DOCKER:=docker}
: ${PODMAN_IMAGE:=mgoltzsche/podman:latest}
: ${TEST_PREFIX:=rootless}

PODMAN_ROOT_DATA_DIR="$BATS_TEST_DIRNAME/../build/test-storage/user"

load test_helper.bash

teardown_file() {
	$DOCKER run --rm --privileged -u podman:podman \
		-v "$PODMAN_ROOT_DATA_DIR:/podman/.local/share/containers/storage" \
		--mount="type=bind,src=`pwd`/test/pod.yaml,dst=/pod.yaml" \
		--pull=never "${PODMAN_IMAGE}" \
		podman pod rm -f mypod || true
}

@test "$TEST_PREFIX podman - internet connectivity (using netavark + pasta)" {
	$DOCKER run --rm --privileged -u podman:podman \
		-v "$PODMAN_ROOT_DATA_DIR:/podman/.local/share/containers/storage" \
		--pull=never "${PODMAN_IMAGE}" \
		docker run --rm alpine:3.22 wget -O /dev/null http://example.org
}

@test "$TEST_PREFIX podman - uid mapping (using fuse-overlayfs) {
	$DOCKER run --rm --privileged -u podman:podman \
		-v "$PODMAN_ROOT_DATA_DIR:/podman/.local/share/containers/storage" \
		--pull=never "${PODMAN_IMAGE}" \
		docker run --rm alpine:3.22 /bin/sh -c 'set -ex; touch /file; chown guest /file; [ $(stat -c %U /file) = guest ]'
}

@test "$TEST_PREFIX podman - unmapped uid" {
	$DOCKER run --rm --privileged --user 9000:9000 -e HOME=/tmp \
		--pull=never "${PODMAN_IMAGE}" \
		docker run --rm alpine:3.22 wget -O /dev/null http://example.org
}

@test "$TEST_PREFIX podman - build image from dockerfile" {
	$DOCKER run --rm --privileged -u podman:podman --entrypoint /bin/sh \
		-v "$PODMAN_ROOT_DATA_DIR:/podman/.local/share/containers/storage" \
		--pull=never "${PODMAN_IMAGE}" \
		-c 'set -e;
			podman build -t podmantestimage -f - . <<-EOF
				FROM alpine:3.22
				RUN echo hello world > /hello
				CMD ["/bin/cat", "/hello"]
			EOF'
}

@test "$TEST_PREFIX podman - port forwarding" {
	if [ "${TEST_SKIP_PORTMAPPING:-}" = true ]; then
		skip "TEST_SKIP_PORTMAPPING=true"
	fi
	testPortForwarding -u podman:podman -v "$PODMAN_ROOT_DATA_DIR:/podman/.local/share/containers/storage" "${PODMAN_IMAGE}"
}

@test "$TEST_PREFIX podman - play kube" {
	if [ "${TEST_SKIP_PLAYKUBE:-}" = true ]; then
		# Otherwise minimal podman fails with "Error: unable to find network with name or ID podman-default-kube-network: network not found"
		skip "TEST_SKIP_PLAYKUBE=true"
	fi
	$DOCKER run --rm --privileged -u podman:podman \
		-v "$PODMAN_ROOT_DATA_DIR:/podman/.local/share/containers/storage" \
		--mount="type=bind,src=`pwd`/test/pod.yaml,dst=/pod.yaml" \
		--pull=never "${PODMAN_IMAGE}" \
		podman play kube /pod.yaml
}
