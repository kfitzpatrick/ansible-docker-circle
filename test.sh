set -e
docker run -i test-box ls /foo/test.txt > result.test.txt
echo "==> Validating the test results..."
sh -c 'grep "foo/test.txt" result.test.txt'
