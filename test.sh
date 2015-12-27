set -e
docker run -i testbox ls /foo/testfile.txt > result.test.txt
echo "==> Validating the test results..."
sh -c 'grep "foo/testfile.txt" result.test.txt'
