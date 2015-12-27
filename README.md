commit 8846f09945a143fb75ef3cda975d08fd12bbc3f6
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:02:19 2015 -0800

    Ignore vagrant files

diff --git a/.gitignore b/.gitignore
new file mode 100644
index 0000000..8000dd9
--- /dev/null
+++ b/.gitignore
@@ -0,0 +1 @@
+.vagrant

commit e87e0cd437d80d55284b54afd78c126ea2342c0e
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:02:28 2015 -0800

    Set ruby version to 2.2.2

diff --git a/.ruby-version b/.ruby-version
new file mode 100644
index 0000000..b1b25a5
--- /dev/null
+++ b/.ruby-version
@@ -0,0 +1 @@
+2.2.2

commit c7bed3dcaea1688782f1de9bc9033be20b148ca0
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:02:53 2015 -0800

    Ignore test results

diff --git a/.gitignore b/.gitignore
index 8000dd9..24f39ff 100644
--- a/.gitignore
+++ b/.gitignore
@@ -1 +1,2 @@
 .vagrant
+result.test.txt

commit a7861d7bec70648a82bb7b9f256d8d2bb5b54415
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:03:26 2015 -0800

    Add a vagrant vm for testing
    
    It builds the docker image on provision

diff --git a/Vagrantfile b/Vagrantfile
new file mode 100644
index 0000000..f249a32
--- /dev/null
+++ b/Vagrantfile
@@ -0,0 +1,18 @@
+Vagrant.configure(2) do |config|
+
+    # ==> Choose a Vagrant box to emulate Linux distribution...
+    config.vm.box = "williamyeh/ubuntu-trusty64-docker"
+
+    config.vm.define "ansible-docker-test" do |machine|
+      machine.vm.provider "virtualbox"
+    end
+
+    # ==> Executing Ansible...
+    config.vm.provision "shell", inline: <<-SHELL
+      cd /vagrant
+      docker build -t test-box .
+    SHELL
+
+end
+
+

commit 67398b1d938ebe487ac6cd323f06189bc5bf640b
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:04:44 2015 -0800

    Run the Ansible wrapper in the docker build.
    
    Uses the fabulous Ansible docker image from
    https://hub.docker.com/r/williamyeh/ansible/
    https://github.com/William-Yeh/docker-ansible

diff --git a/Dockerfile b/Dockerfile
new file mode 100644
index 0000000..162117f
--- /dev/null
+++ b/Dockerfile
@@ -0,0 +1,2 @@
+FROM williamyeh/ansible:ubuntu14.04-onbuild
+RUN ansible-playbook-wrapper

commit 946cafb1325c281d22942009db3b32c03754e456
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:06:30 2015 -0800

    Add a (broken) playbook which adds a file to test against.
    
    These simple tasks represent the configuration that you would be
    doing in your normal playbook. In this case, we’re just touching
    a file which we can then test against later.
    
    You'll note that on line 6, this playbook actually sets the file as
    "absent." This is because whenever we're writing a test, we want to
    make sure it works by making sure it is Red, or broken. For more
    on this process, google for "Red Green Refactor" and you'll find many
    resources on the philosophy behind this.
    
    See the docker image https://github.com/William-Yeh/docker-ansible
    which explains that the base docker image we're using here defaults
    to a playbook location of `./playbook.yml`. You can change this
    following his instructions.

diff --git a/playbook.yml b/playbook.yml
new file mode 100644
index 0000000..826064c
--- /dev/null
+++ b/playbook.yml
@@ -0,0 +1,7 @@
+---
+- name: Sample Play
+  hosts: all
+  tasks:
+  - file: path=/foo state=directory
+  - file: path=/foo/test.txt state=absent
+

commit bfa2c6677eb7250379248da27c79977699510524
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:07:32 2015 -0800

    Add a test file that returns non-zero if anything fails
    
    This file runs an `ls` command on the file which should be there from the Ansible play. If it was not successful, then the playbook doesn’t work.

diff --git a/test.sh b/test.sh
new file mode 100755
index 0000000..4b9108a
--- /dev/null
+++ b/test.sh
@@ -0,0 +1,4 @@
+set -e
+docker run -i test-box ls /foo/test.txt > result.test.txt
+echo "==> Validating the test results..."
+sh -c 'grep "foo/test.txt" result.test.txt'

commit 0b8fd2804bc13773822995d94538e7d71b459795
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:08:24 2015 -0800

    Add a CircleCI configuration file
    
    It builds the docker container, calling it `test-box`. In the tests, it runs the test file created earlier.

diff --git a/circle.yml b/circle.yml
new file mode 100644
index 0000000..6708e81
--- /dev/null
+++ b/circle.yml
@@ -0,0 +1,14 @@
+machine:
+  services:
+    - docker
+
+dependencies:
+  override:
+    - docker info
+    - docker version
+    - docker build  -t test-box .
+
+test:
+  override:
+    - sh -c ./test.sh 
+

commit 0da9d1a89855f727fb6d46ea394a186a3b0fd7c1
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:26:00 2015 -0800

    Fix the playbook so that the tests go green.
    
    Previously, after you have connected your project to CircleCI, you
    should see the that build was broken with a message similar to
    ```
    ls: cannot access /foo/test.txt: No such file or directory sh -c ./test.sh
    returned exit code 2
    ```
    
    You should now see
    ```
    ==> Validating the test results...
    /foo/test.txt
    ```

diff --git a/playbook.yml b/playbook.yml
index 826064c..6099cfe 100644
--- a/playbook.yml
+++ b/playbook.yml
@@ -3,5 +3,5 @@
   hosts: all
   tasks:
   - file: path=/foo state=directory
-  - file: path=/foo/test.txt state=absent
+  - file: path=/foo/test.txt state=touch
 

commit 7973ccb7230ad2db11bd3ce973bdcfe8573455bd
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 10:39:39 2015 -0800

    Cache the docker image after every build.
    
    Due to the large base image docker image, we're saving the produced
    docker image to ~/docker/image.tar, which is cached, and loading it
    before building. This avoids having to download it from outside
    CircleCI's network.
    
    For more information check out https://circleci.com/docs/docker
    
    An in depth use case can be found at
    http://tschottdorf.github.io/cockroach-docker-circleci-continuous-integration/

diff --git a/circle.yml b/circle.yml
index 6708e81..1bde2f0 100644
--- a/circle.yml
+++ b/circle.yml
@@ -3,10 +3,16 @@ machine:
     - docker
 
 dependencies:
+  cache_directories:
+    - "~/docker"
   override:
     - docker info
     - docker version
-    - docker build  -t test-box .
+    - if [[ -e ~/docker/image.tar ]]; then docker load -i ~/docker/image.tar; fi
+    - docker build --rm=false -t testbox .
+    #TODO: we should only do this on a successful build.
+    #TODO: make sure we're actually using the cached image.
+    - mkdir -p ~/docker; docker save testbox > ~/docker/image.tar
 
 test:
   override:
diff --git a/test.sh b/test.sh
index 4b9108a..0b00b1e 100755
--- a/test.sh
+++ b/test.sh
@@ -1,4 +1,4 @@
 set -e
-docker run -i test-box ls /foo/test.txt > result.test.txt
+docker run -i testbox ls /foo/test.txt > result.test.txt
 echo "==> Validating the test results..."
 sh -c 'grep "foo/test.txt" result.test.txt'

commit 99ae6f9df5d6cd670db73a93e8ce1711eaa76145
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 13:04:55 2015 -0800

    Make a small chance to test caching.

diff --git a/playbook.yml b/playbook.yml
index 6099cfe..62243f1 100644
--- a/playbook.yml
+++ b/playbook.yml
@@ -3,5 +3,5 @@
   hosts: all
   tasks:
   - file: path=/foo state=directory
-  - file: path=/foo/test.txt state=touch
+  - file: path=/foo/testfile.txt state=touch
 
diff --git a/test.sh b/test.sh
index 0b00b1e..9187e25 100755
--- a/test.sh
+++ b/test.sh
@@ -1,4 +1,4 @@
 set -e
-docker run -i testbox ls /foo/test.txt > result.test.txt
+docker run -i testbox ls /foo/testfile.txt > result.test.txt
 echo "==> Validating the test results..."
-sh -c 'grep "foo/test.txt" result.test.txt'
+sh -c 'grep "foo/testfile.txt" result.test.txt'

commit 2febca8b2c979c245133b305ed908fed25445f2b
Author: Kevin Fitzpatrick <kevin@influxdb.com>
Date:   Sun Dec 27 13:21:33 2015 -0800

    Another small change to test caching

diff --git a/playbook.yml b/playbook.yml
index 62243f1..9828d25 100644
--- a/playbook.yml
+++ b/playbook.yml
@@ -3,5 +3,5 @@
   hosts: all
   tasks:
   - file: path=/foo state=directory
-  - file: path=/foo/testfile.txt state=touch
+  - file: path=/foo/file.txt state=touch
 
diff --git a/test.sh b/test.sh
index 9187e25..7067b62 100755
--- a/test.sh
+++ b/test.sh
@@ -1,4 +1,4 @@
 set -e
-docker run -i testbox ls /foo/testfile.txt > result.test.txt
+docker run -i testbox ls /foo/file.txt > result.test.txt
 echo "==> Validating the test results..."
-sh -c 'grep "foo/testfile.txt" result.test.txt'
+sh -c 'grep "foo/file.txt" result.test.txt'
