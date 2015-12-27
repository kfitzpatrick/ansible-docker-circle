set -e
docker run -i testbox ls /foo/file.txt > result.test.txt
echo "==> Validating the test results..."
sh -c 'grep "foo/file.txt" result.test.txt'
